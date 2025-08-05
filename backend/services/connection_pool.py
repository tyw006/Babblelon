"""
Connection Pool Manager for optimizing HTTP requests across all services.
Implements connection pooling, keep-alive, and retry logic for better performance.
"""

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from typing import Optional, Dict, Any
import time
import logging
from threading import Lock

class ConnectionPoolManager:
    """
    Singleton connection pool manager for all HTTP requests.
    Provides optimized session with connection pooling, retries, and keep-alive.
    """
    
    _instance = None
    _lock = Lock()
    
    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """Initialize the connection pool manager (only once due to singleton)"""
        if self._initialized:
            return
            
        self._initialize()
        self._initialized = True
    
    def _initialize(self):
        """Set up the session with optimized settings"""
        self.session = requests.Session()
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=3,  # Total number of retries
            backoff_factor=0.3,  # Wait 0.3, 0.6, 1.2 seconds between retries
            status_forcelist=[500, 502, 503, 504, 429],  # Retry on these status codes
            allowed_methods=["GET", "POST", "PUT", "DELETE"],  # Retry these methods
            raise_on_status=False  # Don't raise exception, let caller handle
        )
        
        # Configure connection pooling
        # Separate adapters for different levels of pooling
        standard_adapter = HTTPAdapter(
            pool_connections=10,  # Number of connection pools to cache
            pool_maxsize=10,      # Maximum number of connections to save in the pool
            max_retries=retry_strategy,
            pool_block=False      # Don't block when pool is full
        )
        
        # High-throughput adapter for APIs that we call frequently
        high_throughput_adapter = HTTPAdapter(
            pool_connections=20,
            pool_maxsize=20,
            max_retries=retry_strategy,
            pool_block=False
        )
        
        # Mount adapters for different domains
        self.session.mount('https://', standard_adapter)
        self.session.mount('http://', standard_adapter)
        
        # Mount high-throughput adapter for specific domains
        api_domains = [
            'https://api.openai.com',
            'https://oai.helicone.ai',
            'https://generativelanguage.googleapis.com',
            'https://gateway.helicone.ai',
            'https://texttospeech.googleapis.com'
        ]
        
        for domain in api_domains:
            self.session.mount(domain, high_throughput_adapter)
        
        # Set keep-alive headers
        self.session.headers.update({
            'Connection': 'keep-alive',
            'Keep-Alive': 'timeout=120, max=10',
            'Accept-Encoding': 'gzip, deflate, br',  # Enable compression
            'User-Agent': 'BabbleLon-Backend/1.0 (Connection-Pooled)'
        })
        
        # Pre-warm connections in background (non-blocking)
        self._warm_connections()
        
        logging.info("✅ Connection Pool Manager initialized with optimized settings")
    
    def _warm_connections(self):
        """Pre-establish connections to reduce first-request latency"""
        endpoints = [
            'https://api.openai.com',
            'https://oai.helicone.ai', 
            'https://generativelanguage.googleapis.com',
            'https://gateway.helicone.ai'
        ]
        
        for endpoint in endpoints:
            try:
                # HEAD request to establish connection without heavy payload
                self.session.head(endpoint, timeout=5)
                logging.debug(f"Pre-warmed connection to {endpoint}")
            except Exception as e:
                # Ignore warm-up failures - they're not critical
                logging.debug(f"Failed to pre-warm {endpoint}: {e}")
    
    def get_session(self) -> requests.Session:
        """Get the optimized session for making requests"""
        return self.session
    
    def request(self, method: str, url: str, **kwargs) -> requests.Response:
        """
        Make an HTTP request using the pooled session.
        
        Args:
            method: HTTP method (GET, POST, etc.)
            url: URL to request
            **kwargs: Additional arguments to pass to requests
            
        Returns:
            Response object
        """
        # Add timing if not already present
        start_time = time.time()
        
        try:
            response = self.session.request(method, url, **kwargs)
            elapsed = time.time() - start_time
            
            # Log slow requests
            if elapsed > 5.0:
                logging.warning(f"Slow request: {method} {url} took {elapsed:.2f}s")
            
            return response
            
        except Exception as e:
            elapsed = time.time() - start_time
            logging.error(f"Request failed: {method} {url} after {elapsed:.2f}s - {e}")
            raise
    
    def get(self, url: str, **kwargs) -> requests.Response:
        """Convenience method for GET requests"""
        return self.request('GET', url, **kwargs)
    
    def post(self, url: str, **kwargs) -> requests.Response:
        """Convenience method for POST requests"""
        return self.request('POST', url, **kwargs)
    
    def close(self):
        """Close all connections in the pool"""
        if hasattr(self, 'session'):
            self.session.close()
            logging.info("Connection pool closed")
    
    def get_pool_status(self) -> Dict[str, Any]:
        """Get current status of connection pools"""
        status = {
            "pools": {},
            "total_connections": 0
        }
        
        # Inspect adapter pools
        for prefix, adapter in self.session.adapters.items():
            if hasattr(adapter, 'poolmanager') and adapter.poolmanager:
                pool_stats = {
                    "num_pools": len(adapter.poolmanager.pools),
                    "pools": []
                }
                
                for key, pool in adapter.poolmanager.pools.items():
                    pool_info = {
                        "scheme": key.scheme,
                        "host": key.host,
                        "port": key.port,
                        "num_connections": pool.num_connections if hasattr(pool, 'num_connections') else 'unknown'
                    }
                    pool_stats["pools"].append(pool_info)
                    if isinstance(pool_info["num_connections"], int):
                        status["total_connections"] += pool_info["num_connections"]
                
                status["pools"][prefix] = pool_stats
        
        return status
    
    def __del__(self):
        """Cleanup when object is destroyed"""
        self.close()


# Global instance getter
_pool_manager = None

def get_connection_pool() -> ConnectionPoolManager:
    """
    Get the global connection pool manager instance.
    
    Returns:
        ConnectionPoolManager: The singleton instance
    """
    global _pool_manager
    if _pool_manager is None:
        _pool_manager = ConnectionPoolManager()
    return _pool_manager


# Convenience function for making pooled requests
def pooled_request(method: str, url: str, **kwargs) -> requests.Response:
    """
    Make an HTTP request using the global connection pool.
    
    Args:
        method: HTTP method
        url: URL to request
        **kwargs: Additional arguments for the request
        
    Returns:
        Response object
    """
    pool = get_connection_pool()
    return pool.request(method, url, **kwargs)


# Convenience functions for common HTTP methods
def pooled_get(url: str, **kwargs) -> requests.Response:
    """Make a GET request using connection pool"""
    return pooled_request('GET', url, **kwargs)


def pooled_post(url: str, **kwargs) -> requests.Response:
    """Make a POST request using connection pool"""
    return pooled_request('POST', url, **kwargs)