import os
import sys
from google import genai
from google.genai import types as genai_types # Alias to avoid conflict
from fastapi import HTTPException

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    print("Warning: GEMINI_API_KEY (for Google GenAI) not found in environment variables.")


async def text_to_speech_stream(text_to_speak: str):
    """
    Converts text to speech using Google Gemini TTS and yields audio chunks.
    text_to_speak: The text to be converted to speech.
    Yields bytes of audio data (PCM L16).
    """
    if not GEMINI_API_KEY: # Check if API key was loaded, as client init is global
        raise HTTPException(status_code=500, detail="Google GenAI client not configured. Check API key.")

    try:
        # In the original script, client.models.generate_content_stream was used.
        # With the new genai library, it's usually genai.GenerativeModel(...).generate_content(...)
        # For TTS, it might be slightly different or require a specific model setup.
        # Let's adapt based on common genai TTS patterns.
        
        # The model name for TTS might be just "tts" or specific like "models/tts-1" or the one from your script.
        # Using the model from your script: "gemini-2.5-flash-preview-tts"
        # However, generate_content_stream is not directly on genai.GenerativeModel typically.
        # The original script's client.models.generate_content_stream suggests `genai.get_model` then stream, or a direct client call.
        # Let's try to stick to the structure from your test script as closely as possible,
        # assuming `genai.get_model` then `generate_content` which returns a stream if `stream=True`.
        # Or, if `genai.Client` was meant, and it has `models.generate_content_stream`.

        # Re-checking your `test_gemini_tts_stream.py`:
        # It was `client = genai.Client(api_key=...)` then `client.models.generate_content_stream`.
        # This suggests we need an instance of `genai.Client` if `genai.configure` is not enough for this specific call.
        # Let's instantiate a client within the function if the global configure isn't directly used by such a method.
        # For simplicity and to mirror your test, let's assume `genai.configure` works and try to access model streaming directly.
        # The API for TTS via `generate_content_stream` on a top-level client might be the specific pattern here.

        # Let's assume `genai.configure()` sets up the auth, and we need to find the streaming method.
        # `genai.GenerativeModel('gemini-2.5-flash-preview-tts')` might be the way to get the model. 
        # Then `model.generate_content(..., stream=True)`. 
        # But TTS sometimes has a different modality setup.
        
        # Sticking to your script's `client.models.generate_content_stream` implies a `genai.Client` instance.
        # Let's re-introduce the client if `genai.configure` isn't sufficient for this exact call structure.

        client = genai.Client(api_key=GEMINI_API_KEY) # Re-instantiate if needed for this specific call

        stream = client.models.generate_content_stream(
            model="gemini-2.5-flash-preview-tts", # From your test script
            contents=text_to_speak,
            config=genai_types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=genai_types.SpeechConfig(
                    voice_config=genai_types.VoiceConfig(
                        prebuilt_voice_config=genai_types.PrebuiltVoiceConfig(
                            voice_name="Puck"
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
                        # print(f"Yielding audio chunk of size: {len(part.inline_data.data)}") # For debugging
                        yield part.inline_data.data
                    # else: print("TTS Part has no inline_data.data")
                # else: print("TTS Candidate has no content or parts")
            # else: print("TTS Chunk has no candidates")
            # sys.stdout.flush() # For debugging in case of hangs

    except Exception as e:
        print(f"Error during Google Gemini TTS: {e}")
        # When streaming, raising HTTPException here might be tricky if headers are already sent.
        # Client will see a prematurely ended stream. Logging is crucial.
        # Depending on FastAPI, it might handle this by closing the connection.
        # For robustness, you might want to yield a specific error marker if possible,
        # or ensure the client can handle abruptly closed streams.
        # For now, let the exception propagate, which FastAPI should catch at a higher level if possible,
        # or the connection will drop.
        raise HTTPException(status_code=500, detail=f"Error during text-to-speech conversion: {str(e)}") 