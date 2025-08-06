"""
Device Detection Utilities for platform-specific optimizations.
Detects iOS devices, platform types, and provides mobile-specific headers.
"""

import re
from typing import Dict, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

class Platform(Enum):
    """Supported platforms"""
    IOS = "iOS"
    ANDROID = "Android"
    WEB = "Web"
    DESKTOP = "Desktop"
    UNKNOWN = "Unknown"

class DeviceType(Enum):
    """Device type categories"""
    MOBILE = "mobile"
    TABLET = "tablet"
    DESKTOP = "desktop"
    UNKNOWN = "unknown"

@dataclass
class DeviceInfo:
    """Comprehensive device information"""
    platform: Platform
    device_type: DeviceType
    is_mobile: bool
    os_version: Optional[str] = None
    browser: Optional[str] = None
    device_model: Optional[str] = None
    supports_webrtc: bool = True
    supports_compression: bool = True
    
    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary for logging/analytics"""
        return {
            "platform": self.platform.value,
            "device_type": self.device_type.value,
            "is_mobile": str(self.is_mobile).lower(),
            "os_version": self.os_version or "unknown",
            "browser": self.browser or "unknown",
            "device_model": self.device_model or "unknown",
            "supports_webrtc": str(self.supports_webrtc).lower(),
            "supports_compression": str(self.supports_compression).lower()
        }

class DeviceDetector:
    """
    Advanced device detection based on User-Agent strings.
    Optimized for mobile game clients and web browsers.
    """
    
    # iOS patterns
    IOS_PATTERNS = [
        r'iPhone|iPad|iPod',
        r'CFNetwork.*Darwin',
        r'iOS',
        r'iPhone OS',
        r'OS X.*Mobile'
    ]
    
    # Android patterns  
    ANDROID_PATTERNS = [
        r'Android',
        r'Mobile.*Android',
        r'Linux.*Android'
    ]
    
    # Mobile browser patterns
    MOBILE_PATTERNS = [
        r'Mobile',
        r'mobi',
        r'phone',
        r'Mobile.*Safari',
        r'Mobile.*Chrome'
    ]
    
    # Tablet patterns
    TABLET_PATTERNS = [
        r'iPad',
        r'Tablet',
        r'Android.*(?!.*Mobile)'  # Android without Mobile = tablet
    ]
    
    # Desktop patterns
    DESKTOP_PATTERNS = [
        r'Windows NT',
        r'Macintosh',
        r'Linux.*X11',
        r'CrOS'  # Chrome OS
    ]
    
    # Browser patterns
    BROWSER_PATTERNS = {
        'safari': r'Safari/[\d.]+',
        'chrome': r'Chrome/[\d.]+',
        'firefox': r'Firefox/[\d.]+',
        'edge': r'Edge/[\d.]+',
        'opera': r'Opera/[\d.]+',
        'flutter': r'Flutter',  # Flutter apps
        'native': r'CFNetwork|NSURLConnection'  # Native apps
    }
    
    def __init__(self):
        # Compile patterns for better performance
        self.ios_regex = re.compile('|'.join(self.IOS_PATTERNS), re.IGNORECASE)
        self.android_regex = re.compile('|'.join(self.ANDROID_PATTERNS), re.IGNORECASE)
        self.mobile_regex = re.compile('|'.join(self.MOBILE_PATTERNS), re.IGNORECASE)
        self.tablet_regex = re.compile('|'.join(self.TABLET_PATTERNS), re.IGNORECASE)
        self.desktop_regex = re.compile('|'.join(self.DESKTOP_PATTERNS), re.IGNORECASE)
        
        self.browser_regexes = {
            name: re.compile(pattern, re.IGNORECASE) 
            for name, pattern in self.BROWSER_PATTERNS.items()
        }
    
    def detect(self, user_agent: str) -> DeviceInfo:
        """
        Detect device information from User-Agent string.
        
        Args:
            user_agent: The User-Agent header string
            
        Returns:
            DeviceInfo: Comprehensive device information
        """
        if not user_agent:
            return self._unknown_device()
        
        # Detect platform
        platform = self._detect_platform(user_agent)
        
        # Detect device type
        device_type = self._detect_device_type(user_agent, platform)
        
        # Extract OS version
        os_version = self._extract_os_version(user_agent, platform)
        
        # Detect browser
        browser = self._detect_browser(user_agent)
        
        # Extract device model (for iOS)
        device_model = self._extract_device_model(user_agent, platform)
        
        # Determine capabilities
        is_mobile = device_type in [DeviceType.MOBILE, DeviceType.TABLET]
        supports_webrtc = self._supports_webrtc(user_agent, platform)
        supports_compression = self._supports_compression(user_agent)
        
        return DeviceInfo(
            platform=platform,
            device_type=device_type,
            is_mobile=is_mobile,
            os_version=os_version,
            browser=browser,
            device_model=device_model,
            supports_webrtc=supports_webrtc,
            supports_compression=supports_compression
        )
    
    def _detect_platform(self, user_agent: str) -> Platform:
        """Detect the platform from user agent"""
        if self.ios_regex.search(user_agent):
            return Platform.IOS
        elif self.android_regex.search(user_agent):
            return Platform.ANDROID
        elif self.desktop_regex.search(user_agent):
            return Platform.DESKTOP
        elif 'Mozilla' in user_agent:
            return Platform.WEB
        else:
            return Platform.UNKNOWN
    
    def _detect_device_type(self, user_agent: str, platform: Platform) -> DeviceType:
        """Detect device type"""
        if self.tablet_regex.search(user_agent):
            return DeviceType.TABLET
        elif self.mobile_regex.search(user_agent) or platform == Platform.IOS:
            # iOS devices are generally mobile unless explicitly iPad
            if 'iPad' in user_agent:
                return DeviceType.TABLET
            return DeviceType.MOBILE
        elif platform == Platform.DESKTOP:
            return DeviceType.DESKTOP
        else:
            return DeviceType.UNKNOWN
    
    def _extract_os_version(self, user_agent: str, platform: Platform) -> Optional[str]:
        """Extract OS version from user agent"""
        try:
            if platform == Platform.IOS:
                # Extract iOS version: "OS 17_0" or "iPhone OS 15_5"
                match = re.search(r'(?:OS|iPhone OS) ([\d_]+)', user_agent)
                if match:
                    return match.group(1).replace('_', '.')
            
            elif platform == Platform.ANDROID:
                # Extract Android version: "Android 13" or "Android 11; SM-G991B"
                match = re.search(r'Android ([\d.]+)', user_agent)
                if match:
                    return match.group(1)
            
            elif platform == Platform.DESKTOP:
                # Extract Windows/macOS version
                if 'Windows NT' in user_agent:
                    match = re.search(r'Windows NT ([\d.]+)', user_agent)
                    if match:
                        return f"Windows {match.group(1)}"
                elif 'Mac OS X' in user_agent:
                    match = re.search(r'Mac OS X ([\d_]+)', user_agent)
                    if match:
                        return f"macOS {match.group(1).replace('_', '.')}"
        except Exception:
            pass
        
        return None
    
    def _detect_browser(self, user_agent: str) -> Optional[str]:
        """Detect browser from user agent"""
        for browser_name, regex in self.browser_regexes.items():
            if regex.search(user_agent):
                return browser_name
        return None
    
    def _extract_device_model(self, user_agent: str, platform: Platform) -> Optional[str]:
        """Extract device model (mainly for iOS)"""
        try:
            if platform == Platform.IOS:
                if 'iPhone' in user_agent:
                    return 'iPhone'
                elif 'iPad' in user_agent:
                    return 'iPad'
                elif 'iPod' in user_agent:
                    return 'iPod'
            
            elif platform == Platform.ANDROID:
                # Try to extract Android device model
                match = re.search(r'Android.*?;\s*([^)]+)\)', user_agent)
                if match:
                    model = match.group(1).strip()
                    # Clean up common patterns
                    model = re.sub(r'wv|Mobile|Tablet', '', model).strip()
                    if model and len(model) < 50:  # Reasonable length
                        return model
        except Exception:
            pass
        
        return None
    
    def _supports_webrtc(self, user_agent: str, platform: Platform) -> bool:
        """Determine if device likely supports WebRTC"""
        # Most modern browsers support WebRTC
        if platform in [Platform.IOS, Platform.ANDROID]:
            return True
        
        # Check for older browsers that might not support it
        if 'MSIE' in user_agent or 'Trident' in user_agent:
            return False
        
        return True
    
    def _supports_compression(self, user_agent: str) -> bool:
        """Determine if device supports modern compression"""
        # Almost all modern devices support gzip/deflate/br
        return 'HTTP' in user_agent or 'Mozilla' in user_agent or 'CFNetwork' in user_agent
    
    def _unknown_device(self) -> DeviceInfo:
        """Return device info for unknown devices"""
        return DeviceInfo(
            platform=Platform.UNKNOWN,
            device_type=DeviceType.UNKNOWN,
            is_mobile=False,
            supports_webrtc=False,
            supports_compression=True
        )

# Global detector instance
_detector = DeviceDetector()

def detect_device(user_agent: str) -> DeviceInfo:
    """
    Convenience function to detect device information.
    
    Args:
        user_agent: The User-Agent header string
        
    Returns:
        DeviceInfo: Device information
    """
    return _detector.detect(user_agent)

def is_ios_device(user_agent: str) -> bool:
    """
    Quick check if device is iOS.
    
    Args:
        user_agent: The User-Agent header string
        
    Returns:
        bool: True if iOS device
    """
    if not user_agent:
        return False
    return _detector.ios_regex.search(user_agent) is not None

def is_mobile_device(user_agent: str) -> bool:
    """
    Quick check if device is mobile.
    
    Args:
        user_agent: The User-Agent header string
        
    Returns:
        bool: True if mobile device
    """
    device_info = detect_device(user_agent)
    return device_info.is_mobile

def get_mobile_optimized_headers(user_agent: str) -> Dict[str, str]:
    """
    Get headers optimized for mobile devices.
    
    Args:
        user_agent: The User-Agent header string
        
    Returns:
        Dict: Headers to include in mobile-optimized responses
    """
    device_info = detect_device(user_agent)
    
    headers = {}
    
    if device_info.is_mobile:
        headers.update({
            'X-Device-Type': device_info.device_type.value,
            'X-Platform': device_info.platform.value,
            'X-Mobile-Optimized': 'true'
        })
        
        # iOS-specific optimizations
        if device_info.platform == Platform.IOS:
            headers.update({
                'X-iOS-Device': 'true',
                'X-Supports-Native-Audio': 'true'
            })
            
        # Compression preferences
        if device_info.supports_compression:
            headers['X-Compression-Supported'] = 'gzip,deflate,br'
    
    return headers

def get_platform_string(user_agent: str) -> str:
    """
    Get a simple platform string for analytics.
    
    Args:
        user_agent: The User-Agent header string
        
    Returns:
        str: Platform string (iOS, Android, Web, Desktop, Unknown)
    """
    device_info = detect_device(user_agent)
    return device_info.platform.value

# Example usage and testing
if __name__ == "__main__":
    # Test cases
    test_user_agents = [
        # iOS
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPad; CPU OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
        
        # Android
        "Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36",
        
        # Desktop
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36",
        
        # Flutter app
        "Dart/3.0 (dart:io)",
        
        # Native iOS app
        "BabbleLon/1.0 CFNetwork/1408.0.4 Darwin/22.5.0"
    ]
    
    print("🔍 Device Detection Test Results:")
    print("=" * 50)
    
    for ua in test_user_agents:
        device_info = detect_device(ua)
        print(f"\nUser-Agent: {ua[:60]}...")
        print(f"Platform: {device_info.platform.value}")
        print(f"Device Type: {device_info.device_type.value}")
        print(f"Is Mobile: {device_info.is_mobile}")
        print(f"OS Version: {device_info.os_version}")
        print(f"Browser: {device_info.browser}")
        print(f"Mobile Headers: {get_mobile_optimized_headers(ua)}")
        print("-" * 30)