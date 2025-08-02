import os
import sys
from google import genai
from google.genai import types as genai_types # Alias to avoid conflict
from fastapi import HTTPException
import datetime # For potential debug logging with timestamps
import wave # Import the wave module
import io   # Import the io module
from typing import Optional
import requests  # For PostHog tracking
import json
import time

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")
HELICONE_API_KEY = os.getenv("HELICONE_API_KEY")

# Configure the genai client globally if not already done, or ensure it's configured before use.
# genai.configure(api_key=GEMINI_API_KEY) # This is often done at application startup.
# For services, it might be better to ensure the key exists and let the calling function handle client instantiation
# if a specific client instance is needed per call, or rely on global config.

if not GEMINI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: GEMINI_API_KEY (for Google GenAI) not found in environment variables.")
    # Depending on deployment, you might raise an error or have a fallback.

if not HELICONE_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: HELICONE_API_KEY not found in environment variables. Cost tracking disabled.")
else:
    print(f"[{datetime.datetime.now()}] ✅ HELICONE_API_KEY configured - Gemini cost tracking enabled")

if POSTHOG_API_KEY:
    print(f"[{datetime.datetime.now()}] ✅ POSTHOG_API_KEY configured - TTS event tracking enabled")
else:
    print(f"[{datetime.datetime.now()}] WARNING: POSTHOG_API_KEY not found - TTS event tracking disabled")

print(f"[{datetime.datetime.now()}] 🚀 TTS Service initialized - Gemini API: {'configured' if GEMINI_API_KEY else 'missing'}, Helicone: {'enabled' if HELICONE_API_KEY else 'disabled'}, PostHog: {'enabled' if POSTHOG_API_KEY else 'disabled'}")

def track_tts_call_to_posthog(
    user_id: Optional[str] = None,
    session_id: Optional[str] = None,
    text_length: int = 0,
    voice_name: str = "Puck",
    duration_ms: int = 0,
    success: bool = True,
    error: Optional[str] = None
):
    """Track TTS API calls to PostHog for analytics"""
    if not POSTHOG_API_KEY:
        return
    
    try:
        event_data = {
            "api_key": POSTHOG_API_KEY,
            "event": "gemini_tts_call",
            "properties": {
                "service": "gemini_tts",
                "text_length": text_length,
                "voice_name": voice_name,
                "duration_ms": duration_ms,
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
            
        # Send to PostHog
        requests.post(
            "https://app.posthog.com/capture/",
            json=event_data,
            timeout=5
        )
        print(f"[{datetime.datetime.now()}] ✅ PostHog: TTS call tracked - success: {success}, text_length: {text_length}, voice: {voice_name}")
    except Exception as e:
        print(f"[{datetime.datetime.now()}] WARNING: Failed to track TTS call to PostHog: {e}")

def create_helicone_gemini_client() -> genai.Client:
    """Create a Gemini client that routes through Helicone Gateway for cost tracking"""
    if not GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY is required")
    
    if not HELICONE_API_KEY:
        print(f"[{datetime.datetime.now()}] WARNING: HELICONE_API_KEY missing - Gemini calls will not be tracked in Helicone")
        # Return regular client without Helicone tracking
        return genai.Client(api_key=GEMINI_API_KEY, vertexai=False)
    
    # Create Gemini client with Helicone Gateway integration
    client = genai.Client(
        api_key=GEMINI_API_KEY,
        vertexai=False,
        http_options={
            "base_url": "https://gateway.helicone.ai",
            "headers": {
                "helicone-auth": f"Bearer {HELICONE_API_KEY}",
                "helicone-target-url": "https://generativelanguage.googleapis.com"
            }
        }
    )
    
    print(f"[{datetime.datetime.now()}] ✅ Helicone: Gemini client configured with Gateway integration")
    print(f"[{datetime.datetime.now()}] 📊 Helicone Gateway: https://gateway.helicone.ai -> https://generativelanguage.googleapis.com")
    return client

def add_helicone_headers_for_tts(
    user_id: Optional[str] = None,
    session_id: Optional[str] = None,
    voice_name: str = "Puck",
    text_length: int = 0
) -> dict:
    """Generate additional Helicone headers for TTS tracking context"""
    headers = {
        "helicone-property-service": "gemini_tts",
        "helicone-property-voice": voice_name,
        "helicone-property-text-length": str(text_length),
    }
    
    if user_id:
        headers["helicone-user-id"] = user_id
    if session_id:
        headers["helicone-session-id"] = session_id
        
    return headers

def estimate_gemini_tts_cost(text_length: int) -> float:
    """Estimate cost for Gemini TTS based on character count
    
    Based on Gemini pricing: approximately $0.000016 per character
    This is an estimate - actual pricing may vary
    Note: Actual costs are tracked via Helicone Gateway integration
    """
    # Gemini TTS pricing (estimate based on available data)
    cost_per_character = 0.000016  # Approximate cost in USD
    return text_length * cost_per_character


async def text_to_speech_stream(text_to_speak: str):
    """
    Converts text to speech using Google Gemini TTS and yields audio chunks.
    text_to_speak: The text to be converted to speech.
    Yields bytes of audio data.
    """
    if not GEMINI_API_KEY:
        print(f"[{datetime.datetime.now()}] ERROR: TTS Stream - Google GenAI client not configured. API key missing.")
        raise HTTPException(status_code=500, detail="TTS Stream: Google GenAI client not configured. Check API key.")

    try:
        # Initialize Helicone-enabled Gemini client
        client = create_helicone_gemini_client()
        print(f"[{datetime.datetime.now()}] DEBUG: TTS Stream - Helicone-enabled Gemini client initialized for streaming")

        stream = client.models.generate_content_stream(
            model="gemini-2.5-flash-preview-tts", 
            contents=text_to_speak,
            config=genai_types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=genai_types.SpeechConfig(
                    voice_config=genai_types.VoiceConfig(
                        prebuilt_voice_config=genai_types.PrebuiltVoiceConfig(
                            voice_name="Puck" # Consistent voice
                        )
                    )
                ),
            ),
        )

        # Stream the audio data
        chunk_count = 0
        total_bytes = 0
        for chunk_response in stream:
            if chunk_response.candidates:
                candidate = chunk_response.candidates[0]
                if candidate.content and candidate.content.parts:
                    part = candidate.content.parts[0]
                    if part.inline_data and part.inline_data.data:
                        chunk_count += 1
                        total_bytes += len(part.inline_data.data)
                        yield part.inline_data.data
            # Add more detailed logging here if stream issues persist
            # else: print(f"[{datetime.datetime.now()}] DEBUG: TTS Stream - No relevant data in chunk_response: {chunk_response}")
        
        print(f"[{datetime.datetime.now()}] DEBUG: TTS Stream - Streaming completed. Chunks: {chunk_count}, Total bytes: {total_bytes}")
        print(f"[{datetime.datetime.now()}] ✅ Helicone: TTS streaming call completed via Gateway - text_length: {len(text_to_speak)}, chunks: {chunk_count}")
        
        # Track successful streaming call to PostHog (Helicone tracking happens automatically via Gateway)
        track_tts_call_to_posthog(
            text_length=len(text_to_speak),
            voice_name='Puck',
            success=True
        )

    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: TTS Stream - Error during Google Gemini TTS: {e}")
        
        # Track failed streaming call (Helicone tracking happens automatically via Gateway)
        print(f"[{datetime.datetime.now()}] ❌ Helicone: TTS streaming call failed via Gateway - error: {str(e)}")
        track_tts_call_to_posthog(
            text_length=len(text_to_speak),
            voice_name='Puck',
            success=False,
            error=str(e)
        )
        
        raise HTTPException(status_code=500, detail=f"TTS Stream: Error during text-to-speech conversion: {str(e)}")


async def text_to_speech_full(
    text_to_speak: str, 
    voice_name: str = "Puck", 
    response_tone: Optional[str] = None,
    user_id: Optional[str] = None,
    session_id: Optional[str] = None
) -> bytes:
    """
    Converts text to speech using Google Gemini TTS, packages it as WAV, 
    and returns the full audio data as bytes.
    text_to_speak: The text to be converted to speech.
    voice_name: The prebuilt voice name to use for TTS.
    response_tone: Optional tone for the speech, will be prepended if provided.
    Returns bytes of a complete WAV audio file.
    """
    if not GEMINI_API_KEY:
        print(f"[{datetime.datetime.now()}] ERROR: TTS Full - Google GenAI client not configured. API key missing.")
        raise HTTPException(status_code=500, detail="TTS Full: Google GenAI client not configured. Check API key.")

    final_text_to_speak = text_to_speak
    if response_tone and response_tone.strip():
        final_text_to_speak = f"In a {response_tone.strip()} tone: {text_to_speak}"

    try:
        # Initialize Helicone-enabled Gemini client
        client = create_helicone_gemini_client()
        print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Helicone-enabled Gemini client initialized for full synthesis")

        # Generate additional Helicone headers for context
        helicone_headers = add_helicone_headers_for_tts(
            user_id=user_id,
            session_id=session_id,
            voice_name=voice_name,
            text_length=len(final_text_to_speak)
        )
        
        # Track timing for analytics
        start_time = time.time()
        estimated_cost = estimate_gemini_tts_cost(len(final_text_to_speak))
        print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Starting synthesis. Text length: {len(final_text_to_speak)}, Estimated cost: ${estimated_cost:.6f}")
        print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Helicone headers: {helicone_headers}")
        
        # Make the TTS call through Helicone Gateway (automatic tracking)
        response = client.models.generate_content(
            model="gemini-2.5-flash-preview-tts", 
            contents=final_text_to_speak,
            config=genai_types.GenerateContentConfig(
                response_modalities=["AUDIO"], # This should yield raw PCM data based on user's findings
                speech_config=genai_types.SpeechConfig(
                    voice_config=genai_types.VoiceConfig(
                        prebuilt_voice_config=genai_types.PrebuiltVoiceConfig(
                            voice_name=voice_name # Use the passed voice_name
                        )
                    )
                ),
            ),
            # Note: Additional headers are set at client level via http_options
        )
        
        # Calculate timing
        duration_ms = int((time.time() - start_time) * 1000)

        if response.candidates and response.candidates[0].content and response.candidates[0].content.parts:
            raw_pcm_data = response.candidates[0].content.parts[0].inline_data.data
            # print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Successfully generated {len(raw_pcm_data)} bytes of raw PCM data.") # Commented out

            # Now package this raw PCM data into a WAV file in memory
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, "wb") as wf:
                wf.setnchannels(1)       # Mono
                wf.setsampwidth(2)       # 16-bit PCM (2 bytes)
                wf.setframerate(24000)   # 24kHz sample rate
                wf.writeframes(raw_pcm_data)
            
            wav_bytes = wav_buffer.getvalue()
            # print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Packaged PCM into WAV format, total {len(wav_bytes)} bytes.") # Commented out
            
            # Track successful TTS call to PostHog (Helicone tracking happens automatically via Gateway)
            track_tts_call_to_posthog(
                user_id=user_id,
                session_id=session_id,
                text_length=len(final_text_to_speak),
                voice_name=voice_name,
                duration_ms=duration_ms,
                success=True
            )
            
            print(f"[{datetime.datetime.now()}] ✅ TTS Full - Synthesis completed successfully. Duration: {duration_ms}ms, Audio size: {len(wav_bytes)} bytes")
            print(f"[{datetime.datetime.now()}] ✅ Helicone: TTS call completed via Gateway - user: {user_id}, cost: ${estimated_cost:.6f}, voice: {voice_name}")
            
            return wav_bytes
        else:
            print(f"[{datetime.datetime.now()}] ERROR: TTS Full - No audio data received from Gemini. Response: {response}")
            raise HTTPException(status_code=500, detail="TTS Full: Failed to generate audio, no data in response.")

    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: TTS Full - Error during Google Gemini TTS (full) or WAV packaging: {e}")
        import traceback
        traceback.print_exc()
        
        # Track failed TTS call to PostHog (Helicone tracking happens automatically via Gateway)
        duration_ms = int((time.time() - start_time) * 1000) if 'start_time' in locals() else 0
        estimated_cost = estimate_gemini_tts_cost(len(final_text_to_speak)) if 'final_text_to_speak' in locals() else 0.0
        
        track_tts_call_to_posthog(
            user_id=user_id,
            session_id=session_id,
            text_length=len(final_text_to_speak),
            voice_name=voice_name,
            duration_ms=duration_ms,
            success=False,
            error=str(e)
        )
        
        print(f"[{datetime.datetime.now()}] ❌ Helicone: TTS call failed via Gateway - user: {user_id}, error: {str(e)}, cost: ${estimated_cost:.6f}")
        
        raise HTTPException(status_code=500, detail=f"TTS Full: Error during text-to-speech conversion or WAV packaging: {str(e)}") 