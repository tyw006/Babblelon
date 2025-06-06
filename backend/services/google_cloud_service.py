import os
import base64
from fastapi import HTTPException
from google.cloud import translate_v3
from google.cloud import texttospeech
from pythainlp.transliterate import romanize

def get_google_cloud_project_id():
    """Retrieves the Google Cloud Project ID from environment variables."""
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project_id:
        print("ERROR: GOOGLE_CLOUD_PROJECT environment variable not set.")
        raise HTTPException(status_code=500, detail="Server is not configured for Google Cloud services (missing project ID).")
    return project_id

async def translate_text(text: str, target_language: str = "th") -> dict:
    """Translates text into the target language using Google Cloud Translate API."""
    try:
        project_id = get_google_cloud_project_id()
        client = translate_v3.TranslationServiceClient()
        parent = f"projects/{project_id}/locations/global"

        response = client.translate_text(
            request={
                "parent": parent,
                "contents": [text],
                "mime_type": "text/plain",
                "source_language_code": "en-US",
                "target_language_code": target_language,
            }
        )
        
        translated_text = response.translations[0].translated_text
        print(f"Successfully translated '{text}' to '{translated_text}'")
        return {"translated_text": translated_text}

    except Exception as e:
        print(f"Error during Google Cloud translation: {e}")
        raise HTTPException(status_code=500, detail=f"Google Cloud Translation API error: {e}")

async def romanize_thai_text(thai_text: str) -> dict:
    """Romanizes Thai text using PyThaiNLP."""
    if not thai_text or not thai_text.strip():
        return {"romanized_text": ""}
        
    try:
        romanized_text = romanize(thai_text, engine='thai2rom_onnx')
        print(f"Successfully romanized '{thai_text}' to '{romanized_text}' with PyThaiNLP")
        return {"romanized_text": romanized_text}
        
    except Exception as e:
        print(f"Error during PyThaiNLP romanization: {e}")
        raise HTTPException(status_code=500, detail=f"PyThaiNLP Romanization error: {e}")

async def synthesize_speech(text: str, language_code: str = "th-TH", voice_name: str = "th-TH-Standard-A") -> dict:
    """Synthesizes speech from text using Google Cloud TTS and returns as base64."""
    if not text or not text.strip():
        return {"audio_base64": ""}

    try:
        client = texttospeech.TextToSpeechClient()

        synthesis_input = texttospeech.SynthesisInput(text=text)

        voice = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            name=voice_name
        )

        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3
        )

        response = client.synthesize_speech(
            request={"input": synthesis_input, "voice": voice, "audio_config": audio_config}
        )
        
        audio_base64 = base64.b64encode(response.audio_content).decode("utf-8")
        print(f"Successfully synthesized audio for '{text}'")
        return {"audio_base64": audio_base64}

    except Exception as e:
        print(f"Error during Google Cloud TTS synthesis: {e}")
        raise HTTPException(status_code=500, detail=f"Google Cloud TTS API error: {e}") 