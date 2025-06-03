from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.responses import StreamingResponse, JSONResponse
import uvicorn
import os
import io
import json
import base64
from dotenv import load_dotenv
from pathlib import Path
import datetime
from pydantic import BaseModel # For request body model

# Always load .env from the project root, regardless of where you run the script
project_root = Path(__file__).parent.parent.resolve()
load_dotenv(dotenv_path=project_root / ".env")

from services import stt_service, llm_service, tts_service

app = FastAPI()

# Ensure API keys are loaded (optional: add checks or raise specific errors)
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") # Assuming you use this name for Google GenAI

if not ELEVENLABS_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: ELEVENLABS_API_KEY not set.")
if not OPENAI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: OPENAI_API_KEY not set.")
if not GEMINI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: GEMINI_API_KEY not set.")

# --- New Endpoint 1: Transcribe Only ---
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
        transcribed_text = await stt_service.transcribe_audio(audio_content_stream)
        print(f"[{datetime.datetime.now()}] DEBUG: /transcribe-audio/ STT result: '{transcribed_text}'.")
        return {"transcription": transcribed_text}
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /transcribe-audio/ HTTPException: {e.detail}")
        raise e # Re-raise STT service errors
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /transcribe-audio/ Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=f"Unexpected STT error: {str(e)}")
    finally:
        total_time = datetime.datetime.now() - request_time
        print(f"[{datetime.datetime.now()}] INFO: /transcribe-audio/ finished. Total time: {total_time}")

# --- New Endpoint 2: Generate NPC Response from Text ---
class NPCRequestData(BaseModel):
    player_transcription: str
    conversation_history: str
    current_charm: int
    npc_id: str = "amara" # Default or could be passed by client

@app.post("/generate-npc-response/")
async def generate_npc_response_endpoint(data: NPCRequestData):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /generate-npc-response/ endpoint hit.")
    print(f"[{datetime.datetime.now()}] DEBUG: Received data for NPC response: {data.model_dump_json(indent=2)}")

    try:
        # 1. LLM - Get response based on transcribed text and history
        llm_input_text_for_prompt = (
            f"Previous Conversation:\n{data.conversation_history if data.conversation_history.strip() else '(No previous conversation)'}\n\n"
            f"Player's Latest Utterance (to be responded to):\n{data.player_transcription}"
        )
        print(f"[{datetime.datetime.now()}] DEBUG: Calling LLM for NPC: {data.npc_id} with charm: {data.current_charm}.")
        
        npc_response_data = await llm_service.get_llm_response(
            llm_input_text_for_prompt, 
            npc_id=data.npc_id,
            charm_level=data.current_charm
        )
        if not npc_response_data or not npc_response_data.response_thai:
            print(f"[{datetime.datetime.now()}] ERROR: LLM failed in /generate-npc-response/")
            raise HTTPException(status_code=500, detail="LLM failed to generate a response.")
        print(f"[{datetime.datetime.now()}] DEBUG: LLM response received: {npc_response_data.model_dump_json(indent=2)}")
        print(f"[{datetime.datetime.now()}] RAW LLM TEXTS - Thai: {repr(npc_response_data.response_thai)}, Eng: {repr(npc_response_data.response_eng)}, RTGS: {repr(npc_response_data.response_rtgs)}")

        # 2. TTS - Convert LLM's Thai response to full speech audio bytes
        text_to_speak = f"""In a {npc_response_data.response_tone} tone: {npc_response_data.response_thai}"""
        print(f"[{datetime.datetime.now()}] DEBUG: Requesting full TTS for: '{text_to_speak}'")
        
        npc_audio_bytes = await tts_service.text_to_speech_full(text_to_speak)
        if not npc_audio_bytes:
            print(f"[{datetime.datetime.now()}] ERROR: TTS (full) failed in /generate-npc-response/")
            raise HTTPException(status_code=500, detail="TTS failed to generate audio bytes.")
        print(f"[{datetime.datetime.now()}] DEBUG: TTS (full) generated {len(npc_audio_bytes)} bytes.")

        # 3. Prepare and return the combined JSON response
        response_payload = {
            "type": "full_npc_response", # New type for clarity
            "npc_response_data": npc_response_data.model_dump(), # Contains npc_response_thai, charm_delta etc.
            "npc_audio_base64": base64.b64encode(npc_audio_bytes).decode('utf-8')
        }
        print(f"[{datetime.datetime.now()}] INFO: Successfully generated NPC response. Returning.")
        return JSONResponse(content=response_payload)

    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /generate-npc-response/ HTTPException: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /generate-npc-response/ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"An unexpected server error occurred: {str(e)}")
    finally:
        total_time = datetime.datetime.now() - request_time
        print(f"[{datetime.datetime.now()}] INFO: /generate-npc-response/ finished. Total time: {total_time}")

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

        transcribed_text = await stt_service.transcribe_audio(audio_content_stream)
        print(f"[{datetime.datetime.now()}] DEBUG: STT debug result: '{transcribed_text}'.")
        
        return {"file_path": str(abs_file_path), "transcription": transcribed_text}
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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 