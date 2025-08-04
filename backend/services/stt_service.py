import os
import io
import tempfile
import time
import traceback
from typing import Dict, List, Optional, Tuple
from enum import Enum
from fastapi import HTTPException
from google.cloud.speech_v2 import SpeechClient
from google.cloud.speech_v2.types import cloud_speech
from google.api_core.client_options import ClientOptions
import datetime
import math
from difflib import SequenceMatcher
from elevenlabs.client import ElevenLabs
import ssl
import logging
import asyncio
import numpy as np
import requests  # For PostHog tracking
from .connection_pool import get_connection_pool
import json

# AssemblyAI and Speechmatics imports
# import assemblyai as aai  # Removed - no longer used
# from speechmatics.batch import AsyncClient as SpeechmaticsAsyncClient, TranscriptionConfig, FormatType  # Removed - no longer used

# Configuration
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
if not PROJECT_ID:
    print(f"[{datetime.datetime.now()}] WARNING: GOOGLE_CLOUD_PROJECT environment variable not set. Using default 'babbleon'")
    PROJECT_ID = "babbleon"

LOCATION = "us-central1"
# Remove the custom recognizer ID since we'll use explicit model specification
# RECOGNIZER_ID = "recognizer-with-word-confidence"

# ElevenLabs Configuration
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
if not ELEVENLABS_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: ELEVENLABS_API_KEY not found in environment variables.")

# AssemblyAI and Speechmatics are no longer used
# Their configurations have been removed

# Initialize Google Cloud Speech client
api_endpoint = f"{LOCATION}-speech.googleapis.com"
speech_client = None

try:
    speech_client = SpeechClient(client_options=ClientOptions(api_endpoint=api_endpoint))
    logging.info("Google Cloud Speech client initialized successfully")
except Exception as e:
    logging.error(f"Failed to initialize Google Cloud Speech client: {e}")

# Initialize ElevenLabs client
elevenlabs_client = None
if ELEVENLABS_API_KEY:
    try:
        elevenlabs_client = ElevenLabs(api_key=ELEVENLABS_API_KEY)
        logging.info("ElevenLabs client initialized successfully")
    except Exception as e:
        logging.error(f"Failed to initialize ElevenLabs client: {e}")

# PostHog Configuration
POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")

def track_stt_call_to_posthog(
    service_name: str,
    user_id: Optional[str] = None,
    session_id: Optional[str] = None,
    audio_duration_s: float = 0.0,
    processing_time_ms: int = 0,
    confidence_score: float = 0.0,
    word_count: int = 0,
    success: bool = True,
    error: Optional[str] = None
):
    """Track STT API calls to PostHog for analytics"""
    if not POSTHOG_API_KEY:
        return
    
    try:
        event_data = {
            "api_key": POSTHOG_API_KEY,
            "event": "stt_call",
            "properties": {
                "service": service_name,
                "audio_duration_s": audio_duration_s,
                "processing_time_ms": processing_time_ms,
                "confidence_score": confidence_score,
                "word_count": word_count,
                "success": success,
                "timestamp": datetime.datetime.now().isoformat(),
            },
            "timestamp": datetime.datetime.now().isoformat(),
        }
        
        if user_id:
            event_data["distinct_id"] = user_id
        if session_id:
            event_data["properties"]["session_id"] = session_id
        if error:
            event_data["properties"]["error"] = error
            
        # Send to PostHog using connection pool
        connection_pool = get_connection_pool()
        connection_pool.post(
            "https://app.posthog.com/capture/",
            json=event_data,
            timeout=5
        )
    except Exception as e:
        print(f"[{datetime.datetime.now()}] WARNING: Failed to track STT call to PostHog: {e}")

class ErrorCategory(Enum):
    """Enumeration for error classification"""
    AUDIO_FORMAT_ERROR = "audio_format_error"
    AUDIO_QUALITY_ERROR = "audio_quality_error"
    NETWORK_ERROR = "network_error"
    API_RATE_LIMIT = "api_rate_limit"
    API_AUTHENTICATION = "api_authentication"
    SERVICE_UNAVAILABLE = "service_unavailable"
    LANGUAGE_NOT_SUPPORTED = "language_not_supported"
    TRANSCRIPTION_CONFIDENCE_LOW = "transcription_confidence_low"
    EMPTY_AUDIO = "empty_audio"
    UNKNOWN_ERROR = "unknown_error"

class PerformanceMetrics:
    """Class to track performance metrics for STT operations"""
    
    def __init__(self):
        self.start_time = time.time()
        self.audio_duration = 0.0
        self.processing_time = 0.0
        self.network_latency = 0.0
        self.api_response_time = 0.0
        self.word_count = 0
        self.confidence_scores = []
        self.error_category = None
        self.service_used = ""
        
    def set_audio_duration(self, duration: float):
        self.audio_duration = duration
        
    def record_api_start(self):
        self.api_start_time = time.time()
        
    def record_api_end(self):
        self.api_response_time = time.time() - self.api_start_time
        
    def finish_processing(self):
        self.processing_time = time.time() - self.start_time
        
    def set_transcription_results(self, word_count: int, confidence_scores: List[float]):
        self.word_count = word_count
        self.confidence_scores = confidence_scores
        
    def set_error(self, error_category: ErrorCategory):
        self.error_category = error_category
        
    def get_metrics_dict(self) -> Dict:
        """Return metrics as a dictionary for logging/API response"""
        avg_confidence = sum(self.confidence_scores) / len(self.confidence_scores) if self.confidence_scores else 0.0
        real_time_factor = self.processing_time / self.audio_duration if self.audio_duration > 0 else 0.0
        
        return {
            "processing_time_seconds": round(self.processing_time, 3),
            "audio_duration_seconds": round(self.audio_duration, 3),
            "api_response_time_seconds": round(self.api_response_time, 3),
            "real_time_factor": round(real_time_factor, 3),
            "word_count": self.word_count,
            "average_confidence": round(avg_confidence, 3),
            "min_confidence": round(min(self.confidence_scores), 3) if self.confidence_scores else 0.0,
            "max_confidence": round(max(self.confidence_scores), 3) if self.confidence_scores else 0.0,
            "service_used": self.service_used,
            "error_category": self.error_category.value if self.error_category else None,
            "timestamp": datetime.datetime.now().isoformat()
        }

def classify_error(exception: Exception, context: str = "") -> ErrorCategory:
    """Classify errors into categories for better debugging and monitoring"""
    error_message = str(exception).lower()
    
    # Audio format related errors
    if any(keyword in error_message for keyword in ["format", "codec", "encoding", "unsupported audio"]):
        return ErrorCategory.AUDIO_FORMAT_ERROR
    
    # Audio quality/empty audio errors
    if any(keyword in error_message for keyword in ["empty", "silent", "no audio", "duration too short"]):
        return ErrorCategory.EMPTY_AUDIO
    
    # Service unavailable errors (503, timeouts, gRPC issues)
    if any(keyword in error_message for keyword in ["503", "unavailable", "timed out", "deadline exceeded", "recvmsg"]):
        return ErrorCategory.SERVICE_UNAVAILABLE
    
    # Network related errors
    if any(keyword in error_message for keyword in ["network", "connection", "timeout", "ssl", "certificate"]):
        return ErrorCategory.NETWORK_ERROR
    
    # API rate limiting
    if any(keyword in error_message for keyword in ["rate limit", "quota", "too many requests"]):
        return ErrorCategory.API_RATE_LIMIT
    
    # Authentication errors
    if any(keyword in error_message for keyword in ["auth", "credential", "permission", "unauthorized", "forbidden"]):
        return ErrorCategory.API_AUTHENTICATION
    
    # Service availability
    if any(keyword in error_message for keyword in ["service unavailable", "server error", "internal error"]):
        return ErrorCategory.SERVICE_UNAVAILABLE
    
    # Language support
    if any(keyword in error_message for keyword in ["language", "locale", "not supported"]):
        return ErrorCategory.LANGUAGE_NOT_SUPPORTED
    
    # Google Cloud specific errors
    if "google" in context.lower():
        if any(keyword in error_message for keyword in ["recognizer", "project", "location"]):
            return ErrorCategory.API_AUTHENTICATION
    
    # ElevenLabs specific errors
    if "elevenlabs" in context.lower():
        if any(keyword in error_message for keyword in ["api key", "subscription"]):
            return ErrorCategory.API_AUTHENTICATION
    
    return ErrorCategory.UNKNOWN_ERROR

def log_performance_metrics(metrics: PerformanceMetrics, service_name: str, success: bool = True):
    """Log performance metrics for monitoring and analysis"""
    metrics_dict = metrics.get_metrics_dict()
    status = "SUCCESS" if success else "FAILED"
    
    print(f"[{datetime.datetime.now()}] METRICS: {service_name} {status}")
    print(f"  - Processing Time: {metrics_dict['processing_time_seconds']}s")
    print(f"  - Audio Duration: {metrics_dict['audio_duration_seconds']}s")
    print(f"  - Real-time Factor: {metrics_dict['real_time_factor']}")
    print(f"  - API Response Time: {metrics_dict['api_response_time_seconds']}s")
    print(f"  - Word Count: {metrics_dict['word_count']}")
    print(f"  - Average Confidence: {metrics_dict['average_confidence']}")
    
    if not success and metrics.error_category:
        print(f"  - Error Category: {metrics_dict['error_category']}")

class WordComparison:
    """Structure for individual word comparison results"""
    def __init__(self, word: str, confidence: float, expected: str = "", match_type: str = "exact", 
                 similarity: float = 1.0, start_time: float = 0.0, end_time: float = 0.0):
        self.word = word                # Transcribed word
        self.confidence = confidence    # Google Cloud confidence score (0.0-1.0)
        self.expected = expected        # Expected word (if available)
        self.match_type = match_type    # "exact", "close", "partial", "missing", "extra"
        self.similarity = similarity    # Similarity score (0.0-1.0) for fuzzy matching
        self.start_time = start_time    # Word start time
        self.end_time = end_time        # Word end time

class STTResult:
    """Enhanced structure for STT results with comprehensive metrics"""
    def __init__(self, text: str, word_confidence: List[Dict[str, float]], 
                 expected_text: str = "", word_comparisons: List[WordComparison] = None,
                 processing_time: float = 0.0, service_used: str = "google",
                 # Enhanced metrics
                 overall_confidence: float = 0.0, model_used: str = "",
                 language_detected: str = "", language_probability: float = 0.0,
                 speaker_count: int = 0, audio_events: List[str] = None,
                 audio_duration: float = 0.0, real_time_factor: float = 0.0):
        self.text = text
        self.word_confidence = word_confidence
        self.expected_text = expected_text
        self.word_comparisons = word_comparisons or []
        self.processing_time = processing_time
        self.service_used = service_used
        # Enhanced metrics
        self.overall_confidence = overall_confidence
        self.model_used = model_used
        self.language_detected = language_detected
        self.language_probability = language_probability
        self.speaker_count = speaker_count
        self.audio_events = audio_events or []
        self.audio_duration = audio_duration
        self.real_time_factor = real_time_factor

def thai_word_similarity(word1: str, word2: str) -> float:
    """Calculate similarity between two Thai words using sequence matching"""
    if not word1 or not word2:
        return 0.0
    if word1 == word2:
        return 1.0
    return SequenceMatcher(None, word1, word2).ratio()

def compare_expected_vs_transcribed(transcribed_words: List[Dict], expected_text: str) -> List[WordComparison]:
    """
    Compare transcribed words with expected text and create word comparisons.
    
    Args:
        transcribed_words: List of word dictionaries from Google Cloud STT
        expected_text: The expected Thai text to compare against
    
    Returns:
        List of WordComparison objects with match analysis
    """
    if not expected_text.strip():
        # No expected text - just convert transcribed words to comparisons
        return [
            WordComparison(
                word=word_info["word"],
                confidence=word_info["confidence"],
                match_type="no_reference",
                similarity=word_info["confidence"],
                start_time=word_info.get("start_time", 0.0),
                end_time=word_info.get("end_time", 0.0)
            )
            for word_info in transcribed_words
        ]
    
    # Split expected text into words (Thai text segmentation)
    expected_words = expected_text.strip().split()
    transcribed_word_list = [word_info["word"] for word_info in transcribed_words]
    
    word_comparisons = []
    
    # Use sequence matcher to align expected and transcribed words
    matcher = SequenceMatcher(None, expected_words, transcribed_word_list)
    
    transcribed_used = set()
    expected_used = set()
    
    # Process matching blocks
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == 'equal':
            # Exact matches
            for i in range(i1, i2):
                j = j1 + (i - i1)
                if j < len(transcribed_words):
                    word_info = transcribed_words[j]
                    word_comparisons.append(WordComparison(
                        word=word_info["word"],
                        confidence=word_info["confidence"],
                        expected=expected_words[i],
                        match_type="exact",
                        similarity=1.0,
                        start_time=word_info.get("start_time", 0.0),
                        end_time=word_info.get("end_time", 0.0)
                    ))
                    transcribed_used.add(j)
                    expected_used.add(i)
        
        elif tag == 'replace':
            # Substitutions - check for close matches
            for i in range(i1, i2):
                if i - i1 + j1 < j2 and i - i1 + j1 < len(transcribed_words):
                    j = i - i1 + j1
                    word_info = transcribed_words[j]
                    expected_word = expected_words[i]
                    similarity = thai_word_similarity(word_info["word"], expected_word)
                    
                    # Determine match type based on similarity and confidence
                    if similarity >= 0.8:
                        match_type = "close"
                    elif similarity >= 0.5:
                        match_type = "partial"
                    else:
                        match_type = "mismatch"
                    
                    word_comparisons.append(WordComparison(
                        word=word_info["word"],
                        confidence=word_info["confidence"],
                        expected=expected_word,
                        match_type=match_type,
                        similarity=similarity,
                        start_time=word_info.get("start_time", 0.0),
                        end_time=word_info.get("end_time", 0.0)
                    ))
                    transcribed_used.add(j)
                    expected_used.add(i)
        
        elif tag == 'insert':
            # Extra words in transcription
            for j in range(j1, j2):
                if j < len(transcribed_words):
                    word_info = transcribed_words[j]
                    word_comparisons.append(WordComparison(
                        word=word_info["word"],
                        confidence=word_info["confidence"],
                        expected="",
                        match_type="extra",
                        similarity=word_info["confidence"],
                        start_time=word_info.get("start_time", 0.0),
                        end_time=word_info.get("end_time", 0.0)
                    ))
                    transcribed_used.add(j)
        
        elif tag == 'delete':
            # Missing words (expected but not transcribed)
            for i in range(i1, i2):
                word_comparisons.append(WordComparison(
                    word="",
                    confidence=0.0,
                    expected=expected_words[i],
                    match_type="missing",
                    similarity=0.0,
                    start_time=0.0,
                    end_time=0.0
                ))
                expected_used.add(i)
    
    # Sort word comparisons by start time for proper ordering
    word_comparisons.sort(key=lambda x: x.start_time)
    
    return word_comparisons

async def transcribe_audio(
    audio_stream: io.BytesIO, 
    language_code: str = "tha", 
    expected_text: str = "",
    user_id: Optional[str] = None,
    session_id: Optional[str] = None
) -> STTResult:
    """
    Transcribes audio using Google Cloud STT v2 API with Chirp_2 model and word-level confidence.
    Enhanced with error classification and performance metrics logging.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription (e.g., "tha" for Thai, "en" for English)
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        STTResult object with transcribed text, word confidence scores, and comparison analysis
    """
    metrics = PerformanceMetrics()
    metrics.service_used = "Google Cloud STT v2"
    
    if not speech_client:
        error_msg = "Google Cloud Speech client not initialized. Check credentials."
        metrics.set_error(ErrorCategory.API_AUTHENTICATION)
        log_performance_metrics(metrics, "Google Cloud STT", success=False)
        raise HTTPException(status_code=500, detail=error_msg)

    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        initial_stream_pos = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(initial_stream_pos)

        
        if stream_size == 0:
            print(f"[{datetime.datetime.now()}] ERROR STT: Stream is empty before calling Google Cloud STT.")
            metrics.set_error(ErrorCategory.EMPTY_AUDIO)
            log_performance_metrics(metrics, "Google Cloud STT", success=False)
            raise HTTPException(status_code=400, detail="Audio stream is empty before STT processing.")

        # Calculate actual audio duration from WAV header and validate format
        audio_stream.seek(0)
        try:
            import wave
            with wave.open(audio_stream, 'rb') as wav_file:
                frames = wav_file.getnframes()
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()
                sample_width = wav_file.getsampwidth()
                actual_duration = frames / float(sample_rate)
                
                # Enhanced audio format logging
                print(f"[{datetime.datetime.now()}] AUDIO FORMAT: Google Cloud STT")
                print(f"  - Duration: {actual_duration:.3f}s")
                print(f"  - Sample Rate: {sample_rate}Hz (Optimal: 16000Hz)")
                print(f"  - Channels: {channels} ({'Mono' if channels == 1 else 'Stereo'})")
                print(f"  - Sample Width: {sample_width} bytes ({sample_width * 8}-bit)")
                print(f"  - Total Frames: {frames}")
                print(f"  - File Size: {stream_size} bytes")
                
                # Validate optimal format for Google Cloud STT
                format_warnings = []
                if sample_rate != 16000:
                    format_warnings.append(f"Sample rate is {sample_rate}Hz, optimal is 16000Hz")
                if channels != 1:
                    format_warnings.append(f"Audio has {channels} channels, mono (1) is preferred")
                if sample_width != 2:
                    format_warnings.append(f"Sample width is {sample_width} bytes, 16-bit (2 bytes) is optimal")
                
                if format_warnings:
                    print(f"[{datetime.datetime.now()}] FORMAT WARNINGS:")
                    for warning in format_warnings:
                        print(f"  ⚠ {warning}")
                else:
                    print(f"[{datetime.datetime.now()}] ✓ Audio format is optimal for Google Cloud STT")
                    
        except Exception as e:
            # Fallback to rough approximation if WAV header parsing fails
            print(f"[{datetime.datetime.now()}] WARNING STT: Could not parse WAV header ({e}), using approximation")
            actual_duration = max(1.0, stream_size / (16000 * 1 * 2))  # Assume 16kHz, mono, 16-bit
        
        metrics.set_audio_duration(actual_duration)

        # Google Cloud STT can accept WAV directly - no need for redundant conversion
        audio_stream.seek(0)
        wav_content = audio_stream.getvalue()

        # Centralized language code mapping for Google Cloud STT
        def get_google_cloud_language_code(input_code: str) -> str:
            """Convert input language code to Google Cloud STT format"""
            language_mapping = {
                "tha": "th-TH",
                "th": "th-TH", 
                "en": "en-US",
                "eng": "en-US"
            }
            return language_mapping.get(input_code.lower(), "th-TH")
        
        gcloud_language_code = get_google_cloud_language_code(language_code)

        # Use explicit Chirp_2 model configuration with correct v2 API format
        config = cloud_speech.RecognitionConfig(
            auto_decoding_config=cloud_speech.AutoDetectDecodingConfig(),
            model="chirp_2",  # Chirp2 model for v2 API
            language_codes=[gcloud_language_code],
            features=cloud_speech.RecognitionFeatures(
                enable_word_confidence=True,  # Enable word-level confidence
                enable_word_time_offsets=True,  # Enable word timing information
            )
        )

        # Create the parent path for v2 API
        # Note: For Chirp_2 model, use regional location (us-central1), not global
        parent = f"projects/{PROJECT_ID}/locations/{LOCATION}"
        
        request = cloud_speech.RecognizeRequest(
            recognizer=f"{parent}/recognizers/_",  # Use default recognizer with our config
            config=config,
            content=wav_content,
        )

        # Perform recognition with retry logic and exponential backoff
        
        max_retries = 3
        base_delay = 1.0  # Start with 1 second delay
        
        for attempt in range(max_retries):
            try:
                if attempt > 0:
                    delay = base_delay * (2 ** (attempt - 1))  # Exponential backoff: 1s, 2s, 4s
                    print(f"[{datetime.datetime.now()}] INFO STT: Retry attempt {attempt + 1}/{max_retries} after {delay}s delay...")
                    await asyncio.sleep(delay)
                
                metrics.record_api_start()
                response = speech_client.recognize(request=request)
                metrics.record_api_end()
                
                # If we get here, the request succeeded
                break
                
            except Exception as retry_exception:
                error_message = str(retry_exception).lower()
                is_timeout_or_unavailable = any(keyword in error_message for keyword in [
                    "timeout", "timed out", "unavailable", "503", "connection", "deadline exceeded"
                ])
                
                if attempt < max_retries - 1 and is_timeout_or_unavailable:
                    print(f"[{datetime.datetime.now()}] WARNING STT: Attempt {attempt + 1} failed with timeout/unavailable error: {retry_exception}")
                    print(f"[{datetime.datetime.now()}] INFO STT: Will retry in {base_delay * (2 ** attempt)}s...")
                    continue
                else:
                    # Final attempt failed or non-retryable error
                    print(f"[{datetime.datetime.now()}] ERROR STT: All retry attempts exhausted or non-retryable error: {retry_exception}")
                    raise retry_exception

        # Process results
        transcribed_text = ""
        word_confidence_list = []

        # Extract enhanced metrics from response
        overall_confidence = 0.0
        language_detected = gcloud_language_code
        model_used = "chirp_2"
        
        for result in response.results:
            if result.alternatives:
                alternative = result.alternatives[0]
                transcribed_text = alternative.transcript
                overall_confidence = alternative.confidence
                
                # Check for language detection information
                if hasattr(result, 'language_code') and result.language_code:
                    language_detected = result.language_code
                
                # Extract word-level confidence with enhanced data
                if alternative.words:
                    for word_info in alternative.words:
                        word_confidence_list.append({
                            "word": word_info.word,
                            "confidence": word_info.confidence,
                            "start_time": word_info.start_offset.total_seconds() if word_info.start_offset else 0.0,
                            "end_time": word_info.end_offset.total_seconds() if word_info.end_offset else 0.0,
                            # Additional Google Cloud STT v2 fields
                            "speaker_tag": getattr(word_info, 'speaker_tag', 0) if hasattr(word_info, 'speaker_tag') else 0
                        })

                print(f"[{datetime.datetime.now()}] INFO: Google Cloud STT successful. Transcription: '{transcribed_text}'")
                
                # Perform word comparison if expected text is provided
                word_comparisons = compare_expected_vs_transcribed(word_confidence_list, expected_text)
                
                # Calculate enhanced metrics
                confidence_scores = [wc["confidence"] for wc in word_confidence_list]
                metrics.set_transcription_results(len(word_confidence_list), confidence_scores)
                metrics.finish_processing()
                
                # Calculate real-time factor
                real_time_factor = metrics.processing_time / actual_duration if actual_duration > 0 else 0.0
                
                log_performance_metrics(metrics, "Google Cloud STT", success=True)
                
                # Track successful STT call to PostHog
                track_stt_call_to_posthog(
                    service_name="google_cloud_stt",
                    user_id=user_id,
                    session_id=session_id,
                    audio_duration_s=actual_duration,
                    processing_time_ms=int(metrics.processing_time * 1000),
                    confidence_score=overall_confidence,
                    word_count=len(word_confidence_list),
                    success=True
                )
                
                return STTResult(
                    text=transcribed_text, 
                    word_confidence=word_confidence_list,
                    expected_text=expected_text,
                    word_comparisons=word_comparisons,
                    processing_time=metrics.processing_time,  # Fix: Add missing processing time
                    service_used="google",
                    # Enhanced metrics
                    overall_confidence=overall_confidence,
                    model_used=model_used,
                    language_detected=language_detected,
                    language_probability=1.0,  # Google Cloud doesn't provide language probability
                    speaker_count=len(set(wc.get("speaker_tag", 0) for wc in word_confidence_list)),
                    audio_duration=actual_duration,
                    real_time_factor=real_time_factor
                )

        # No results case
        print(f"[{datetime.datetime.now()}] WARNING: Google Cloud STT returned no results")
        metrics.set_error(ErrorCategory.TRANSCRIPTION_CONFIDENCE_LOW)
        metrics.finish_processing()
        log_performance_metrics(metrics, "Google Cloud STT", success=False)
        return STTResult(text="", word_confidence=[], expected_text=expected_text, word_comparisons=[], processing_time=0.0, service_used="google")

    except Exception as e:
        # Enhanced error logging
        current_pos_after_error = -1
        stream_size_after_error = -1
        if isinstance(audio_stream, io.BytesIO):
            try:
                current_pos_after_error = audio_stream.tell()
                original_pos = audio_stream.tell()
                audio_stream.seek(0, io.SEEK_END)
                stream_size_after_error = audio_stream.tell()
                audio_stream.seek(original_pos)
            except:
                pass

        # Classify the error for better debugging
        error_category = classify_error(e, "google cloud stt")
        metrics.set_error(error_category)
        metrics.finish_processing()
        log_performance_metrics(metrics, "Google Cloud STT", success=False)

        print(f"[{datetime.datetime.now()}] ERROR: Error during Google Cloud STT: {e}. Stream pos: {current_pos_after_error}, size: {stream_size_after_error} after error.")
        
        # Track failed STT call to PostHog
        track_stt_call_to_posthog(
            service_name="google_cloud_stt",
            user_id=user_id,
            session_id=session_id,
            audio_duration_s=0.0,
            processing_time_ms=int(metrics.processing_time * 1000) if hasattr(metrics, 'processing_time') else 0,
            confidence_score=0.0,
            word_count=0,
            success=False,
            error=str(e)
        )
        
        raise HTTPException(status_code=500, detail=f"Error during speech-to-text processing: {str(e)}")

async def transcribe_audio_elevenlabs(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> STTResult:
    """
    Transcribes audio using ElevenLabs Scribe v1 STT service.
    Simplified version with essential confidence tracking and performance logging.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription (e.g., "tha" for Thai, "en" for English)
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        STTResult object with transcribed text, word confidence scores, and processing time
    """
    if not elevenlabs_client:
        print(f"[{datetime.datetime.now()}] ERROR: ElevenLabs client not initialized. Check API key.")
        raise HTTPException(status_code=500, detail="ElevenLabs client not initialized. Check API key.")

    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        initial_stream_pos = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(initial_stream_pos)

        
        if stream_size == 0:
            print(f"[{datetime.datetime.now()}] ERROR STT: Stream is empty before calling ElevenLabs STT.")
            raise HTTPException(status_code=400, detail="Audio stream is empty before STT processing.")

        # Start timing for performance comparison
        start_time = datetime.datetime.now()
        
        # Call ElevenLabs Scribe API
        transcription_response = elevenlabs_client.speech_to_text.convert(
            file=audio_stream,  # Pass the BytesIO stream directly
            model_id="scribe_v1",  # Model to use
            language_code=language_code,  # Use the provided language code
        )
        
        # Calculate processing time
        end_time = datetime.datetime.now()
        processing_time = (end_time - start_time).total_seconds()
        
        if transcription_response and hasattr(transcription_response, 'text'):
            transcribed_text = transcription_response.text
            
            # Extract word-level confidence data if available
            word_confidence_list = []
            overall_confidence = 0.0
            
            if transcribed_text.strip():
                # Check if the response has detailed word information with confidence scores
                if hasattr(transcription_response, 'words') and transcription_response.words:
                    # Use actual word-level data from ElevenLabs
                    confidence_scores = []
                    for word_info in transcription_response.words:
                        # Convert logprob to confidence (logprob is negative, closer to 0 = higher confidence)
                        logprob = getattr(word_info, 'logprob', -1.0)
                        # Convert logprob to confidence: exp(logprob) but cap it reasonably
                        confidence = min(0.95, max(0.1, math.exp(logprob))) if logprob < 0 else 0.5
                        confidence_scores.append(confidence)
                        
                        word_data = {
                            "word": getattr(word_info, 'word', '') or getattr(word_info, 'text', ''),
                            "confidence": confidence,
                            "start_time": getattr(word_info, 'start_time', getattr(word_info, 'start', 0.0)),
                            "end_time": getattr(word_info, 'end_time', getattr(word_info, 'end', 0.0)),
                        }
                        word_confidence_list.append(word_data)
                    
                    # Calculate overall confidence as average of word confidences
                    overall_confidence = sum(confidence_scores) / len(confidence_scores) if confidence_scores else 0.5
                else:
                    # Fallback: split by spaces and use reasonable confidence estimate
                    words = transcribed_text.strip().split()
                    base_confidence = 0.7  # Reasonable default confidence
                    overall_confidence = base_confidence
                    
                    for word in words:
                        word_data = {
                            "word": word,
                            "confidence": base_confidence,
                            "start_time": 0.0,
                            "end_time": 0.0,
                        }
                        word_confidence_list.append(word_data)
            
            # Calculate audio duration and validate format for performance metrics
            audio_stream.seek(0)
            try:
                import wave
                with wave.open(audio_stream, 'rb') as wav_file:
                    frames = wav_file.getnframes()
                    sample_rate = wav_file.getframerate()
                    channels = wav_file.getnchannels()
                    sample_width = wav_file.getsampwidth()
                    actual_duration = frames / float(sample_rate)
                    
                    # Enhanced audio format logging
                    print(f"[{datetime.datetime.now()}] AUDIO FORMAT: ElevenLabs Scribe")
                    print(f"  - Duration: {actual_duration:.3f}s")
                    print(f"  - Sample Rate: {sample_rate}Hz (Optimal: 16000Hz)")
                    print(f"  - Channels: {channels} ({'Mono' if channels == 1 else 'Stereo'})")
                    print(f"  - Sample Width: {sample_width} bytes ({sample_width * 8}-bit)")
                    print(f"  - Total Frames: {frames}")
                    print(f"  - File Size: {stream_size} bytes")
                    
                    # Validate optimal format for ElevenLabs Scribe
                    format_warnings = []
                    if sample_rate != 16000:
                        format_warnings.append(f"Sample rate is {sample_rate}Hz, optimal is 16000Hz for best performance")
                    if channels != 1:
                        format_warnings.append(f"Audio has {channels} channels, mono (1) is optimal for ElevenLabs")
                    if sample_width != 2:
                        format_warnings.append(f"Sample width is {sample_width} bytes, 16-bit (2 bytes) is optimal")
                    
                    if format_warnings:
                        print(f"[{datetime.datetime.now()}] FORMAT WARNINGS:")
                        for warning in format_warnings:
                            print(f"  ⚠ {warning}")
                    else:
                        print(f"[{datetime.datetime.now()}] ✓ Audio format is optimal for ElevenLabs Scribe")
                        
            except Exception as e:
                print(f"[{datetime.datetime.now()}] WARNING: Could not parse WAV header ({e}), using approximation")
                actual_duration = max(1.0, stream_size / (16000 * 1 * 2))  # Assume 16kHz, mono, 16-bit
            
            real_time_factor = processing_time / actual_duration if actual_duration > 0 else 0.0
            
            # Performance logging for API comparison
            print(f"[{datetime.datetime.now()}] INFO: ElevenLabs STT successful. Transcription: '{transcribed_text}'")
            print(f"[{datetime.datetime.now()}] PERFORMANCE: ElevenLabs processing time: {processing_time:.3f}s, audio duration: {actual_duration:.3f}s, RTF: {real_time_factor:.3f}")
            print(f"[{datetime.datetime.now()}] PERFORMANCE: ElevenLabs overall confidence: {overall_confidence:.3f}, word count: {len(word_confidence_list)}")
            
            # Create word comparisons if expected text provided
            word_comparisons = compare_expected_vs_transcribed(word_confidence_list, expected_text) if expected_text.strip() else []
            
            return STTResult(
                text=transcribed_text,
                word_confidence=word_confidence_list,
                expected_text=expected_text,
                word_comparisons=word_comparisons,
                processing_time=processing_time,
                service_used="elevenlabs",
                overall_confidence=overall_confidence,
                model_used="scribe_v1",
                language_detected=language_code,
                language_probability=1.0,
                speaker_count=1,
                audio_events=[],
                audio_duration=actual_duration,
                real_time_factor=real_time_factor
            )
        else:
            print(f"[{datetime.datetime.now()}] ERROR: ElevenLabs STT did not return a valid text transcription.")
            return STTResult(
                text="", 
                word_confidence=[], 
                expected_text=expected_text, 
                word_comparisons=[],
                processing_time=processing_time,
                service_used="elevenlabs"
            )

    except ssl.SSLEOFError as ssl_e:
        error_msg = f"SSL EOF error during ElevenLabs STT: {ssl_e}. This might be a temporary network issue or an issue with ElevenLabs." 
        print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
        raise HTTPException(status_code=503, detail=error_msg) # 503 Service Unavailable
    except Exception as e:
        # Add stream state check here too
        current_pos_after_error = -1
        stream_size_after_error = -1
        if isinstance(audio_stream, io.BytesIO):
            current_pos_after_error = audio_stream.tell()
            # To get size, seek to end then back
            original_pos = audio_stream.tell()
            audio_stream.seek(0, io.SEEK_END)
            stream_size_after_error = audio_stream.tell()
            audio_stream.seek(original_pos) # Attempt to restore original position

        print(f"[{datetime.datetime.now()}] ERROR: Error during ElevenLabs STT: {e}. Stream pos: {current_pos_after_error}, size: {stream_size_after_error} after error.")
        raise HTTPException(status_code=500, detail=f"Error during speech-to-text processing: {str(e)}")

async def transcribe_audio_short(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> STTResult:
    """
    Transcribes audio using Google Cloud STT v2 API with short model for short utterances.
    Optimized for commands and single-shot directed speech, supports Thai language.
    
    NOTE: short model confidence scores may have different characteristics than standard models.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription (e.g., "tha" for Thai, "en" for English)
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        STTResult object with transcribed text, word confidence scores, and comparison analysis
    """
    metrics = PerformanceMetrics()
    metrics.service_used = "Google Cloud STT v2 (short)"
    
    if not speech_client:
        error_msg = "Google Cloud Speech client not initialized. Check credentials."
        metrics.set_error(ErrorCategory.API_AUTHENTICATION)
        log_performance_metrics(metrics, "Google Cloud STT (latest_short)", success=False)
        raise HTTPException(status_code=500, detail=error_msg)

    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        initial_stream_pos = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(initial_stream_pos)

        
        if stream_size == 0:
            print(f"[{datetime.datetime.now()}] ERROR STT: Stream is empty before calling Google Cloud STT (short).")
            metrics.set_error(ErrorCategory.EMPTY_AUDIO)
            log_performance_metrics(metrics, "Google Cloud STT (short)", success=False)
            raise HTTPException(status_code=400, detail="Audio stream is empty before STT processing.")

        # Calculate actual audio duration from WAV header and validate format
        audio_stream.seek(0)
        try:
            import wave
            with wave.open(audio_stream, 'rb') as wav_file:
                frames = wav_file.getnframes()
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()
                sample_width = wav_file.getsampwidth()
                actual_duration = frames / float(sample_rate)
                
                # Enhanced audio format logging
                print(f"[{datetime.datetime.now()}] AUDIO FORMAT: Google Cloud STT (latest_short)")
                print(f"  - Duration: {actual_duration:.3f}s")
                print(f"  - Sample Rate: {sample_rate}Hz (Optimal: 16000Hz)")
                print(f"  - Channels: {channels} ({'Mono' if channels == 1 else 'Stereo'})")
                print(f"  - Sample Width: {sample_width} bytes ({sample_width * 8}-bit)")
                print(f"  - Total Frames: {frames}")
                print(f"  - File Size: {stream_size} bytes")
                
                # Validate optimal format for Google Cloud STT
                format_warnings = []
                if sample_rate != 16000:
                    format_warnings.append(f"Sample rate is {sample_rate}Hz, optimal is 16000Hz")
                if channels != 1:
                    format_warnings.append(f"Audio has {channels} channels, mono (1) is preferred")
                if sample_width != 2:
                    format_warnings.append(f"Sample width is {sample_width} bytes, 16-bit (2 bytes) is optimal")
                
                if format_warnings:
                    print(f"[{datetime.datetime.now()}] FORMAT WARNINGS:")
                    for warning in format_warnings:
                        print(f"  ⚠ {warning}")
                else:
                    print(f"[{datetime.datetime.now()}] ✓ Audio format is optimal for Google Cloud STT (latest_short)")
                    
        except Exception as e:
            # Fallback to rough approximation if WAV header parsing fails
            print(f"[{datetime.datetime.now()}] WARNING STT: Could not parse WAV header ({e}), using approximation")
            actual_duration = max(1.0, stream_size / (16000 * 1 * 2))  # Assume 16kHz, mono, 16-bit
        
        metrics.set_audio_duration(actual_duration)

        # Google Cloud STT can accept WAV directly - no need for redundant conversion
        audio_stream.seek(0)
        wav_content = audio_stream.getvalue()

        # Centralized language code mapping for Google Cloud STT
        def get_google_cloud_language_code(input_code: str) -> str:
            """Convert input language code to Google Cloud STT format"""
            language_mapping = {
                "tha": "th-TH",
                "th": "th-TH", 
                "en": "en-US",
                "eng": "en-US"
            }
            return language_mapping.get(input_code.lower(), "th-TH")
        
        gcloud_language_code = get_google_cloud_language_code(language_code)

        # Use short model configuration with enhanced features
        config = cloud_speech.RecognitionConfig(
            auto_decoding_config=cloud_speech.AutoDetectDecodingConfig(),
            model="short",  # short model optimized for short utterances with Thai support
            language_codes=[gcloud_language_code],
            features=cloud_speech.RecognitionFeatures(
                enable_word_confidence=True,  # Enable word-level confidence (NOTE: not true confidence)
                enable_word_time_offsets=True,  # Enable word timing information
                enable_automatic_punctuation=True,  # Enhanced feature for latest_short
                enable_spoken_punctuation=False,  # Disable spoken punctuation
                max_alternatives=5,  # Get multiple alternatives for mispronunciation tolerance
                profanity_filter=False  # Disable profanity filter for language learning
            )
        )

        # Create the parent path for v2 API
        # Note: For short model, use regional location (us-central1), not global
        parent = f"projects/{PROJECT_ID}/locations/{LOCATION}"
        
        request = cloud_speech.RecognizeRequest(
            recognizer=f"{parent}/recognizers/_",  # Use default recognizer with our config
            config=config,
            content=wav_content,
        )

        # Perform recognition with metrics tracking
        metrics.record_api_start()
        response = speech_client.recognize(request=request)
        metrics.record_api_end()

        # Process results with multiple alternatives support
        transcribed_text = ""
        word_confidence_list = []
        all_alternatives = []

        # Extract enhanced metrics from response
        overall_confidence = 0.0
        language_detected = gcloud_language_code
        model_used = "short"
        
        for result in response.results:
            if result.alternatives:
                # Process the best alternative (first one)
                best_alternative = result.alternatives[0]
                transcribed_text = best_alternative.transcript
                overall_confidence = best_alternative.confidence  # NOTE: Not a true confidence score
                
                # Store all alternatives for mispronunciation tolerance
                for i, alternative in enumerate(result.alternatives):
                    all_alternatives.append({
                        "transcript": alternative.transcript,
                        "confidence": alternative.confidence,
                        "rank": i
                    })
                
                # Check for language detection information
                if hasattr(result, 'language_code') and result.language_code:
                    language_detected = result.language_code
                
                # Extract word-level confidence with enhanced data from best alternative
                if best_alternative.words:
                    for word_info in best_alternative.words:
                        word_confidence_list.append({
                            "word": word_info.word,
                            "confidence": word_info.confidence,  # NOTE: Not a true confidence score
                            "start_time": word_info.start_offset.total_seconds() if word_info.start_offset else 0.0,
                            "end_time": word_info.end_offset.total_seconds() if word_info.end_offset else 0.0,
                            # Additional Google Cloud STT v2 fields
                            "speaker_tag": getattr(word_info, 'speaker_tag', 0) if hasattr(word_info, 'speaker_tag') else 0
                        })

                print(f"[{datetime.datetime.now()}] INFO: Google Cloud STT (latest_short) successful. Transcription: '{transcribed_text}'")
                
                # Log all alternatives for debugging
                
                # Perform word comparison if expected text is provided
                word_comparisons = compare_expected_vs_transcribed(word_confidence_list, expected_text)
                
                # Calculate enhanced metrics
                confidence_scores = [wc["confidence"] for wc in word_confidence_list]
                metrics.set_transcription_results(len(word_confidence_list), confidence_scores)
                metrics.finish_processing()
                
                # Calculate real-time factor
                real_time_factor = metrics.processing_time / actual_duration if actual_duration > 0 else 0.0
                
                log_performance_metrics(metrics, "Google Cloud STT (latest_short)", success=True)
                
                return STTResult(
                    text=transcribed_text, 
                    word_confidence=word_confidence_list,
                    expected_text=expected_text,
                    word_comparisons=word_comparisons,
                    processing_time=metrics.processing_time,
                    service_used="google_latest_short",
                    # Enhanced metrics
                    overall_confidence=overall_confidence,  # NOTE: Not a true confidence score
                    model_used=model_used,
                    language_detected=language_detected,
                    language_probability=1.0,  # Google Cloud doesn't provide language probability
                    speaker_count=len(set(wc.get("speaker_tag", 0) for wc in word_confidence_list)),
                    audio_duration=actual_duration,
                    real_time_factor=real_time_factor
                )

        # No results case
        print(f"[{datetime.datetime.now()}] WARNING: Google Cloud STT (latest_short) returned no results")
        metrics.set_error(ErrorCategory.TRANSCRIPTION_CONFIDENCE_LOW)
        metrics.finish_processing()
        log_performance_metrics(metrics, "Google Cloud STT (latest_short)", success=False)
        return STTResult(text="", word_confidence=[], expected_text=expected_text, word_comparisons=[], processing_time=0.0, service_used="google_latest_short")

    except Exception as e:
        # Enhanced error logging
        current_pos_after_error = -1
        stream_size_after_error = -1
        if isinstance(audio_stream, io.BytesIO):
            try:
                current_pos_after_error = audio_stream.tell()
                original_pos = audio_stream.tell()
                audio_stream.seek(0, io.SEEK_END)
                stream_size_after_error = audio_stream.tell()
                audio_stream.seek(original_pos)
            except:
                pass

        # Classify the error for better debugging
        error_category = classify_error(e, "google cloud stt latest_short")
        metrics.set_error(error_category)
        metrics.finish_processing()
        log_performance_metrics(metrics, "Google Cloud STT (latest_short)", success=False)

        print(f"[{datetime.datetime.now()}] ERROR: Error during Google Cloud STT (latest_short): {e}. Stream pos: {current_pos_after_error}, size: {stream_size_after_error} after error.")
        raise HTTPException(status_code=500, detail=f"Error during speech-to-text processing: {str(e)}")

async def parallel_transcribe_audio(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> Dict[str, STTResult]:
    """
    Transcribes audio using three STT services in parallel for comprehensive comparison.
    Compares Google Cloud Chirp_2, AssemblyAI Universal-1, and Speechmatics Ursa 2 models.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        Dictionary with three transcription results: 
        {"google_chirp2": STTResult, "assemblyai_universal": STTResult, "speechmatics_ursa": STTResult}
    """
    # Create copies of the audio stream for parallel processing
    audio_stream.seek(0)
    audio_data = audio_stream.getvalue()
    
    google_chirp2_stream = io.BytesIO(audio_data)
    assemblyai_stream = io.BytesIO(audio_data)
    speechmatics_stream = io.BytesIO(audio_data)
    
    results = {}
    
    print(f"[{datetime.datetime.now()}] INFO: Starting three-way STT comparison: Google Chirp_2, AssemblyAI Universal-1, Speechmatics Ursa 2")
    
    # Process Google Cloud STT with Chirp_2 model
    try:
        results["google_chirp2"] = await transcribe_audio(google_chirp2_stream, language_code, expected_text)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Google Cloud STT (Chirp_2) failed: {e}")
        results["google_chirp2"] = STTResult(
            text="", word_confidence=[], expected_text=expected_text, 
            word_comparisons=[], service_used="Google Cloud STT (Chirp_2)",
            processing_time=0.0, overall_confidence=0.0, model_used="chirp_2",
            audio_duration=0.0, real_time_factor=0.0
        )
    
    # Process AssemblyAI Universal-1 model
    try:
        results["assemblyai_universal"] = await transcribe_audio_assemblyai(assemblyai_stream, language_code, expected_text)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: AssemblyAI Universal-1 failed: {e}")
        results["assemblyai_universal"] = STTResult(
            text="", word_confidence=[], expected_text=expected_text, 
            word_comparisons=[], service_used="AssemblyAI Universal-1",
            processing_time=0.0, overall_confidence=0.0, model_used="universal-1",
            audio_duration=0.0, real_time_factor=0.0
        )
    
    # Process Speechmatics Ursa 2 model
    try:
        results["speechmatics_ursa"] = await transcribe_audio_speechmatics(speechmatics_stream, language_code, expected_text)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Speechmatics Ursa 2 failed: {e}")
        results["speechmatics_ursa"] = STTResult(
            text="", word_confidence=[], expected_text=expected_text, 
            word_comparisons=[], service_used="Speechmatics Ursa 2",
            processing_time=0.0, overall_confidence=0.0, model_used="ursa-2",
            audio_duration=0.0, real_time_factor=0.0
        )
    
    # Enhanced analysis with word-level metrics
    print(f"[{datetime.datetime.now()}] INFO: Performing enhanced word-level analysis...")
    for service_name, result in results.items():
        if result.word_confidence:
            # Calculate additional word-level metrics
            confidences = [w['confidence'] for w in result.word_confidence]
            result.average_word_confidence = sum(confidences) / len(confidences) if confidences else 0.0
            result.confidence_variance = np.var(confidences) if len(confidences) > 1 else 0.0
            result.low_confidence_words = [w['word'] for w in result.word_confidence if w['confidence'] < 0.7]
            
        else:
            result.average_word_confidence = result.overall_confidence
            result.confidence_variance = 0.0
            result.low_confidence_words = []
    
    print(f"[{datetime.datetime.now()}] INFO: Three-way STT comparison completed successfully")
    return results

async def transcribe_audio_assemblyai(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> STTResult:
    """
    Transcribes audio using AssemblyAI Universal-1 model with word-level confidence and timing.
    Optimized for high accuracy across 99 languages including Thai.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription (e.g., "tha" for Thai, "en" for English)
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        STTResult object with transcribed text, word-level confidence scores, and timing analysis
    """
    metrics = PerformanceMetrics()
    metrics.service_used = "AssemblyAI Universal-1"
    
    if not ASSEMBLYAI_API_KEY:
        error_msg = "AssemblyAI API key not configured. Check environment variables."
        metrics.set_error(ErrorCategory.API_AUTHENTICATION)
        log_performance_metrics(metrics, "AssemblyAI Universal-1", success=False)
        raise HTTPException(status_code=500, detail=error_msg)

    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        initial_stream_pos = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(initial_stream_pos)

        
        if stream_size == 0:
            print(f"[{datetime.datetime.now()}] ERROR STT: Stream is empty before calling AssemblyAI.")
            metrics.set_error(ErrorCategory.EMPTY_AUDIO)
            log_performance_metrics(metrics, "AssemblyAI Universal-1", success=False)
            raise HTTPException(status_code=400, detail="Audio stream is empty before STT processing.")

        # Calculate actual audio duration from WAV header and validate format
        audio_stream.seek(0)
        try:
            import wave
            with wave.open(audio_stream, 'rb') as wav_file:
                frames = wav_file.getnframes()
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()
                sample_width = wav_file.getsampwidth()
                actual_duration = frames / float(sample_rate)
                
                
                # Check if audio format is optimal for AssemblyAI
                if sample_rate == 16000:
                    print(f"[{datetime.datetime.now()}] ✓ Audio format is optimal for AssemblyAI")
                else:
                    print(f"[{datetime.datetime.now()}] ⚠ Audio sample rate {sample_rate}Hz is not optimal (16kHz preferred)")
        except Exception as wav_error:
            print(f"[{datetime.datetime.now()}] WARNING: Could not parse WAV header: {wav_error}")
            actual_duration = 0.0

        # Save audio to temporary file for AssemblyAI
        audio_stream.seek(0)
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            temp_file.write(audio_stream.getvalue())
            temp_file_path = temp_file.name

        try:
            # Configure AssemblyAI for Thai language with word-level features
            config = aai.TranscriptionConfig(
                language_code="th" if language_code.startswith("th") else "en",  # Thai language code
                speech_model=aai.SpeechModel.best,  # Use Universal-1 model for best accuracy
                punctuate=True,
                format_text=True,
                dual_channel=False,
                speaker_labels=False,
                language_detection=False,
                filter_profanity=False,
                redact_pii=False,
                sentiment_analysis=False,
                auto_chapters=False,
                entity_detection=False,
                summarization=False
            )

            # Create transcriber and perform transcription
            transcriber = aai.Transcriber(config=config)
            
            metrics.record_api_start()
            transcript = transcriber.transcribe(temp_file_path)
            metrics.record_api_end()

            if transcript.status == aai.TranscriptStatus.error:
                error_msg = f"AssemblyAI transcription failed: {transcript.error}"
                print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
                metrics.set_error(ErrorCategory.SERVICE_UNAVAILABLE)
                log_performance_metrics(metrics, "AssemblyAI Universal-1", success=False)
                raise HTTPException(status_code=500, detail=error_msg)

            # Extract transcribed text
            transcribed_text = transcript.text or ""
            overall_confidence = transcript.confidence if transcript.confidence is not None else 0.0
            
            # Extract word-level confidence and timing data
            word_confidence_list = []
            if transcript.words:
                for word in transcript.words:
                    word_confidence_list.append({
                        'word': word.text,
                        'confidence': word.confidence if word.confidence is not None else 0.0,
                        'start_time': word.start / 1000.0 if word.start is not None else 0.0,  # Convert ms to seconds
                        'end_time': word.end / 1000.0 if word.end is not None else 0.0,      # Convert ms to seconds
                    })
            else:
                pass

            # Calculate enhanced metrics
            word_count = len(word_confidence_list) if word_confidence_list else len(transcribed_text.split())
            average_word_confidence = sum(w['confidence'] for w in word_confidence_list) / max(word_count, 1) if word_confidence_list else overall_confidence
            
            # Finish metrics tracking
            metrics.finish_processing()
            processing_time = metrics.processing_time
            api_time = metrics.api_response_time
            real_time_factor = processing_time / max(actual_duration, 0.001)
            
            # Set transcription results for metrics
            confidence_scores = [w['confidence'] for w in word_confidence_list]
            metrics.set_transcription_results(word_count, confidence_scores)
            
            log_performance_metrics(metrics, "AssemblyAI Universal-1", success=True)

            print(f"[{datetime.datetime.now()}] SUCCESS: AssemblyAI transcription completed. Text: '{transcribed_text}', Confidence: {overall_confidence:.3f}, Words: {word_count}")

            # Compare with expected text if provided
            word_comparisons = []
            if expected_text and transcribed_text:
                word_comparisons = compare_expected_vs_transcribed(word_confidence_list, expected_text)

            return STTResult(
                text=transcribed_text,
                word_confidence=word_confidence_list,
                expected_text=expected_text,
                word_comparisons=word_comparisons,
                processing_time=processing_time,
                service_used="AssemblyAI Universal-1",
                overall_confidence=overall_confidence,
                model_used="universal-1",
                language_detected="th",
                language_probability=1.0,
                speaker_count=1,
                audio_events=[],
                audio_duration=actual_duration,
                real_time_factor=real_time_factor
            )
            
        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_file_path)
            except Exception as cleanup_error:
                print(f"[{datetime.datetime.now()}] WARNING: Could not clean up temp file: {cleanup_error}")

    except HTTPException as e:
        raise e
    except Exception as e:
        # Error handling and metrics
        current_pos_after_error = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size_after_error = audio_stream.tell()
        
        try:
            audio_stream.seek(0)
        except Exception:
            pass

        # Classify the error for better debugging  
        error_category = classify_error(e, "assemblyai universal-1")
        metrics.set_error(error_category)
        metrics.finish_processing()
        log_performance_metrics(metrics, "AssemblyAI Universal-1", success=False)

        print(f"[{datetime.datetime.now()}] ERROR: Error during AssemblyAI transcription: {e}. Stream pos: {current_pos_after_error}, size: {stream_size_after_error} after error.")
        raise HTTPException(status_code=500, detail=f"Error during speech-to-text processing: {str(e)}")

async def transcribe_audio_speechmatics(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> STTResult:
    """
    Transcribes audio using Speechmatics Ursa 2 model with word-level confidence and timing.
    Highest accuracy speech-to-text with support for 50+ languages including Thai.
    
    Args:
        audio_stream: A BytesIO stream of the audio file  
        language_code: The language code for transcription (e.g., "tha" for Thai, "en" for English)
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        STTResult object with transcribed text, word-level confidence scores, and timing analysis
    """
    metrics = PerformanceMetrics()
    metrics.service_used = "Speechmatics Ursa 2"
    
    if not SPEECHMATICS_API_KEY:
        error_msg = "Speechmatics API key not configured. Check environment variables."
        metrics.set_error(ErrorCategory.API_AUTHENTICATION)
        log_performance_metrics(metrics, "Speechmatics Ursa 2", success=False)
        raise HTTPException(status_code=500, detail=error_msg)

    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        initial_stream_pos = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(initial_stream_pos)

        
        if stream_size == 0:
            print(f"[{datetime.datetime.now()}] ERROR STT: Stream is empty before calling Speechmatics.")
            metrics.set_error(ErrorCategory.EMPTY_AUDIO)
            log_performance_metrics(metrics, "Speechmatics Ursa 2", success=False)
            raise HTTPException(status_code=400, detail="Audio stream is empty before STT processing.")

        # Calculate actual audio duration from WAV header and validate format
        audio_stream.seek(0)
        try:
            import wave
            with wave.open(audio_stream, 'rb') as wav_file:
                frames = wav_file.getnframes()
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()
                sample_width = wav_file.getsampwidth()
                actual_duration = frames / float(sample_rate)
                
                
                # Check if audio format is optimal for Speechmatics
                if sample_rate in [16000, 22050, 44100, 48000]:
                    print(f"[{datetime.datetime.now()}] ✓ Audio format is compatible with Speechmatics")
                else:
                    print(f"[{datetime.datetime.now()}] ⚠ Audio sample rate {sample_rate}Hz may not be optimal")
        except Exception as wav_error:
            print(f"[{datetime.datetime.now()}] WARNING: Could not parse WAV header: {wav_error}")
            actual_duration = 0.0

        # Save audio to temporary file for Speechmatics
        audio_stream.seek(0)
        audio_data = audio_stream.getvalue()

        # Configure Speechmatics for Thai language with word-level features
        transcription_config = TranscriptionConfig(
            language="th" if language_code.startswith("th") else "en"  # Thai language code
        )

        
        metrics.record_api_start()
        
        # Use Speechmatics async batch client
        client = SpeechmaticsAsyncClient(api_key=SPEECHMATICS_API_KEY)
        
        # Create temporary file for audio data
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_audio:
            temp_audio.write(audio_data)
            temp_audio_path = temp_audio.name
        
        try:
            # Submit transcription job with audio file
            # Use the correct method signature for AsyncClient.submit_job()
            with open(temp_audio_path, 'rb') as audio_file:
                job_details = await client.submit_job(
                    audio_file=audio_file,
                    transcription_config=transcription_config
                )
                job_id = job_details.id
            
            # Wait for completion with timeout
            transcript_result = await client.wait_for_completion(
                job_id=job_id,
                format_type=FormatType.JSON
            )
        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_audio_path)
            except OSError:
                pass
            
        metrics.record_api_end()

        # Extract results from Speechmatics response  
        if not transcript_result:
            error_msg = "Speechmatics returned empty response"
            print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
            metrics.set_error(ErrorCategory.API_ERROR)
            log_performance_metrics(metrics, "Speechmatics Ursa 2", success=False)
            raise HTTPException(status_code=500, detail=error_msg)

        # Access transcript text and confidence from the Transcript object
        transcribed_text = transcript_result.transcript_text if hasattr(transcript_result, 'transcript_text') else ""
        overall_confidence = transcript_result.confidence if hasattr(transcript_result, 'confidence') else 0.0
        
        # Extract word-level confidence and timing data from results
        word_confidence_list = []
        if hasattr(transcript_result, 'results') and transcript_result.results:
            for result in transcript_result.results:
                if hasattr(result, 'alternatives') and result.alternatives:
                    best_alternative = result.alternatives[0]
                    if hasattr(best_alternative, 'words') and best_alternative.words:
                        for word_data in best_alternative.words:
                            word_confidence_list.append({
                                'word': getattr(word_data, 'content', getattr(word_data, 'word', '')),
                                'confidence': getattr(word_data, 'confidence', 0.0),
                                'start_time': getattr(word_data, 'start_time', 0.0),
                                'end_time': getattr(word_data, 'end_time', 0.0),
                            })
        
        if not transcribed_text:
            print(f"[{datetime.datetime.now()}] INFO: Speechmatics detected no speech in audio")
        else:
            pass

        # Calculate enhanced metrics
        word_count = len(word_confidence_list) if word_confidence_list else len(transcribed_text.split())
        average_word_confidence = sum(w['confidence'] for w in word_confidence_list) / max(word_count, 1) if word_confidence_list else overall_confidence
        
        # Finish metrics tracking
        metrics.finish_processing()
        processing_time = metrics.processing_time
        api_time = metrics.api_response_time
        real_time_factor = processing_time / max(actual_duration, 0.001)
        
        # Set transcription results for metrics
        confidence_scores = [w['confidence'] for w in word_confidence_list]
        metrics.set_transcription_results(word_count, confidence_scores)
        
        log_performance_metrics(metrics, "Speechmatics Ursa 2", success=True)

        print(f"[{datetime.datetime.now()}] SUCCESS: Speechmatics transcription completed. Text: '{transcribed_text}', Confidence: {overall_confidence:.3f}, Words: {word_count}")

        # Compare with expected text if provided
        word_comparisons = []
        if expected_text and transcribed_text:
            word_comparisons = compare_expected_vs_transcribed(word_confidence_list, expected_text)

        return STTResult(
            text=transcribed_text,
            word_confidence=word_confidence_list,
            expected_text=expected_text,
            word_comparisons=word_comparisons,
            processing_time=processing_time,
            service_used="Speechmatics Ursa 2",
            overall_confidence=overall_confidence,
            model_used="ursa-2",
            language_detected="th",
            language_probability=1.0,
            speaker_count=1,
            audio_events=[],
            audio_duration=actual_duration,
            real_time_factor=real_time_factor
        )

    except HTTPException as e:
        raise e
    except Exception as e:
        # Error handling and metrics
        current_pos_after_error = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size_after_error = audio_stream.tell()
        
        try:
            audio_stream.seek(0)
        except Exception:
            pass

        # Classify the error for better debugging  
        error_category = classify_error(e, "speechmatics ursa 2")
        metrics.set_error(error_category)
        metrics.finish_processing()
        log_performance_metrics(metrics, "Speechmatics Ursa 2", success=False)

        print(f"[{datetime.datetime.now()}] ERROR: Error during Speechmatics transcription: {e}. Stream pos: {current_pos_after_error}, size: {stream_size_after_error} after error.")
        raise HTTPException(status_code=500, detail=f"Error during speech-to-text processing: {str(e)}")

# Backward compatibility function for existing code
async def transcribe_audio_simple(audio_stream: io.BytesIO, language_code: str = "tha") -> str:
    """
    Simplified version that returns just the text (for backward compatibility)
    """
    result = await transcribe_audio(audio_stream, language_code, "")
    return result.text

# ElevenLabs simple function for backward compatibility
async def transcribe_audio_elevenlabs_simple(audio_stream: io.BytesIO, language_code: str = "tha") -> str:
    """
    Simplified ElevenLabs version that returns just the text (for backward compatibility)
    """
    result = await transcribe_audio_elevenlabs(audio_stream, language_code)
    return result.text