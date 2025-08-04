import os
import io
import tempfile
import time
import traceback
from typing import Dict, List, Optional, Union
import datetime
import asyncio
from fastapi import HTTPException
from openai import OpenAI
import logging

# Configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: OPENAI_API_KEY not found in environment variables.")

# Initialize OpenAI client
openai_client = None
if OPENAI_API_KEY:
    try:
        openai_client = OpenAI(api_key=OPENAI_API_KEY)
        print(f"[{datetime.datetime.now()}] INFO: OpenAI client initialized successfully")
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Failed to initialize OpenAI client: {e}")

class OpenAIWhisperResult:
    """Structure for OpenAI Whisper transcription results"""
    def __init__(self, text: str, processing_time: float, service_used: str = "openai_whisper",
                 language_detected: str = "", model_used: str = "whisper-1", 
                 audio_duration: float = 0.0, real_time_factor: float = 0.0,
                 cost_estimate: float = 0.0, is_translation: bool = False):
        self.text = text
        self.processing_time = processing_time
        self.service_used = service_used
        self.language_detected = language_detected
        self.model_used = model_used
        self.audio_duration = audio_duration
        self.real_time_factor = real_time_factor
        self.cost_estimate = cost_estimate
        self.is_translation = is_translation

def calculate_whisper_cost(audio_duration_seconds: float) -> float:
    """
    Calculate OpenAI Whisper API cost based on audio duration.
    Current pricing: $0.006 per minute
    """
    minutes = audio_duration_seconds / 60.0
    return round(minutes * 0.006, 4)

def get_audio_duration(audio_stream: io.BytesIO) -> float:
    """Extract audio duration from WAV file"""
    try:
        audio_stream.seek(0)
        import wave
        with wave.open(audio_stream, 'rb') as wav_file:
            frames = wav_file.getnframes()
            sample_rate = wav_file.getframerate()
            duration = frames / float(sample_rate)
            return duration
    except Exception as e:
        print(f"[{datetime.datetime.now()}] WARNING: Could not parse audio duration: {e}")
        # Fallback estimation: assume 16kHz, mono, 16-bit
        audio_stream.seek(0, io.SEEK_END)
        size = audio_stream.tell()
        return max(1.0, size / (16000 * 1 * 2))

async def transcribe_audio_openai(
    audio_stream: io.BytesIO, 
    language_code: str = "th",
    prompt: Optional[str] = None
) -> OpenAIWhisperResult:
    """
    Transcribes audio using OpenAI Whisper API (transcription endpoint).
    Maintains original language - Thai audio becomes Thai text.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        language_code: The language code for transcription (e.g., "th" for Thai)
        prompt: Optional prompt to guide the transcription
    
    Returns:
        OpenAIWhisperResult object with transcribed text and metrics
    """
    if not openai_client:
        error_msg = "OpenAI client not initialized. Check API key."
        print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
        raise HTTPException(status_code=500, detail=error_msg)

    start_time = time.time()
    
    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(0)

        print(f"[{datetime.datetime.now()}] DEBUG OpenAI Whisper: Stream size: {stream_size} bytes")
        
        if stream_size == 0:
            error_msg = "Audio stream is empty before OpenAI Whisper processing."
            print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)

        # Check file size limit (25MB)
        max_size = 25 * 1024 * 1024  # 25MB in bytes
        if stream_size > max_size:
            error_msg = f"Audio file too large ({stream_size} bytes). OpenAI Whisper limit is 25MB."
            print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)

        # Get audio duration for cost calculation
        audio_duration = get_audio_duration(audio_stream)
        cost_estimate = calculate_whisper_cost(audio_duration)
        
        print(f"[{datetime.datetime.now()}] INFO: OpenAI Whisper transcription starting")
        print(f"  - Audio duration: {audio_duration:.3f}s")
        print(f"  - File size: {stream_size} bytes")
        print(f"  - Estimated cost: ${cost_estimate:.4f}")
        print(f"  - Language: {language_code}")

        # Create temporary file for OpenAI API (required format)
        audio_stream.seek(0)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
            temp_file.write(audio_stream.getvalue())
            temp_file_path = temp_file.name

        try:
            # Prepare transcription parameters
            transcription_params = {
                "model": "whisper-1",
                "language": language_code,
                "response_format": "text"
            }
            
            # Add prompt if provided
            if prompt:
                transcription_params["prompt"] = prompt

            # Call OpenAI Whisper transcription API
            api_start_time = time.time()
            
            with open(temp_file_path, "rb") as audio_file:
                transcription = openai_client.audio.transcriptions.create(
                    file=audio_file,
                    **transcription_params
                )
            
            api_end_time = time.time()
            api_response_time = api_end_time - api_start_time

            # Extract transcribed text
            transcribed_text = transcription if isinstance(transcription, str) else getattr(transcription, 'text', str(transcription))
            
            end_time = time.time()
            processing_time = end_time - start_time
            real_time_factor = processing_time / audio_duration if audio_duration > 0 else 0.0

            logging.info(f"OpenAI Whisper transcription completed - text: '{transcribed_text[:50]}...', processing: {processing_time:.2f}s")

            return OpenAIWhisperResult(
                text=transcribed_text,
                processing_time=processing_time,
                service_used="openai_whisper_transcription",
                language_detected=language_code,
                model_used="whisper-1",
                audio_duration=audio_duration,
                real_time_factor=real_time_factor,
                cost_estimate=cost_estimate,
                is_translation=False
            )

        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_file_path)
            except Exception as cleanup_error:
                print(f"[{datetime.datetime.now()}] WARNING: Could not clean up temp file: {cleanup_error}")

    except Exception as e:
        end_time = time.time()
        processing_time = end_time - start_time
        
        print(f"[{datetime.datetime.now()}] ERROR: OpenAI Whisper transcription failed: {e}")
        print(f"[{datetime.datetime.now()}] DEBUG: Full error traceback: {traceback.format_exc()}")
        
        # Classify error for better handling
        error_message = str(e).lower()
        if "rate limit" in error_message or "quota" in error_message:
            raise HTTPException(status_code=429, detail=f"OpenAI API rate limit exceeded: {str(e)}")
        elif "unauthorized" in error_message or "authentication" in error_message:
            raise HTTPException(status_code=401, detail=f"OpenAI API authentication failed: {str(e)}")
        elif "file too large" in error_message or "size" in error_message:
            raise HTTPException(status_code=400, detail=f"Audio file too large for OpenAI Whisper: {str(e)}")
        else:
            raise HTTPException(status_code=500, detail=f"OpenAI Whisper transcription error: {str(e)}")

async def translate_audio_openai(
    audio_stream: io.BytesIO,
    prompt: Optional[str] = None
) -> OpenAIWhisperResult:
    """
    Translates audio using OpenAI Whisper API (translation endpoint).
    Converts any language audio to English text.
    
    Args:
        audio_stream: A BytesIO stream of the audio file
        prompt: Optional prompt to guide the translation
    
    Returns:
        OpenAIWhisperResult object with translated English text and metrics
    """
    if not openai_client:
        error_msg = "OpenAI client not initialized. Check API key."
        print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
        raise HTTPException(status_code=500, detail=error_msg)

    start_time = time.time()
    
    try:
        # Reset stream position and validate
        audio_stream.seek(0)
        audio_stream.seek(0, io.SEEK_END)
        stream_size = audio_stream.tell()
        audio_stream.seek(0)

        print(f"[{datetime.datetime.now()}] DEBUG OpenAI Whisper Translation: Stream size: {stream_size} bytes")
        
        if stream_size == 0:
            error_msg = "Audio stream is empty before OpenAI Whisper translation processing."
            print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)

        # Check file size limit (25MB)
        max_size = 25 * 1024 * 1024  # 25MB in bytes
        if stream_size > max_size:
            error_msg = f"Audio file too large ({stream_size} bytes). OpenAI Whisper limit is 25MB."
            print(f"[{datetime.datetime.now()}] ERROR: {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)

        # Get audio duration for cost calculation
        audio_duration = get_audio_duration(audio_stream)
        cost_estimate = calculate_whisper_cost(audio_duration)
        
        print(f"[{datetime.datetime.now()}] INFO: OpenAI Whisper translation starting")
        print(f"  - Audio duration: {audio_duration:.3f}s")
        print(f"  - File size: {stream_size} bytes")
        print(f"  - Estimated cost: ${cost_estimate:.4f}")
        print(f"  - Target language: English")

        # Create temporary file for OpenAI API (required format)
        audio_stream.seek(0)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
            temp_file.write(audio_stream.getvalue())
            temp_file_path = temp_file.name

        try:
            # Prepare translation parameters
            translation_params = {
                "model": "whisper-1",
                "response_format": "text"
            }
            
            # Add prompt if provided
            if prompt:
                translation_params["prompt"] = prompt

            # Call OpenAI Whisper translation API
            api_start_time = time.time()
            
            with open(temp_file_path, "rb") as audio_file:
                translation = openai_client.audio.translations.create(
                    file=audio_file,
                    **translation_params
                )
            
            api_end_time = time.time()
            api_response_time = api_end_time - api_start_time

            # Extract translated text
            translated_text = translation if isinstance(translation, str) else getattr(translation, 'text', str(translation))
            
            end_time = time.time()
            processing_time = end_time - start_time
            real_time_factor = processing_time / audio_duration if audio_duration > 0 else 0.0

            print(f"[{datetime.datetime.now()}] SUCCESS: OpenAI Whisper translation completed")
            print(f"  - Text: '{translated_text}'")
            print(f"  - Processing time: {processing_time:.3f}s")
            print(f"  - API response time: {api_response_time:.3f}s")
            print(f"  - Real-time factor: {real_time_factor:.3f}")
            print(f"  - Actual cost: ${cost_estimate:.4f}")

            return OpenAIWhisperResult(
                text=translated_text,
                processing_time=processing_time,
                service_used="openai_whisper_translation",
                language_detected="en",  # Translation always outputs English
                model_used="whisper-1",
                audio_duration=audio_duration,
                real_time_factor=real_time_factor,
                cost_estimate=cost_estimate,
                is_translation=True
            )

        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_file_path)
            except Exception as cleanup_error:
                print(f"[{datetime.datetime.now()}] WARNING: Could not clean up temp file: {cleanup_error}")

    except Exception as e:
        end_time = time.time()
        processing_time = end_time - start_time
        
        print(f"[{datetime.datetime.now()}] ERROR: OpenAI Whisper translation failed: {e}")
        print(f"[{datetime.datetime.now()}] DEBUG: Full error traceback: {traceback.format_exc()}")
        
        # Classify error for better handling
        error_message = str(e).lower()
        if "rate limit" in error_message or "quota" in error_message:
            raise HTTPException(status_code=429, detail=f"OpenAI API rate limit exceeded: {str(e)}")
        elif "unauthorized" in error_message or "authentication" in error_message:
            raise HTTPException(status_code=401, detail=f"OpenAI API authentication failed: {str(e)}")
        elif "file too large" in error_message or "size" in error_message:
            raise HTTPException(status_code=400, detail=f"Audio file too large for OpenAI Whisper: {str(e)}")
        else:
            raise HTTPException(status_code=500, detail=f"OpenAI Whisper translation error: {str(e)}")

# Utility functions for integration with existing codebase
async def transcribe_audio_openai_simple(audio_stream: io.BytesIO, language_code: str = "th") -> str:
    """
    Simplified version that returns just the text (for backward compatibility)
    """
    result = await transcribe_audio_openai(audio_stream, language_code)
    return result.text

async def translate_audio_openai_simple(audio_stream: io.BytesIO) -> str:
    """
    Simplified translation version that returns just the English text
    """
    result = await translate_audio_openai(audio_stream)
    return result.text