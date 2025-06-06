import os
import base64
from fastapi import HTTPException
from google.cloud import translate_v3
from google.cloud import texttospeech
from pythainlp.transliterate import romanize
from pythainlp.tokenize import word_tokenize

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
    """Romanizes Thai text using PyThaiNLP with tokenization for proper spacing."""
    if not thai_text or not thai_text.strip():
        return {"romanized_text": ""}
        
    try:
        # 1. Tokenize the Thai text into words
        thai_words = word_tokenize(thai_text, engine="newmm")

        # 2. Romanize each word and 3. Join with spaces
        romanized_parts = []
        for word in thai_words:
            if word.strip(): # Ensure word is not just whitespace
                romanized_word = romanize(word, engine="thai2rom")
                romanized_parts.append(romanized_word)

        spaced_romanization = " ".join(romanized_parts)
        
        print(f"Successfully romanized '{thai_text}' to '{spaced_romanization}' with PyThaiNLP")
        return {"romanized_text": spaced_romanization}
        
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
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=0.8
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