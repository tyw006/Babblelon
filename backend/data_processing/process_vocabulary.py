# To run this code you need to install the following dependencies:
# pip install -r requirements.txt

import json
import os
import re
import time
import argparse
import random
import traceback
import azure.cognitiveservices.speech as speechsdk
from pydub import AudioSegment
import tempfile
import mimetypes
import struct
import wave
from collections import defaultdict

from dotenv import load_dotenv
from google import genai
from google.genai import types
from tqdm import tqdm


def save_binary_file(file_name: str, data: bytes) -> None:
    """Save binary data to a file."""
    with open(file_name, "wb") as f:
        f.write(data)
    print(f"File saved to: {file_name}")


def wave_file(filename, pcm, channels=1, rate=24000, sample_width=2):
    """Set up the wave file to save the output (from test notebook)."""
    with wave.open(filename, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sample_width)
        wf.setframerate(rate)
        wf.writeframes(pcm)


def is_valid_wav_file(file_path: str) -> bool:
    """
    Validate that a file is a proper WAV file by trying to open it.
    Returns True if valid, False otherwise.
    """
    try:
        with wave.open(file_path, 'rb') as wav_file:
            # Try to read basic properties
            frames = wav_file.getnframes()
            sample_rate = wav_file.getframerate()
            channels = wav_file.getnchannels()
            sample_width = wav_file.getsampwidth()
            
            # Basic validation: file should have some content
            if frames > 0 and sample_rate > 0 and channels > 0 and sample_width > 0:
                tqdm.write(f"    - WAV validation: {frames} frames, {sample_rate}Hz, {channels}ch, {sample_width}B/sample")
                return True
            else:
                tqdm.write(f"    - WAV validation failed: Invalid parameters")
                return False
    except Exception as e:
        tqdm.write(f"    - WAV validation failed: {str(e)}")
        return False


def check_audio_paths_exist(data: dict, project_root: str) -> tuple[int, int]:
    """
    Check how many vocabulary entries have valid audio_path fields.
    Returns (valid_count, total_count).
    """
    valid_count = 0
    total_count = len(data['vocabulary'])
    
    print("\n--- Checking audio_path fields ---")
    for i, entry in enumerate(data['vocabulary']):
        english_phrase = entry['english']
        audio_path = entry.get('audio_path')
        
        if not audio_path:
            tqdm.write(f"  - Missing audio_path: '{english_phrase}'")
            continue
            
        full_audio_path = os.path.join(project_root, audio_path)
        if not os.path.exists(full_audio_path):
            tqdm.write(f"  - Audio file not found: '{english_phrase}' -> '{audio_path}'")
            continue
            
        valid_count += 1
    
    print(f"Audio path validation: {valid_count}/{total_count} entries have valid audio files")
    return valid_count, total_count


def convert_to_wav(audio_data: bytes, mime_type: str) -> bytes:
    """Generates a WAV file header for the given audio data and parameters.

    Args:
        audio_data: The raw audio data as a bytes object.
        mime_type: Mime type of the audio data.

    Returns:
        A bytes object representing the WAV file header.
    """
    parameters = parse_audio_mime_type(mime_type)
    bits_per_sample = parameters["bits_per_sample"]
    sample_rate = parameters["rate"]
    num_channels = 1
    data_size = len(audio_data)
    bytes_per_sample = bits_per_sample // 8
    block_align = num_channels * bytes_per_sample
    byte_rate = sample_rate * block_align
    chunk_size = 36 + data_size  # 36 bytes for header fields before data chunk size

    # http://soundfile.sapp.org/doc/WaveFormat/

    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",          # ChunkID
        chunk_size,       # ChunkSize (total file size - 8 bytes)
        b"WAVE",          # Format
        b"fmt ",          # Subchunk1ID
        16,               # Subchunk1Size (16 for PCM)
        1,                # AudioFormat (1 for PCM)
        num_channels,     # NumChannels
        sample_rate,      # SampleRate
        byte_rate,        # ByteRate
        block_align,      # BlockAlign
        bits_per_sample,  # BitsPerSample
        b"data",          # Subchunk2ID
        data_size         # Subchunk2Size (size of audio data)
    )
    return header + audio_data


def parse_audio_mime_type(mime_type: str) -> dict[str, int]:
    """Parses bits per sample and rate from an audio MIME type string.

    Assumes bits per sample is encoded like "L16" and rate as "rate=xxxxx".

    Args:
        mime_type: The audio MIME type string (e.g., "audio/L16;rate=24000").

    Returns:
        A dictionary with "bits_per_sample" and "rate" keys. Values will be
        integers if found, otherwise defaults are used.
    """
    bits_per_sample = 16
    rate = 24000

    # Extract rate from parameters
    parts = mime_type.split(";")
    for param in parts:  # Skip the main type part
        param = param.strip()
        if param.lower().startswith("rate="):
            try:
                rate_str = param.split("=", 1)[1]
                rate = int(rate_str)
            except (ValueError, IndexError):
                # Handle cases like "rate=" with no value or non-integer value
                pass  # Keep rate as default
        elif param.startswith("audio/L"):
            try:
                bits_per_sample = int(param.split("L", 1)[1])
            except (ValueError, IndexError):
                pass  # Keep bits_per_sample as default if conversion fails

    return {"bits_per_sample": bits_per_sample, "rate": rate}


def retry_with_backoff(api_func, *args, max_retries=5, min_wait=2, max_wait=30, **kwargs):
    """
    Retry an API function with exponential backoff on 429/Resource_exhausted errors.
    """
    attempt = 0
    while attempt < max_retries:
        try:
            return api_func(*args, **kwargs)
        except Exception as e:
            err_str = str(e)
            if '429' in err_str or 'RESOURCE_EXHAUSTED' in err_str or 'Resource_exhausted' in err_str:
                wait_time = min(max_wait, min_wait * (2 ** attempt) + random.uniform(0, 1))
                tqdm.write(f"  - Rate limit hit (429/Resource_exhausted). Sleeping for {wait_time:.1f}s and retrying...")
                time.sleep(wait_time)
                attempt += 1
            else:
                raise
    raise RuntimeError(f"API call failed after {max_retries} retries due to rate limits.")


def retry_audio_generation(api_func, *args, max_retries=3, min_wait=2, max_wait=15, **kwargs):
    """
    Retry audio generation with exponential backoff on various failures including:
    - Rate limiting (429/Resource_exhausted)
    - API returning empty data 
    - WAV file validation failures
    """
    attempt = 0
    while attempt < max_retries:
        try:
            result = api_func(*args, **kwargs)
            # Check if the result indicates failure (None path means failed generation)
            if result[0] is None:  # result is (path, streamed) tuple
                if attempt == max_retries - 1:
                    # On final attempt, don't retry - return the failed result
                    tqdm.write(f"  - Audio generation failed after {max_retries} attempts")
                    return result
                else:
                    # Treat None result as a retriable failure
                    wait_time = min(max_wait, min_wait * (2 ** attempt) + random.uniform(0, 1))
                    tqdm.write(f"  - Audio generation failed (attempt {attempt + 1}/{max_retries}). Retrying in {wait_time:.1f}s...")
                    time.sleep(wait_time)
                    attempt += 1
                    continue
            else:
                # Success - return the result
                return result
        except Exception as e:
            err_str = str(e)
            # Check for retriable errors
            if ('429' in err_str or 'RESOURCE_EXHAUSTED' in err_str or 'Resource_exhausted' in err_str or
                'timeout' in err_str.lower() or 'connection' in err_str.lower() or 
                'network' in err_str.lower() or 'temporary' in err_str.lower()):
                
                if attempt == max_retries - 1:
                    # On final attempt, re-raise the exception
                    raise
                else:
                    wait_time = min(max_wait, min_wait * (2 ** attempt) + random.uniform(0, 1))
                    tqdm.write(f"  - Retriable error (attempt {attempt + 1}/{max_retries}): {str(e)[:100]}...")
                    tqdm.write(f"  - Retrying in {wait_time:.1f}s...")
                    time.sleep(wait_time)
                    attempt += 1
            else:
                # Non-retriable error - re-raise immediately
                raise
    
    # This should not be reached due to the logic above, but added for safety
    raise RuntimeError(f"Audio generation failed after {max_retries} retries.")


def get_transliteration_and_translation_batch(unique_words: list[str], client, model_name: str) -> dict[str, dict]:
    """
    Gets transliteration and translation for a list of unique Thai words using Gemini
    in a single API call. Ensures consistent transliterations for the same characters.
    Returns a dictionary mapping Thai words to their transliteration and translation.
    """
    if not unique_words:
        return {}

    # Create the list of JSON objects for the prompt
    word_list_str = ",\n".join([f'    {{"thai": "{word}", "transliteration": "", "translation": ""}}' for word in unique_words])

    prompt = f"""
You are helping to create accurate and CONSISTENT transliterations and translations for Thai words.

IMPORTANT: Use the SAME transliteration for identical Thai characters across all words. For example, if you see the character "ก" in multiple words, it should always be transliterated the same way (e.g., "g" or "k" consistently).

Please fill in the 'transliteration' (using standard romanization for pronunciation) and 'translation' (English meaning) for each of the following Thai words. Ensure consistency in your transliteration system across all words.

Guidelines:
1. Use consistent romanization for the same Thai characters
2. Follow standard Thai romanization conventions
3. Provide accurate English translations
4. Be consistent with tone markers and vowel representations

Input:
[
{word_list_str}
]

Return the result as a single, raw JSON object with a single key "azure_pron_mapping" which contains the completed list. Do not include any other text, formatting, or markdown.

Expected Output Format:
{{
    "azure_pron_mapping": [
        {{
            "thai": "...",
            "transliteration": "...",
            "translation": "..."
        }}
    ]
}}
"""
    
    def api_call():
        response = client.models.generate_content(
            model=model_name,
            contents=[prompt],
        )
        # Clean the response to ensure it's valid JSON
        cleaned_response = response.text.strip().replace("```json", "").replace("```", "").strip()
        return json.loads(cleaned_response)
    
    try:
        result = retry_with_backoff(api_call)
        if result and 'azure_pron_mapping' in result:
            # Convert list to dictionary for easy lookup
            word_dict = {}
            for item in result['azure_pron_mapping']:
                thai_word = item['thai']
                word_dict[thai_word] = {
                    'transliteration': item['transliteration'],
                    'translation': item['translation']
                }
            return word_dict
        else:
            tqdm.write(f"  - Error: Gemini API did not return 'azure_pron_mapping'. Response: {result}")
            return {}
    except Exception as e:
        tqdm.write(f"  - Error processing batch transliteration: {e}")
        tqdm.write(f"  - Exception type: {type(e).__name__}")
        tqdm.write(f"  - Full traceback: {traceback.format_exc()}")
        return {}


def generate_audio_file(client, model_name, text: str, file_path: str, english_phrase: str) -> tuple[str | None, bool]:
    """
    Generates an audio file from text using Gemini TTS.
    Follows the same structure as the test notebook.
    Returns the path to the saved file and a boolean indicating if streaming occurred.
    """
    def api_call():
        tqdm.write(f"  - TTS: Requesting audio for '{english_phrase}'...")
        
        response = client.models.generate_content(
            model=model_name,
            contents=text,
            config=types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name='Aoede',
                        )
                    )
                ),
            )
        )

        # Check for a valid response before attempting to access its parts.
        # An empty response can occur due to content filtering or other API issues.
        if not response.candidates or not response.candidates[0].content or not response.candidates[0].content.parts:
            tqdm.write(f"  - TTS Error: API returned no content for '{english_phrase}'. Skipping.")
            try:
                # Log details for debugging if available
                tqdm.write(f"    - Finish Reason: {response.candidates[0].finish_reason}")
                tqdm.write(f"    - Safety Ratings: {response.candidates[0].safety_ratings}")
            except (AttributeError, IndexError):
                # Fallback for unexpected response structures
                tqdm.write(f"    - Full Response: {response}")
            return None, False

        data = response.candidates[0].content.parts[0].inline_data.data
        
        tqdm.write(f"  - TTS: Received audio data ({len(data)} bytes). Saving to '{file_path}'...")
        wave_file(file_path, data)  # Use the wave_file helper from the notebook
        
        # Validate the saved WAV file
        if is_valid_wav_file(file_path):
            tqdm.write(f"  - TTS: WAV file validation successful")
            return file_path, False  # False indicates non-streaming (single response)
        else:
            tqdm.write(f"  - TTS: WAV file validation failed, removing invalid file")
            if os.path.exists(file_path):
                os.remove(file_path)
            return None, False

    return retry_with_backoff(api_call)


def check_existing_audio_files(project_root: str, thai_phrase: str, english_phrase: str) -> str | None:
    """
    Check if audio already exists for this Thai phrase in any audio directory.
    Also checks for files in backend/assets/audio and migrates them if found.
    Returns the relative path to the existing audio file if found, None otherwise.
    """
    # Generate the expected filename for this entry
    sanitized_filename = sanitize_filename(english_phrase) + ".wav"
    
    # First check the correct location: project_root/assets/audio
    audio_base_dir = os.path.join(project_root, 'assets/audio')
    if os.path.exists(audio_base_dir):
        for subdir in os.listdir(audio_base_dir):
            subdir_path = os.path.join(audio_base_dir, subdir)
            if os.path.isdir(subdir_path):
                potential_file = os.path.join(subdir_path, sanitized_filename)
                if os.path.exists(potential_file):
                    # Validate it's a proper WAV file
                    if is_valid_wav_file(potential_file):
                        relative_path = os.path.relpath(potential_file, project_root).replace(os.sep, '/')
                        tqdm.write(f"  - Found existing audio: '{english_phrase}' -> '{relative_path}'")
                        return relative_path
                    else:
                        tqdm.write(f"  - Found invalid audio file: '{potential_file}' (will be skipped)")
    
    # Also check for files in the wrong location (backend/assets/audio) and migrate them
    backend_audio_base_dir = os.path.join(project_root, 'backend/assets/audio')
    if os.path.exists(backend_audio_base_dir):
        for subdir in os.listdir(backend_audio_base_dir):
            subdir_path = os.path.join(backend_audio_base_dir, subdir)
            if os.path.isdir(subdir_path):
                potential_file = os.path.join(subdir_path, sanitized_filename)
                if os.path.exists(potential_file):
                    # Validate it's a proper WAV file
                    if is_valid_wav_file(potential_file):
                        # Migrate the file to the correct location
                        correct_subdir = os.path.join(audio_base_dir, subdir)
                        os.makedirs(correct_subdir, exist_ok=True)
                        correct_file_path = os.path.join(correct_subdir, sanitized_filename)
                        
                        try:
                            # Copy the file to the correct location
                            import shutil
                            shutil.copy2(potential_file, correct_file_path)
                            tqdm.write(f"  - Migrated audio file from '{potential_file}' to '{correct_file_path}'")
                            
                            # Return the relative path from project root
                            relative_path = os.path.relpath(correct_file_path, project_root).replace(os.sep, '/')
                            tqdm.write(f"  - Using migrated audio: '{english_phrase}' -> '{relative_path}'")
                            return relative_path
                        except Exception as e:
                            tqdm.write(f"  - Error migrating file '{potential_file}': {e}")
                    else:
                        tqdm.write(f"  - Found invalid audio file in backend: '{potential_file}' (will be skipped)")
    
    return None


def sanitize_filename(text: str) -> str:
    """Sanitizes a string to be a valid filename."""
    text = re.sub(r'[\\/*?:"<>|]', "", text)
    text = text.replace(" ", "_").lower()
    # Limit filename length to avoid issues on some filesystems
    return text[:100]


def get_azure_tokens_from_audio(audio_file_path: str, speech_key: str, speech_region: str, english_phrase: str, thai_phrase: str = "") -> list[str]:
    """
    Uses Azure Speech SDK with Pronunciation Assessment to get proper word-level tokenization.
    This uses the pronunciation assessment feature to get individual words with timing and accuracy.
    Resamples audio to 16kHz mono if necessary.
    Enhanced with debugging statements.
    """
    tqdm.write(f"  - Azure Speech: Starting pronunciation assessment for '{english_phrase}'")
    tqdm.write(f"    - Audio file: {audio_file_path}")
    
    # Validate input file exists
    if not os.path.exists(audio_file_path):
        tqdm.write(f"    - ERROR: Audio file does not exist: {audio_file_path}")
        return []
    
    speech_config = speechsdk.SpeechConfig(subscription=speech_key, region=speech_region)
    speech_config.speech_recognition_language = "th-TH"  # Thai language recognition
    
    tqdm.write(f"    - Azure Speech config: language=th-TH, region={speech_region}")

    temp_wav_path = None
    try:
        # Check and potentially resample audio
        tqdm.write(f"    - Loading audio file...")
        audio = AudioSegment.from_file(audio_file_path)
        tqdm.write(f"    - Original audio: {audio.frame_rate}Hz, {audio.channels}ch, {len(audio)}ms")
        
        if audio.frame_rate != 16000 or audio.channels != 1:
            tqdm.write(f"    - Resampling to 16kHz mono...")
            audio = audio.set_frame_rate(16000).set_channels(1)
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
                audio.export(temp_wav.name, format="wav")
                temp_wav_path = temp_wav.name
                tqdm.write(f"    - Resampled audio saved to: {temp_wav_path}")
            audio_config = speechsdk.audio.AudioConfig(filename=temp_wav_path)
        else:
            tqdm.write(f"    - Audio format is already correct (16kHz mono)")
            audio_config = speechsdk.audio.AudioConfig(filename=audio_file_path)

        # Set up pronunciation assessment config
        # Use the Thai phrase as reference text for better pronunciation assessment
        reference_text = thai_phrase if thai_phrase else ""  # Use Thai phrase as reference
        tqdm.write(f"    - Using reference text: '{reference_text}'")
        pronunciation_config = speechsdk.PronunciationAssessmentConfig(
            reference_text=reference_text,
            grading_system=speechsdk.PronunciationAssessmentGradingSystem.HundredMark,
            granularity=speechsdk.PronunciationAssessmentGranularity.Word,
            enable_miscue=True
        )
        
        tqdm.write(f"    - Creating speech recognizer with pronunciation assessment...")
        speech_recognizer = speechsdk.SpeechRecognizer(speech_config=speech_config, audio_config=audio_config)
        pronunciation_config.apply_to(speech_recognizer)
        
        tqdm.write(f"    - Starting pronunciation assessment...")
        result = speech_recognizer.recognize_once()
        
        tqdm.write(f"    - Recognition result reason: {result.reason}")

        if result.reason == speechsdk.ResultReason.RecognizedSpeech:
            recognized_text = result.text
            tqdm.write(f"    - Recognized text: '{recognized_text}'")
            
            # Get pronunciation assessment results
            pronunciation_result = speechsdk.PronunciationAssessmentResult(result)
            tqdm.write(f"    - Pronunciation assessment score: {pronunciation_result.accuracy_score}")
            
            # Extract individual words from pronunciation assessment
            word_tokens = []
            if hasattr(pronunciation_result, 'words') and pronunciation_result.words:
                for word in pronunciation_result.words:
                    word_text = word.word
                    word_tokens.append(word_text)
            else:
                # Fallback to simple split if pronunciation assessment doesn't return words
                tqdm.write(f"    - No detailed word breakdown available, falling back to text splitting")
                word_tokens = recognized_text.split()
            
            # Consolidated debug output showing the phrase split into tokens
            tqdm.write(f"    - Thai phrase '{thai_phrase}' split into tokens: {word_tokens}")
            return word_tokens
            
        elif result.reason == speechsdk.ResultReason.NoMatch:
            tqdm.write(f"    - Azure Speech: No speech could be recognized for {audio_file_path}")
            if hasattr(result, 'no_match_details'):
                tqdm.write(f"    - No match details: {result.no_match_details}")
        elif result.reason == speechsdk.ResultReason.Canceled:
            cancellation_details = speechsdk.CancellationDetails(result)
            tqdm.write(f"    - Azure Speech: Recognition canceled for {audio_file_path}")
            tqdm.write(f"    - Cancellation reason: {cancellation_details.reason}")
            tqdm.write(f"    - Error details: {cancellation_details.error_details}")
            if cancellation_details.error_code:
                tqdm.write(f"    - Error code: {cancellation_details.error_code}")
    except Exception as e:
        tqdm.write(f"    - ERROR during Azure Speech pronunciation assessment for {audio_file_path}: {str(e)}")
        tqdm.write(f"    - Exception type: {type(e).__name__}")
        tqdm.write(f"    - Full traceback: {traceback.format_exc()}")
    finally:
        if temp_wav_path and os.path.exists(temp_wav_path):
            tqdm.write(f"    - Cleaning up temporary file: {temp_wav_path}")
            os.unlink(temp_wav_path)
    
    tqdm.write(f"    - Azure Speech: Returning empty tokens for '{english_phrase}'")
    return []


def process_vocabulary(vocab_file_path: str):
    """
    Processes a vocabulary file to:
    - Check audio_path fields exist before processing
    - Generate audio (TTS API)
    - Validate WAV files after generation
    - Tokenize audio using Azure Speech API
    - Collect all unique Thai words and send to Gemini for consistent transliteration/translation
    - Apply the consistent mappings to all entries
    - Save progress after each step
    - Add 'audio_generated' and 'azure_pron_mapping_verified' fields
    """
    load_dotenv(dotenv_path=os.path.join(os.getcwd(), '.env'))

    gemini_api_key = os.environ.get("GEMINI_API_KEY")
    azure_speech_key = os.environ.get("AZURE_SPEECH_KEY")
    azure_speech_region = os.environ.get("AZURE_SPEECH_REGION")

    if not gemini_api_key:
        print("Error: GEMINI_API_KEY not found in .env file.")
        return
    if not azure_speech_key or not azure_speech_region:
        print("Error: AZURE_SPEECH_KEY and AZURE_SPEECH_REGION not found in .env file.")
        return

    # Set up the Gemini client using the API key from the .env file.
    # This explicitly uses the API key to avoid conflicts with gcloud's
    # Application Default Credentials (ADC) which might point to Vertex AI.
    client = genai.Client(api_key=gemini_api_key,
                          vertexai=False)
    tts_model_name = "gemini-2.5-flash-preview-tts"
    text_model_name = "gemini-2.5-flash"

    # Define paths - ensure we use the project root, not the current working directory
    # This script may be run from the backend/ directory, so we need to find the actual project root
    current_dir = os.getcwd()
    if current_dir.endswith('backend'):
        project_root = os.path.dirname(current_dir)  # Go up one level to project root
    else:
        project_root = current_dir
    
    if not os.path.isabs(vocab_file_path):
        vocab_file_path = os.path.join(project_root, vocab_file_path)

    if not os.path.exists(vocab_file_path):
        print(f"Error: Vocabulary file not found at '{vocab_file_path}'")
        return

    file_basename = os.path.splitext(os.path.basename(vocab_file_path))[0]
    audio_output_dir = os.path.join(project_root, 'assets/audio', file_basename)

    # Load vocabulary
    with open(vocab_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    os.makedirs(audio_output_dir, exist_ok=True)

    # Check audio_path fields before processing
    valid_audio_count, total_count = check_audio_paths_exist(data, project_root)
    if valid_audio_count == 0:
        print("Warning: No entries have valid audio files. Audio generation will be performed first.")

    tts_failures = 0
    azure_tokenization_failures = 0
    existing_audio_used = 0
    new_audio_generated = 0

    # --- Pass 1: Audio Generation and immediate JSON update ---
    print("\n--- Pass 1: Generating audio files ---")
    for i, entry in enumerate(tqdm(data['vocabulary'], desc="Generating audio")):
        thai_phrase = entry['thai']
        english_phrase = entry['english']
        audio_path_key = 'audio_path'

        # Only generate audio if not already done
        if not entry.get('audio_generated'):
            # First check if audio already exists anywhere in assets/audio
            existing_audio_path = check_existing_audio_files(project_root, thai_phrase, english_phrase)
            
            if existing_audio_path:
                # Use existing audio file
                entry[audio_path_key] = existing_audio_path
                entry['audio_generated'] = True
                existing_audio_used += 1
                tqdm.write(f"  - Using existing audio for '{english_phrase}'")
                # Immediately save progress to disk
                with open(vocab_file_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=4)
            else:
                # Generate new audio file
                sanitized_filename = sanitize_filename(english_phrase) + ".wav"
                relative_audio_dir = os.path.join('assets/audio', file_basename)
                audio_file_path = os.path.join(project_root, relative_audio_dir, sanitized_filename)
                try:
                    saved_path, streamed = retry_audio_generation(generate_audio_file, client, tts_model_name, thai_phrase, audio_file_path, english_phrase)
                    if saved_path:
                        relative_path = os.path.relpath(saved_path, project_root).replace(os.sep, '/')
                        entry[audio_path_key] = relative_path
                        entry['audio_generated'] = True
                        new_audio_generated += 1
                        tqdm.write(f"  - Successfully generated audio for '{english_phrase}'")
                        # Immediately save progress to disk after each audio file
                        with open(vocab_file_path, 'w', encoding='utf-8') as f:
                            json.dump(data, f, ensure_ascii=False, indent=4)
                    else:
                        tts_failures += 1
                        tqdm.write(f"  - Failed to generate audio for '{thai_phrase}' after retries (API returned empty data or validation failed).")
                except Exception as e:
                    tts_failures += 1
                    tqdm.write(f"  - Error generating audio for '{thai_phrase}' after retries: {e}")
                    tqdm.write(traceback.format_exc())

    # --- Pass 2: Azure Tokenization ---
    print("\n--- Pass 2: Tokenizing audio with Azure Speech API ---")
    entry_tokens = {}  # Store tokens for each entry index
    all_unique_words = set()  # Collect all unique Thai words
    
    for i, entry in enumerate(tqdm(data['vocabulary'], desc="Tokenizing audio")):
        thai_phrase = entry['thai']
        english_phrase = entry['english']
        audio_path = entry.get('audio_path')
        audio_generated = entry.get('audio_generated', False)
        azure_pron_mapping_verified = entry.get('azure_pron_mapping_verified', False)

        # Skip if azure pronunciation mapping is already verified
        if azure_pron_mapping_verified:
            tqdm.write(f"  - Skipping '{english_phrase}' - already verified")
            continue

        # Only process if audio has been generated successfully
        if not audio_generated:
            tqdm.write(f"  - Skipping '{english_phrase}' - audio not generated yet")
            continue

        if not audio_path:
            tqdm.write(f"  - Skipping tokenization for '{english_phrase}' due to missing audio_path field.")
            continue

        full_audio_path = os.path.join(project_root, audio_path)
        if not os.path.exists(full_audio_path):
            tqdm.write(f"  - Skipping tokenization for '{english_phrase}' - audio file not found at '{full_audio_path}'.")
            continue

        tqdm.write(f"  - Tokenizing audio for '{english_phrase}'...")
        try:
            # Use Azure Speech SDK for tokenization from audio
            azure_tokens = get_azure_tokens_from_audio(full_audio_path, azure_speech_key, azure_speech_region, english_phrase, thai_phrase)

            if not azure_tokens:
                azure_tokenization_failures += 1
                tqdm.write(f"  - Azure Speech API returned no tokens for '{english_phrase}'.")
                continue

            # Store tokens for this entry and add to unique words set
            entry_tokens[i] = azure_tokens
            all_unique_words.update(azure_tokens)
            tqdm.write(f"  - Successfully tokenized '{english_phrase}' into {len(azure_tokens)} words")
            
        except Exception as e:
            azure_tokenization_failures += 1
            tqdm.write(f"  - Error tokenizing '{thai_phrase}': {e}")
            tqdm.write(traceback.format_exc())

    # --- Pass 3: Batch Transliteration and Translation with Gemini ---
    print(f"\n--- Pass 3: Getting consistent transliterations for {len(all_unique_words)} unique words ---")
    word_mapping_dict = {}
    
    if all_unique_words:
        unique_words_list = list(all_unique_words)
        tqdm.write(f"  - Unique Thai words found: {unique_words_list}")
        
        # Process in batches to avoid hitting API limits (adjust batch size as needed)
        batch_size = 50  # Adjust based on API limits
        for batch_start in range(0, len(unique_words_list), batch_size):
            batch_end = min(batch_start + batch_size, len(unique_words_list))
            batch_words = unique_words_list[batch_start:batch_end]
            
            tqdm.write(f"  - Processing batch {batch_start // batch_size + 1}: words {batch_start + 1}-{batch_end} of {len(unique_words_list)}")
            
            try:
                batch_mapping = get_transliteration_and_translation_batch(batch_words, client, text_model_name)
                word_mapping_dict.update(batch_mapping)
                tqdm.write(f"  - Successfully processed {len(batch_mapping)} words in this batch")
                
                # Small delay between batches to be respectful to the API
                if batch_end < len(unique_words_list):
                    time.sleep(1)
                    
            except Exception as e:
                tqdm.write(f"  - Error processing batch {batch_start // batch_size + 1}: {e}")
                tqdm.write(traceback.format_exc())

    # --- Pass 4: Apply Consistent Mappings to Entries ---
    print(f"\n--- Pass 4: Applying consistent mappings to vocabulary entries ---")
    mapping_failures = 0
    
    for i, entry in enumerate(tqdm(data['vocabulary'], desc="Applying mappings")):
        english_phrase = entry['english']
        
        # Skip if already verified or no tokens available
        if entry.get('azure_pron_mapping_verified', False):
            continue
            
        if i not in entry_tokens:
            continue
            
        tokens = entry_tokens[i]
        
        try:
            # Build azure pronunciation mapping for this entry using the consistent dictionary
            azure_pron_mapping = []
            for token in tokens:
                if token in word_mapping_dict:
                    azure_pron_mapping.append({
                        "thai": token,
                        "transliteration": word_mapping_dict[token]['transliteration'],
                        "translation": word_mapping_dict[token]['translation']
                    })
                else:
                    # Fallback for words that weren't processed successfully
                    tqdm.write(f"  - Warning: No mapping found for token '{token}' in '{english_phrase}'")
                    azure_pron_mapping.append({
                        "thai": token,
                        "transliteration": "",
                        "translation": ""
                    })
            
            # Update the entry
            entry['azure_pron_mapping'] = azure_pron_mapping
            entry['azure_pron_mapping_verified'] = True
            tqdm.write(f"  - Applied consistent mapping to '{english_phrase}' ({len(azure_pron_mapping)} words)")
            
        except Exception as e:
            mapping_failures += 1
            tqdm.write(f"  - Error applying mapping to '{english_phrase}': {e}")
            tqdm.write(traceback.format_exc())

        # Save progress after each entry
        with open(vocab_file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)

    # Print summary
    print(f"\nSUMMARY:")
    print(f"  Existing audio files used: {existing_audio_used}")
    print(f"  New audio files generated: {new_audio_generated}")
    print(f"  TTS API failures: {tts_failures}")
    print(f"  Azure Tokenization failures: {azure_tokenization_failures}")
    print(f"  Mapping application failures: {mapping_failures}")
    print(f"  Unique Thai words processed: {len(word_mapping_dict)}")
    print(f"  Total vocabulary entries: {len(data['vocabulary'])}")
    print(f"Vocabulary processing complete. File '{vocab_file_path}' updated.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process vocabulary files to generate audio and verify word mappings.")
    parser.add_argument(
        '--file',
        type=str,
        default='assets/data/beginner_food_vocabulary.json',
        help='Path to the vocabulary JSON file to process.'
    )
    args = parser.parse_args()
    
    process_vocabulary(args.file) 