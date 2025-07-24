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
from typing import Optional, Dict, List, Union
import logging

# --- Logging Configuration ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
# --- End Logging Configuration ---

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
from services.llm_service import get_llm_response, NPCResponse, regenerate_npc_vocabulary, process_item_giving
from services.stt_service import transcribe_audio_simple as transcribe_audio, transcribe_audio as transcribe_audio_advanced, STTResult, parallel_transcribe_audio
from services.translation_service import translate_text, romanize_target_text, synthesize_speech, create_word_level_translation_mapping, get_language_name, get_thai_writing_tips, get_drawable_vocabulary_items, generate_syllable_writing_guide, analyze_character_components, detect_complex_vowel_patterns, get_complex_vowel_info, generate_complex_vowel_explanation, translate_and_syllabify
from services.pronunciation_service import assess_pronunciation, PronunciationAssessmentResponse

app = FastAPI()

# Log server startup time
startup_time = datetime.datetime.now()
print(f"🚀 Backend server starting up at {startup_time.strftime('%Y-%m-%d %H:%M:%S')}")
logging.info(f"Backend server starting up at {startup_time.strftime('%Y-%m-%d %H:%M:%S')}")

# API keys will now be read by service modules using os.getenv AFTER load_dotenv has run.
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
AZURE_SPEECH_KEY = os.getenv("AZURE_SPEECH_KEY")
AZURE_SPEECH_REGION = os.getenv("AZURE_SPEECH_REGION")

if not ELEVENLABS_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: ELEVENLABS_API_KEY not set in environment for main.py.")
if not OPENAI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: OPENAI_API_KEY not set in environment for main.py.")
if not GEMINI_API_KEY:
    print(f"[{datetime.datetime.now()}] WARNING: GEMINI_API_KEY not set in environment for main.py (used by TTS service).")
if not AZURE_SPEECH_KEY or not AZURE_SPEECH_REGION:
    print(f"[{datetime.datetime.now()}] WARNING: AZURE_SPEECH_KEY or AZURE_SPEECH_REGION not set in environment for main.py (used by Pronunciation Assessment service).")

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

class WordComparisonData(BaseModel):
    """Word comparison data for frontend display"""
    word: str
    confidence: float
    expected: str = ""
    match_type: str  # "exact", "close", "partial", "missing", "extra", "no_reference"
    similarity: float
    start_time: float = 0.0
    end_time: float = 0.0

class TranscribeTranslateResponse(BaseModel):
    transcription: str
    translation: str
    romanization: str
    word_confidence: List[Dict[str, Union[str, float]]]  # Enhanced with transliteration and translation
    word_comparisons: List[WordComparisonData] = []      # Enhanced comparison data
    pronunciation_score: float
    expected_text: str = ""

class STTServiceResult(BaseModel):
    """Single STT service result for parallel comparison"""
    text: str
    word_confidence: List[Dict[str, Union[str, float]]]
    word_comparisons: List[WordComparisonData]
    processing_time: float
    service_used: str
    
class ParallelTranscriptionResponse(BaseModel):
    """Response model for parallel transcription comparison"""
    google: STTServiceResult
    elevenlabs: STTServiceResult
    expected_text: str = ""
    processing_summary: Dict[str, Union[str, float]]

class TranslationComparisonData(BaseModel):
    """Translation comparison for a transcription result"""
    transcription: str
    translation: str
    word_mappings: List[Dict[str, str]]
    confidence: float

class ParallelTranslationResponse(BaseModel):
    """Response model for parallel transcription + translation comparison"""
    google_transcription: STTServiceResult
    elevenlabs_transcription: STTServiceResult
    google_translation: TranslationComparisonData
    elevenlabs_translation: TranslationComparisonData
    expected_text: str = ""
    translation_accuracy_metrics: Dict[str, Union[str, float]]

# --- End Pydantic Models ---

# Voice mapping for NPCs
NPC_VOICE_MAP: Dict[str, str] = {
    "amara": "Sulafat",
    "somchai": "Charon",
    "default": "Puck" 
}

@app.get("/")
async def root():
    return {"message": "Welcome to the Babblelon Backend!"}

@app.post("/generate-npc-response/")
async def generate_npc_response_endpoint(
    audio_file: UploadFile = File(None),  # Made optional for item giving
    npc_id: str = Form(...),
    npc_name: str = Form(...),
    charm_level: int = Form(50),
    target_language: Optional[str] = Form("th"),  # Add target language parameter
    previous_conversation_history: Optional[str] = Form(""),
    custom_message: Optional[str] = Form(None),  # NEW: For item giving bypass STT
    action_type: Optional[str] = Form(""),        # NEW: "GIVE_ITEM" or ""
    action_item: Optional[str] = Form(""),        # NEW: Item name from traceable canvas
    quest_state_json: Optional[str] = Form("{}"), # NEW: Complete quest state
    use_enhanced_stt: Optional[bool] = Form(False) # NEW: Enable enhanced STT with word confidence
):
    print(f"[{datetime.datetime.now()}] INFO: /generate-npc-response/ received request for NPC: {npc_id}, Name: {npc_name}, Charm: {charm_level}, Language: {target_language}. Custom message: {custom_message is not None}, Action: {action_type}")
    
    try:
        # 1. Parse quest state from JSON
        quest_state = {}
        if quest_state_json and quest_state_json != "{}":
            try:
                quest_state = json.loads(quest_state_json)
                print(f"[{datetime.datetime.now()}] INFO: Quest state loaded for {npc_id}")
                print(f"[{datetime.datetime.now()}] DEBUG: Initial quest state: {quest_state}")
            except json.JSONDecodeError:
                print(f"[{datetime.datetime.now()}] WARNING: Invalid quest_state_json for {npc_id}")
                quest_state = {}
        else:
            print(f"[{datetime.datetime.now()}] DEBUG: No quest state provided, will initialize fresh quest")
        
        # 2. Handle STT or Custom Message
        word_confidence_data = []  # Initialize for enhanced STT
        pronunciation_score = 0.0  # Initialize for enhanced STT
        
        if custom_message:
            # Item giving: Skip STT, use custom message directly
            latest_player_message = custom_message
            player_transcription = custom_message  # For response consistency
            print(f"[{datetime.datetime.now()}] INFO: Using custom message for {npc_id}: '{custom_message}'")
        else:
            # Normal conversation: STT - Transcribe player's audio
            if not audio_file:
                raise HTTPException(status_code=400, detail="Either audio_file or custom_message must be provided.")
                
            player_audio_bytes = await audio_file.read()
            await audio_file.close()
            if not player_audio_bytes:
                raise HTTPException(status_code=400, detail="Uploaded audio file is empty.")
            
            player_audio_stream = io.BytesIO(player_audio_bytes)
            
            if use_enhanced_stt:
                # Enhanced STT with word-level confidence using Chirp2 model
                print(f"[{datetime.datetime.now()}] DEBUG: Using enhanced STT with word confidence for {npc_id}")
                stt_result: STTResult = await transcribe_audio_advanced(player_audio_stream, language_code=target_language)
                player_transcription = stt_result.text
                word_confidence_data = stt_result.word_confidence
                
                # Calculate pronunciation score
                if word_confidence_data:
                    confidence_scores = [word["confidence"] for word in word_confidence_data]
                    pronunciation_score = sum(confidence_scores) / len(confidence_scores)
                
                print(f"[{datetime.datetime.now()}] INFO: Enhanced STT for {npc_id} successful. Transcription: '{player_transcription}', Pronunciation Score: {pronunciation_score:.3f}")
                print(f"[{datetime.datetime.now()}] DEBUG: Enhanced STT Details - Audio bytes: {len(player_audio_bytes)}, Language: {target_language}, Words with confidence: {len(word_confidence_data)}")
            else:
                # Standard STT (backward compatibility)
                print(f"[{datetime.datetime.now()}] DEBUG: Using standard STT for {npc_id}")
                player_transcription = await transcribe_audio(player_audio_stream, language_code=target_language)
                print(f"[{datetime.datetime.now()}] INFO: Standard STT for {npc_id} successful. Transcription: '{player_transcription}'")
                print(f"[{datetime.datetime.now()}] DEBUG: Standard STT Details - Audio bytes: {len(player_audio_bytes)}, Language: {target_language}, Transcribed: '{player_transcription}'")
            
            latest_player_message = player_transcription if player_transcription and player_transcription.strip() else ""

        # 3. Prepare conversation history and latest message for LLM
        conversation_history = previous_conversation_history if previous_conversation_history else ""
        
        if not latest_player_message and not action_type:
            raise HTTPException(status_code=400, detail="Player message is empty or invalid.")

        # 4. LLM - Get NPC's response with quest parameters
        npc_response_data: NPCResponse = await get_llm_response(
            npc_id=npc_id, 
            npc_name=npc_name,
            conversation_history=conversation_history,
            latest_player_message=latest_player_message,
            current_charm_level=charm_level,
            target_language=target_language,
            quest_state=quest_state,
            action_type=action_type,
            action_item=action_item
        )
        print(f"[{datetime.datetime.now()}] INFO: LLM response for {npc_id} OK. Target: '{npc_response_data.response_target[:30]}...', Tone: '{npc_response_data.response_tone}'")

        # 4a. Process item giving and update quest state (following notebook pattern)
        # BACKEND ENFORCEMENT: Only process items with valid GIVE_ITEM action (matches notebook)
        valid_item_action = (action_type == "GIVE_ITEM" and action_item.strip() != "")
        print(f"[{datetime.datetime.now()}] DEBUG: Action validation - action_type='{action_type}', item='{action_item}', valid_item_action={valid_item_action}")
        
        updated_quest_state = quest_state  # Default to original state
        if quest_state and valid_item_action:
            # Update quest state with item giving results (following notebook pattern)
            print(f"[{datetime.datetime.now()}] DEBUG: Processing item giving for valid action")
            updated_quest_state = process_item_giving(npc_response_data, quest_state)
            quest_complete = updated_quest_state.get('quest_state', {}).get('scenario_complete', False)
            print(f"[{datetime.datetime.now()}] DEBUG: Quest state updated after item giving. Complete: {quest_complete}")
            print(f"[{datetime.datetime.now()}] DEBUG: Updated quest state: {updated_quest_state}")
        else:
            # Regular conversation or invalid action - no quest processing (following notebook pattern)
            if quest_state:
                print(f"[{datetime.datetime.now()}] DEBUG: Regular conversation or invalid item action, no quest processing needed")
            else:
                print(f"[{datetime.datetime.now()}] DEBUG: No quest state provided, skipping quest processing")

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
            "charm_reason": npc_response_data.charm_reason,
            "player_transcription_raw": player_transcription,
            # NEW: Enhanced STT fields
            "word_confidence": word_confidence_data,
            "pronunciation_score": pronunciation_score,
            "enhanced_stt_used": use_enhanced_stt,
            # NEW: Quest-related fields
            "user_item_given": npc_response_data.user_item_given,
            "user_item_accepted": npc_response_data.user_item_accepted,
            "item_category": npc_response_data.item_category,
            # NEW: Action validation (matching notebook pattern)
            "valid_item_action": valid_item_action,
            "action_type_received": action_type,
            "action_item_received": action_item,
            # NEW: Updated quest state for frontend
            "updated_quest_state": updated_quest_state if updated_quest_state else {},
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
async def transcribe_audio_endpoint(
    audio_file: UploadFile = File(...),
    language_code: Optional[str] = Form("tha")
):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /transcribe-audio/ endpoint hit. File: {audio_file.filename}, Language: {language_code}")
    audio_bytes = await audio_file.read()
    await audio_file.close()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio file content is empty.")

    audio_content_stream = io.BytesIO(audio_bytes)
    try:
        transcription = await transcribe_audio(audio_content_stream, language_code=language_code)
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

# --- New STT + Translation Endpoint ---
@app.post("/transcribe-and-translate/", response_model=TranscribeTranslateResponse)
async def transcribe_and_translate_endpoint(
    audio_file: UploadFile = File(...),
    source_language: Optional[str] = Form("tha"),  # Language of audio
    target_language: Optional[str] = Form("en"),   # Language to translate to
    expected_text: Optional[str] = Form("")        # Expected text for comparison
):
    """
    Combined STT + Translation endpoint with word-level confidence for user verification.
    Uses Google Cloud STT (Chirp2 model) + Google Cloud Translation.
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /transcribe-and-translate/ endpoint hit. File: {audio_file.filename}, Source: {source_language}, Target: {target_language}")
    
    try:
        # Read audio file
        audio_bytes = await audio_file.read()
        await audio_file.close()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file content is empty.")

        audio_content_stream = io.BytesIO(audio_bytes)
        
        # Step 1: STT with word-level confidence using Chirp2 model and expected text comparison
        print(f"[{datetime.datetime.now()}] DEBUG: Starting advanced STT with word confidence and expected text comparison...")
        print(f"[{datetime.datetime.now()}] DEBUG: Expected text for comparison: '{expected_text}'")
        stt_result: STTResult = await transcribe_audio_advanced(audio_content_stream, language_code=source_language, expected_text=expected_text or "")
        
        if not stt_result.text.strip():
            print(f"[{datetime.datetime.now()}] WARNING: STT returned empty transcription")
            return TranscribeTranslateResponse(
                transcription="",
                translation="",
                romanization="",
                word_confidence=[],
                word_comparisons=[],
                pronunciation_score=0.0,
                expected_text=expected_text or ""
            )
        
        print(f"[{datetime.datetime.now()}] INFO: STT successful. Transcription: '{stt_result.text}'")
        print(f"[{datetime.datetime.now()}] DEBUG: Word confidence data: {len(stt_result.word_confidence)} words")
        
        # Step 2: Translation
        print(f"[{datetime.datetime.now()}] DEBUG: Starting translation...")
        print(f"[{datetime.datetime.now()}] DEBUG: Input text for translation: '{stt_result.text}'")
        print(f"[{datetime.datetime.now()}] DEBUG: Translation direction: {source_language} -> {target_language}")
        translation_result = await translate_text(stt_result.text, source_language, target_language)
        print(f"[{datetime.datetime.now()}] DEBUG: Raw translation result: {translation_result}")
        print(f"[{datetime.datetime.now()}] DEBUG: Extracted translated_text: '{translation_result.get('translated_text', '')}')")
        
        # Step 3: Romanization (if source is Thai)
        romanization = ""
        if source_language in ["tha", "th"]:
            print(f"[{datetime.datetime.now()}] DEBUG: Generating romanization for Thai text...")
            romanization_result = await romanize_target_text(stt_result.text, source_language)
            romanization = romanization_result.get("romanized_text", "")
        
        # Step 4: Enhance word confidence with transliteration and translation
        enhanced_word_confidence = []
        if stt_result.word_confidence:
            # Extract just the words for parallel processing
            words_to_process = [word["word"] for word in stt_result.word_confidence]
            
            # Create parallel tasks for romanization and translation
            tasks = []
            
            # Add romanization tasks if source is Thai
            if source_language in ["tha", "th"] and words_to_process:
                romanization_tasks = [
                    romanize_target_text(word, source_language) for word in words_to_process
                ]
                tasks.extend(romanization_tasks)
            
            # Add translation tasks for each word
            if words_to_process:
                translation_tasks = [
                    translate_text(word, source_language, target_language) for word in words_to_process
                ]
                if source_language in ["tha", "th"]:
                    tasks.extend(translation_tasks)
                else:
                    tasks = translation_tasks
            
            # Execute all tasks in parallel
            if tasks:
                import asyncio
                results = await asyncio.gather(*tasks, return_exceptions=True)
                
                # Process results
                num_words = len(words_to_process)
                romanization_results = []
                translation_results = []
                
                if source_language in ["tha", "th"]:
                    # First half are romanization results, second half are translation results
                    romanization_results = results[:num_words]
                    translation_results = results[num_words:] if len(results) > num_words else []
                else:
                    # All results are translation results
                    translation_results = results[:num_words]
                
                # Build enhanced word confidence
                for i, original_word_data in enumerate(stt_result.word_confidence):
                    enhanced_word = dict(original_word_data)  # Copy original data
                    
                    # Add transliteration if available
                    if i < len(romanization_results) and not isinstance(romanization_results[i], Exception):
                        enhanced_word["transliteration"] = romanization_results[i].get("romanized_text", "")
                    else:
                        enhanced_word["transliteration"] = ""
                    
                    # Add translation if available
                    if i < len(translation_results) and not isinstance(translation_results[i], Exception):
                        enhanced_word["translation"] = translation_results[i].get("translated_text", "")
                    else:
                        enhanced_word["translation"] = ""
                    
                    enhanced_word_confidence.append(enhanced_word)
            else:
                # No parallel processing needed, just copy original data with empty fields
                for word_data in stt_result.word_confidence:
                    enhanced_word = dict(word_data)
                    enhanced_word["transliteration"] = ""
                    enhanced_word["translation"] = ""
                    enhanced_word_confidence.append(enhanced_word)
        
        # Step 5: Calculate pronunciation score based on word confidence
        pronunciation_score = 0.0
        if enhanced_word_confidence:
            confidence_scores = [word["confidence"] for word in enhanced_word_confidence]
            pronunciation_score = sum(confidence_scores) / len(confidence_scores)
        
        print(f"[{datetime.datetime.now()}] INFO: Translation successful. Result: '{translation_result}'")
        print(f"[{datetime.datetime.now()}] INFO: Pronunciation score: {pronunciation_score:.3f}")
        print(f"[{datetime.datetime.now()}] DEBUG: Word comparisons: {len(stt_result.word_comparisons)} comparisons")
        
        # Convert word comparisons to response format
        word_comparison_data = [
            WordComparisonData(
                word=comp.word,
                confidence=comp.confidence,
                expected=comp.expected,
                match_type=comp.match_type,
                similarity=comp.similarity,
                start_time=comp.start_time,
                end_time=comp.end_time
            )
            for comp in stt_result.word_comparisons
        ]
        
        return TranscribeTranslateResponse(
            transcription=stt_result.text,
            translation=translation_result.get("translated_text", ""),
            romanization=romanization,
            word_confidence=enhanced_word_confidence,
            word_comparisons=word_comparison_data,
            pronunciation_score=pronunciation_score,
            expected_text=expected_text or ""
        )
        
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /transcribe-and-translate/ HTTPException: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /transcribe-and-translate/ Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=f"Unexpected error in transcribe-and-translate: {str(e)}")
    finally:
        total_time = datetime.datetime.now() - request_time
        print(f"[{datetime.datetime.now()}] INFO: /transcribe-and-translate/ finished. Total time: {total_time}")

# --- Parallel Transcription Comparison Endpoint ---
@app.post("/parallel-transcribe/", response_model=ParallelTranscriptionResponse)
async def parallel_transcribe_endpoint(
    audio_file: UploadFile = File(...),
    language_code: Optional[str] = Form("tha"),
    expected_text: Optional[str] = Form("")
):
    """
    Parallel transcription endpoint that processes audio through both Google Cloud STT and ElevenLabs Scribe
    for accuracy comparison and testing.
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /parallel-transcribe/ endpoint hit. File: {audio_file.filename}, Language: {language_code}")
    
    try:
        # Read audio file
        audio_bytes = await audio_file.read()
        await audio_file.close()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file content is empty.")
        
        audio_content_stream = io.BytesIO(audio_bytes)
        
        # Process through both STT services in parallel
        print(f"[{datetime.datetime.now()}] DEBUG: Starting parallel transcription processing...")
        parallel_results = await parallel_transcribe_audio(audio_content_stream, language_code, expected_text)
        
        # Convert STTResult objects to response format
        def convert_stt_result(stt_result: STTResult) -> STTServiceResult:
            word_comparisons_data = [
                WordComparisonData(
                    word=wc.word,
                    confidence=wc.confidence,
                    expected=wc.expected,
                    match_type=wc.match_type,
                    similarity=wc.similarity,
                    start_time=wc.start_time,
                    end_time=wc.end_time
                ) for wc in stt_result.word_comparisons
            ]
            
            return STTServiceResult(
                text=stt_result.text,
                word_confidence=stt_result.word_confidence,
                word_comparisons=word_comparisons_data,
                processing_time=stt_result.processing_time,
                service_used=stt_result.service_used
            )
        
        google_result = convert_stt_result(parallel_results["google"])
        elevenlabs_result = convert_stt_result(parallel_results["elevenlabs"])
        
        # Create processing summary
        processing_summary = {
            "total_processing_time": datetime.datetime.now() - request_time,
            "google_processing_time": google_result.processing_time,
            "elevenlabs_processing_time": elevenlabs_result.processing_time,
            "google_success": bool(google_result.text.strip()),
            "elevenlabs_success": bool(elevenlabs_result.text.strip()),
            "text_match": google_result.text.strip() == elevenlabs_result.text.strip(),
            "google_word_count": len(google_result.word_confidence),
            "elevenlabs_word_count": len(elevenlabs_result.word_confidence)
        }
        
        print(f"[{datetime.datetime.now()}] INFO: Parallel transcription completed.")
        print(f"[{datetime.datetime.now()}] DEBUG: Google result: '{google_result.text}'")
        print(f"[{datetime.datetime.now()}] DEBUG: ElevenLabs result: '{elevenlabs_result.text}'")
        
        return ParallelTranscriptionResponse(
            google=google_result,
            elevenlabs=elevenlabs_result,
            expected_text=expected_text,
            processing_summary=processing_summary
        )
        
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /parallel-transcribe/ HTTPException: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /parallel-transcribe/ Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=f"Unexpected parallel transcription error: {str(e)}")
    finally:
        total_time = datetime.datetime.now() - request_time
        print(f"[{datetime.datetime.now()}] INFO: /parallel-transcribe/ finished. Total time: {total_time}")

@app.post("/parallel-transcribe-translate/", response_model=ParallelTranslationResponse)
async def parallel_transcribe_translate_endpoint(
    audio_file: UploadFile = File(...),
    source_language: Optional[str] = Form("tha"),
    target_language: Optional[str] = Form("en"),
    expected_text: Optional[str] = Form("")
):
    """
    Enhanced parallel processing endpoint that performs both transcription comparison
    and translation comparison using both Google Cloud STT and ElevenLabs Scribe.
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /parallel-transcribe-translate/ endpoint hit. File: {audio_file.filename}")
    
    try:
        # Read audio file
        audio_bytes = await audio_file.read()
        await audio_file.close()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file content is empty.")
        
        audio_content_stream = io.BytesIO(audio_bytes)
        
        # Step 1: Parallel transcription
        print(f"[{datetime.datetime.now()}] DEBUG: Starting parallel transcription...")
        parallel_results = await parallel_transcribe_audio(audio_content_stream, source_language, expected_text)
        
        # Convert STTResult objects to response format
        def convert_stt_result(stt_result: STTResult) -> STTServiceResult:
            word_comparisons_data = [
                WordComparisonData(
                    word=wc.word,
                    confidence=wc.confidence,
                    expected_word=wc.expected_word,
                    accuracy_score=wc.accuracy_score
                ) for wc in stt_result.word_comparisons
            ]
            return STTServiceResult(
                transcription=stt_result.transcription,
                confidence=stt_result.confidence,
                word_comparisons=word_comparisons_data,
                processing_time=stt_result.processing_time,
                service_used=stt_result.service_used
            )
        
        google_stt = convert_stt_result(parallel_results["google"])
        elevenlabs_stt = convert_stt_result(parallel_results["elevenlabs"])
        
        # Step 2: Parallel translation of both transcriptions
        print(f"[{datetime.datetime.now()}] DEBUG: Starting parallel translation...")
        
        async def translate_transcription(transcription: str, service_name: str) -> TranslationComparisonData:
            if not transcription.strip():
                return TranslationComparisonData(
                    transcription=transcription,
                    translation="",
                    word_mappings=[],
                    confidence=0.0
                )
            
            # Use the translation service
            translation_result = await translate_and_syllabify(transcription, target_language)
            translated_text = ' '.join([mapping['target'] for mapping in translation_result['word_mappings']])
            
            # Calculate confidence based on transcription confidence
            stt_confidence = google_stt.confidence if service_name == "google" else elevenlabs_stt.confidence
            
            return TranslationComparisonData(
                transcription=transcription,
                translation=translated_text,
                word_mappings=translation_result['word_mappings'],
                confidence=stt_confidence
            )
        
        # Translate both transcriptions
        google_translation = await translate_transcription(google_stt.transcription, "google")
        elevenlabs_translation = await translate_transcription(elevenlabs_stt.transcription, "elevenlabs")
        
        # Step 3: Calculate translation accuracy metrics
        accuracy_metrics = {
            "google_transcription_confidence": google_stt.confidence,
            "elevenlabs_transcription_confidence": elevenlabs_stt.confidence,
            "google_translation_word_count": len(google_translation.word_mappings),
            "elevenlabs_translation_word_count": len(elevenlabs_translation.word_mappings),
            "transcription_similarity": _calculate_similarity(google_stt.transcription, elevenlabs_stt.transcription),
            "translation_similarity": _calculate_similarity(google_translation.translation, elevenlabs_translation.translation),
            "processing_time": (datetime.datetime.now() - request_time).total_seconds()
        }
        
        response = ParallelTranslationResponse(
            google_transcription=google_stt,
            elevenlabs_transcription=elevenlabs_stt,
            google_translation=google_translation,
            elevenlabs_translation=elevenlabs_translation,
            expected_text=expected_text or "",
            translation_accuracy_metrics=accuracy_metrics
        )
        
        print(f"[{datetime.datetime.now()}] INFO: Parallel transcribe-translate successful")
        return response
        
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /parallel-transcribe-translate/ HTTPException: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /parallel-transcribe-translate/ Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=f"Unexpected parallel transcribe-translate error: {str(e)}")
    finally:
        total_time = datetime.datetime.now() - request_time
        print(f"[{datetime.datetime.now()}] INFO: /parallel-transcribe-translate/ finished. Total time: {total_time}")

def _calculate_similarity(text1: str, text2: str) -> float:
    """Simple similarity calculation between two texts"""
    if not text1 or not text2:
        return 0.0
    
    words1 = set(text1.lower().split())
    words2 = set(text2.lower().split())
    
    if not words1 and not words2:
        return 1.0
    
    intersection = words1.intersection(words2)
    union = words1.union(words2)
    
    return len(intersection) / len(union) if union else 0.0

# --- Google Cloud Translation and TTS Endpoint ---
@app.post("/gcloud-translate-tts/", response_model=GoogleTranslationResponse)
async def gcloud_translate_tts_endpoint(request: TranslationRequest):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /gcloud-translate-tts/ received request for text: '{request.english_text[:50]}...' in {request.target_language}")
    try:
        # Use the new translate_and_syllabify function for better compound word handling
        syllable_result = await translate_and_syllabify(request.english_text, request.target_language)
        
        # Extract target text from word mappings
        target_text = ' '.join([mapping['target'] for mapping in syllable_result['word_mappings']])
        
        # Generate audio for the full target text
        audio_result = await synthesize_speech(target_text, request.target_language)
        
        # Build response in the expected format
        response_payload = {
            "english_text": request.english_text,
            "target_text": target_text,
            "translated_text": target_text,  # Add this field for frontend compatibility
            "romanized_text": ' '.join([mapping['transliteration'] for mapping in syllable_result['word_mappings']]),
            "transliteration": ' '.join([mapping['transliteration'] for mapping in syllable_result['word_mappings']]),  # Add this field for frontend compatibility
            "audio_base64": audio_result.get("audio_base64", ""),
            "word_mappings": syllable_result['word_mappings'],
            "target_language_name": get_language_name(request.target_language)
        }
        
        return JSONResponse(content=response_payload)
    except HTTPException as e:
        # Re-raise HTTPException to let FastAPI handle it
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /gcloud-translate-tts/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- Pronunciation Assessment Endpoint ---
@app.post("/pronunciation/assess/", response_model=PronunciationAssessmentResponse)
async def pronunciation_assessment_endpoint(
    audio_file: UploadFile = File(...),
    reference_text: str = Form(...),
    transliteration: str = Form(...),
    complexity: int = Form(...),
    item_type: str = Form(...),
    turn_type: str = Form(...), # 'attack' or 'defense'
    was_revealed: bool = Form(False), # Whether the flashcard was revealed before assessment
    azure_pron_mapping_json: str = Form('[]'), # Receive azure pronunciation mapping as a JSON string
    language: str = Form("th-TH")
):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /pronunciation/assess/ received request for text: '{reference_text}' in {language}, revealed: {was_revealed}")
    
    try:
        # Parse the azure_pron_mapping from the JSON string
        try:
            azure_pron_mapping = json.loads(azure_pron_mapping_json)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid format for azure_pron_mapping_json.")

        audio_bytes = await audio_file.read()
        await audio_file.close()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file content is empty.")

        assessment_result = await assess_pronunciation(
            audio_bytes=audio_bytes,
            reference_text=reference_text,
            transliteration=transliteration,
            complexity=complexity,
            item_type=item_type,
            turn_type=turn_type,
            was_revealed=was_revealed,
            azure_pron_mapping=azure_pron_mapping, # Pass the parsed list
            language=language
        )
        
        print(f"[{datetime.datetime.now()}] INFO: /pronunciation/assess/ successful for '{reference_text}'. Rating: {assessment_result.rating}")
        return assessment_result

    except HTTPException as e:
        # Re-raise HTTPException to let FastAPI handle it
        print(f"[{datetime.datetime.now()}] ERROR: in /pronunciation/assess/: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: Unhandled exception in /pronunciation/assess/: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during pronunciation assessment: {str(e)}")

# --- Thai Character Tracing Endpoints ---

@app.get("/thai-writing-tips/{character}")
async def get_writing_tips_endpoint(
    character: str,
    target_language: str = Query("th", description="Target language code"),
    context_word: Optional[str] = Query(None, description="Word context for contextual tips"),
    position_in_word: Optional[int] = Query(None, description="Position of character in word")
):
    """Get writing tips for a specific Thai character with optional context."""
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /thai-writing-tips/ received request for character: '{character}' in {target_language}")
    if context_word:
        print(f"[{request_time}] INFO: Context provided - word: '{context_word}', position: {position_in_word}")
    try:
        tips = await get_thai_writing_tips(
            character, 
            target_language, 
            context_word=context_word, 
            position_in_word=position_in_word or 0
        )
        return JSONResponse(content=tips)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /thai-writing-tips/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/drawable-vocabulary/")
async def get_drawable_vocabulary_endpoint(
    target_language: str = Query("th", description="Target language code")
):
    """Get vocabulary items that can be drawn as characters."""
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /drawable-vocabulary/ received request for language: {target_language}")
    try:
        vocab_items = await get_drawable_vocabulary_items(target_language)
        return JSONResponse(content=vocab_items)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /drawable-vocabulary/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/character-analysis/{character}")
async def get_character_analysis_endpoint(
    character: str,
    target_language: str = Query("th", description="Target language code")
):
    """Analyze the components of a character for tracing guidance."""
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /character-analysis/ received request for character: '{character}' in {target_language}")
    try:
        analysis = await analyze_character_components(character, target_language)
        return JSONResponse(content=analysis)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /character-analysis/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Removed redundant filter-drawable-items endpoint 
# All vocabulary items should be drawable in a language learning context

class SynthesizeSpeechRequest(BaseModel):
    text: str
    target_language: str = "th"
    custom_voice: Optional[str] = None

@app.post("/synthesize-speech/")
async def synthesize_speech_endpoint(request: SynthesizeSpeechRequest):
    """Synthesize speech from text for character audio playback."""
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /synthesize-speech/ received request for text: '{request.text}' in {request.target_language}")
    try:
        # Use the existing synthesize_speech function from translation_service
        audio_result = await synthesize_speech(
            text=request.text,
            target_language=request.target_language,
            custom_voice=request.custom_voice
        )
        
        print(f"[{datetime.datetime.now()}] INFO: /synthesize-speech/ successful for '{request.text}'. Audio generated: {bool(audio_result.get('audio_base64'))}")
        return JSONResponse(content=audio_result)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /synthesize-speech/: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Speech synthesis error: {str(e)}")

# --- NEW SYLLABLE-BASED WRITING GUIDE ENDPOINT ---

class WritingGuideRequest(BaseModel):
    word: str
    target_language: str = "th"

@app.post("/generate-writing-guide")
async def generate_writing_guide_endpoint(request: WritingGuideRequest):
    """
    Generate comprehensive writing guide for Thai words using syllable-based analysis.
    Uses PyThaiNLP TCC engine to break words into syllables and provide ordered writing tips.
    
    Process:
    1. Break word into syllables using TCC engine
    2. Parse each syllable into grammatical components  
    3. Assemble tips in correct Thai writing order
    4. Return structured data for frontend consumption
    
    Returns syllable-by-syllable writing guidance with:
    - Component analysis (before_vowels, consonants, clusters, etc.)
    - Step-by-step writing instructions
    - Pronunciation guidance
    - Traceable canvas splitting by syllable
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /generate-writing-guide endpoint hit for word: '{request.word}' in {request.target_language}")
    
    try:
        # Add timeout to prevent hanging requests
        import asyncio
        guide_result = await asyncio.wait_for(
            generate_syllable_writing_guide(request.word, request.target_language),
            timeout=15.0  # 15 second timeout for syllable processing
        )
        
        print(f"[{datetime.datetime.now()}] DEBUG: Syllable writing guide result: {guide_result}")
        return JSONResponse(content=guide_result)
        
    except asyncio.TimeoutError:
        print(f"[{datetime.datetime.now()}] ERROR: Syllable writing guide timeout for: '{request.word}'")
        raise HTTPException(status_code=408, detail=f"Request timeout while processing word: {request.word}")
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Syllable writing guide failed: {e}")
        # Return fallback result
        return JSONResponse(content={
            "word": request.word,
            "error": str(e),
            "fallback": True,
            "syllables": [],
            "traceable_canvases": [request.word]  # Fallback to whole word
        })

@app.post("/regenerate-npc-vocabulary/")
async def regenerate_npc_vocabulary_endpoint(
    npc_id: str = Form(...),
):
    """Regenerate vocabulary selection for an NPC. Useful for testing different vocabulary combinations."""
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /regenerate-npc-vocabulary/ received request for NPC: {npc_id}")
    
    try:
        selected_vocab = regenerate_npc_vocabulary(npc_id)
        
        if not selected_vocab:
            raise HTTPException(status_code=404, detail=f"No vocabulary found for NPC '{npc_id}'")
        
        # Format response with category info
        categories_info = {}
        for category, item in selected_vocab.items():
            categories_info[category] = {
                "english": item["english"],
                "thai": item["thai"], 
                "transliteration": item["transliteration"],
                "category": item["category"]
            }
        
        return JSONResponse(content={
            "npc_id": npc_id,
            "total_categories": len(selected_vocab),
            "vocabulary": categories_info,
            "message": f"Successfully regenerated vocabulary for {npc_id}"
        })
        
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /regenerate-npc-vocabulary/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- COMPLEX VOWEL ANALYSIS ENDPOINT ---

class ComplexVowelAnalysisRequest(BaseModel):
    word: str
    target_language: str = "th"

@app.post("/analyze-complex-vowels/")
async def analyze_complex_vowels_endpoint(request: ComplexVowelAnalysisRequest):
    """
    Analyze complex vowel patterns in Thai words.
    
    Detects patterns like เ◌ือ (sara uea), เ◌า (sara ao), etc. and provides:
    - Pattern identification and components
    - Educational explanations about reading order
    - Component breakdown and positions
    - Pronunciation guidance
    
    Returns comprehensive data for educational vowel pattern display.
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /analyze-complex-vowels/ received request for word: '{request.word}' in {request.target_language}")
    
    try:
        if request.target_language.lower() != "th":
            raise HTTPException(status_code=400, detail=f"Complex vowel analysis only supported for Thai (th), not {request.target_language}")
        
        # Detect complex vowel patterns
        complex_vowels = detect_complex_vowel_patterns(request.word)
        
        result = {
            "word": request.word,
            "target_language": request.target_language,
            "complex_vowels_detected": len(complex_vowels),
            "patterns": []
        }
        
        # Build detailed information for each detected pattern
        for vowel_pattern in complex_vowels:
            pattern_info = {
                "pattern_key": vowel_pattern.pattern_key,
                "name": vowel_pattern.name,
                "components": vowel_pattern.components,
                "component_positions": vowel_pattern.positions,
                "consonant_position": vowel_pattern.consonant_pos,
                "romanization": vowel_pattern.romanization,
                "reading_explanation": vowel_pattern.reading_explanation,
                "component_explanation": vowel_pattern.component_explanation,
                "educational_content": generate_complex_vowel_explanation(request.word, vowel_pattern)
            }
            result["patterns"].append(pattern_info)
        
        # Add character-by-character analysis with complex vowel context
        character_analysis = []
        for i, char in enumerate(request.word):
            char_info = {
                "character": char,
                "position": i,
                "complex_vowel_info": None
            }
            
            # Check if this character is part of a complex vowel
            complex_vowel_info = get_complex_vowel_info(request.word, i)
            if complex_vowel_info:
                char_info["complex_vowel_info"] = {
                    "pattern": complex_vowel_info.pattern_key,
                    "name": complex_vowel_info.name,
                    "role": "consonant" if i == complex_vowel_info.consonant_pos else "vowel_component",
                    "full_pronunciation": complex_vowel_info.romanization
                }
            
            character_analysis.append(char_info)
        
        result["character_analysis"] = character_analysis
        
        print(f"[{datetime.datetime.now()}] INFO: /analyze-complex-vowels/ successful for '{request.word}'. Found {len(complex_vowels)} complex patterns")
        return JSONResponse(content=result)
        
    except HTTPException as e:
        # Re-raise HTTPException to let FastAPI handle it
        print(f"[{datetime.datetime.now()}] ERROR: in /analyze-complex-vowels/: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: Unhandled exception in /analyze-complex-vowels/: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during complex vowel analysis: {str(e)}")

if __name__ == "__main__":
    # Changed host from "127.0.0.1" to "0.0.0.0" to allow connections
    # from the Android emulator and other devices on the local network.
    uvicorn.run(app, host="0.0.0.0", port=8000) 