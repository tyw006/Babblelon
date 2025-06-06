from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Query
from fastapi.responses import StreamingResponse, JSONResponse
import uvicorn
import os
import io
import json
import base64
from pathlib import Path
from dotenv import load_dotenv
import datetime
from pydantic import BaseModel # For request body model
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional, Dict

# --- Load .env file very first ---
# This ensures that environment variables are loaded before any other modules
# (especially your service modules) are imported and try to access them.
project_root = Path(__file__).parent.parent.resolve()
dotenv_path = project_root / ".env"
if dotenv_path.exists():
    print(f"Loading .env file from: {dotenv_path}")
    load_dotenv(dotenv_path=dotenv_path)
else:
    print(f"Warning: .env file not found at {dotenv_path}")
# --- End .env loading ---

from services.tts_service import text_to_speech_full
from services.llm_service import get_llm_response, NPCResponse
from services.stt_service import transcribe_audio
# Remove the old translation service import
# from services.translation_service import translate_english_to_thai_and_romanize

# Import the new Google Cloud service functions
from services.google_cloud_service import translate_text, romanize_thai_text, synthesize_speech

app = FastAPI()

# API keys will now be read by service modules using os.getenv AFTER load_dotenv has run.
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not ELEVENLABS_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: ELEVENLABS_API_KEY not set in environment for main.py.")
if not OPENAI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: OPENAI_API_KEY not set in environment for main.py.")
if not GEMINI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: GEMINI_API_KEY not set in environment for main.py (used by TTS service).")

# Define the origins allowed to access the backend.
# Using a wildcard for development, but should be restricted in production.
origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Pydantic Models for Endpoints ---
class TextToSpeechRequest(BaseModel):
    text: str
    voice_name: Optional[str] = "Puck"
    response_tone: Optional[str] = None # Added to allow testing tone directly

# TranscribeRequest is not strictly needed if /transcribe-audio/ uses File directly
# class TranscribeRequest(BaseModel):
# audio_file: UploadFile

# GenerateNPCResponseRequest is removed as parameters will be handled by Form for this endpoint.
# class GenerateNPCResponseRequest(BaseModel):
#     npc_id: str
#     npc_name: str
#     conversation_history: str # This is conversation_history_full for get_llm_response
#     charm_level: int

class TestLLMRequest(BaseModel):
    npc_id: str
    npc_name: str
    conversation_history_full: str
    current_charm_level: int

class TranslationRequest(BaseModel):
    english_text: str

class GoogleTranslationResponse(BaseModel):
    english_text: str
    thai_text: str
    romanized_text: str
    audio_base64: str

# --- End Pydantic Models ---

# Voice mapping for NPCs
NPC_VOICE_MAP: Dict[str, str] = {
    "amara": "Sulafat",
    "default": "Puck" 
}

@app.get("/")
async def root():
    return {"message": "Welcome to the Babblelon Backend!"}

@app.post("/generate-npc-response/")
async def generate_npc_response(
    audio_file: UploadFile = File(...),
    npc_id: str = Form(...),
    npc_name: str = Form(...),
    charm_level: int = Form(...),
    previous_conversation_history: Optional[str] = Form(None) # Client sends history UP TO this player's turn
):
    print(f"[{datetime.datetime.now()}] INFO: /generate-npc-response/ received request for NPC: {npc_id}, Name: {npc_name}, Charm: {charm_level}. File: {audio_file.filename}")
    
    try:
        # 1. STT - Transcribe player's audio
        player_audio_bytes = await audio_file.read()
        await audio_file.close()
        if not player_audio_bytes:
            raise HTTPException(status_code=400, detail="Uploaded audio file is empty.")
        
        player_audio_stream = io.BytesIO(player_audio_bytes)
        player_transcription = await transcribe_audio(player_audio_stream)
        print(f"[{datetime.datetime.now()}] INFO: STT for {npc_id} successful. Transcription: '{player_transcription}'")

        # 2. Construct full conversation history for LLM
        conversation_history_full_for_llm = previous_conversation_history if previous_conversation_history else ""
        if player_transcription and player_transcription.strip(): # Ensure transcription is not empty
            conversation_history_full_for_llm += f"\nPlayer: {player_transcription}"
        # Ensure it's not just a blank line if previous_history was None and transcription was empty
        conversation_history_full_for_llm = conversation_history_full_for_llm.strip()


        # 3. LLM - Get NPC's response
        npc_response_data: NPCResponse = await get_llm_response(
            npc_id=npc_id, 
            npc_name=npc_name,
            conversation_history_full=conversation_history_full_for_llm, 
            current_charm_level=charm_level
        )
        print(f"[{datetime.datetime.now()}] INFO: LLM response for {npc_id} OK. Target: '{npc_response_data.response_target[:30]}...', Tone: '{npc_response_data.response_tone}'")

        # 4. TTS - Convert NPC's text response to speech
        voice_name = NPC_VOICE_MAP.get(npc_id.lower(), NPC_VOICE_MAP["default"])
        npc_audio_bytes = await text_to_speech_full(
            text_to_speak=npc_response_data.response_target, 
            voice_name=voice_name,
            response_tone=npc_response_data.response_tone 
        )
        print(f"[{datetime.datetime.now()}] INFO: TTS for {npc_id} OK. Audio bytes: {len(npc_audio_bytes) if npc_audio_bytes else 'None'}")

        if not npc_audio_bytes:
            print(f"[{datetime.datetime.now()}] ERROR: text_to_speech_full returned empty audio_bytes for NPC {npc_id}, text: '{npc_response_data.response_target}'")
            raise HTTPException(status_code=500, detail="TTS service failed to generate audio for NPC response.")
        
        # 5. Prepare header data (NPCResponse + player_transcription)
        header_payload = npc_response_data.model_dump() # NPCResponse fields
        header_payload["player_transcription"] = player_transcription # Add player's transcription
        
        response_data_json = json.dumps(header_payload)
        response_data_json_b64 = base64.b64encode(response_data_json.encode('utf-8')).decode('ascii')

        print(f"[{datetime.datetime.now()}] DEBUG: Backend preparing to send X-NPC-Response-Data (JSON): {response_data_json}") # Log the JSON before base64
        print(f"[{datetime.datetime.now()}] DEBUG: Backend preparing to send audio bytes length: {len(npc_audio_bytes) if npc_audio_bytes else 'None'}")

        print(f"[{datetime.datetime.now()}] INFO: Sending NPC response for {npc_id}. Header JSON (first 60 chars of b64): {response_data_json_b64[:60]}...")
        
        return StreamingResponse(
            io.BytesIO(npc_audio_bytes), 
            media_type="audio/wav",
            headers={
                "X-NPC-Response-Data": response_data_json_b64
            }
        )
    except HTTPException as e:
        # Re-raise HTTPExceptions (e.g., from STT, LLM, or TTS services if they raise them)
        print(f"[{datetime.datetime.now()}] ERROR: HTTPException in /generate-npc-response/: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: Unhandled exception in /generate-npc-response/: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="An unexpected error occurred processing NPC response.")

@app.post("/text-to-speech/")
async def convert_text_to_speech(request: TextToSpeechRequest):
    print(f"Received TTS request for text: '{request.text}' with voice '{request.voice_name}', tone: '{request.response_tone}'")
    try:
        audio_bytes = await text_to_speech_full( # Use text_to_speech_full
            text_to_speak=request.text, 
            voice_name=request.voice_name,
            response_tone=request.response_tone # Pass tone
        )
        if not audio_bytes:
            raise HTTPException(status_code=500, detail="Failed to generate audio (empty bytes returned)")
        
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        return {"audio_base64": audio_base64} # Return as base64 JSON for simple clients
    except HTTPException as e: # Re-raise HTTP exceptions from tts_service
        raise
    except Exception as e:
        print(f"Error in /text-to-speech/: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"TTS conversion error: {str(e)}")

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.post("/transcribe-audio/")
async def transcribe_audio_endpoint(audio_file: UploadFile = File(...)):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /transcribe-audio/ endpoint hit. File: {audio_file.filename}")
    audio_bytes = await audio_file.read()
    await audio_file.close()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio file content is empty.")

    audio_content_stream = io.BytesIO(audio_bytes)
    try:
        transcription = await transcribe_audio(audio_content_stream)
        print(f"[{datetime.datetime.now()}] DEBUG: /transcribe-audio/ STT result: '{transcription}'.")
        return {"transcription": transcription}
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /transcribe-audio/ HTTPException: {e.detail}")
        raise e # Re-raise STT service errors
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /transcribe-audio/ Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=f"Unexpected STT error: {str(e)}")
    finally:
        total_time = datetime.datetime.now() - request_time
        print(f"[{datetime.datetime.now()}] INFO: /transcribe-audio/ finished. Total time: {total_time}")

# --- Temporary Debug Endpoint for STT ---
@app.post("/debug-stt/")
async def debug_stt_endpoint(file_path: str = Form("assets/audio/test/test_input1.wav")):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /debug-stt/ endpoint hit. Testing with file: {file_path}")
    abs_file_path = project_root / file_path # Construct absolute path from project root
    
    if not os.path.exists(abs_file_path):
        print(f"[{datetime.datetime.now()}] ERROR: File not found for STT debug: {abs_file_path}")
        raise HTTPException(status_code=404, detail=f"File not found: {abs_file_path}")
    
    try:
        with open(abs_file_path, 'rb') as audio_file:
            audio_bytes = audio_file.read()
        audio_content_stream = io.BytesIO(audio_bytes)
        print(f"[{datetime.datetime.now()}] DEBUG: Read {len(audio_bytes)} bytes from {abs_file_path} for STT debug.")

        transcription = await transcribe_audio(audio_content_stream)
        print(f"[{datetime.datetime.now()}] DEBUG: STT debug result: '{transcription}'.")
        
        return {"file_path": str(abs_file_path), "transcription": transcription}
    except HTTPException as e:
        # Re-raise HTTPExceptions from the service
        print(f"[{datetime.datetime.now()}] ERROR: HTTPException in STT debug: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: Unexpected error in STT debug: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Unexpected error during STT debug: {str(e)}")
    finally:
        total_time = datetime.datetime.now() - request_time
        print(f"[{datetime.datetime.now()}] INFO: /debug-stt/ request finished. Total time: {total_time}")
# --- End Temporary Debug Endpoint ---

# --- New Test Endpoint for LLM ---
@app.post("/test-llm-response/")
async def test_llm_response_endpoint(request: TestLLMRequest):
    print(f"[{datetime.datetime.now()}] INFO: /test-llm-response/ received request for NPC: {request.npc_id}, Name: {request.npc_name}")
    try:
        npc_response_data = await get_llm_response(
            npc_id=request.npc_id,
            npc_name=request.npc_name,
            conversation_history_full=request.conversation_history_full,
            current_charm_level=request.current_charm_level
        )
        print(f"[{datetime.datetime.now()}] INFO: LLM test response for {request.npc_id} OK.")
        return npc_response_data # Returns NPCResponse Pydantic model as JSON
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: HTTPException in /test-llm-response/: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: Unhandled exception in /test-llm-response/: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during LLM test: {str(e)}")
# --- End New Test Endpoint for LLM ---

# --- New Google Cloud Translation and TTS Endpoint ---
@app.post("/gcloud-translate-tts/", response_model=GoogleTranslationResponse)
async def gcloud_translate_tts_endpoint(request: TranslationRequest):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /gcloud-translate-tts/ received request for text: '{request.english_text[:50]}...'")
    try:
        # 1. Translate English to Thai
        translation_result = await translate_text(request.english_text)
        thai_text = translation_result["translated_text"]

        # 2. Romanize the resulting Thai text
        romanization_result = await romanize_thai_text(thai_text)
        romanized_text = romanization_result["romanized_text"]

        # 3. Synthesize speech from the Thai text
        tts_result = await synthesize_speech(thai_text)
        audio_base64 = tts_result["audio_base64"]

        response_payload = {
            "english_text": request.english_text,
            "thai_text": thai_text,
            "romanized_text": romanized_text,
            "audio_base64": audio_base64,
        }
        
        return GoogleTranslationResponse(**response_payload)

    except HTTPException as e:
        # Re-raise exceptions from the service layer
        print(f"[{datetime.datetime.now()}] ERROR: HTTPException in /gcloud-translate-tts/: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: Unhandled exception in /gcloud-translate-tts/: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during Google Cloud processing: {str(e)}")
# --- End New Google Cloud Translation and TTS Endpoint ---

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 