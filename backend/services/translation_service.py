import os
import base64
import asyncio
import json
import time
import logging
from fastapi import HTTPException
from google.cloud import translate_v3
from google.cloud import texttospeech
from typing import List, Dict, Optional
from pythainlp.transliterate import romanize
from pythainlp.tokenize import subword_tokenize, word_tokenize

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

def load_thai_writing_guide() -> dict:
    """Load the Thai writing guide JSON data."""
    try:
        # Get the project root directory (go up from backend/services/)
        current_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(os.path.dirname(current_dir))
        guide_path = os.path.join(project_root, "assets", "data", "thai_writing_guide.json")
        
        with open(guide_path, 'r', encoding='utf-8') as file:
            return json.load(file)
    except Exception as e:
        print(f"Error loading Thai writing guide: {e}")
        return {}

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

async def _romanize_word_async(word: str, engine: str) -> str:
    """Helper function to romanize a single word for parallel execution."""
    try:
        if not word.strip():
            return ""
        from pythainlp.transliterate import romanize
        return romanize(word, engine=engine)
    except Exception as e:
        print(f"Error romanizing word '{word}': {e}")
        return word  # Return original word on error

async def _analyze_subword_async(subword: str) -> dict:
    """Helper function to analyze a single subword for parallel execution."""
    try:
        from pythainlp.util.thai import thai_consonants as consonants, thai_vowels as vowels, thai_tonemarks as tone_marks
        
        # Define character classification functions since they don't exist in util
        def is_thai_consonant(char):
            return char in consonants
        
        def is_thai_vowel(char):
            return char in vowels
            
        def is_thai_tone(char):
            return char in tone_marks
        
        analysis = {'consonants': [], 'vowels': [], 'tone_marks': [], 'others': []}
        
        for char in subword:
            if is_thai_consonant(char):
                analysis['consonants'].append(char)
            elif is_thai_vowel(char):
                analysis['vowels'].append(char)
            elif is_thai_tone(char):
                analysis['tone_marks'].append(char)
            else:
                analysis['others'].append(char)
        
        return {
            'subword': subword,
            'analysis': analysis,
            'char_count': len(subword)
        }
    except Exception as e:
        print(f"Error analyzing subword '{subword}': {e}")
        return {'subword': subword, 'analysis': {}, 'error': str(e)}

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

        # 6. Create final word mappings with parallel romanization
        word_mappings = []
        
        # If Thai, romanize all words in parallel
        if lang_config.get("romanizer_available", False) and target_language.lower() == "th":
            from pythainlp.transliterate import romanize
            romanization_tasks = [
                _romanize_word_async(word, lang_config["romanizer_engine"]) 
                for word in target_words
            ]
            romanization_results = await asyncio.gather(*romanization_tasks, return_exceptions=True)
            romanized_words = {
                target_words[i]: result if not isinstance(result, Exception) else target_words[i]
                for i, result in enumerate(romanization_results)
            }
        else:
            romanized_words = {word: word for word in target_words}
        
        # Create word mappings
        for target_word in target_words:
            english_mapping = back_translations.get(target_word, "")
            romanized_word = romanized_words.get(target_word, target_word)

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

# --- Thai Character Tracing and Writing Guidance Functions ---

async def get_thai_writing_tips(character: str, target_language: str = "th", context_word: str = None, position_in_word: int = 0) -> dict:
    """Get Thai-specific writing guidance with contextual rules and tooltips."""
    if target_language.lower() != "th":
        return {"character": character, "tips": [], "is_supported": False}
    
    # Load the enhanced writing guide
    writing_guide = load_thai_writing_guide()
    
    tips = []
    contextual_rules = []
    tooltips = []
    
    # Get basic character info (focus on technical aspects, not cultural context)
    consonant_info = writing_guide.get("consonants", {}).get(character, {})
    vowel_info = writing_guide.get("vowels", {}).get(f"◌{character}", {}) or writing_guide.get("vowels", {}).get(f"{character}◌", {})
    tone_info = writing_guide.get("tone_marks", {}).get(character, {})
    
    # Add basic writing tips (exclude cultural context)
    if consonant_info:
        # Only include technical writing tips, exclude cultural context
        common_tips = consonant_info.get("common_tips", [])
        filtered_tips = [tip for tip in common_tips if not any(cultural_word in tip.lower() 
                        for cultural_word in ["alphabet", "first letter", "easy to remember", "like", "shape"])]
        tips.extend(filtered_tips)
        if "special_rules" in consonant_info:
            contextual_rules.extend(consonant_info["special_rules"])
    elif vowel_info:
        common_tips = vowel_info.get("common_tips", [])
        filtered_tips = [tip for tip in common_tips if not any(cultural_word in tip.lower() 
                        for cultural_word in ["easy", "remember", "like", "shape"])]
        tips.extend(filtered_tips)
    elif tone_info:
        common_tips = tone_info.get("common_tips", [])
        filtered_tips = [tip for tip in common_tips if not any(cultural_word in tip.lower() 
                        for cultural_word in ["easy", "remember", "like", "shape"])]
        tips.extend(filtered_tips)
    
    # Add contextual analysis if word context is provided
    if context_word and position_in_word is not None:
        contextual_analysis = _analyze_character_context(character, context_word, position_in_word, writing_guide)
        tips.extend(contextual_analysis.get("tips", []))
        contextual_rules.extend(contextual_analysis.get("rules", []))
        tooltips.extend(contextual_analysis.get("tooltips", []))
    
    # Add technical writing guidance (no cultural references)
    if character in ['อ', 'ด', 'ต', 'บ', 'ป', 'ภ', 'ฟ', 'ฝ', 'ล', 'ม', 'ว', 'ส', 'ห', 'ฮ']:
        tips.append("Start with the circular component, draw clockwise from the top")
    
    # Leading vowels (appear before consonant when reading)
    if character in ['เ', 'แ', 'โ', 'ใ', 'ไ']:
        tips.append("This vowel appears BEFORE the consonant when reading, but write the consonant first")
    
    # Vowel positioning
    if character in ['ิ', 'ี', 'ึ', 'ื', '่', '้', '๊', '๋']:
        tips.append("This mark goes ABOVE the consonant")
    elif character in ['ุ', 'ู']:
        tips.append("This mark goes BELOW the consonant")
    
    # Complex characters with specific guidance
    if character in ['ผ', 'ฝ', 'ฟ']:
        tips.append("Start with the vertical line on the left, then add the curved components")
    elif character in ['ค', 'ข']:
        tips.append("Draw the main body first, then add the horizontal line")
    
    # Characters with loops
    if character in ['ญ', 'ย']:
        tips.append("Make sure the loop is clearly defined and connected")
    
    return {
        "character": character,
        "tips": tips,
        "contextual_rules": contextual_rules,
        "tooltips": tooltips,
        "is_vowel": character in 'เแโใไิีึืุู่้๊๋',
        "is_tone_mark": character in '่้๊๋',
        "is_supported": True,
        "context_analysis": {
            "word": context_word,
            "position": position_in_word,
            "has_special_rules": len(contextual_rules) > 0
        }
    }

def _analyze_character_context(character: str, word: str, position: int, writing_guide: dict) -> dict:
    """Analyze a character's role within its word context and provide specific guidance."""
    tips = []
    rules = []
    tooltips = []
    
    interaction_rules = writing_guide.get("consonant_interaction_rules", {})
    contextual_tips = writing_guide.get("contextual_tips", {})
    
    # Enhanced silent modifier detection
    if character == "ห" and position < len(word) - 1:
        next_char = word[position + 1] if position + 1 < len(word) else None
        if next_char and _is_consonant(next_char):
            next_char_class = _get_consonant_class(next_char, writing_guide)
            silent_rules = interaction_rules.get("silent_modifiers", {}).get("rules", [])
            
            for rule in silent_rules:
                if rule["pattern"] == "ห + low/mid consonant" and next_char_class in ["low", "mid"]:
                    rules.append(f"'{character}' is silent here - it changes the tone of '{next_char}' instead of making a sound")
                    
                    # Find example from the rule if available
                    examples = rule.get("examples", [])
                    example_word = None
                    for example in examples:
                        if example["word"] == word:
                            example_word = example
                            break
                    
                    if example_word:
                        explanation = example_word.get("explanation", f"ห is silent, but changes {next_char} tone")
                        pronunciation = example_word.get("pronunciation", "")
                        meaning = example_word.get("meaning", "")
                        
                        tooltips.append({
                            "type": "silent_modifier",
                            "title": "Silent Tone Modifier",
                            "explanation": f"In '{word}' ({meaning}): {explanation}",
                            "pronunciation": pronunciation,
                            "meaning_focus": f"Focus on learning '{word}' as a complete word - the ห is doing grammar work, not sound work."
                        })
                        tips.append(f"🔇 This ห is silent in '{word}' - its job is to change the tone")
                    else:
                        tooltips.append({
                            "type": "silent_modifier",
                            "title": "Silent Tone Modifier",
                            "explanation": f"In '{word}', the ห doesn't make an 'h' sound. It's a special rule that changes how '{next_char}' sounds.",
                            "meaning_focus": f"Focus on learning '{word}' as a complete word - the ห is doing grammar work, not sound work."
                        })
                        tips.append("🔇 This ห is silent - its job is to change the tone, not add sound")
                    break
    
    # Enhanced consonant cluster detection
    if position < len(word) - 1:
        cluster = word[position:position+2]
        cluster_rules = interaction_rules.get("consonant_clusters", {}).get("rules", [])
        
        for rule in cluster_rules:
            if rule["pattern"] == cluster:
                sound_change = rule["sound_change"]
                rules.append(f"'{cluster}' makes '{sound_change}' - not individual sounds")
                
                # Find specific example for this word if available
                examples = rule.get("examples", [])
                example_word = None
                for example in examples:
                    if example["word"] == word:
                        example_word = example
                        break
                
                if example_word:
                    pronunciation = example_word.get("pronunciation", "")
                    meaning = example_word.get("meaning", "")
                    explanation = example_word.get("explanation", f"{cluster} transforms to {sound_change} sound")
                    
                    tooltips.append({
                        "type": "cluster_transformation",
                        "title": "Consonant Cluster",
                        "explanation": f"In '{word}' ({meaning}): {explanation}",
                        "pronunciation": pronunciation,
                        "meaning_focus": f"Learn how '{cluster}' sounds in '{word}' rather than individual letters."
                    })
                    tips.append(f"🔄 '{cluster}' in '{word}' makes '{sound_change}' sound")
                else:
                    tooltips.append({
                        "type": "cluster_transformation", 
                        "title": "Consonant Cluster",
                        "explanation": f"'{cluster}' works as a team to make a '{sound_change}' sound.",
                        "meaning_focus": f"Learn how '{cluster}' sounds in '{word}' rather than individual letters."
                    })
                    tips.append(f"🔄 '{character}' + next letter = {sound_change} (they work together)")
                break
    
    # Add consonant position context within word
    if _is_consonant(character):
        consonant_position = _detect_consonant_position_in_word(character, word, position)
        consonant_class = _get_consonant_class(character, writing_guide)
        
        # Add position-specific tips
        if consonant_position == "initial":
            tips.append(f"This consonant starts the word - it affects the overall tone")
            if consonant_class != "unknown":
                tips.append(f"As a {consonant_class}-class consonant, it influences tone rules")
        elif consonant_position == "final":
            tips.append(f"This consonant ends the word - final consonants often change pronunciation")
        elif consonant_position == "medial":
            tips.append(f"This consonant is in the middle - it connects word parts")
        
        # Add tone class information if relevant
        if consonant_class in ["high", "mid", "low"]:
            tooltips.append({
                "type": "consonant_class",
                "title": f"{consonant_class.title()}-Class Consonant",
                "explanation": f"'{character}' is a {consonant_class}-class consonant which affects tone rules in Thai.",
                "meaning_focus": f"In '{word}', this affects how the word should be pronounced."
            })
    
    # Determine position context for compound words
    word_tokenization = word_tokenize(word, engine='newmm') if word else [word]
    if len(word_tokenization) > 1:  # It's a compound word
        # Find which semantic unit this character belongs to
        char_position = 0
        for i, unit in enumerate(word_tokenization):
            if char_position <= position < char_position + len(unit):
                position_in_unit = position - char_position
                unit_position = i
                
                compound_tips = contextual_tips.get("in_compound_words", {}).get("tips", [])
                if unit_position == 0:
                    # Beginning of compound
                    tip_data = next((t for t in compound_tips if t["context"] == "beginning_of_compound"), None)
                    if tip_data:
                        tips.append(f"📖 {tip_data['guidance']}")
                        tooltips.append({
                            "type": "compound_position", 
                            "title": "Start of Compound Word",
                            "explanation": f"'{character}' starts the '{unit}' part of '{word}'",
                            "meaning_focus": f"This part means something specific in the whole word"
                        })
                elif unit_position == len(word_tokenization) - 1:
                    # End of compound
                    tip_data = next((t for t in compound_tips if t["context"] == "end_of_compound"), None)
                    if tip_data:
                        tips.append(f"🏁 {tip_data['guidance']}")
                        tooltips.append({
                            "type": "compound_position",
                            "title": "End of Compound Word", 
                            "explanation": f"'{character}' is in the '{unit}' part that completes '{word}'",
                            "meaning_focus": f"This part adds the final meaning to the whole word"
                        })
                else:
                    # Middle of compound
                    tip_data = next((t for t in compound_tips if t["context"] == "middle_of_compound"), None)
                    if tip_data:
                        tips.append(f"🔗 {tip_data['guidance']}")
                        tooltips.append({
                            "type": "compound_position",
                            "title": "Middle of Compound Word",
                            "explanation": f"'{character}' is in the '{unit}' part that connects parts of '{word}'",
                            "meaning_focus": f"This part bridges the meanings together"
                        })
                break
            char_position += len(unit)
    else:
        # Single semantic word
        tips.append("📝 This character is part of a single meaningful word")
        tooltips.append({
            "type": "single_word",
            "title": "Complete Word",
            "explanation": f"'{character}' is part of '{word}', which is one complete word",
            "meaning_focus": f"Focus on learning '{word}' as a complete unit"
        })
    
    # Add sound vs meaning guidance
    sound_tips = contextual_tips.get("sound_vs_meaning", {}).get("tips", [])
    if not any(rule for rule in rules if "silent" in rule):  # Normal pronunciation
        normal_tip = next((t for t in sound_tips if t["situation"] == "normal_pronunciation"), None)
        if normal_tip:
            tips.append(f"🔊 {normal_tip['tip']}")
    
    return {
        "tips": tips,
        "rules": rules,
        "tooltips": tooltips
    }

def _is_consonant(char: str) -> bool:
    """Check if a character is a Thai consonant."""
    # Thai consonant range in Unicode
    return '\u0e01' <= char <= '\u0e2e'

def _get_consonant_class(char: str, writing_guide: dict) -> str:
    """Get the consonant class (high, mid, low) for tone rules."""
    tone_interaction = writing_guide.get("consonant_interaction_rules", {}).get("tone_interaction", {})
    
    if char in tone_interaction.get("high_class", []):
        return "high"
    elif char in tone_interaction.get("mid_class", []):
        return "mid"
    elif char in tone_interaction.get("low_class", []):
        return "low"
    else:
        return "unknown"

def _detect_consonant_position_in_word(char: str, word: str, position: int) -> str:
    """Detect if consonant is at beginning, middle, or end of semantic word."""
    if position == 0:
        return "initial"
    elif position == len(word) - 1:
        return "final"
    else:
        return "medial"

def _get_character_difficulty(character: str) -> str:
    """Assess the difficulty level of a Thai character for drawing."""
    # Simple characters (basic strokes)
    if character in ['ก', 'ข', 'ค', 'ง', 'จ', 'ช', 'ซ', 'ด', 'ต', 'น', 'บ', 'ป', 'ม', 'ย', 'ร', 'ล', 'ว', 'ส', 'ห', 'อ']:
        return "beginner"
    
    # Medium complexity (more strokes or curves)
    elif character in ['ฃ', 'ฅ', 'ฆ', 'ญ', 'ฎ', 'ฏ', 'ฐ', 'ฑ', 'ฒ', 'ณ', 'ผ', 'ฝ', 'พ', 'ฟ', 'ภ', 'ถ', 'ท', 'ธ', 'ศ', 'ษ', 'ฮ']:
        return "intermediate"
    
    # Advanced (complex shapes or multiple components)
    else:
        return "advanced"

async def get_drawable_vocabulary_items(target_language: str = "th") -> dict:
    """Get vocabulary items that can be drawn as single characters or simple words."""
    drawable_items = {
        "th": [
            {
                "english": "chicken", 
                "thai": "ไก่", 
                "drawable_char": "ก",
                "transliteration": "gai",
                "meaning": "The first letter represents 'Gor Gai' (chicken)"
            },
            {
                "english": "egg", 
                "thai": "ไข่", 
                "drawable_char": "ข",
                "transliteration": "kai",
                "meaning": "The first letter represents 'Khor Kai' (egg)"
            },
            {
                "english": "bottle", 
                "thai": "ขวด", 
                "drawable_char": "ข",
                "transliteration": "khuad",
                "meaning": "Practice the 'Khor' consonant"
            },
            {
                "english": "fish", 
                "thai": "ปลา", 
                "drawable_char": "ป",
                "transliteration": "plaa",
                "meaning": "The first letter represents 'Por Plaa' (fish)"
            },
            {
                "english": "water", 
                "thai": "น้ำ", 
                "drawable_char": "น",
                "transliteration": "nam",
                "meaning": "The first letter represents 'Nor Nuu' (mouse)"
            },
            {
                "english": "rice", 
                "thai": "ข้าว", 
                "drawable_char": "ข",
                "transliteration": "khaao",
                "meaning": "Practice the 'Khor' consonant with rice"
            },
            {
                "english": "dog", 
                "thai": "หมา", 
                "drawable_char": "ห",
                "transliteration": "maa",
                "meaning": "The first letter represents 'Hor Nok Huuk' (owl)"
            },
            {
                "english": "cat", 
                "thai": "แมว", 
                "drawable_char": "ม",
                "transliteration": "maeo",
                "meaning": "Practice the 'Mor Maa' (horse) consonant"
            }
        ]
    }
    
    return {
        "items": drawable_items.get(target_language.lower(), []),
        "total_count": len(drawable_items.get(target_language.lower(), [])),
        "language": target_language,
        "language_name": get_language_name(target_language)
    }

async def split_word_for_tracing(word: str, target_language: str = "th") -> dict:
    """
    Split a Thai word into semantic components for tracing, with detailed character analysis.
    
    Uses a two-level approach:
    1. Standard tokenization for meaningful word boundaries (canvas splitting)
    2. TCC tokenization for character-level details within each meaningful word
    """
    start_time = time.time()
    logging.info(f"[{start_time}] Processing word for tracing: {word}")
    
    try:
        # Get language configuration
        config = get_language_config(target_language)
        if not config:
            return {"error": f"Unsupported language: {target_language}"}
        
        # Step 1: Standard tokenization for semantic word boundaries
        semantic_words = word_tokenize(word, engine='newmm')
        logging.info(f"Semantic tokenization: {word} → {semantic_words}")
        
        # Step 2: Determine if this is a compound word
        is_compound = len(semantic_words) > 1
        
        # Step 3: Process each semantic word
        constituent_word_data = []
        all_tcc_clusters = []
        
        for semantic_word in semantic_words:
            # Get TCC breakdown for this semantic word
            tcc_clusters = subword_tokenize(semantic_word, engine='tcc')
            all_tcc_clusters.extend(tcc_clusters)
            
            # Get translation from vocabulary files
            translation = await get_translation_from_vocabulary(semantic_word)
            
            # Get romanization
            romanized = romanize(semantic_word, engine=config["romanizer_engine"])
            
            # Build detailed TCC analysis for writing guidance
            tcc_details = []
            for cluster in tcc_clusters:
                cluster_romanized = romanize(cluster, engine=config["romanizer_engine"])
                tcc_details.append({
                "cluster": cluster,
                    "romanized": cluster_romanized,
                    "position": len(tcc_details)  # Position within the semantic word
                })
            
            constituent_word_data.append({
                "word": semantic_word,
                "translation": translation,
                "romanized": romanized,
                "tcc_clusters": tcc_details,
                "is_semantic_unit": True
            })
        
        # Step 4: Build final response
        result = {
            "original_word": word,
            "semantic_words": semantic_words,  # For canvas splitting
            "is_compound": is_compound,
            "constituent_word_data": constituent_word_data,
            "all_tcc_clusters": all_tcc_clusters,  # For backward compatibility
            "subword_clusters": all_tcc_clusters,  # Legacy field name
            "processing_time": time.time() - start_time
        }
        
        logging.info(f"Successfully processed {word} in {result['processing_time']:.3f}s")
        return result
        
    except Exception as e:
        error_msg = f"Error processing word '{word}': {str(e)}"
        logging.error(error_msg)
        return {"error": error_msg}

async def analyze_word_syllables(word: str, target_language: str = "th") -> dict:
    """
    Comprehensive syllable analysis for Thai words following educational format.
    Provides detailed breakdown including tone rules, component roles, and writing guidance.
    """
    if target_language.lower() != "th":
        return {"error": f"Syllable analysis not supported for {target_language}"}
    
    try:
        from pythainlp import word_tokenize
        from pythainlp.tokenize import subword_tokenize
        from pythainlp.transliterate import romanize
        
        # Load enhanced writing guide data
        writing_guide = load_thai_writing_guide()
        
        # Step 1: Get syllable boundaries (for multi-syllable words like กระเทียม)
        # Use word tokenization to identify potential syllable breaks
        word_segments = word_tokenize(word, engine='newmm')
        
        # For single semantic words, analyze as syllables manually
        if len(word_segments) == 1:
            syllables = _analyze_syllable_structure(word)
        else:
            syllables = word_segments
        
        # Step 2: Analyze each syllable comprehensively
        syllable_analyses = []
        
        for i, syllable in enumerate(syllables):
            syllable_analysis = await _analyze_single_syllable(syllable, i + 1, writing_guide)
            syllable_analyses.append(syllable_analysis)
        
        # Step 3: Build comprehensive response
        result = {
            "word": word,
            "transliteration": romanize(word, engine="thai2rom"),
            "translation": await get_translation_from_vocabulary(word),
            "syllable_count": len(syllables),
            "syllables": syllable_analyses,
            "high_level_overview": {
                "word": word,
                "syllable_structure": f"{len(syllables)} syllable{'s' if len(syllables) > 1 else ''}",
                "writing_complexity": _assess_writing_complexity(syllables, writing_guide)
            }
        }
        
        return result
        
    except Exception as e:
        error_msg = f"Error analyzing syllables for '{word}': {str(e)}"
        logging.error(error_msg)
        return {"error": error_msg}

def _analyze_syllable_structure(word: str) -> list:
    """
    Analyze syllable structure within a single word.
    For words like กระเทียม, identify syllable boundaries.
    """
    from pythainlp.tokenize import subword_tokenize
    
    # Use TCC to get character clusters, then group into syllables
    tcc_clusters = subword_tokenize(word, engine='tcc')
    
    # Basic syllable boundary detection
    # This is a simplified approach - could be enhanced with more sophisticated logic
    syllables = []
    current_syllable = ""
    
    for cluster in tcc_clusters:
        current_syllable += cluster
        
        # Check if this forms a complete syllable
        # Heuristic: if cluster ends with vowel or consonant that can end syllables
        if _is_syllable_ending(cluster, current_syllable):
            syllables.append(current_syllable)
            current_syllable = ""
    
    # Add remaining characters as final syllable
    if current_syllable:
        syllables.append(current_syllable)
    
    return syllables if syllables else [word]

def _is_syllable_ending(cluster: str, current_syllable: str) -> bool:
    """
    Determine if a TCC cluster likely ends a syllable.
    """
    # Basic heuristics for Thai syllable endings
    if len(cluster) == 1:
        char = cluster[0]
        # Vowels that typically end syllables
        if char in 'ะาิีุูเแโใไ':
            return True
        # Final consonants
        if char in 'งนมยรลว':
            return True
    
    # Short vowel (ะ) always ends syllable
    if 'ะ' in cluster:
        return True
        
    return False

async def _analyze_single_syllable(syllable: str, syllable_number: int, writing_guide: dict) -> dict:
    """
    Comprehensive analysis of a single syllable following educational format.
    """
    from pythainlp.tokenize import subword_tokenize
    from pythainlp.transliterate import romanize
    from pythainlp.util.thai import thai_consonants, thai_vowels, thai_tonemarks
    
    # Get TCC breakdown for detailed analysis
    tcc_clusters = subword_tokenize(syllable, engine='tcc')
    
    # Analyze components
    components = {
        "initial_consonants": [],
        "consonant_clusters": [],
        "vowels": [],
        "final_consonants": [],
        "tone_marks": []
    }
    
    # Component role analysis
    component_roles = []
    
    for i, cluster in enumerate(tcc_clusters):
        for char in cluster:
            if char in thai_consonants:
                consonant_data = writing_guide.get("consonants", {}).get(char, {})
                role_data = {
                    "character": char,
                    "type": "consonant",
                    "romanization": consonant_data.get("romanization", ""),
                    "sound_description": consonant_data.get("sound_description", ""),
                    "position": "initial" if i == 0 else ("final" if i == len(tcc_clusters) - 1 else "medial"),
                    "consonant_class": _get_consonant_class(char, writing_guide),
                    "writing_steps": consonant_data.get("beginner_steps", [])
                }
                
                if i == 0:
                    components["initial_consonants"].append(role_data)
                elif i == len(tcc_clusters) - 1:
                    components["final_consonants"].append(role_data)
                
                component_roles.append(role_data)
                
            elif char in thai_vowels or _is_vowel_part(char):
                vowel_data = _get_vowel_data(char, writing_guide)
                role_data = {
                    "character": char,
                    "type": "vowel",
                    "romanization": vowel_data.get("romanization", ""),
                    "sound_description": vowel_data.get("sound_description", ""),
                    "position": vowel_data.get("position", "after"),
                    "writing_steps": vowel_data.get("beginner_steps", [])
                }
                
                components["vowels"].append(role_data)
                component_roles.append(role_data)
                
            elif char in thai_tonemarks:
                tone_data = writing_guide.get("tone_marks", {}).get(char, {})
                role_data = {
                    "character": char,
                    "type": "tone_mark",
                    "romanization": tone_data.get("romanization", ""),
                    "sound_description": tone_data.get("sound_description", ""),
                    "position": "above"
                }
                
                components["tone_marks"].append(role_data)
                component_roles.append(role_data)
    
    # Tone analysis
    tone_analysis = _analyze_tone_rules(syllable, components, writing_guide)
    
    # Generate step-by-step writing instructions
    writing_steps = _generate_syllable_writing_steps(syllable, component_roles, writing_guide)
    
    return {
        "syllable": syllable,
        "syllable_number": syllable_number,
        "romanization": romanize(syllable, engine="thai2rom"),
        "tcc_clusters": tcc_clusters,
        "components": components,
        "component_roles": component_roles,
        "tone_analysis": tone_analysis,
        "writing_steps": writing_steps,
        "syllable_type": _determine_syllable_type(syllable, components, writing_guide)
    }

def _get_consonant_class(char: str, writing_guide: dict) -> str:
    """Get consonant class from writing guide data."""
    consonant_classes = writing_guide.get("consonant_classes", {})
    
    for class_name, class_data in consonant_classes.items():
        if char in class_data.get("consonants", []):
            return class_name
    
    return "unknown"

def _is_vowel_part(char: str) -> bool:
    """Check if character is part of a vowel (including complex vowels)."""
    vowel_parts = ['เ', 'แ', 'โ', 'ใ', 'ไ', 'ั', 'ิ', 'ี', 'ึ', 'ื', 'ุ', 'ู', 'ะ', 'า', 'ำ', 'ย', 'ว']
    return char in vowel_parts

def _get_vowel_data(char: str, writing_guide: dict) -> dict:
    """Get vowel information from writing guide."""
    vowels = writing_guide.get("vowels", {})
    
    # Direct lookup
    for pattern, data in vowels.items():
        if char in pattern:
            return data
    
    # Default data for unknown vowels
    return {
        "romanization": char,
        "sound_description": f"{char} sound",
        "position": "after"
    }

def _analyze_tone_rules(syllable: str, components: dict, writing_guide: dict) -> dict:
    """Analyze tone rules for the syllable."""
    # Get initial consonant class
    initial_consonants = components.get("initial_consonants", [])
    if not initial_consonants:
        return {"error": "No initial consonant found"}
    
    consonant_class = initial_consonants[0].get("consonant_class", "unknown")
    
    # Determine if syllable is live or dead
    syllable_type = _determine_syllable_type(syllable, components, writing_guide)
    
    # Look up tone rule
    tone_rules = writing_guide.get("tone_rules", {})
    rule_key = f"{consonant_class}_{syllable_type}"
    
    tone_rule = tone_rules.get(rule_key, {})
    
    return {
        "consonant_class": consonant_class,
        "syllable_type": syllable_type,
        "resulting_tone": tone_rule.get("result", "unknown"),
        "rule_explanation": tone_rule.get("explanation", ""),
        "example": tone_rule.get("example", "")
    }

def _determine_syllable_type(syllable: str, components: dict, writing_guide: dict) -> str:
    """Determine if syllable is live or dead."""
    vowels = components.get("vowels", [])
    final_consonants = components.get("final_consonants", [])
    
    # Check for short vowels
    has_short_vowel = any(
        vowel.get("romanization", "").endswith("a") and len(vowel.get("romanization", "")) == 1 
        for vowel in vowels
    )
    
    # Check for final consonants
    if final_consonants:
        final_char = final_consonants[0].get("character", "")
        # Stop consonants make dead syllables
        if final_char in "กจดตบป":
            return "dead_syllable"
        # Sonorant consonants make live syllables  
        elif final_char in "งนมยรลว":
            return "live_syllable"
    
    # No final consonant
    if has_short_vowel:
        return "dead_syllable"
    else:
        return "live_syllable"

def _generate_syllable_writing_steps(syllable: str, component_roles: list, writing_guide: dict) -> list:
    """Generate detailed step-by-step writing instructions for the syllable."""
    steps = []
    step_number = 1
    
    # Group components by writing order
    before_components = [c for c in component_roles if c.get("position") == "before"]
    consonant_components = [c for c in component_roles if c.get("type") == "consonant"]
    above_components = [c for c in component_roles if c.get("position") == "above"]
    after_components = [c for c in component_roles if c.get("position") == "after"]
    
    # Step 1: Before components (leading vowels)
    for component in before_components:
        steps.append({
            "step": step_number,
            "component": component["character"],
            "type": component["type"],
            "instruction": f"Write {component['type']} \"{component['character']}\" ({component.get('romanization', '')}) BEFORE the consonant",
            "sound_description": component.get("sound_description", ""),
            "writing_tips": component.get("writing_steps", [])
        })
        step_number += 1
    
    # Step 2: Consonants
    for component in consonant_components:
        steps.append({
            "step": step_number,
            "component": component["character"],
            "type": component["type"],
            "instruction": f"Write {component['type']} \"{component['character']}\" ({component.get('romanization', '')} sound)",
            "sound_description": component.get("sound_description", ""),
            "consonant_class": component.get("consonant_class", ""),
            "writing_tips": component.get("writing_steps", [])
        })
        step_number += 1
    
    # Step 3: Above components (vowel marks, tone marks)
    for component in above_components:
        steps.append({
            "step": step_number,
            "component": component["character"],
            "type": component["type"],
            "instruction": f"Add {component['type']} \"{component['character']}\" ({component.get('romanization', '')}) ABOVE the consonant",
            "sound_description": component.get("sound_description", ""),
            "writing_tips": component.get("writing_steps", [])
        })
        step_number += 1
    
    # Step 4: After components (final vowels, consonants)
    for component in after_components:
        steps.append({
            "step": step_number,
            "component": component["character"],
            "type": component["type"],
            "instruction": f"Write {component['type']} \"{component['character']}\" ({component.get('romanization', '')}) AFTER the consonant",
            "sound_description": component.get("sound_description", ""),
            "writing_tips": component.get("writing_steps", [])
        })
        step_number += 1
    
    return steps

def _assess_writing_complexity(syllables: list, writing_guide: dict) -> str:
    """Assess the writing complexity of the word."""
    total_components = sum(len(syllable) for syllable in syllables)
    
    if total_components <= 3:
        return "beginner"
    elif total_components <= 6:
        return "intermediate"
    else:
        return "advanced"

async def get_translation_from_vocabulary(word: str) -> str:
    """
    Get translation for a word from vocabulary files, with Google Translate fallback.
    Only loads files containing 'vocabulary' in the filename.
    """
    try:
        # Load vocabulary from files containing 'vocabulary'
        vocab_translations = {}
        
        assets_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'assets', 'data')
        if os.path.exists(assets_path):
            for filename in os.listdir(assets_path):
                if filename.endswith('.json') and 'vocabulary' in filename:
                    file_path = os.path.join(assets_path, filename)
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            data = json.load(f)
                            if 'vocabulary' in data:
                                for item in data['vocabulary']:
                                    if 'thai' in item and 'english' in item:
                                        vocab_translations[item['thai']] = item['english']
                                        
                                        # Also add word_mapping constituents
                                        if 'word_mapping' in item:
                                            for mapping in item['word_mapping']:
                                                if 'thai' in mapping and 'translation' in mapping:
                                                    vocab_translations[mapping['thai']] = mapping['translation']
                    except Exception as e:
                        logging.warning(f"Error loading vocabulary from {filename}: {e}")
        
        # Check if word exists in vocabulary
        if word in vocab_translations:
            return vocab_translations[word]
        
        # Fallback to Google Translate for unknown words
        try:
            from google.cloud import translate_v3
            
            project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
            if project_id:
                client = translate_v3.TranslationServiceClient()
                parent = f"projects/{project_id}/locations/global"
                
                response = client.translate_text(
                    request={
                        "parent": parent,
                        "contents": [word],
                        "mime_type": "text/plain",
                        "source_language_code": "th",
                        "target_language_code": "en",
                    }
                )
                
                if response.translations:
                    translation = response.translations[0].translated_text.strip()
                    logging.info(f"Google Translate: {word} → {translation}")
                    return translation
                
        except Exception as e:
            logging.warning(f"Google Translate failed for '{word}': {e}")
        
        # Final fallback
        return f"[Unknown: {word}]"
    
    except Exception as e:
        logging.error(f"Error getting translation for '{word}': {e}")
        return f"[Error: {word}]"

async def analyze_character_components(character: str, target_language: str = "th") -> dict:
    """
    Analyze Thai character/word components for writing tips using PyThaiNLP best practices.
    
    Enhanced with traditional Thai writing guide data including traditional names,
    cultural context, and detailed writing instructions.
    """
    if target_language.lower() != "th":
        return {"error": f"Character analysis not supported for {target_language}"}
    
    try:
        import pythainlp
        from pythainlp import word_tokenize, pos_tag
        from pythainlp.tokenize import subword_tokenize
        from pythainlp.util import normalize, reorder_vowels
        
        # Use proper PyThaiNLP character classification utilities
        from pythainlp.util.thai import thai_consonants, thai_vowels, thai_tonemarks
        
        # Load writing guide data
        writing_guide = load_thai_writing_guide()
        
        # Define character classification functions since they don't exist in util
        def is_thai_consonant(char):
            return char in thai_consonants
        
        def is_thai_vowel(char):
            return char in thai_vowels
            
        def is_thai_tone(char):
            return char in thai_tonemarks
        
        # Normalize the input and reorder vowels for proper analysis
        normalized_char = normalize(character)
        reordered_char = reorder_vowels(normalized_char) if len(normalized_char) > 1 else normalized_char
        
        # Get subword tokenization for proper segmentation
        subwords = subword_tokenize(character, engine='tcc')
        
        # Initialize result structure with enhanced data (removed cultural_context and learning_level)
        result = {
            "character": character,
            "normalized": normalized_char,
            "reordered": reordered_char,
            "subwords": subwords,
            "total_length": len(character),
            "consonants": [],
            "vowels": [],
            "tone_marks": [],
            "other_marks": [],
            "breakdown": [],
            "writing_guidance": [],
            "writing_tips": [],
            "component_colors": writing_guide.get("component_colors", {})
        }
        
        # Analyze each character in the input using proper utilities enhanced with writing guide
        for i, char in enumerate(character):
            char_analysis = {
                "character": char,
                "position": i,
                "type": "unknown"
            }
            
            # Check writing guide for detailed information
            consonant_data = writing_guide.get("consonants", {}).get(char)
            vowel_data = None
            tone_data = writing_guide.get("tone_marks", {}).get(char)
            
            # Find vowel data (vowels use placeholder notation like ◌า)
            for vowel_pattern, vowel_info in writing_guide.get("vowels", {}).items():
                if char in vowel_pattern:
                    vowel_data = vowel_info
                    break
            
            # Use character classification functions
            if is_thai_consonant(char):
                char_analysis["type"] = "consonant"
                # Enhanced consonant analysis with new beginner-friendly structure
                if consonant_data:
                    char_analysis.update({
                        "romanization": consonant_data.get("romanization"),
                        "sound_description": consonant_data.get("sound_description"),
                        "cultural_context": consonant_data.get("cultural_context"),
                        "beginner_steps": consonant_data.get("beginner_steps", []),
                        "common_tips": consonant_data.get("common_tips", [])
                    })
                
                # Determine consonant class
                if char in 'กจดตบปอ':
                    char_analysis["consonant_class"] = "middle"
                elif char in 'ขฃคฅฆงฉชซฌญฎฏฐฑฒณถทธนพฟภมยรลวศษสหฬฮ':
                    char_analysis["consonant_class"] = "high"
                else:
                    char_analysis["consonant_class"] = "low"
                
                result["consonants"].append(char_analysis)
                
            elif is_thai_vowel(char):
                char_analysis["type"] = "vowel"
                # Enhanced vowel analysis with new beginner-friendly structure
                if vowel_data:
                    char_analysis.update({
                        "romanization": vowel_data.get("romanization"),
                        "sound_description": vowel_data.get("sound_description"),
                        "position": vowel_data.get("position"),
                        "beginner_steps": vowel_data.get("beginner_steps", []),
                        "common_tips": vowel_data.get("common_tips", []),
                        "cultural_context": vowel_data.get("cultural_context")
                    })
                
                # Determine vowel position
                if char in 'เแโใไ':
                    char_analysis["position_type"] = "leading"
                elif char in 'ะาำ':
                    char_analysis["position_type"] = "trailing"
                elif char in 'ิีึื็ํ':
                    char_analysis["position_type"] = "above"
                elif char in 'ุู':
                    char_analysis["position_type"] = "below"
                else:
                    char_analysis["position_type"] = "unknown"
                    
                result["vowels"].append(char_analysis)
                
            elif is_thai_tone(char):
                char_analysis["type"] = "tone_mark"
                # Enhanced tone mark analysis with new beginner-friendly structure
                if tone_data:
                    char_analysis.update({
                        "romanization": tone_data.get("romanization"),
                        "sound_description": tone_data.get("sound_description"),
                        "beginner_steps": tone_data.get("beginner_steps", []),
                        "common_tips": tone_data.get("common_tips", []),
                        "cultural_context": tone_data.get("cultural_context")
                    })
                
                tone_names = {'่': 'mai_ek', '้': 'mai_tho', '๊': 'mai_tri', '๋': 'mai_chattawa'}
                char_analysis["tone_name"] = tone_names.get(char, "unknown")
                result["tone_marks"].append(char_analysis)
                
            elif char in '์็ั':
                char_analysis["type"] = "diacritic"
                diacritic_names = {'์': 'thanthakhat', '็': 'mai_taikhu', 'ั': 'mai_hanakat'}
                char_analysis["diacritic_name"] = diacritic_names.get(char, "unknown")
                result["other_marks"].append(char_analysis)
                
            else:
                char_analysis["type"] = "other"
                
            result["breakdown"].append(char_analysis)
        
        # Add analysis for the whole word using PyThaiNLP
        try:
            # Tokenize to see if it's a complete word
            tokens = word_tokenize(character, engine='newmm')
            if len(tokens) == 1 and tokens[0] == character:
                result["is_complete_word"] = True
                
                # Get POS tagging
                pos_tags = pos_tag([character], engine='perceptron')
                if pos_tags:
                    result["pos_tag"] = pos_tags[0][1]
                    
            else:
                result["is_complete_word"] = False
                result["tokens"] = tokens
                
        except Exception as e:
            print(f"Error in word analysis: {e}")
            result["word_analysis_error"] = str(e)
        
        # Add enhanced writing guidance based on analysis
        result["writing_tips"] = _generate_enhanced_writing_tips(result, writing_guide)
        
        # Add comprehensive writing guidance
        result["writing_guidance"] = _generate_comprehensive_guidance(character, result, writing_guide)
        
        return result
        
    except ImportError:
        # Fallback if PyThaiNLP is not available
        print("PyThaiNLP not available, using fallback analysis")
        return {
            "character": character,
            "error": "PyThaiNLP not installed",
            "fallback_analysis": True,
            "components": [{"type": "character", "description": f"Character: {character}"}]
        }
    except Exception as e:
        print(f"Error in PyThaiNLP analysis: {e}")
        return {
            "character": character,
            "error": str(e),
            "components": []
        }

def _determine_learning_level(character: str, writing_guide: dict) -> str:
    """Determine the learning level for a character based on the writing guide."""
    learning_progression = writing_guide.get("learning_progression", {})
    
    if character in learning_progression.get("level_1_characters", []):
        return "beginner"
    elif character in learning_progression.get("level_2_characters", []):
        return "intermediate"
    elif character in learning_progression.get("level_3_characters", []):
        return "advanced"
    else:
        return "unknown"

def _generate_enhanced_writing_tips(analysis: dict, writing_guide: dict) -> list:
    """Generate enhanced writing tips using writing guide data."""
    tips = []
    
    # Add writing principles from guide
    principles = writing_guide.get("writing_principles", {})
    if principles.get("general_order"):
        tips.extend(["Writing Order:"] + principles["general_order"])
    
    # Tips based on consonants with cultural context
    if analysis["consonants"]:
        tips.append(f"Contains {len(analysis['consonants'])} consonant(s)")
        for consonant in analysis["consonants"]:
            char = consonant["character"]
            if consonant.get("traditional_name"):
                tips.append(f"'{char}' is '{consonant['traditional_name']}' ({consonant.get('meaning', 'unknown meaning')})")
            if consonant.get("consonant_class"):
                tips.append(f"'{char}' is {consonant['consonant_class']} class consonant")
    
    # Tips based on vowels
    if analysis["vowels"]:
        tips.append(f"Contains {len(analysis['vowels'])} vowel(s)")
        for vowel in analysis["vowels"]:
            char = vowel["character"]
            if vowel.get("name"):
                tips.append(f"'{char}' is '{vowel['name']}' (sound: {vowel.get('sound', 'unknown')})")
            pos_type = vowel.get("position_type", "unknown")
            if pos_type == "leading":
                tips.append(f"Vowel '{vowel['character']}' goes BEFORE the consonant in writing order")
            elif pos_type == "above":
                tips.append(f"Vowel '{vowel['character']}' goes ABOVE the consonant")
            elif pos_type == "below":
                tips.append(f"Vowel '{vowel['character']}' goes BELOW the consonant")
    
    # Tips based on tone marks
    if analysis["tone_marks"]:
        tips.append(f"Contains {len(analysis['tone_marks'])} tone mark(s)")
        for tone in analysis["tone_marks"]:
            tips.append(f"Tone mark '{tone['character']}' ({tone.get('tone_name', 'unknown')}) goes above")
    
    # General writing order tips
    if len(analysis["breakdown"]) > 1:
        tips.append("Write consonants first, then add vowels and tone marks")
        tips.append("Follow left-to-right, top-to-bottom order")
    
    return tips

def _generate_comprehensive_guidance(character: str, analysis: dict, writing_guide: dict) -> dict:
    """Generate comprehensive writing guidance for the character."""
    guidance = {
        "character": character,
        "component_breakdown": [],
        "writing_steps": []
    }
    
    # Create component breakdown with colors
    component_colors = writing_guide.get("component_colors", {})
    for component in analysis.get("breakdown", []):
        comp_type = component.get("type", "unknown")
        color = component_colors.get(f"{comp_type}s", "#000000")  # consonants, vowels, etc.
        
        component_info = {
            "character": component.get("character"),
            "type": comp_type,
            "color": color,
            "writing_tips": component.get("writing_tips", []),
            "position": component.get("position", 0)
        }
        
        if comp_type == "consonant":
            component_info.update({
                "traditional_name": component.get("traditional_name"),
                "sound_initial": component.get("sound_initial"),
                "sound_final": component.get("sound_final"),
                "class": component.get("consonant_class")
            })
        elif comp_type == "vowel":
            component_info.update({
                "name": component.get("name"),
                "sound": component.get("sound"),
                "position_type": component.get("position_type"),
                "length": component.get("length")
            })
        elif comp_type == "tone_mark":
            component_info.update({
                "name": component.get("name"),
                "tone_name": component.get("tone_name")
            })
            
        guidance["component_breakdown"].append(component_info)
    
    # Generate writing steps based on components
    if analysis.get("consonants"):
        guidance["writing_steps"].append("1. Write the consonant(s) first (foundation)")
    if analysis.get("vowels"):
        guidance["writing_steps"].append("2. Add vowels in their designated positions")
    if analysis.get("tone_marks"):
        guidance["writing_steps"].append("3. Place tone marks above consonants or vowels")
    
    # Add specific writing tips from guide
    principles = writing_guide.get("writing_principles", {})
    if principles.get("cultural_guidelines"):
        guidance["cultural_guidelines"] = principles["cultural_guidelines"]
    
    return guidance

async def split_compound_word(word: str, target_language: str = "th") -> dict:
    """
    Split compound words into constituent words using PyThaiNLP subword tokenization.
    Example: เครื่องปรุง -> [เครื่อง, ปรุง]
    """
    if not word or not word.strip():
        return {
            "original_word": word,
            "is_compound": False,
            "constituent_words": [word] if word else [],
            "subword_clusters": [],
            "method": "empty_input"
        }
    
    lang_config = get_language_config(target_language)
    
    # If tokenization is not available for this language, return the original word
    if not lang_config.get("tokenizer_available", False):
        print(f"Tokenization not available for {target_language}, returning original word")
        return {
            "original_word": word,
            "is_compound": False,
            "constituent_words": [word],
            "subword_clusters": [],
            "method": "no_tokenizer"
        }
    
    try:
        if target_language.lower() == "th":
            from pythainlp.tokenize import subword_tokenize, word_tokenize
            
            # First try word tokenization to see if it's already a single word
            word_tokens = word_tokenize(word.strip(), engine=lang_config["tokenizer_engine"])
            
            # Use subword tokenization for more granular analysis
            subword_tokens = subword_tokenize(word.strip(), engine="newmm")
            
            # Filter out empty tokens and whitespace
            filtered_subwords = [token for token in subword_tokens if token.strip()]
            filtered_words = [token for token in word_tokens if token.strip()]
            
            # Determine if it's a compound word
            is_compound = len(filtered_subwords) > 1 or len(filtered_words) > 1
            
            # Use word tokens as constituent words if available, otherwise subwords
            constituent_words = filtered_words if filtered_words else filtered_subwords
            
            return {
                "original_word": word,
                "is_compound": is_compound,
                "constituent_words": constituent_words,
                "subword_clusters": filtered_subwords,
                "method": "pythainlp_tokenization"
            }
        else:
            # For other languages, implement specific tokenization logic here
            return {
                "original_word": word,
                "is_compound": False,
                "constituent_words": [word],
                "subword_clusters": [word],
                "method": "fallback"
            }
        
    except Exception as e:
        print(f"Error during compound word splitting for {target_language}: {e}")
        return {
            "original_word": word,
            "is_compound": False,
            "constituent_words": [word],
            "subword_clusters": [],
            "method": "error_fallback",
            "error": str(e)
        }

async def filter_drawable_items_from_translation(word_mappings: List, target_language: str = "th") -> dict:
    """Filter translated words to show only drawable items (nouns)."""
    if target_language.lower() != "th":
        return {"filtered_items": [], "total_filtered": 0}
    
    drawable_vocab = await get_drawable_vocabulary_items(target_language)
    drawable_thai_words = {item["thai"] for item in drawable_vocab["items"]}
    
    filtered_items = []
    for mapping in word_mappings:
        target_word = mapping.get("target", "")
        if target_word in drawable_thai_words:
            # Find the corresponding drawable item info
            item_info = next((item for item in drawable_vocab["items"] if item["thai"] == target_word), None)
            if item_info:
                filtered_items.append({
                    **mapping,
                    "drawable_char": item_info["drawable_char"],
                    "item_meaning": item_info["meaning"],
                    "is_drawable": True
                })
    
    return {
        "filtered_items": filtered_items,
        "total_filtered": len(filtered_items),
        "original_count": len(word_mappings)
    } 