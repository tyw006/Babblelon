# To run this code you need to install the following dependencies:
# pip install -r requirements.txt

import base64
import json
import mimetypes
import os
import re
import struct
import time
import argparse
import random
import traceback

from dotenv import load_dotenv
from google import genai
from google.genai import types
from pythainlp.tokenize import word_tokenize
from tqdm import tqdm


def save_binary_file(file_name, data):
    """Saves binary data to a file."""
    with open(file_name, "wb") as f:
        f.write(data)
    # print(f"File saved to: {file_name}")


def convert_to_wav(audio_data: bytes, mime_type: str) -> bytes:
    """Generates a WAV file header for the given audio data and parameters."""
    parameters = parse_audio_mime_type(mime_type)
    bits_per_sample = parameters["bits_per_sample"]
    sample_rate = parameters["rate"]
    num_channels = 1
    data_size = len(audio_data)
    bytes_per_sample = bits_per_sample // 8
    block_align = num_channels * bytes_per_sample
    byte_rate = sample_rate * block_align
    chunk_size = 36 + data_size

    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        chunk_size,
        b"WAVE",
        b"fmt ",
        16,
        1,
        num_channels,
        sample_rate,
        byte_rate,
        block_align,
        bits_per_sample,
        b"data",
        data_size,
    )
    return header + audio_data


def parse_audio_mime_type(mime_type: str) -> dict[str, int | None]:
    """Parses bits per sample and rate from an audio MIME type string."""
    bits_per_sample = 16
    rate = 24000
    parts = mime_type.split(";")
    for param in parts:
        param = param.strip()
        if param.lower().startswith("rate="):
            try:
                rate_str = param.split("=", 1)[1]
                rate = int(rate_str)
            except (ValueError, IndexError):
                pass
        elif param.startswith("audio/L"):
            try:
                bits_per_sample = int(param.split("L", 1)[1])
            except (ValueError, IndexError):
                pass
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


def get_transliteration_and_translation(tokens: list[str], client, model_name: str):
    """
    Gets transliteration and translation for a list of tokenized words using Gemini
    in a single API call.
    """
    if not tokens:
        return None

    # Create the list of JSON objects for the prompt
    word_list_str = ",\n".join([f'    {{"thai": "{token}", "transliteration": "", "translation": ""}}' for token in tokens])

    prompt = f"""
Please fill in the 'transliteration' (for pronunciation) and 'translation' for each of the following Thai words.
Return the result as a single, raw JSON object with a single key "word_mapping" which contains the completed list. Do not include any other text, formatting, or markdown.

Input:
[
{word_list_str}
]

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
        tqdm.write(f"  - Error processing tokens '{tokens}': {e}")
        return None


def generate_audio_file(client, model_name, text: str, file_path: str, english_phrase: str) -> tuple[str | None, bool]:
    """
    Generates an audio file from text using Gemini TTS.
    Returns the path to the saved file and a boolean indicating if streaming occurred.
    """
    contents = [
        types.Content(
            role="user",
            parts=[types.Part.from_text(text=text)],
        ),
    ]
    generate_content_config = types.GenerateContentConfig(
        response_modalities=["audio"],
        speech_config=types.SpeechConfig(
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Aoede")
            )
        ),
    )
    def api_call():
        audio_chunks = []
        
        tqdm.write(f"  - TTS: Requesting audio for '{english_phrase}'...")
        for chunk in client.models.generate_content_stream(
            model=model_name,
            contents=contents,
            config=generate_content_config,
        ):
            if (
                chunk.candidates is None
                or chunk.candidates[0].content is None
                or chunk.candidates[0].content.parts is None
            ):
                continue
            part = chunk.candidates[0].content.parts[0]
            if part.inline_data and part.inline_data.data:
                inline_data = part.inline_data
                audio_chunks.append(inline_data.data)

        was_streamed = len(audio_chunks) > 1
        final_audio_data = b"".join(audio_chunks)

        if final_audio_data:
            tqdm.write(f"  - TTS: Received audio. Saving to '{file_path}'...")
            save_binary_file(file_path, final_audio_data)
            return file_path, was_streamed
        return None, False

    return retry_with_backoff(api_call)


def sanitize_filename(text: str) -> str:
    """Sanitizes a string to be a valid filename."""
    text = re.sub(r'[\\/*?:"<>|]', "", text)
    text = text.replace(" ", "_").lower()
    # Limit filename length to avoid issues on some filesystems
    return text[:100]


def process_vocabulary(vocab_file_path: str):
    """
    Processes a vocabulary file to:
    - Verify/correct word mapping (text API)
    - Generate audio (TTS API)
    - Save progress after each step
    - Add 'word_mapping_verified' and 'audio_generated' fields
    """
    load_dotenv(dotenv_path=os.path.join(os.getcwd(), '.env'))

    gemini_api_key = os.environ.get("GEMINI_API_KEY")
    if not gemini_api_key:
        print("Error: GEMINI_API_KEY not found in .env file.")
        return

    # Set up Gemini client
    client = genai.Client(api_key=gemini_api_key)
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
    
    tts_failures = 0
    text_failures = 0

    for i, entry in enumerate(tqdm(data['vocabulary'], desc="Processing vocabulary")):
        thai_phrase = entry['thai']
        english_phrase = entry['english']
        word_mapping = entry.get('word_mapping', [])
        audio_path_key = 'audio_path'

        # Skip if both word_mapping_verified and audio_generated are True
        if entry.get('word_mapping_verified') and entry.get('audio_generated'):
            continue

        # --- Word Mapping Verification ---
        if not entry.get('word_mapping_verified'):
            tokenized = word_tokenize(thai_phrase, engine='newmm')
            
            # Extract Thai words from the existing mapping for comparison
            existing_tokens = []
            if word_mapping:
                try:
                    existing_tokens = [item['thai'] for item in word_mapping]
                except (TypeError, KeyError):
                    # Handle cases where word_mapping might not be a list of dicts
                    existing_tokens = []

            if not word_mapping or existing_tokens != tokenized:
                tqdm.write(f"  - Word mapping mismatch or missing for '{english_phrase}'. Correcting...")
                try:
                    correction = retry_with_backoff(get_transliteration_and_translation, tokenized, client, text_model_name)
                    if correction and 'word_mapping' in correction:
                        entry['word_mapping'] = correction['word_mapping']
                        tqdm.write("  - Word mapping corrected.")
                        # Immediately save progress
                        with open(vocab_file_path, 'w', encoding='utf-8') as f:
                            json.dump(data, f, ensure_ascii=False, indent=4)
                    else:
                        text_failures += 1
                        tqdm.write(f"  - Gemini API did not return 'word_mapping' for '{thai_phrase}'. Response: {correction}")
                except Exception as e:
                    text_failures += 1
                    tqdm.write(f"  - Error processing word mapping for '{thai_phrase}': {e}")
                    tqdm.write(traceback.format_exc())
            else:
                tqdm.write(f"  - Word mapping for '{thai_phrase}' is already correct. Skipping correction call.")
            
            # Mark as verified and save
            entry['word_mapping_verified'] = True
            with open(vocab_file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=4)


        # --- Audio Generation ---
        # Only generate audio if not already done
        if not entry.get('audio_generated'):
            sanitized_filename = sanitize_filename(english_phrase) + ".wav"
            relative_audio_dir = os.path.join('assets/audio', file_basename)
            audio_file_path = os.path.join(project_root, relative_audio_dir, sanitized_filename)
            try:
                saved_path, streamed = generate_audio_file(client, tts_model_name, thai_phrase, audio_file_path, english_phrase)
                if saved_path:
                    relative_path = os.path.relpath(saved_path, project_root).replace(os.sep, '/')
                    entry[audio_path_key] = relative_path
                    entry['audio_generated'] = True
                    # Immediately save progress to disk after each audio file
                    with open(vocab_file_path, 'w', encoding='utf-8') as f:
                        json.dump(data, f, ensure_ascii=False, indent=4)
                else:
                    tts_failures += 1
                    tqdm.write(f"  - Failed to generate audio for '{thai_phrase}' (API returned empty data).")
            except Exception as e:
                tts_failures += 1
                tqdm.write(f"  - Error generating audio for '{thai_phrase}': {e}")
                tqdm.write(traceback.format_exc())

    # Print summary
    print(f"\nSUMMARY:")
    print(f"  Text API failures: {text_failures}")
    print(f"  TTS API failures: {tts_failures}")
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