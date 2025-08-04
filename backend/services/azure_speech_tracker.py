"""
Azure Speech Services Tracking and Cost Calculation

This module provides comprehensive tracking and cost analysis for Azure Speech Services
including Speech-to-Text, Text-to-Speech, and Pronunciation Assessment APIs.
"""

import os
import time
import json
import datetime
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, asdict
from enum import Enum
import requests
from .connection_pool import get_connection_pool
from collections import defaultdict
import threading

# PostHog Configuration
POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")

class AzureSpeechService(Enum):
    """Supported Azure Speech Services"""
    SPEECH_TO_TEXT = "stt"
    TEXT_TO_SPEECH = "tts"
    PRONUNCIATION_ASSESSMENT = "pronunciation"

@dataclass
class AzureSpeechRequest:
    """Azure Speech API request tracking data"""
    request_id: str
    service: AzureSpeechService
    user_id: Optional[str]
    session_id: Optional[str]
    timestamp: datetime.datetime
    
    # Request details
    audio_duration_seconds: Optional[float] = None
    text_length: Optional[int] = None
    language: Optional[str] = None
    voice_name: Optional[str] = None
    reference_text: Optional[str] = None
    
    # Processing details
    region: Optional[str] = None
    model_version: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        data['service'] = self.service.value
        return data

@dataclass
class AzureSpeechResponse:
    """Azure Speech API response tracking data"""
    request_id: str
    success: bool
    response_time_ms: int
    timestamp: datetime.datetime
    
    # Response details
    recognition_result: Optional[str] = None
    pronunciation_score: Optional[float] = None
    accuracy_score: Optional[float] = None
    confidence_score: Optional[float] = None
    
    # Cost calculation
    estimated_cost_usd: float = 0.0
    billable_units: float = 0.0
    
    # Error handling
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        return data

class AzureSpeechCostCalculator:
    """Calculate costs for Azure Speech Services based on official pricing"""
    
    # Azure Speech Services Pricing (USD) - Updated as of 2025
    PRICING = {
        AzureSpeechService.SPEECH_TO_TEXT: {
            'standard': 1.00,  # Per hour of audio
            'neural': 2.50,    # Per hour of audio (if using neural models)
            'unit': 'hour'
        },
        AzureSpeechService.TEXT_TO_SPEECH: {
            'standard': 4.00,   # Per 1M characters
            'neural': 16.00,    # Per 1M characters (neural voices)
            'unit': 'million_chars'
        },
        AzureSpeechService.PRONUNCIATION_ASSESSMENT: {
            'standard': 1.00,  # Same as STT pricing
            'neural': 2.50,    # Same as STT pricing
            'unit': 'hour'
        }
    }
    
    @staticmethod
    def calculate_stt_cost(audio_duration_seconds: float, use_neural: bool = False) -> tuple[float, float]:
        """Calculate Speech-to-Text cost"""
        audio_hours = audio_duration_seconds / 3600.0
        tier = 'neural' if use_neural else 'standard'
        cost_per_hour = AzureSpeechCostCalculator.PRICING[AzureSpeechService.SPEECH_TO_TEXT][tier]
        total_cost = audio_hours * cost_per_hour
        return total_cost, audio_hours
    
    @staticmethod
    def calculate_tts_cost(text_length: int, use_neural: bool = True) -> tuple[float, float]:
        """Calculate Text-to-Speech cost"""
        characters_millions = text_length / 1_000_000.0
        tier = 'neural' if use_neural else 'standard'
        cost_per_million = AzureSpeechCostCalculator.PRICING[AzureSpeechService.TEXT_TO_SPEECH][tier]
        total_cost = characters_millions * cost_per_million
        return total_cost, characters_millions
    
    @staticmethod
    def calculate_pronunciation_cost(audio_duration_seconds: float, use_neural: bool = False) -> tuple[float, float]:
        """Calculate Pronunciation Assessment cost (same as STT)"""
        return AzureSpeechCostCalculator.calculate_stt_cost(audio_duration_seconds, use_neural)

class AzureSpeechTracker:
    """Main tracking class for Azure Speech Services"""
    
    def __init__(self):
        self.active_requests: Dict[str, AzureSpeechRequest] = {}
        self.completed_requests: List[Dict[str, Any]] = []
        self.metrics = defaultdict(lambda: defaultdict(int))
        self.cost_totals = defaultdict(float)
        self._lock = threading.Lock()
        
        print(f"[{datetime.datetime.now()}] 🚀 AzureSpeechTracker initialized - PostHog: {'enabled' if POSTHOG_API_KEY else 'disabled'}")
    
    def start_request(self, 
                     request_id: str,
                     service: AzureSpeechService,
                     user_id: Optional[str] = None,
                     session_id: Optional[str] = None,
                     **kwargs) -> AzureSpeechRequest:
        """Start tracking a new Azure Speech API request"""
        
        request_data = AzureSpeechRequest(
            request_id=request_id,
            service=service,
            user_id=user_id,
            session_id=session_id,
            timestamp=datetime.datetime.now(),
            **kwargs
        )
        
        with self._lock:
            self.active_requests[request_id] = request_data
        
        print(f"[{datetime.datetime.now()}] 📊 Azure Speech: Started tracking {service.value} request - ID: {request_id}, User: {user_id}")
        return request_data
    
    def end_request(self,
                   request_id: str,
                   success: bool = True,
                   response_time_ms: Optional[int] = None,
                   **kwargs) -> Optional[AzureSpeechResponse]:
        """End tracking and calculate costs for an Azure Speech API request"""
        
        with self._lock:
            request_data = self.active_requests.pop(request_id, None)
        
        if not request_data:
            print(f"[{datetime.datetime.now()}] ⚠️ Azure Speech: Request ID {request_id} not found in active requests")
            return None
        
        # Calculate response time if not provided
        if response_time_ms is None:
            response_time_ms = int((datetime.datetime.now() - request_data.timestamp).total_seconds() * 1000)
        
        # Calculate costs based on service type
        estimated_cost = 0.0
        billable_units = 0.0
        
        if request_data.service == AzureSpeechService.SPEECH_TO_TEXT:
            if request_data.audio_duration_seconds:
                estimated_cost, billable_units = AzureSpeechCostCalculator.calculate_stt_cost(
                    request_data.audio_duration_seconds
                )
        elif request_data.service == AzureSpeechService.TEXT_TO_SPEECH:
            if request_data.text_length:
                estimated_cost, billable_units = AzureSpeechCostCalculator.calculate_tts_cost(
                    request_data.text_length
                )
        elif request_data.service == AzureSpeechService.PRONUNCIATION_ASSESSMENT:
            if request_data.audio_duration_seconds:
                estimated_cost, billable_units = AzureSpeechCostCalculator.calculate_pronunciation_cost(
                    request_data.audio_duration_seconds
                )
        
        # Create response data
        response_data = AzureSpeechResponse(
            request_id=request_id,
            success=success,
            response_time_ms=response_time_ms,
            timestamp=datetime.datetime.now(),
            estimated_cost_usd=estimated_cost,
            billable_units=billable_units,
            **kwargs
        )
        
        # Update metrics and costs
        with self._lock:
            service_key = request_data.service.value
            self.metrics[service_key]['total_requests'] += 1
            if success:
                self.metrics[service_key]['successful_requests'] += 1
                self.cost_totals[service_key] += estimated_cost
            else:
                self.metrics[service_key]['failed_requests'] += 1
            
            self.metrics[service_key]['total_response_time_ms'] += response_time_ms
            
            # Store completed request
            completed_entry = {
                'request': request_data.to_dict(),
                'response': response_data.to_dict()
            }
            self.completed_requests.append(completed_entry)
            
            # Keep only last 1000 completed requests to prevent memory issues
            if len(self.completed_requests) > 1000:
                self.completed_requests = self.completed_requests[-1000:]
        
        # Track to PostHog
        self._track_to_posthog(request_data, response_data)
        
        # Log completion
        status = "✅" if success else "❌"
        cost_str = f"${estimated_cost:.6f}" if estimated_cost > 0 else "N/A"
        print(f"[{datetime.datetime.now()}] {status} Azure Speech: {request_data.service.value} completed - "
              f"Cost: {cost_str}, Time: {response_time_ms}ms, User: {request_data.user_id}")
        
        return response_data
    
    def _track_to_posthog(self, request_data: AzureSpeechRequest, response_data: AzureSpeechResponse):
        """Send tracking data to PostHog"""
        if not POSTHOG_API_KEY:
            return
        
        try:
            event_data = {
                "api_key": POSTHOG_API_KEY,
                "event": f"azure_speech_{request_data.service.value}",
                "properties": {
                    "service": request_data.service.value,
                    "success": response_data.success,
                    "response_time_ms": response_data.response_time_ms,
                    "estimated_cost_usd": response_data.estimated_cost_usd,
                    "billable_units": response_data.billable_units,
                    "language": request_data.language,
                    "region": request_data.region,
                    "timestamp": response_data.timestamp.isoformat(),
                },
                "timestamp": response_data.timestamp.isoformat(),
            }
            
            # Add user identification - PostHog requires distinct_id
            if request_data.user_id:
                event_data["distinct_id"] = request_data.user_id
            else:
                # Use a fallback distinct_id if user_id is None
                event_data["distinct_id"] = f"anonymous_{request_data.request_id}"
            
            if request_data.session_id:
                event_data["properties"]["session_id"] = request_data.session_id
            
            # Add service-specific properties
            if request_data.service == AzureSpeechService.PRONUNCIATION_ASSESSMENT:
                if response_data.pronunciation_score:
                    event_data["properties"]["pronunciation_score"] = response_data.pronunciation_score
                if response_data.accuracy_score:
                    event_data["properties"]["accuracy_score"] = response_data.accuracy_score
                if request_data.reference_text:
                    event_data["properties"]["reference_text_length"] = len(request_data.reference_text)
            
            # Add error details if failed
            if not response_data.success:
                if response_data.error_code:
                    event_data["properties"]["error_code"] = response_data.error_code
                if response_data.error_message:
                    event_data["properties"]["error_message"] = response_data.error_message
            
            # Send to PostHog using connection pool
            connection_pool = get_connection_pool()
            response = connection_pool.post(
                "https://app.posthog.com/capture/",
                json=event_data,
                timeout=5
            )
            
            if response.status_code == 200:
                print(f"[{datetime.datetime.now()}] ✅ PostHog: Azure Speech {request_data.service.value} event tracked - "
                      f"Cost: ${response_data.estimated_cost_usd:.6f}, User: {request_data.user_id}")
            else:
                print(f"[{datetime.datetime.now()}] ⚠️ PostHog: Failed to track Azure Speech event - "
                      f"Status: {response.status_code}")
                
        except Exception as e:
            print(f"[{datetime.datetime.now()}] ⚠️ PostHog: Error tracking Azure Speech event: {e}")
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get current tracking metrics"""
        with self._lock:
            current_metrics = dict(self.metrics)
            current_costs = dict(self.cost_totals)
        
        # Calculate success rates and average response times
        processed_metrics = {}
        for service, metrics in current_metrics.items():
            total_requests = metrics.get('total_requests', 0)
            successful_requests = metrics.get('successful_requests', 0)
            total_response_time = metrics.get('total_response_time_ms', 0)
            
            processed_metrics[service] = {
                'total_requests': total_requests,
                'successful_requests': successful_requests,
                'failed_requests': metrics.get('failed_requests', 0),
                'success_rate': successful_requests / total_requests if total_requests > 0 else 0,
                'average_response_time_ms': total_response_time / total_requests if total_requests > 0 else 0,
                'total_cost_usd': current_costs.get(service, 0.0)
            }
        
        return {
            'services': processed_metrics,
            'total_cost_usd': sum(current_costs.values()),
            'last_updated': datetime.datetime.now().isoformat()
        }
    
    def get_cost_summary(self, time_range_hours: int = 24) -> Dict[str, Any]:
        """Get cost summary for a specific time range"""
        cutoff_time = datetime.datetime.now() - datetime.timedelta(hours=time_range_hours)
        
        with self._lock:
            recent_requests = [
                req for req in self.completed_requests 
                if datetime.datetime.fromisoformat(req['response']['timestamp']) > cutoff_time
            ]
        
        cost_by_service = defaultdict(float)
        requests_by_service = defaultdict(int)
        
        for req in recent_requests:
            service = req['request']['service']
            cost = req['response']['estimated_cost_usd']
            cost_by_service[service] += cost
            requests_by_service[service] += 1
        
        return {
            'time_range_hours': time_range_hours,
            'total_cost_usd': sum(cost_by_service.values()),
            'cost_by_service': dict(cost_by_service),
            'requests_by_service': dict(requests_by_service),
            'period_start': cutoff_time.isoformat(),
            'period_end': datetime.datetime.now().isoformat()
        }

# Global tracker instance
_tracker_instance = None

def get_azure_speech_tracker() -> AzureSpeechTracker:
    """Get or create the global Azure Speech tracker instance"""
    global _tracker_instance
    if _tracker_instance is None:
        _tracker_instance = AzureSpeechTracker()
    return _tracker_instance