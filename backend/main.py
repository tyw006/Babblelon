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
from typing import Optional, Dict, List

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
from services.translation_service import translate_text, romanize_target_text, synthesize_speech, create_word_level_translation_mapping, get_language_name

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
class TranslationRequest(BaseModel):
    english_text: str
    target_language: str = "th"  # Default to Thai for backward compatibility

class WordMapping(BaseModel):
    english: str
    target: str  # Changed from 'thai' to 'target'
    romanized: str

class GoogleTranslationResponse(BaseModel):
    english_text: str
    target_text: str  # Changed from 'thai_text' to 'target_text'
    romanized_text: str
    audio_base64: str
    word_mappings: list[WordMapping]
    target_language_name: str

# --- End Pydantic Models ---

# Voice mapping for NPCs
NPC_VOICE_MAP: Dict[str, str] = {
    "amara": "Sulafat",
    "somchai": "Algenib",
    "default": "Puck" 
}

@app.get("/")
async def root():
    return {"message": "Welcome to the Babblelon Backend!"}

@app.post("/generate-npc-response/")
async def generate_npc_response_endpoint(
    audio_file: UploadFile = File(...),
    npc_id: str = Form(...),
    npc_name: str = Form(...),
    charm_level: int = Form(50),
    target_language: Optional[str] = Form("th"),  # Add target language parameter
    previous_conversation_history: Optional[str] = Form("")
):
    print(f"[{datetime.datetime.now()}] INFO: /generate-npc-response/ received request for NPC: {npc_id}, Name: {npc_name}, Charm: {charm_level}, Language: {target_language}. File: {audio_file.filename}")
    
    try:
        # 1. STT - Transcribe player's audio
        player_audio_bytes = await audio_file.read()
        await audio_file.close()
        if not player_audio_bytes:
            raise HTTPException(status_code=400, detail="Uploaded audio file is empty.")
        
        player_audio_stream = io.BytesIO(player_audio_bytes)
        player_transcription = await transcribe_audio(player_audio_stream)
        print(f"[{datetime.datetime.now()}] INFO: STT for {npc_id} successful. Transcription: '{player_transcription}'")

        # 2. Prepare conversation history and latest message for LLM
        conversation_history = previous_conversation_history if previous_conversation_history else ""
        latest_player_message = player_transcription if player_transcription and player_transcription.strip() else ""
        
        if not latest_player_message:
            raise HTTPException(status_code=400, detail="Player transcription is empty or invalid.")

        # 3. LLM - Get NPC's response
        npc_response_data: NPCResponse = await get_llm_response(
            npc_id=npc_id, 
            npc_name=npc_name,
            conversation_history=conversation_history,
            latest_player_message=latest_player_message,
            current_charm_level=charm_level,
            target_language=target_language
        )
        print(f"[{datetime.datetime.now()}] INFO: LLM response for {npc_id} OK. Target: '{npc_response_data.response_target[:30]}...', Tone: '{npc_response_data.response_tone}'")

        # 4. TTS - Convert NPC's text response to speech
        voice_name = NPC_VOICE_MAP.get(npc_id.lower(), NPC_VOICE_MAP["default"])
        npc_audio_bytes = await text_to_speech_full(
            text_to_speak=npc_response_data.response_target, 
            voice_name=voice_name,
            response_tone=npc_response_data.response_tone 
        )
        print(f"[{datetime.datetime.now()}] INFO: TTS for {npc_id} using voice '{voice_name}' OK. Audio bytes: {len(npc_audio_bytes) if npc_audio_bytes else 'None'}")

        if not npc_audio_bytes:
            print(f"[{datetime.datetime.now()}] ERROR: text_to_speech_full returned empty audio_bytes for NPC {npc_id}, text: '{npc_response_data.response_target}'")
            raise HTTPException(status_code=500, detail="TTS service failed to generate audio for NPC response.")
        
        # 5. Prepare header data (NPCResponse + player_transcription)
        header_payload = npc_response_data.model_dump() # NPCResponse fields
        header_payload["player_transcription"] = player_transcription # Add player's transcription
        
        # The JSON data part of the response needs to be base64 encoded to be sent in a header.
        response_data_dict = {
            "input_target": npc_response_data.input_target,
            "emotion": npc_response_data.emotion,
            "response_tone": npc_response_data.response_tone,
            "response_target": npc_response_data.response_target,
            "response_english": npc_response_data.response_english,
            "response_mapping": [m.model_dump() for m in npc_response_data.response_mapping],
            "input_mapping": [m.model_dump() for m in npc_response_data.input_mapping],
            "charm_delta": npc_response_data.charm_delta,
            "player_transcription_raw": player_transcription,
        }
        # Force JSON to ASCII to prevent encoding errors on the client.
        # This escapes all non-ASCII characters (e.g., to \uXXXX), making it safe
        # for transport and decoding on the Flutter client.
        response_data_json = json.dumps(response_data_dict, ensure_ascii=True)
        response_data_b64 = base64.b64encode(response_data_json.encode('ascii')).decode('ascii')

        print(f"[{datetime.datetime.now()}] DEBUG: Backend preparing to send X-NPC-Response-Data (JSON): {response_data_json}") # Log the JSON before base64
        print(f"[{datetime.datetime.now()}] DEBUG: Backend preparing to send audio bytes length: {len(npc_audio_bytes) if npc_audio_bytes else 'None'}")

        print(f"[{datetime.datetime.now()}] INFO: Sending NPC response for {npc_id}. Header JSON (first 60 chars of b64): {response_data_b64[:60]}...")
        
        return StreamingResponse(
            io.BytesIO(npc_audio_bytes), 
            media_type="audio/wav",
            headers={
                "X-NPC-Response-Data": response_data_b64
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

# --- Google Cloud Translation and TTS Endpoint ---
@app.post("/gcloud-translate-tts/", response_model=GoogleTranslationResponse)
async def gcloud_translate_tts_endpoint(request: TranslationRequest):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /gcloud-translate-tts/ received request for text: '{request.english_text[:50]}...' in {request.target_language}")
    try:
        # Use the new optimized and parallelized mapping function
        translation_result = await create_word_level_translation_mapping(request.english_text, request.target_language)

        response_payload = {
            "english_text": request.english_text,
            "target_text": translation_result["target_text_spaced"],
            "romanized_text": translation_result["romanized_text"],
            "audio_base64": translation_result["audio_base64"],
            "word_mappings": translation_result["word_mappings"],
            "target_language_name": get_language_name(request.target_language)
        }
        
        return JSONResponse(content=response_payload)
    except HTTPException as e:
        # Re-raise HTTPException to let FastAPI handle it
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /gcloud-translate-tts/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 