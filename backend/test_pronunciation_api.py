import requests
import os
from pathlib import Path
import tempfile
from pydub import AudioSegment

# --- Configuration ---
# Assuming the FastAPI server is running on localhost:8000
BASE_URL = "http://localhost:8000"
ENDPOINT_URL = f"{BASE_URL}/pronunciation/assess/"

# Get the path to a test audio file.
try:
    script_dir = Path(__file__).parent
    audio_file_path = script_dir / 'patty-thai-test.m4a'
    if not audio_file_path.exists():
        # Fallback to test_files directory if not found in backend/
        audio_file_path = script_dir / 'test_files' / 'patty-thai-test.m4a'
        if not audio_file_path.exists():
            raise FileNotFoundError(f"Test audio file 'patty-thai-test.m4a' not found.")
except NameError:
    # Fallback for environments where __file__ is not defined
    audio_file_path = Path('patty-thai-test.m4a')
    if not audio_file_path.exists():
        raise FileNotFoundError(f"Test audio file not found at: {audio_file_path}")

# --- Test Data ---
test_data = {
    "reference_text": "ไอ้เหี้ยไอ้สัตว์มึงหุบปากสักทีได้ป่ะพูดอยู่นั่นแหละอีควายปากหมาฉิบหายเลยโอเค",
    "transliteration": "ai hia ai sat meung hub pak sak tee dai pa plod yoo nan lae ee kwai pak ma chib hai loey o ke",
    "complexity": "medium",
    "item_type": "special",
    "turn_type": "defense",
    "language": "th-TH"
}

def test_pronunciation_assessment_endpoint():
    """
    Tests the /pronunciation/assess/ endpoint by converting an M4A file
    to WAV in-memory and sending it for assessment.
    """
    print("--- Running Pronunciation Assessment Endpoint Test ---")
    
    temp_wav_file = None
    try:
        # --- Convert M4A to WAV ---
        print(f"Converting {audio_file_path.name} to WAV...")
        audio = AudioSegment.from_file(audio_file_path, format="m4a")
        # Azure prefers 16kHz mono for best results
        audio = audio.set_frame_rate(16000).set_channels(1)
        
        # Export to a temporary WAV file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            audio.export(tmp.name, format="wav")
            temp_wav_file = tmp.name
        print(f"Temporary WAV created at: {temp_wav_file}")

        # Prepare the file for the multipart/form-data request
        with open(temp_wav_file, 'rb') as f:
            files = {'audio_file': (os.path.basename(temp_wav_file), f, 'audio/wav')}
            
            print(f"Sending POST request to: {ENDPOINT_URL}")
            print(f"With data: {test_data}")
            print(f"And file: {os.path.basename(temp_wav_file)}")
            
            # Make the request
            response = requests.post(ENDPOINT_URL, files=files, data=test_data)
            
            # --- Check Response ---
            print(f"\nResponse Status Code: {response.status_code}")
            
            # Raise an exception for bad status codes (4xx or 5xx)
            response.raise_for_status()
            
            response_json = response.json()
            
            print("\nReceived JSON response:")
            # Pretty print the JSON for better readability
            import json
            print(json.dumps(response_json, indent=2, ensure_ascii=False))
            
            # --- Assertions ---
            assert 'rating' in response_json
            assert 'pronunciation_score' in response_json
            assert 'attack_multiplier' in response_json
            assert 'defense_multiplier' in response_json
            assert 'word_results' in response_json
            assert 'word_feedback' in response_json
            assert 'calculation_breakdown' in response_json
            assert 'base_attack' in response_json['calculation_breakdown']
            assert len(response_json['word_results']) > 0
            
            print(f"\n✅ Test Passed: Successfully received a valid assessment.")
            print(f"   - Rating: {response_json['rating']}")
            print(f"   - Score: {response_json['pronunciation_score']}")
            print(f"   - Attack Multiplier: {response_json['attack_multiplier']}")
            print(f"   - Defense Multiplier: {response_json['defense_multiplier']:.4f}")
            
    except FileNotFoundError as e:
        print(f"\n❌ Test Failed: Could not find the audio file.")
        print(f"   Error: {e}")
    except requests.exceptions.RequestException as e:
        print(f"\n❌ Test Failed: An error occurred during the request.")
        print(f"   Error: {e}")
        if e.response is not None:
            print(f"   Response Body: {e.response.text}")
    except Exception as e:
        print(f"\n❌ Test Failed: An unexpected error occurred.")
        print(f"   Error: {e}")
    finally:
        # Clean up the temporary file
        if temp_wav_file and os.path.exists(temp_wav_file):
            os.unlink(temp_wav_file)
            print(f"\nTemporary file {temp_wav_file} deleted.")

if __name__ == "__main__":
    test_pronunciation_assessment_endpoint() 