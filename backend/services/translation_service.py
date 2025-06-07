import os
import base64
import asyncio
from fastapi import HTTPException
from google.cloud import translate_v3
from google.cloud import texttospeech
from typing import List, Dict, Optional

# Language-specific configurations
LANGUAGE_CONFIGS = {
    "th": {
        "code": "th",
        "name": "Thai",
        "tts_code": "th-TH",
        "tts_voice": "th-TH-Standard-A",
        "tokenizer_available": True,
        "romanizer_available": True,
        "tokenizer_engine": "newmm",
        "romanizer_engine": "thai2rom"
    },
    "vi": {
        "code": "vi",
        "name": "Vietnamese",
        "tts_code": "vi-VN",
        "tts_voice": "vi-VN-Standard-A",
        "tokenizer_available": False,
        "romanizer_available": False
    },
    "zh": {
        "code": "zh",
        "name": "Chinese",
        "tts_code": "zh-CN",
        "tts_voice": "zh-CN-Standard-A",
        "tokenizer_available": False,
        "romanizer_available": False
    },
    "ja": {
        "code": "ja",
        "name": "Japanese",
        "tts_code": "ja-JP",
        "tts_voice": "ja-JP-Standard-A",
        "tokenizer_available": False,
        "romanizer_available": False
    },
    "ko": {
        "code": "ko",
        "name": "Korean",
        "tts_code": "ko-KR",
        "tts_voice": "ko-KR-Standard-A",
        "tokenizer_available": False,
        "romanizer_available": False
    }
}

def get_language_name(target_language: str) -> str:
    """Get the display name for a language code."""
    config = LANGUAGE_CONFIGS.get(target_language.lower(), LANGUAGE_CONFIGS["th"])
    return config.get("name", target_language.upper())

def get_language_config(target_language: str) -> dict:
    """Get language-specific configuration."""
    return LANGUAGE_CONFIGS.get(target_language.lower(), LANGUAGE_CONFIGS["th"])

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
        
        lang_config = get_language_config(target_language)

        response = client.translate_text(
            request={
                "parent": parent,
                "contents": [text],
                "mime_type": "text/plain",
                "source_language_code": "en-US",
                "target_language_code": lang_config["code"],
            }
        )
        
        translated_text = response.translations[0].translated_text
        print(f"Successfully translated '{text}' to '{translated_text}' in {target_language}")
        return {"translated_text": translated_text}

    except Exception as e:
        print(f"Error during Google Cloud translation: {e}")
        raise HTTPException(status_code=500, detail=f"Google Cloud Translation API error: {e}")

async def romanize_target_text(target_text: str, target_language: str = "th") -> dict:
    """Romanizes target language text with tokenization for proper spacing when available."""
    if not target_text or not target_text.strip():
        return {"romanized_text": ""}
    
    lang_config = get_language_config(target_language)
    
    # If romanization is not available for this language, return the original text
    if not lang_config.get("romanizer_available", False):
        print(f"Romanization not available for {target_language}, returning original text")
        return {"romanized_text": target_text}
        
    try:
        # Import language-specific libraries only when needed
        if target_language.lower() == "th":
            from pythainlp.transliterate import romanize
            from pythainlp.tokenize import word_tokenize
            
            # 1. Tokenize the target text into words
            target_words = word_tokenize(target_text, engine=lang_config["tokenizer_engine"])

            # 2. Romanize each word and 3. Join with spaces
            romanized_parts = []
            for word in target_words:
                if word.strip(): # Ensure word is not just whitespace
                    romanized_word = romanize(word, engine=lang_config["romanizer_engine"])
                    romanized_parts.append(romanized_word)

            spaced_romanization = " ".join(romanized_parts)
        else:
            # For other languages, implement specific romanization logic here
            spaced_romanization = target_text  # Fallback
        
        print(f"Successfully romanized '{target_text}' to '{spaced_romanization}' for {target_language}")
        return {"romanized_text": spaced_romanization}
        
    except Exception as e:
        print(f"Error during romanization for {target_language}: {e}")
        raise HTTPException(status_code=500, detail=f"Romanization error for {target_language}: {e}")

async def _translate_one_word(client, parent: str, word: str, source_lang: str, target_lang: str) -> tuple[str, str]:
    """Helper function to translate a single word for parallel execution."""
    try:
        clean_word = word.strip('.,!?;:"()[]{}')
        if not clean_word:
            return word, ""
        response = client.translate_text(
            request={
                "parent": parent,
                "contents": [clean_word],
                "mime_type": "text/plain",
                "source_language_code": source_lang,
                "target_language_code": target_lang,
            }
        )
        return word, response.translations[0].translated_text
    except Exception as e:
        print(f"Error translating individual word '{word}' from {source_lang} to {target_lang}: {e}")
        return word, "" # Return empty string on error to handle it gracefully downstream

async def create_word_level_translation_mapping(english_text: str, target_language: str = "th") -> dict:
    """
    Creates word-level mappings using a reverse-translation approach for accuracy.
    1. Translates the full English sentence to the target language for correct word order.
    2. Tokenizes the correct target sentence into words.
    3. In parallel:
        a. Synthesizes speech from the full, correct sentence.
        b. Translates each target language word BACK to English to create mappings.
    4. Combines the results, ensuring the UI reflects the correct sentence structure.
    """
    if not english_text or not english_text.strip():
        return {
            "target_text_spaced": "",
            "romanized_text": "",
            "audio_base64": "",
            "word_mappings": []
        }

    try:
        lang_config = get_language_config(target_language)
        project_id = get_google_cloud_project_id()
        client = translate_v3.TranslationServiceClient()
        parent = f"projects/{project_id}/locations/global"

        # 1. Translate the entire sentence first for correct word order
        full_sentence_response = client.translate_text(
            request={
                "parent": parent,
                "contents": [english_text],
                "mime_type": "text/plain",
                "source_language_code": "en-US",
                "target_language_code": lang_config["code"],
            }
        )
        full_target_text = full_sentence_response.translations[0].translated_text
        print(f"Full sentence translation (EN->TH): '{english_text}' -> '{full_target_text}'")

        # 2. Tokenize the correct target sentence into words
        if lang_config.get("tokenizer_available", False) and target_language.lower() == "th":
            from pythainlp.tokenize import word_tokenize
            target_words = [word for word in word_tokenize(full_target_text, engine=lang_config["tokenizer_engine"]) if word.strip()]
        else:
            target_words = [word for word in full_target_text.strip().split() if word.strip()]

        # 3. Prepare parallel tasks
        tasks = []

        # Task A: Synthesize speech from the full, correct sentence
        tasks.append(synthesize_speech(full_target_text, target_language))

        # Task B: Translate each target word BACK to English for mapping
        for word in target_words:
            tasks.append(_translate_one_word(client, parent, word, lang_config["code"], "en-US"))

        # 4. Run all tasks concurrently
        print(f"Executing {len(tasks)} parallel tasks (1 TTS + {len(target_words)} Word Translations)...")
        results = await asyncio.gather(*tasks, return_exceptions=True)
        print("Parallel execution finished.")

        # 5. Process results
        # First result is from TTS
        tts_result = results[0]
        if isinstance(tts_result, Exception):
            print(f"TTS task failed: {tts_result}")
            audio_base64 = ""
        else:
            audio_base64 = tts_result.get("audio_base64", "")

        # Subsequent results are from individual word back-translations (TH -> EN)
        back_translations = {
            original_word: translated_word
            for res in results[1:]
            if not isinstance(res, Exception) and (original_word := res[0]) and (translated_word := res[1])
        }

        # 6. Create final word mappings based on the correct target words
        word_mappings = []
        for target_word in target_words:
            english_mapping = back_translations.get(target_word, "")
            
            # Romanize the correctly ordered target word
            romanized_word = target_word # fallback
            if lang_config.get("romanizer_available", False) and target_language.lower() == "th":
                from pythainlp.transliterate import romanize
                romanized_word = romanize(target_word, engine=lang_config["romanizer_engine"]) if target_word.strip() else ""

            word_mappings.append({
                "english": english_mapping,
                "target": target_word,
                "romanized": romanized_word
            })

        # 7. Finalize texts for the response
        target_text_spaced = " ".join(target_words)
        romanized_text = " ".join([m["romanized"] for m in word_mappings])

        final_result = {
            "target_text_spaced": target_text_spaced,
            "romanized_text": romanized_text,
            "audio_base64": audio_base64,
            "word_mappings": word_mappings
        }
        
        print(f"Successfully created mapping for '{english_text}' with reverse translation.")
        return final_result
        
    except Exception as e:
        print(f"Error during reverse-translation mapping for {target_language}: {e}")
        raise HTTPException(status_code=500, detail=f"Word-level translation mapping error for {target_language}: {e}")

async def synthesize_speech(text: str, target_language: str = "th", custom_voice: Optional[str] = None) -> dict:
    """Synthesizes speech from text using Google Cloud TTS and returns as base64."""
    if not text or not text.strip():
        return {"audio_base64": ""}

    try:
        lang_config = get_language_config(target_language)
        
        client = texttospeech.TextToSpeechClient()

        synthesis_input = texttospeech.SynthesisInput(text=text)

        # Use custom voice if provided, otherwise use language default
        voice_name = custom_voice or lang_config["tts_voice"]
        language_code = lang_config["tts_code"]

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
        print(f"Successfully synthesized audio for '{text}' in {target_language}")
        return {"audio_base64": audio_base64}

    except Exception as e:
        print(f"Error during Google Cloud TTS synthesis for {target_language}: {e}")
        raise HTTPException(status_code=500, detail=f"Google Cloud TTS API error for {target_language}: {e}")

# Legacy function names for backward compatibility
async def romanize_thai_text(thai_text: str) -> dict:
    """Legacy function for backward compatibility."""
    return await romanize_target_text(thai_text, "th") 