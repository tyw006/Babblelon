import os
import io
from elevenlabs.client import ElevenLabs
from fastapi import HTTPException

ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")

if not ELEVENLABS_API_KEY:
    print("Warning: ELEVENLABS_API_KEY not found in environment variables.")
    # You might want to raise an error or handle this more gracefully
    # For now, the service will fail if the key isn't present at runtime.

elevenlabs_client = None
if ELEVENLABS_API_KEY:
    try:
        elevenlabs_client = ElevenLabs(api_key=ELEVENLABS_API_KEY)
    except Exception as e:
        print(f"Error initializing ElevenLabs client: {e}")
        # The client will remain None, and calls will fail.

async def transcribe_audio(audio_stream: io.BytesIO) -> str:
    """
    Transcribes audio using ElevenLabs STT service.
    audio_stream: A BytesIO stream of the audio file.
    Returns the transcribed text or None if an error occurs.
    """
    if not elevenlabs_client:
        raise HTTPException(status_code=500, detail="ElevenLabs client not initialized. Check API key.")

    try:
        # The ElevenLabs SDK expects a file-like object that can be read.
        # Resetting the stream position in case it has been read before.
        audio_stream.seek(0)

        transcription_response = elevenlabs_client.speech_to_text.convert(
            file=audio_stream, # Pass the BytesIO stream directly
            model_id="scribe_v1", # Model to use
            # language_code="tha", # Optional: Specify language or let it auto-detect
        )
        
        if transcription_response and hasattr(transcription_response, 'text'):
            return transcription_response.text
        else:
            print("ElevenLabs STT did not return a valid text transcription.")
            return "" # Return empty string or handle as an error

    except Exception as e:
        print(f"Error during ElevenLabs STT: {e}")
        raise HTTPException(status_code=500, detail=f"Error during speech-to-text processing: {str(e)}") 