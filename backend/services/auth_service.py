"""
Authentication and authorization service for BabbleOn backend.
Handles JWT token validation with Supabase integration.
"""

import os
import jwt
import time
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from fastapi import HTTPException, Request
from pydantic import BaseModel
import logging
import httpx
from functools import wraps
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientError, InvalidTokenError

logger = logging.getLogger(__name__)

class UserInfo(BaseModel):
    """User information extracted from JWT token"""
    user_id: str
    email: Optional[str] = None
    is_anonymous: bool = False
    user_metadata: Dict[str, Any] = {}
    app_metadata: Dict[str, Any] = {}

class AuthService:
    """Authentication service for JWT token validation"""
    
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_anon_key = os.getenv("SUPABASE_ANON_KEY")
        
        if not self.supabase_url:
            logger.warning("Supabase URL missing - authentication will be disabled")
            self.enabled = False
        else:
            # Extract project configuration for JWKS
            self.project_id = self.supabase_url.split('//')[1].split('.')[0]
            self.jwks_url = f"{self.supabase_url}/auth/v1/.well-known/jwks.json"
            self.issuer = f"{self.supabase_url}/auth/v1"
            
            # Initialize JWKS client with caching for performance
            try:
                self.jwk_client = PyJWKClient(self.jwks_url, cache_keys=True)
                self.enabled = True
                logger.info(f"Auth service initialized with JWKS endpoint: {self.jwks_url}")
            except Exception as e:
                logger.error(f"Failed to initialize JWKS client: {e}")
                self.enabled = False
    
    def verify_jwt_token(self, token: str) -> Optional[UserInfo]:
        """
        Verify JWT token using JWKS endpoint (modern Supabase approach)
        
        Args:
            token: JWT token string
            
        Returns:
            UserInfo object if token is valid, None otherwise
        """
        if not self.enabled:
            # For development - return a default user when auth is disabled
            return UserInfo(
                user_id="dev_user", 
                email="dev@babblelon.local",
                is_anonymous=False
            )
        
        try:
            # Remove 'Bearer ' prefix if present
            if token.startswith('Bearer '):
                token = token[7:]
            
            # Get the signing key from JWKS endpoint
            signing_key = self.jwk_client.get_signing_key_from_jwt(token)
            
            # Verify and decode the JWT with modern algorithms (ES256/RS256)
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256", "RS256"],  # Modern asymmetric algorithms
                audience="authenticated",
                issuer=self.issuer
            )
            
            # Extract user information
            user_info = UserInfo(
                user_id=payload.get("sub", ""),
                email=payload.get("email"),
                is_anonymous=payload.get("role") == "anon",
                user_metadata=payload.get("user_metadata", {}),
                app_metadata=payload.get("app_metadata", {})
            )
            
            logger.info(f"Successfully authenticated user via JWKS: {user_info.user_id}")
            return user_info
            
        except PyJWKClientError as e:
            logger.error(f"Failed to fetch JWKS: {e}")
            return None
        except jwt.ExpiredSignatureError:
            logger.warning("JWT token has expired")
            return None
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid JWT token: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error verifying JWT: {e}")
            return None
    
    def extract_token_from_request(self, request: Request) -> Optional[str]:
        """
        Extract JWT token from request headers
        
        Args:
            request: FastAPI request object
            
        Returns:
            JWT token string if found, None otherwise
        """
        # Check Authorization header
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            return auth_header
        
        # Check X-Access-Token header (alternative)
        access_token = request.headers.get("X-Access-Token")
        if access_token:
            return f"Bearer {access_token}"
        
        return None
    
    def authenticate_request(self, request: Request) -> UserInfo:
        """
        Authenticate request and return user information
        
        Args:
            request: FastAPI request object
            
        Returns:
            UserInfo object for authenticated user
            
        Raises:
            HTTPException: If authentication fails
        """
        # Extract token from request
        token = self.extract_token_from_request(request)
        if not token:
            raise HTTPException(
                status_code=401,
                detail="Authentication required - missing token"
            )
        
        # Verify token
        user_info = self.verify_jwt_token(token)
        if not user_info:
            raise HTTPException(
                status_code=401,
                detail="Authentication failed - invalid token"
            )
        
        return user_info

# Global auth service instance
auth_service = AuthService()

def require_auth(request: Request) -> UserInfo:
    """
    FastAPI dependency for requiring authentication
    
    Args:
        request: FastAPI request object
        
    Returns:
        UserInfo object for authenticated user
        
    Raises:
        HTTPException: If authentication fails
    """
    return auth_service.authenticate_request(request)

def optional_auth(request: Request) -> Optional[UserInfo]:
    """
    FastAPI dependency for optional authentication
    
    Args:
        request: FastAPI request object
        
    Returns:
        UserInfo object if authenticated, None otherwise
    """
    try:
        return auth_service.authenticate_request(request)
    except HTTPException:
        return None

# Rate limiting (basic implementation)
class RateLimiter:
    """Simple in-memory rate limiter"""
    
    def __init__(self):
        self.requests = {}
        self.beta_limit = 100  # 100 requests per hour for beta
        self.window = 3600  # 1 hour window
    
    def is_allowed(self, user_id: str) -> bool:
        """
        Check if request is allowed based on rate limits
        
        Args:
            user_id: User ID for rate limiting
            
        Returns:
            True if request is allowed, False otherwise
        """
        current_time = time.time()
        
        # Clean old entries
        if user_id in self.requests:
            self.requests[user_id] = [
                req_time for req_time in self.requests[user_id]
                if current_time - req_time < self.window
            ]
        else:
            self.requests[user_id] = []
        
        # Check if under limit
        if len(self.requests[user_id]) < self.beta_limit:
            self.requests[user_id].append(current_time)
            return True
        
        return False

# Global rate limiter instance
rate_limiter = RateLimiter()

def check_rate_limit(user_info: UserInfo) -> None:
    """
    Check rate limits for user
    
    Args:
        user_info: User information
        
    Raises:
        HTTPException: If rate limit is exceeded
    """
    if not rate_limiter.is_allowed(user_info.user_id):
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded - please try again later"
        )