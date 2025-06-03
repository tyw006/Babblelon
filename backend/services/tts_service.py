import os
import sys
from google import genai
from google.genai import types as genai_types # Alias to avoid conflict
from fastapi import HTTPException
import datetime # For potential debug logging with timestamps
import wave # Import the wave module
import io   # Import the io module

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
# Configure the genai client globally if not already done, or ensure it's configured before use.
# genai.configure(api_key=GEMINI_API_KEY) # This is often done at application startup.
# For services, it might be better to ensure the key exists and let the calling function handle client instantiation
# if a specific client instance is needed per call, or rely on global config.

if not GEMINI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: GEMINI_API_KEY (for Google GenAI) not found in environment variables.")
    # Depending on deployment, you might raise an error or have a fallback.


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
        # Using a client instance as it seems required for `client.models.generate_content_stream`
        client = genai.Client(api_key=GEMINI_API_KEY)

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
        for chunk_response in stream:
            if chunk_response.candidates:
                candidate = chunk_response.candidates[0]
                if candidate.content and candidate.content.parts:
                    part = candidate.content.parts[0]
                    if part.inline_data and part.inline_data.data:
                        yield part.inline_data.data
            # Add more detailed logging here if stream issues persist
            # else: print(f"[{datetime.datetime.now()}] DEBUG: TTS Stream - No relevant data in chunk_response: {chunk_response}")

    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: TTS Stream - Error during Google Gemini TTS: {e}")
        raise HTTPException(status_code=500, detail=f"TTS Stream: Error during text-to-speech conversion: {str(e)}")


async def text_to_speech_full(text_to_speak: str) -> bytes:
    """
    Converts text to speech using Google Gemini TTS, packages it as WAV, 
    and returns the full audio data as bytes.
    text_to_speak: The text to be converted to speech.
    Returns bytes of a complete WAV audio file.
    """
    if not GEMINI_API_KEY:
        print(f"[{datetime.datetime.now()}] ERROR: TTS Full - Google GenAI client not configured. API key missing.")
        raise HTTPException(status_code=500, detail="TTS Full: Google GenAI client not configured. Check API key.")

    try:
        print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Requesting raw audio for: '{text_to_speak}' with voice 'Puck'")
        client = genai.Client(api_key=GEMINI_API_KEY)

        response = client.models.generate_content(
            model="gemini-2.5-flash-preview-tts", 
            contents=text_to_speak,
            config=genai_types.GenerateContentConfig(
                response_modalities=["AUDIO"], # This should yield raw PCM data based on user's findings
                speech_config=genai_types.SpeechConfig(
                    voice_config=genai_types.VoiceConfig(
                        prebuilt_voice_config=genai_types.PrebuiltVoiceConfig(
                            voice_name="Puck" 
                        )
                    )
                ),
            ),
        )

        if response.candidates and response.candidates[0].content and response.candidates[0].content.parts:
            raw_pcm_data = response.candidates[0].content.parts[0].inline_data.data
            print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Successfully generated {len(raw_pcm_data)} bytes of raw PCM data.")

            # Now package this raw PCM data into a WAV file in memory
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, "wb") as wf:
                wf.setnchannels(1)       # Mono
                wf.setsampwidth(2)       # 16-bit PCM (2 bytes)
                wf.setframerate(24000)   # 24kHz sample rate
                wf.writeframes(raw_pcm_data)
            
            wav_bytes = wav_buffer.getvalue()
            print(f"[{datetime.datetime.now()}] DEBUG: TTS Full - Packaged PCM into WAV format, total {len(wav_bytes)} bytes.")
            return wav_bytes
        else:
            print(f"[{datetime.datetime.now()}] ERROR: TTS Full - No audio data received from Gemini. Response: {response}")
            raise HTTPException(status_code=500, detail="TTS Full: Failed to generate audio, no data in response.")

    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: TTS Full - Error during Google Gemini TTS (full) or WAV packaging: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"TTS Full: Error during text-to-speech conversion or WAV packaging: {str(e)}") 