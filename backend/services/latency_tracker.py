"""
Latency Tracker Service for comprehensive timing and performance monitoring.
Tracks detailed latency breakdown and sends metrics to PostHog and Sentry.
"""

import time
import datetime
import uuid
from typing import Dict, Optional, Any, List
from dataclasses import dataclass, field
import requests
import logging
import os
import json

# Import connection pool for optimized requests
from .connection_pool import get_connection_pool

# Environment variables
POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")
SENTRY_DSN = os.getenv("SENTRY_DSN")

# Configurable alert thresholds
DEFAULT_HIGH_LATENCY_THRESHOLD = float(os.getenv("HIGH_LATENCY_THRESHOLD", "25.0"))  # Increased from 15s to 25s
DEFAULT_CRITICAL_LATENCY_THRESHOLD = float(os.getenv("CRITICAL_LATENCY_THRESHOLD", "45.0"))  # For critical errors

# Import Sentry if available
try:
    import sentry_sdk
    SENTRY_AVAILABLE = bool(SENTRY_DSN)
except ImportError:
    SENTRY_AVAILABLE = False


@dataclass 
class TimingEvent:
    """Represents a single timing event"""
    name: str
    start_time: float
    end_time: Optional[float] = None
    duration: Optional[float] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def end(self, metadata: Optional[Dict[str, Any]] = None):
        """Mark the event as ended and calculate duration"""
        self.end_time = time.time()
        self.duration = self.end_time - self.start_time
        if metadata:
            self.metadata.update(metadata)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization"""
        return {
            "name": self.name,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": self.duration,
            "metadata": self.metadata
        }


class LatencyTracker:
    """
    Comprehensive latency tracking for NPC response pipeline.
    Tracks timing for each stage and sends analytics to PostHog.
    """
    
    def __init__(self, request_id: Optional[str] = None, user_id: Optional[str] = None, session_id: Optional[str] = None):
        self.request_id = request_id or str(uuid.uuid4())
        self.user_id = user_id or "anonymous"
        self.session_id = session_id or "unknown"
        
        # Timing data
        self.events: Dict[str, TimingEvent] = {}
        self.request_start_time = time.time()
        self.platform = "unknown"
        self.device_type = "unknown"
        
        # Request metadata
        self.metadata = {
            "request_id": self.request_id,
            "user_id": self.user_id,
            "session_id": self.session_id,
            "timestamp": datetime.datetime.now().isoformat()
        }
        
        # Connection pool for sending metrics
        self.connection_pool = get_connection_pool()
        
        logging.debug(f"LatencyTracker initialized - Request: {self.request_id}")
    
    def start(self, event_name: str, metadata: Optional[Dict[str, Any]] = None):
        """Start timing an event"""
        if event_name in self.events:
            logging.warning(f"Event '{event_name}' already started, overwriting")
        
        self.events[event_name] = TimingEvent(
            name=event_name,
            start_time=time.time(),
            metadata=metadata or {}
        )
        
        logging.debug(f"Started timing: {event_name}")
    
    def end(self, event_name: str, metadata: Optional[Dict[str, Any]] = None):
        """End timing an event"""
        if event_name not in self.events:
            logging.error(f"Event '{event_name}' not found. Cannot end timing.")
            return None
        
        event = self.events[event_name]
        event.end(metadata)
        
        logging.debug(f"Ended timing: {event_name} - Duration: {event.duration:.3f}s")
        return event.duration
    
    def set_platform(self, platform: str):
        """Set the platform (iOS, Android, Web, etc.)"""
        self.platform = platform
        self.metadata["platform"] = platform
    
    def set_device_type(self, device_type: str):
        """Set device type (mobile, desktop, etc.)"""
        self.device_type = device_type
        self.metadata["device_type"] = device_type
    
    def add_metadata(self, key: str, value: Any):
        """Add custom metadata"""
        self.metadata[key] = value
    
    def get_duration(self, event_name: str) -> Optional[float]:
        """Get duration of a specific event"""
        event = self.events.get(event_name)
        return event.duration if event else None
    
    def get_total_duration(self) -> float:
        """Get total request duration"""
        return time.time() - self.request_start_time
    
    def get_breakdown(self) -> Dict[str, float]:
        """Get timing breakdown for all completed events"""
        breakdown = {}
        for name, event in self.events.items():
            if event.duration is not None:
                breakdown[name] = round(event.duration, 3)
        
        breakdown["total"] = round(self.get_total_duration(), 3)
        return breakdown
    
    def is_high_latency(self, threshold: float = DEFAULT_HIGH_LATENCY_THRESHOLD) -> bool:
        """Check if total latency exceeds threshold"""
        return self.get_total_duration() > threshold
    
    def send_to_posthog(self, event_name: str = "npc_response_latency_breakdown"):
        """Send latency metrics to PostHog"""
        if not POSTHOG_API_KEY:
            logging.debug("PostHog API key not configured, skipping metric send")
            return
        
        breakdown = self.get_breakdown()
        
        # Prepare PostHog event
        event_data = {
            "api_key": POSTHOG_API_KEY,
            "event": event_name,
            "properties": {
                **breakdown,
                **self.metadata,
                "platform": self.platform,
                "device_type": self.device_type,
                "high_latency": self.is_high_latency(),
                # Individual stage timings
                "stt_duration": breakdown.get("stt", 0),
                "llm_duration": breakdown.get("llm", 0), 
                "tts_duration": breakdown.get("tts", 0),
                "total_duration": breakdown.get("total", 0),
                # Add stage percentages
                "stt_percentage": round((breakdown.get("stt", 0) / breakdown.get("total", 1)) * 100, 1),
                "llm_percentage": round((breakdown.get("llm", 0) / breakdown.get("total", 1)) * 100, 1),
                "tts_percentage": round((breakdown.get("tts", 0) / breakdown.get("total", 1)) * 100, 1),
            },
            "distinct_id": self.user_id,
            "timestamp": datetime.datetime.now().isoformat()
        }
        
        try:
            response = self.connection_pool.post(
                "https://app.posthog.com/capture/",
                json=event_data,
                timeout=5
            )
            
            if response.status_code == 200:
                logging.debug(f"✅ PostHog: Latency tracking sent - Total: {breakdown.get('total')}s")
            else:
                logging.warning(f"⚠️ PostHog: Failed to send latency tracking - Status: {response.status_code}")
                
        except Exception as e:
            logging.error(f"❌ PostHog: Error sending latency tracking: {e}")
    
    def send_high_latency_alert(self, threshold: float = DEFAULT_HIGH_LATENCY_THRESHOLD):
        """Send high latency alert to Sentry"""
        total_duration = self.get_total_duration()
        
        if total_duration < threshold:
            return
        
        if SENTRY_AVAILABLE:
            try:
                with sentry_sdk.push_scope() as scope:
                    # Add context
                    scope.set_context("latency_breakdown", self.get_breakdown())
                    scope.set_context("request_metadata", self.metadata)
                    scope.set_tag("platform", self.platform)
                    scope.set_tag("device_type", self.device_type)
                    scope.set_tag("high_latency", True)
                    scope.set_level("warning")
                    
                    # Send alert
                    sentry_sdk.capture_message(
                        f"High latency detected: {total_duration:.2f}s for NPC response",
                        level="warning"
                    )
                    
                logging.warning(f"🚨 Sentry: High latency alert sent - {total_duration:.2f}s")
                
            except Exception as e:
                logging.error(f"❌ Sentry: Error sending high latency alert: {e}")
        else:
            # Fallback: log the alert
            logging.warning(f"🚨 HIGH LATENCY ALERT: {total_duration:.2f}s for request {self.request_id}")
            logging.warning(f"   Breakdown: {self.get_breakdown()}")
    
    def finalize(self, send_to_posthog: bool = True, alert_threshold: float = DEFAULT_HIGH_LATENCY_THRESHOLD):
        """
        Finalize tracking and send metrics.
        Call this at the end of request processing.
        """
        # End total timing if not already ended
        if "total" not in self.events:
            self.start("total", {"auto_created": True})
        
        if "total" in self.events and self.events["total"].duration is None:
            self.end("total")
        
        # Send metrics
        if send_to_posthog:
            self.send_to_posthog()
        
        # Send high latency alerts
        self.send_high_latency_alert(alert_threshold)
        
        # Log summary
        breakdown = self.get_breakdown()
        logging.info(f"🏁 Request {self.request_id} completed in {breakdown.get('total')}s")
        logging.info(f"   Breakdown: STT={breakdown.get('stt', 'N/A')}s, "
                    f"LLM={breakdown.get('llm', 'N/A')}s, "
                    f"TTS={breakdown.get('tts', 'N/A')}s")
    
    def to_response_headers(self) -> Dict[str, str]:
        """
        Generate HTTP headers with timing information.
        Useful for debugging and the test script.
        """
        breakdown = self.get_breakdown()
        headers = {}
        
        # Add individual timings
        for stage in ["stt", "llm", "tts", "total"]:
            if stage in breakdown:
                headers[f"X-{stage.upper()}-Duration"] = str(breakdown[stage])
        
        # Add metadata
        headers["X-Request-ID"] = self.request_id
        headers["X-Platform"] = self.platform
        headers["X-High-Latency"] = str(self.is_high_latency()).lower()
        
        return headers
    
    def get_summary(self) -> Dict[str, Any]:
        """Get complete summary of timing data"""
        return {
            "request_id": self.request_id,
            "user_id": self.user_id,
            "session_id": self.session_id,
            "platform": self.platform,
            "device_type": self.device_type,
            "breakdown": self.get_breakdown(),
            "high_latency": self.is_high_latency(),
            "events": {name: event.to_dict() for name, event in self.events.items()},
            "metadata": self.metadata
        }


# Context manager for easy timing
class TimingContext:
    """Context manager for timing code blocks"""
    
    def __init__(self, tracker: LatencyTracker, event_name: str, metadata: Optional[Dict[str, Any]] = None):
        self.tracker = tracker
        self.event_name = event_name
        self.metadata = metadata or {}
    
    def __enter__(self):
        self.tracker.start(self.event_name, self.metadata)
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        # Add exception info if there was an error
        if exc_type:
            self.metadata["error"] = str(exc_val)
            self.metadata["error_type"] = exc_type.__name__
        
        self.tracker.end(self.event_name, self.metadata)


# Convenience function for creating timing contexts
def timing_context(tracker: LatencyTracker, event_name: str, **metadata) -> TimingContext:
    """Create a timing context for use with 'with' statement"""
    return TimingContext(tracker, event_name, metadata)