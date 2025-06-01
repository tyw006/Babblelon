from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse
import uvicorn
import os
import io
import json
import base64
from dotenv import load_dotenv
from pathlib import Path

# Always load .env from the project root, regardless of where you run the script
project_root = Path(__file__).parent.parent.resolve()
load_dotenv(dotenv_path=project_root / ".env")

from services import stt_service, llm_service, tts_service

app = FastAPI()

# Ensure API keys are loaded (optional: add checks or raise specific errors)
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") # Assuming you use this name for Google GenAI

if not all([ELEVENLABS_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY]):
    # In a real app, you might want more specific error handling or logging
    print("Warning: One or more API keys are not set in environment variables.")

async def stream_conversation_data(audio_content_stream: io.BytesIO):
    try:
        # 1. STT - Transcribe the uploaded audio
        audio_content_stream.seek(0)
        
        transcribed_text = await stt_service.transcribe_audio(audio_content_stream)
        if not transcribed_text:
            # Yield an error message if STT fails
            error_message = {"type": "error", "payload": "STT failed to transcribe audio."}
            yield json.dumps(error_message) + "\n"
            return

        # Yield transcribed text
        transcription_event = {"type": "transcription", "payload": transcribed_text}
        yield json.dumps(transcription_event) + "\n"

        # 2. LLM - Get response based on transcribed text
        # TODO: Get npc_id and current_charm from the request in a real scenario
        current_npc_id = "amara" # Hardcoded for now
        current_charm = 50 # Hardcoded for now, frontend should manage and send this
        llm_input_text = f"Current Charm: {current_charm}\n{transcribed_text}"
        
        npc_response_data = await llm_service.get_llm_response(llm_input_text, npc_id=current_npc_id)
        if not npc_response_data or not npc_response_data.response_thai:
            error_message = {"type": "error", "payload": "LLM failed to generate a response."}
            yield json.dumps(error_message) + "\n"
            return

        # Yield NPC response object (as a dict for JSON serialization)
        # Pydantic models have a .model_dump() method (or .dict() in older Pydantic)
        npc_response_event = {"type": "npc_response", "payload": npc_response_data.model_dump()}
        yield json.dumps(npc_response_event) + "\n"

        # 3. TTS - Convert LLM's Thai response to speech and stream audio chunks
        text_to_speak = npc_response_data.response_thai
        
        async for audio_chunk in tts_service.text_to_speech_stream(text_to_speak):
            # Base64 encode the audio chunk for JSON compatibility
            encoded_chunk = base64.b64encode(audio_chunk).decode('utf-8')
            audio_chunk_event = {"type": "audio_chunk", "payload": encoded_chunk}
            yield json.dumps(audio_chunk_event) + "\n"
        
        # Signal end of audio stream
        stream_end_event = {"type": "audio_stream_end", "payload": "Audio streaming finished."}
        yield json.dumps(stream_end_event) + "\n"

    except HTTPException as e: # Catch specific HTTPExceptions from services
        error_message = {"type": "error", "payload": e.detail, "status_code": e.status_code}
        yield json.dumps(error_message) + "\n"
    except Exception as e:
        print(f"An unexpected error occurred in stream_conversation_data: {e}")
        error_message = {"type": "error", "payload": f"An unexpected server error occurred: {str(e)}"}
        yield json.dumps(error_message) + "\n"

@app.post("/process-audio/")
async def process_audio_flow(audio_file: UploadFile = File(...)):
    """
    Receives an audio file, transcribes it, gets an LLM response,
    converts LLM response to speech, and streams all data back as NDJSON.
    """
    # Read the file content immediately
    try:
        audio_bytes = await audio_file.read()
    finally:
        # It's good practice to explicitly close the UploadFile if you've read it,
        # though Starlette usually handles this.
        await audio_file.close()
            
    audio_content_stream = io.BytesIO(audio_bytes)
    
    return StreamingResponse(stream_conversation_data(audio_content_stream), media_type="application/x-ndjson")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 