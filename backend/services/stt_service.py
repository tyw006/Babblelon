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
from difflib import SequenceMatcher
from elevenlabs.client import ElevenLabs
import ssl
import logging

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

# Initialize Google Cloud Speech client
api_endpoint = f"{LOCATION}-speech.googleapis.com"
speech_client = None

try:
    speech_client = SpeechClient(client_options=ClientOptions(api_endpoint=api_endpoint))
    print(f"[{datetime.datetime.now()}] INFO: Google Cloud Speech client initialized successfully")
except Exception as e:
    print(f"[{datetime.datetime.now()}] ERROR: Failed to initialize Google Cloud Speech client: {e}")

# Initialize ElevenLabs client
elevenlabs_client = None
if ELEVENLABS_API_KEY:
    try:
        elevenlabs_client = ElevenLabs(api_key=ELEVENLABS_API_KEY)
        print(f"[{datetime.datetime.now()}] INFO: ElevenLabs client initialized successfully")
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Failed to initialize ElevenLabs client: {e}")

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
    """Enhanced structure for STT results with word-level confidence and comparison"""
    def __init__(self, text: str, word_confidence: List[Dict[str, float]], 
                 expected_text: str = "", word_comparisons: List[WordComparison] = None,
                 processing_time: float = 0.0, service_used: str = "google"):
        self.text = text
        self.word_confidence = word_confidence
        self.expected_text = expected_text
        self.word_comparisons = word_comparisons or []
        self.processing_time = processing_time
        self.service_used = service_used

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

async def transcribe_audio(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> STTResult:
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

        print(f"[{datetime.datetime.now()}] DEBUG STT: Stream initial_pos: {initial_stream_pos}, size: {stream_size} before calling Google Cloud STT.")
        
        if stream_size == 0:
            print(f"[{datetime.datetime.now()}] ERROR STT: Stream is empty before calling Google Cloud STT.")
            metrics.set_error(ErrorCategory.EMPTY_AUDIO)
            log_performance_metrics(metrics, "Google Cloud STT", success=False)
            raise HTTPException(status_code=400, detail="Audio stream is empty before STT processing.")

        # Estimate audio duration (rough approximation for WAV files)
        # WAV file size approximation: bytes / (sample_rate * channels * bytes_per_sample)
        estimated_duration = max(1.0, stream_size / (16000 * 1 * 2))  # Assume 16kHz, mono, 16-bit
        metrics.set_audio_duration(estimated_duration)

        # Google Cloud STT can accept WAV directly - no need for redundant conversion
        audio_stream.seek(0)
        wav_content = audio_stream.getvalue()

        # Map language codes to Google Cloud format
        language_mapping = {
            "tha": "th-TH",
            "th": "th-TH", 
            "en": "en-US",
            "eng": "en-US"
        }
        gcloud_language_code = language_mapping.get(language_code, "th-TH")

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

        # Perform recognition with metrics tracking
        print(f"[{datetime.datetime.now()}] DEBUG STT: Starting Google Cloud STT using Chirp_2 model for language: {gcloud_language_code}")
        metrics.record_api_start()
        response = speech_client.recognize(request=request)
        metrics.record_api_end()

        # Process results
        transcribed_text = ""
        word_confidence_list = []

        for result in response.results:
            if result.alternatives:
                alternative = result.alternatives[0]
                transcribed_text = alternative.transcript
                
                # Extract word-level confidence
                if alternative.words:
                    for word_info in alternative.words:
                        word_confidence_list.append({
                            "word": word_info.word,
                            "confidence": word_info.confidence,
                            "start_time": word_info.start_offset.total_seconds() if word_info.start_offset else 0.0,
                            "end_time": word_info.end_offset.total_seconds() if word_info.end_offset else 0.0
                        })

                print(f"[{datetime.datetime.now()}] INFO: Google Cloud STT successful. Transcription: '{transcribed_text}'")
                print(f"[{datetime.datetime.now()}] DEBUG: Overall confidence: {alternative.confidence:.4f}, Words with confidence: {len(word_confidence_list)}")
                
                # Perform word comparison if expected text is provided
                word_comparisons = compare_expected_vs_transcribed(word_confidence_list, expected_text)
                
                # Set metrics for successful transcription
                confidence_scores = [wc["confidence"] for wc in word_confidence_list]
                metrics.set_transcription_results(len(word_confidence_list), confidence_scores)
                metrics.finish_processing()
                log_performance_metrics(metrics, "Google Cloud STT", success=True)
                
                return STTResult(
                    text=transcribed_text, 
                    word_confidence=word_confidence_list,
                    expected_text=expected_text,
                    word_comparisons=word_comparisons,
                    service_used="google"
                )

        # No results case
        print(f"[{datetime.datetime.now()}] WARNING: Google Cloud STT returned no results")
        metrics.set_error(ErrorCategory.TRANSCRIPTION_CONFIDENCE_LOW)
        metrics.finish_processing()
        log_performance_metrics(metrics, "Google Cloud STT", success=False)
        return STTResult(text="", word_confidence=[], expected_text=expected_text, word_comparisons=[], service_used="google")

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
        print(f"[{datetime.datetime.now()}] DEBUG STT: Error category: {error_category.value}")
        print(f"[{datetime.datetime.now()}] DEBUG STT: Full error traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Error during speech-to-text processing: {str(e)}")

async def transcribe_audio_elevenlabs(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> STTResult:
    """
    Transcribes audio using ElevenLabs Scribe v1 STT service.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription (e.g., "tha" for Thai, "en" for English)
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        STTResult object with transcribed text and processing time
    """
    metrics = PerformanceMetrics()
    metrics.service_used = "ElevenLabs Scribe v1"
    
    if not elevenlabs_client:
        error_msg = "ElevenLabs client not initialized. Check API key."
        metrics.set_error(ErrorCategory.API_AUTHENTICATION)
        log_performance_metrics(metrics, "ElevenLabs STT", success=False)
        raise HTTPException(status_code=500, detail=error_msg)

    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        initial_stream_pos = audio_stream.tell()
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(initial_stream_pos)

        print(f"[{datetime.datetime.now()}] DEBUG ElevenLabs STT: Stream initial_pos: {initial_stream_pos}, size: {stream_size} before STT processing.")
        
        if stream_size == 0:
            print(f"[{datetime.datetime.now()}] ERROR ElevenLabs STT: Stream is empty before processing.")
            raise HTTPException(status_code=400, detail="Audio stream is empty before STT processing.")

        # Start timing
        start_time = datetime.datetime.now()
        
        # Call ElevenLabs Scribe API - no format conversion needed
        transcription_response = elevenlabs_client.speech_to_text.convert(
            file=audio_stream,  # Pass the BytesIO stream directly
            model_id="scribe_v1",  # Model to use, currently only "scribe_v1" is supported
            language_code=language_code,  # Use the provided language code
        )
        
        # Calculate processing time
        end_time = datetime.datetime.now()
        processing_time = (end_time - start_time).total_seconds()
        
        if transcription_response and hasattr(transcription_response, 'text'):
            transcribed_text = transcription_response.text
            print(f"[{datetime.datetime.now()}] INFO: ElevenLabs STT successful. Transcription: '{transcribed_text}'")
            print(f"[{datetime.datetime.now()}] DEBUG: ElevenLabs processing time: {processing_time:.3f} seconds")
            
            # ElevenLabs doesn't provide word-level confidence, so create empty comparison
            word_comparisons = []
            if expected_text.strip():
                # Basic comparison without word-level details
                word_comparisons = [WordComparison(
                    word=transcribed_text,
                    confidence=1.0,  # ElevenLabs doesn't provide confidence scores
                    expected=expected_text,
                    match_type="exact" if transcribed_text.strip() == expected_text.strip() else "mismatch",
                    similarity=thai_word_similarity(transcribed_text, expected_text)
                )]
            
            # Set metrics for successful transcription
            metrics.set_transcription_results(1, [1.0])  # ElevenLabs doesn't provide confidence
            metrics.finish_processing()
            log_performance_metrics(metrics, "ElevenLabs STT", success=True)
            
            return STTResult(
                text=transcribed_text,
                word_confidence=[],  # ElevenLabs doesn't provide word-level confidence
                expected_text=expected_text,
                word_comparisons=word_comparisons,
                processing_time=processing_time,
                service_used="elevenlabs"
            )
        else:
            print(f"[{datetime.datetime.now()}] WARNING: ElevenLabs STT did not return valid text transcription.")
            metrics.set_error(ErrorCategory.TRANSCRIPTION_CONFIDENCE_LOW)
            metrics.finish_processing()
            log_performance_metrics(metrics, "ElevenLabs STT", success=False)
            return STTResult(
                text="", 
                word_confidence=[], 
                expected_text=expected_text, 
                word_comparisons=[],
                processing_time=processing_time,
                service_used="elevenlabs"
            )

    except ssl.SSLEOFError as ssl_e:
        error_msg = f"SSL EOF error during ElevenLabs STT: {ssl_e}. This might be a temporary network issue."
        print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
        raise HTTPException(status_code=503, detail=error_msg)
    
    except Exception as e:
        # Enhanced error logging with stream state
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
        error_category = classify_error(e, "elevenlabs stt")
        metrics.set_error(error_category)
        metrics.finish_processing()
        log_performance_metrics(metrics, "ElevenLabs STT", success=False)

        print(f"[{datetime.datetime.now()}] ERROR: Error during ElevenLabs STT: {e}. Stream pos: {current_pos_after_error}, size: {stream_size_after_error} after error.")
        print(f"[{datetime.datetime.now()}] DEBUG STT: Error category: {error_category.value}")
        print(f"[{datetime.datetime.now()}] DEBUG STT: Full error traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Error during ElevenLabs speech-to-text processing: {str(e)}")

async def parallel_transcribe_audio(audio_stream: io.BytesIO, language_code: str = "tha", expected_text: str = "") -> Dict[str, STTResult]:
    """
    Transcribes audio using both Google Cloud STT and ElevenLabs Scribe in parallel.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription
        expected_text: Optional expected text to compare against transcription
    
    Returns:
        Dictionary with both transcription results: {"google": STTResult, "elevenlabs": STTResult}
    """
    # Create copies of the audio stream for parallel processing
    audio_stream.seek(0)
    audio_data = audio_stream.getvalue()
    
    google_stream = io.BytesIO(audio_data)
    elevenlabs_stream = io.BytesIO(audio_data)
    
    results = {}
    
    # Process Google Cloud STT
    try:
        results["google"] = await transcribe_audio(google_stream, language_code, expected_text)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Google Cloud STT failed: {e}")
        results["google"] = STTResult(
            text="", word_confidence=[], expected_text=expected_text, 
            word_comparisons=[], service_used="google"
        )
    
    # Process ElevenLabs STT
    try:
        results["elevenlabs"] = await transcribe_audio_elevenlabs(elevenlabs_stream, language_code, expected_text)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: ElevenLabs STT failed: {e}")
        results["elevenlabs"] = STTResult(
            text="", word_confidence=[], expected_text=expected_text, 
            word_comparisons=[], service_used="elevenlabs"
        )
    
    return results

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