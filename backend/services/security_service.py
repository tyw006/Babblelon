"""
Security service and middleware for BabbleOn backend.
Handles CORS, security headers, request logging, and basic security measures.
"""

import time
import logging
from typing import Dict, List, Optional
from fastapi import Request, Response, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response as StarletteResponse
import json

logger = logging.getLogger(__name__)

class SecurityMiddleware(BaseHTTPMiddleware):
    """Security middleware for adding security headers and request logging"""
    
    async def dispatch(self, request: Request, call_next):
        # Start timing
        start_time = time.time()
        
        # Log request
        logger.info(f"{request.method} {request.url.path} - Client: {request.client}")
        
        # Add security headers
        response = await call_next(request)
        
        # Calculate request duration
        process_time = time.time() - start_time
        
        # Add security headers
        self._add_security_headers(response)
        
        # Add timing header
        response.headers["X-Process-Time"] = str(process_time)
        
        # Log response
        logger.info(f"{request.method} {request.url.path} - {response.status_code} - {process_time:.3f}s")
        
        return response
    
    def _add_security_headers(self, response: StarletteResponse):
        """Add security headers to response"""
        security_headers = {
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "X-XSS-Protection": "1; mode=block",
            "Referrer-Policy": "strict-origin-when-cross-origin",
            "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';",
            "Server": "BabbleOn-API"
        }
        
        for header, value in security_headers.items():
            response.headers[header] = value

class CORSConfig:
    """CORS configuration for different environments"""
    
    @staticmethod
    def get_allowed_origins() -> List[str]:
        """Get allowed origins based on environment"""
        import os
        environment = os.getenv("ENVIRONMENT", "development")
        
        if environment == "production":
            # Production origins - replace with your actual domains
            return [
                "https://babblelon.app",
                "https://www.babblelon.app",
                "https://app.babblelon.com"
            ]
        elif environment == "staging":
            # Staging origins
            return [
                "https://staging.babblelon.app",
                "http://localhost:3000",
                "http://127.0.0.1:3000"
            ]
        else:
            # Development - allow localhost and common ports
            return [
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                "http://localhost:8080",
                "http://127.0.0.1:8080",
                "http://10.0.2.2:8000",  # Android emulator
                "*"  # Allow all for development
            ]

class RequestLogger:
    """Request logging service"""
    
    def __init__(self):
        self.requests = []
        self.max_logs = 1000  # Keep last 1000 requests
    
    def log_request(self, request: Request, response: Response, duration: float):
        """Log request details"""
        log_entry = {
            "timestamp": time.time(),
            "method": request.method,
            "url": str(request.url),
            "client_ip": request.client.host if request.client else None,
            "user_agent": request.headers.get("user-agent", ""),
            "status_code": response.status_code,
            "duration": duration,
            "content_length": response.headers.get("content-length", 0)
        }
        
        # Add to memory log (for development)
        self.requests.append(log_entry)
        
        # Keep only recent logs
        if len(self.requests) > self.max_logs:
            self.requests = self.requests[-self.max_logs:]
        
        # Log to file/system
        logger.info(f"API Request: {json.dumps(log_entry)}")
    
    def get_recent_requests(self, limit: int = 100) -> List[Dict]:
        """Get recent requests for monitoring"""
        return self.requests[-limit:]

class SecurityUtils:
    """Security utility functions"""
    
    @staticmethod
    def is_safe_redirect_url(url: str) -> bool:
        """Check if URL is safe for redirects"""
        if not url:
            return False
        
        # Block javascript: and data: URLs
        if url.lower().startswith(('javascript:', 'data:', 'vbscript:')):
            return False
        
        # Allow relative URLs and known domains
        if url.startswith('/'):
            return True
        
        # For absolute URLs, check against allowed domains
        allowed_domains = ['babblelon.app', 'babblelon.com', 'localhost']
        
        try:
            from urllib.parse import urlparse
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            
            for allowed_domain in allowed_domains:
                if domain == allowed_domain or domain.endswith(f'.{allowed_domain}'):
                    return True
        except:
            return False
        
        return False
    
    @staticmethod
    def sanitize_filename(filename: str) -> str:
        """Sanitize filename for safe storage"""
        import re
        
        # Remove directory traversal attempts
        filename = filename.replace('../', '').replace('..\\', '')
        
        # Remove non-alphanumeric characters except dots and dashes
        filename = re.sub(r'[^a-zA-Z0-9\.\-_]', '_', filename)
        
        # Limit length
        if len(filename) > 100:
            name, ext = filename.rsplit('.', 1) if '.' in filename else (filename, '')
            filename = name[:96] + '.' + ext if ext else name[:100]
        
        return filename
    
    @staticmethod
    def generate_request_id() -> str:
        """Generate unique request ID for tracing"""
        import uuid
        return str(uuid.uuid4())[:8]

# Global instances
request_logger = RequestLogger()
security_utils = SecurityUtils()

# Error handler for common exceptions
class SecurityExceptionHandler:
    """Handle security-related exceptions"""
    
    @staticmethod
    def handle_validation_error(detail: str) -> HTTPException:
        """Handle input validation errors"""
        logger.warning(f"Validation error: {detail}")
        return HTTPException(status_code=400, detail=detail)
    
    @staticmethod
    def handle_auth_error(detail: str) -> HTTPException:
        """Handle authentication errors"""
        logger.warning(f"Authentication error: {detail}")
        return HTTPException(status_code=401, detail=detail)
    
    @staticmethod
    def handle_rate_limit_error(detail: str) -> HTTPException:
        """Handle rate limiting errors"""
        logger.warning(f"Rate limit error: {detail}")
        return HTTPException(status_code=429, detail=detail)
    
    @staticmethod
    def handle_server_error(detail: str) -> HTTPException:
        """Handle server errors"""
        logger.error(f"Server error: {detail}")
        return HTTPException(status_code=500, detail="Internal server error")

# Initialize security exception handler
security_exceptions = SecurityExceptionHandler()