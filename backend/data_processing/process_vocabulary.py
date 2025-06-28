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


def get_transliteration_and_translation(tokens: list[str], client, model_name: str, english_context: str, thai_context: str = ""):
    """
    Gets transliteration and translation for a list of tokenized words using Gemini
    in a single API call. Now includes English context for better accuracy.
    """
    if not tokens:
        return None

    # Create the list of JSON objects for the prompt
    word_list_str = ",\n".join([f'    {{"thai": "{token}", "transliteration": "", "translation": ""}}' for token in tokens])

    thai_context_line = f"The original Thai phrase is: '{thai_context}'" if thai_context else ""
    
    prompt = f"""
You are helping to create accurate transliterations and translations for Thai words that were automatically tokenized from speech recognition.

CONTEXT: These Thai words come from the phrase that means "{english_context}" in English.
{thai_context_line}

Please fill in the 'transliteration' (using standard romanization for pronunciation) and 'translation' (English meaning) for each of the following Thai words. Use the English and Thai context to help determine the most appropriate translation for each word.

Input:
[
{word_list_str}
]

Return the result as a single, raw JSON object with a single key "word_mapping" which contains the completed list. Do not include any other text, formatting, or markdown.

Expected Output Format:
{{
    "word_mapping": [
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
        return retry_with_backoff(api_call)
    except Exception as e:
        tqdm.write(f"  - Error processing tokens '{tokens}' with context '{english_context}': {e}")
        tqdm.write(f"  - Exception type: {type(e).__name__}")
        tqdm.write(f"  - Full traceback: {traceback.format_exc()}")
        return None


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
    - Verify/correct word mapping (Azure Speech API for tokenization, then Gemini for text API)
    - Save progress after each step
    - Add 'audio_generated' and 'word_mapping_verified' fields
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

    # Define paths
    project_root = os.getcwd()
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
    
    # Note: We'll process word mappings for entries that have audio_generated=True and need verification

    tts_failures = 0
    text_failures = 0
    azure_tokenization_failures = 0

    # --- Pass 1: Audio Generation and immediate JSON update ---
    print("\n--- Pass 1: Generating audio files ---")
    for i, entry in enumerate(tqdm(data['vocabulary'], desc="Generating audio")):
        thai_phrase = entry['thai']
        english_phrase = entry['english']
        audio_path_key = 'audio_path'

        # Only generate audio if not already done
        if not entry.get('audio_generated'):
            sanitized_filename = sanitize_filename(english_phrase) + ".wav"
            relative_audio_dir = os.path.join('assets/audio', file_basename)
            audio_file_path = os.path.join(project_root, relative_audio_dir, sanitized_filename)
            try:
                saved_path, streamed = retry_audio_generation(generate_audio_file, client, tts_model_name, thai_phrase, audio_file_path, english_phrase)
                if saved_path:
                    relative_path = os.path.relpath(saved_path, project_root).replace(os.sep, '/')
                    entry[audio_path_key] = relative_path
                    entry['audio_generated'] = True
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

    # --- Pass 2: Azure Tokenization and Gemini Text Processing ---
    print("\n--- Pass 2: Tokenizing with Azure and verifying word mappings ---")
    for i, entry in enumerate(tqdm(data['vocabulary'], desc="Processing word mappings")):
        thai_phrase = entry['thai']
        english_phrase = entry['english']
        word_mapping = entry.get('word_mapping', [])
        audio_path = entry.get('audio_path')
        audio_generated = entry.get('audio_generated', False)
        word_mapping_verified = entry.get('word_mapping_verified', False)

        # Skip if word mapping is already verified
        if word_mapping_verified:
            tqdm.write(f"  - Skipping '{english_phrase}' - already verified")
            continue

        # Only process if audio has been generated successfully
        if not audio_generated:
            tqdm.write(f"  - Skipping '{english_phrase}' - audio not generated yet")
            continue

        if not audio_path:
            tqdm.write(f"  - Skipping word mapping for '{english_phrase}' due to missing audio_path field.")
            continue

        full_audio_path = os.path.join(project_root, audio_path)
        if not os.path.exists(full_audio_path):
            tqdm.write(f"  - Skipping word mapping for '{english_phrase}' - audio file not found at '{full_audio_path}'.")
            continue

        tqdm.write(f"  - Processing word mapping for '{english_phrase}'...")
        try:
            # Use Azure Speech SDK for tokenization from audio
            azure_tokens = get_azure_tokens_from_audio(full_audio_path, azure_speech_key, azure_speech_region, english_phrase, thai_phrase)

            if not azure_tokens:
                azure_tokenization_failures += 1
                tqdm.write(f"  - Azure Speech API returned no tokens for '{english_phrase}'.")
                continue

            # Now send these tokens to Gemini for transliteration and translation with English context
            tqdm.write(f"  - Sending Azure tokens '{azure_tokens}' to Gemini for transliteration/translation...")
            correction = retry_with_backoff(get_transliteration_and_translation, azure_tokens, client, text_model_name, english_phrase, thai_phrase)
            if correction and 'word_mapping' in correction:
                entry['word_mapping'] = correction['word_mapping']
                entry['word_mapping_verified'] = True
                tqdm.write("  - Word mapping corrected with English context and marked as verified.")
            else:
                text_failures += 1
                tqdm.write(f"  - Gemini API did not return 'word_mapping' for '{thai_phrase}'. Response: {correction}")
        except Exception as e:
            text_failures += 1
            tqdm.write(f"  - Error processing word mapping for '{thai_phrase}': {e}")
            tqdm.write(traceback.format_exc())

        # Save progress after each entry in the second pass
        with open(vocab_file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)

    # Print summary
    print(f"\nSUMMARY:")
    print(f"  Text API failures: {text_failures}")
    print(f"  TTS API failures: {tts_failures}")
    print(f"  Azure Tokenization failures: {azure_tokenization_failures}")
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