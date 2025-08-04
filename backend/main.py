from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Query, Request
from fastapi.responses import StreamingResponse, JSONResponse, Response
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
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

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

# --- Initialize Sentry (BEFORE creating FastAPI app) ---
SENTRY_DSN = os.getenv("SENTRY_DSN")
if SENTRY_DSN:
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[
            StarletteIntegration(transaction_style="endpoint"),
            FastApiIntegration(transaction_style="endpoint"),
        ],
        traces_sample_rate=1.0,  # Adjust in production (e.g., 0.1 for 10%)
        send_default_pii=True,
        environment="development",  # Change to "production" when deploying
    )
    print("✅ Sentry initialized for error tracking and performance monitoring")
else:
    print("⚠️ Sentry DSN not found, skipping Sentry initialization")
# --- End Sentry initialization ---

from services.tts_service import text_to_speech_full
from services.llm_service import get_llm_response, NPCResponse, regenerate_npc_vocabulary, process_item_giving
from services.stt_service import transcribe_audio_simple as transcribe_audio, transcribe_audio as transcribe_audio_advanced, STTResult, parallel_transcribe_audio, transcribe_audio_elevenlabs
from services.translation_service import translate_text, romanize_target_text, synthesize_speech, create_word_level_translation_mapping, get_language_name, get_thai_writing_tips, get_drawable_vocabulary_items, generate_syllable_writing_guide, analyze_character_components, detect_complex_vowel_patterns, get_complex_vowel_info, generate_complex_vowel_explanation, translate_and_syllabify, translate_with_deepl, translate_and_syllabify_deepl, translate_and_syllabify_enhanced
from services.pronunciation_service import assess_pronunciation, PronunciationAssessmentResponse
from services.azure_speech_tracker import get_azure_speech_tracker
from services.openai_whisper_service import transcribe_audio_openai, translate_audio_openai, OpenAIWhisperResult
from services.latency_tracker import LatencyTracker, timing_context, DEFAULT_HIGH_LATENCY_THRESHOLD
from utils.device_detection import detect_device, get_platform_string, get_mobile_optimized_headers

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
    """Single STT service result for parallel comparison with enhanced metrics"""
    service_name: str
    transcription: str
    english_translation: str
    processing_time: float
    confidence_score: float
    audio_duration: float
    real_time_factor: float
    word_count: int
    accuracy_score: float
    status: str
    error: Optional[str] = None
    
class ThreeWayTranscriptionResponse(BaseModel):
    """Response model for three-way transcription comparison"""
    google_chirp2: STTServiceResult
    assemblyai_universal: STTServiceResult
    speechmatics_ursa: STTServiceResult
    expected_text: str = ""
    processing_summary: Dict[str, Union[str, float]]
    winner_service: str
    performance_analysis: Dict[str, float]

class ParallelTranscriptionResponse(BaseModel):
    """Response model for parallel transcription comparison (legacy two-way)"""
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
    google_result: STTServiceResult
    elevenlabs_result: STTServiceResult
    winner_service: str
    audio_duration: float
    status: str
    error: Optional[str] = None

# --- End Pydantic Models ---

# Voice mapping for NPCs
NPC_VOICE_MAP: Dict[str, str] = {
    "amara": "Sulafat",
    "somchai": "Charon",
    "default": "Puck" 
}

@app.on_event("startup")
async def startup_event():
    """Log all service configurations at startup"""
    import os
    print("\n" + "="*80)
    print("🚀 BABBLELON BACKEND STARTUP - SERVICE CONFIGURATION")
    print("="*80)
    
    # Check API Keys
    services_status = {
        'OpenAI': bool(os.getenv('OPENAI_API_KEY')),
        'Gemini': bool(os.getenv('GEMINI_API_KEY')),
        'Helicone': bool(os.getenv('HELICONE_API_KEY')),
        'PostHog': bool(os.getenv('POSTHOG_API_KEY')),
        'Sentry': bool(os.getenv('SENTRY_DSN')),
        'Supabase': bool(os.getenv('SUPABASE_URL')) and bool(os.getenv('SUPABASE_ANON_KEY'))
    }
    
    print("🔑 API Key Configuration:")
    for service, configured in services_status.items():
        status = "✅ Configured" if configured else "❌ Missing"
        print(f"  {service}: {status}")
    
    print("\n📊 Tracking & Monitoring:")
    if services_status['Helicone'] and services_status['OpenAI']:
        print("  ✅ OpenAI + Helicone: LLM cost tracking enabled")
    else:
        print("  ❌ OpenAI + Helicone: LLM cost tracking disabled")
        
    if services_status['Helicone'] and services_status['Gemini']:
        print("  ✅ Gemini + Helicone: TTS cost tracking enabled")
    else:
        print("  ❌ Gemini + Helicone: TTS cost tracking disabled")
        
    if services_status['PostHog']:
        print("  ✅ PostHog: Event analytics enabled")
    else:
        print("  ❌ PostHog: Event analytics disabled")
        
    if services_status['Sentry']:
        print("  ✅ Sentry: Error tracking enabled")
    else:
        print("  ❌ Sentry: Error tracking disabled")
    
    print("\n🎮 Game Services:")
    if services_status['Supabase']:
        print("  ✅ Supabase: User data & quests enabled")
    else:
        print("  ❌ Supabase: User data & quests disabled")
    
    print("\n🎵 Voice Configuration:")
    for npc, voice in NPC_VOICE_MAP.items():
        print(f"  {npc.capitalize()}: {voice}")
    
    # Overall health check
    critical_services = ['OpenAI', 'Gemini']
    critical_missing = [s for s in critical_services if not services_status[s]]
    
    if not critical_missing:
        print("\n✅ SYSTEM STATUS: All critical services configured")
    else:
        print(f"\n⚠️  SYSTEM STATUS: Missing critical services: {', '.join(critical_missing)}")
    
    # Initialize Azure Speech Tracker
    try:
        azure_tracker = get_azure_speech_tracker()
        print("\u2705 Azure Speech Tracker: Initialized successfully")
    except Exception as e:
        print(f"\u274c Azure Speech Tracker: Failed to initialize - {e}")
    
    print("="*80 + "\n")

@app.get("/")
async def root():
    return {
        "message": "Welcome to the Babblelon Backend!",
        "services": {
            "llm": "OpenAI GPT-4.1-mini via Helicone",
            "tts": "Google Gemini TTS via Helicone Gateway", 
            "analytics": "PostHog + Helicone",
            "monitoring": "Sentry"
        },
        "status": "running"
    }

@app.post("/generate-npc-response/")
async def generate_npc_response_endpoint(
    request: Request,
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
    use_enhanced_stt: Optional[bool] = Form(False), # NEW: Enable enhanced STT with word confidence
    user_id: Optional[str] = Form(None),          # NEW: For Helicone user tracking
    session_id: Optional[str] = Form(None)        # NEW: For Helicone session tracking
):
    print(f"[{datetime.datetime.now()}] INFO: /generate-npc-response/ received request for NPC: {npc_id}, Name: {npc_name}, Charm: {charm_level}, Language: {target_language}. Custom message: {custom_message is not None}, Action: {action_type}")
    
    # Initialize latency tracking and device detection
    tracker = LatencyTracker(
        request_id=f"npc_{npc_id}_{int(datetime.datetime.now().timestamp())}",
        user_id=user_id or "anonymous",
        session_id=session_id or "unknown"
    )
    tracker.start("total")
    
    # Detect device information from User-Agent header
    user_agent = request.headers.get("user-agent", "")
    device_info = detect_device(user_agent)
    tracker.set_platform(device_info.platform.value)
    tracker.set_device_type(device_info.device_type.value)
    tracker.add_metadata("npc_id", npc_id)
    tracker.add_metadata("action_type", action_type)
    tracker.add_metadata("uses_custom_message", custom_message is not None)
    
    print(f"[{datetime.datetime.now()}] INFO: Device detected - Platform: {device_info.platform.value}, Type: {device_info.device_type.value}, Mobile: {device_info.is_mobile}")
    
    try:
        # 1. Parse quest state from JSON
        quest_state = {}
        if quest_state_json and quest_state_json != "{}":
            try:
                quest_state = json.loads(quest_state_json)
                print(f"[{datetime.datetime.now()}] INFO: Quest state loaded for {npc_id}")
            except json.JSONDecodeError:
                print(f"[{datetime.datetime.now()}] WARNING: Invalid quest_state_json for {npc_id}")
                quest_state = {}
        
        # 2. Handle STT or Custom Message
        word_confidence_data = []  # Initialize for enhanced STT
        pronunciation_score = 0.0  # Initialize for enhanced STT
        
        if custom_message:
            # Item giving: Skip STT, use custom message directly
            latest_player_message = custom_message
            player_transcription = custom_message  # For response consistency
            print(f"[{datetime.datetime.now()}] INFO: Using custom message for {npc_id}: '{custom_message}'")
            # Mark STT as skipped
            tracker.add_metadata("stt_skipped", True)
        else:
            # Normal conversation: STT - Transcribe player's audio
            if not audio_file:
                raise HTTPException(status_code=400, detail="Either audio_file or custom_message must be provided.")
                
            player_audio_bytes = await audio_file.read()
            await audio_file.close()
            if not player_audio_bytes:
                raise HTTPException(status_code=400, detail="Uploaded audio file is empty.")
            
            player_audio_stream = io.BytesIO(player_audio_bytes)
            
            # Start timing STT
            tracker.start("stt", {"audio_size_bytes": len(player_audio_bytes), "enhanced": use_enhanced_stt})
            
            if use_enhanced_stt:
                # Enhanced STT with word-level confidence using Chirp2 model
                stt_result: STTResult = await transcribe_audio_advanced(
                    player_audio_stream, 
                    language_code=target_language,
                    expected_text="",
                    user_id=user_id,
                    session_id=session_id
                )
                player_transcription = stt_result.text
                word_confidence_data = stt_result.word_confidence
                
                # Calculate pronunciation score
                if word_confidence_data:
                    confidence_scores = [word["confidence"] for word in word_confidence_data]
                    pronunciation_score = sum(confidence_scores) / len(confidence_scores)
                
                print(f"[{datetime.datetime.now()}] INFO: Enhanced STT for {npc_id} successful. Transcription: '{player_transcription}', Pronunciation Score: {pronunciation_score:.3f}")
            else:
                # Standard STT (backward compatibility)
                stt_result = await transcribe_audio(
                    player_audio_stream, 
                    language_code=target_language,
                    expected_text="",
                    user_id=user_id,
                    session_id=session_id
                )
                player_transcription = stt_result.text
                print(f"[{datetime.datetime.now()}] INFO: Standard STT for {npc_id} successful. Transcription: '{player_transcription}'")
            
            # End timing STT
            stt_duration = tracker.end("stt", {
                "transcription_length": len(player_transcription),
                "language": target_language,
                "success": bool(player_transcription)
            })
            
            latest_player_message = player_transcription if player_transcription and player_transcription.strip() else ""

        # 3. Prepare conversation history and latest message for LLM
        conversation_history = previous_conversation_history if previous_conversation_history else ""
        
        if not latest_player_message and not action_type:
            raise HTTPException(status_code=400, detail="Player message is empty or invalid.")

        # 4. LLM - Get NPC's response with quest parameters and tracking
        tracker.start("llm", {
            "npc_id": npc_id,
            "charm_level": charm_level,
            "has_quest_state": bool(quest_state),
            "message_length": len(latest_player_message)
        })
        
        npc_response_data: NPCResponse = await get_llm_response(
            npc_id=npc_id, 
            npc_name=npc_name,
            conversation_history=conversation_history,
            latest_player_message=latest_player_message,
            current_charm_level=charm_level,
            target_language=target_language,
            quest_state=quest_state,
            action_type=action_type,
            action_item=action_item,
            user_id=user_id,
            session_id=session_id
        )
        
        llm_duration = tracker.end("llm", {
            "response_length": len(npc_response_data.response_target),
            "response_tone": npc_response_data.response_tone,
            "charm_delta": npc_response_data.charm_delta,
            "item_accepted": npc_response_data.user_item_accepted
        })
        
        print(f"[{datetime.datetime.now()}] INFO: LLM response for {npc_id} OK. Target: '{npc_response_data.response_target[:30]}...', Tone: '{npc_response_data.response_tone}'")

        # 4a. Process item giving and update quest state (following notebook pattern)
        # BACKEND ENFORCEMENT: Only process items with valid GIVE_ITEM action (matches notebook)
        valid_item_action = (action_type == "GIVE_ITEM" and action_item.strip() != "")
        
        updated_quest_state = quest_state  # Default to original state
        if quest_state and valid_item_action:
            # Update quest state with item giving results (following notebook pattern)
            updated_quest_state = process_item_giving(npc_response_data, quest_state)
            quest_complete = updated_quest_state.get('quest_state', {}).get('scenario_complete', False)
        else:
            # Regular conversation or invalid action - no quest processing (following notebook pattern)
            pass

        # 5. TTS - Convert NPC's text response to speech
        voice_name = NPC_VOICE_MAP.get(npc_id.lower(), NPC_VOICE_MAP["default"])
        
        tracker.start("tts", {
            "voice_name": voice_name,
            "text_length": len(npc_response_data.response_target),
            "response_tone": npc_response_data.response_tone
        })
        
        npc_audio_bytes = await text_to_speech_full(
            text_to_speak=npc_response_data.response_target, 
            voice_name=voice_name,
            response_tone=npc_response_data.response_tone,
            user_id=user_id,
            session_id=session_id
        )
        
        tts_duration = tracker.end("tts", {
            "audio_bytes": len(npc_audio_bytes) if npc_audio_bytes else 0,
            "success": bool(npc_audio_bytes)
        })
        
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
            "input_english": npc_response_data.input_english,
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


        # Finalize timing and create response headers
        tracker.end("total")
        timing_headers = tracker.to_response_headers()
        mobile_headers = get_mobile_optimized_headers(user_agent)
        
        # Send metrics to PostHog and alerts to Sentry
        tracker.finalize(send_to_posthog=True)  # Use default threshold (25s)
        
        print(f"[{datetime.datetime.now()}] INFO: Sending NPC response for {npc_id}. Header JSON (first 60 chars of b64): {response_data_b64[:60]}...")
        print(f"[{datetime.datetime.now()}] 📊 Request completed - Total: {tracker.get_duration('total'):.2f}s, "
              f"STT: {tracker.get_duration('stt') or 'N/A'}s, "
              f"LLM: {tracker.get_duration('llm'):.2f}s, "
              f"TTS: {tracker.get_duration('tts'):.2f}s")
        
        # Combine all headers
        response_headers = {
            "X-NPC-Response-Data": response_data_b64,
            **timing_headers,
            **mobile_headers
        }
        
        return StreamingResponse(
            io.BytesIO(npc_audio_bytes), 
            media_type="audio/wav",
            headers=response_headers
        )
    except HTTPException as e:
        # Re-raise HTTPExceptions (e.g., from STT, LLM, or TTS services if they raise them)
        print(f"[{datetime.datetime.now()}] ERROR: HTTPException in /generate-npc-response/: {e.detail}")
        # Still track the failed request
        if 'tracker' in locals():
            tracker.add_metadata("error_type", "HTTPException")
            tracker.add_metadata("error_detail", str(e.detail))
            tracker.finalize(send_to_posthog=True, alert_threshold=20.0)  # Lower threshold for errors
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: Unhandled exception in /generate-npc-response/: {e}")
        import traceback
        traceback.print_exc()
        # Track the failed request
        if 'tracker' in locals():
            tracker.add_metadata("error_type", "UnhandledException")
            tracker.add_metadata("error_detail", str(e))
            tracker.finalize(send_to_posthog=True, alert_threshold=15.0)  # Lower threshold for critical errors
        raise HTTPException(status_code=500, detail="An unexpected error occurred processing NPC response.")

@app.get("/health")
async def health_check():
    return {"status": "healthy"}






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
    print(f"[{request_time}] INFO: Translation Service Usage - STT Processing: Google Translate API")
    
    try:
        # Read audio file
        audio_bytes = await audio_file.read()
        await audio_file.close()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file content is empty.")

        audio_content_stream = io.BytesIO(audio_bytes)
        
        # Step 1: STT with word-level confidence using Chirp2 model and expected text comparison
        
        # Try Google Cloud STT first, with fallback to ElevenLabs on timeout/unavailable errors
        stt_result: STTResult = None
        try:
            stt_result = await transcribe_audio_advanced(audio_content_stream, language_code=source_language, expected_text=expected_text or "")
            print(f"[{datetime.datetime.now()}] INFO: Google Cloud STT succeeded")
        except HTTPException as http_ex:
            # Check if this is a service unavailable error that should trigger fallback
            if http_ex.status_code == 503 or "timed out" in str(http_ex.detail).lower() or "unavailable" in str(http_ex.detail).lower():
                print(f"[{datetime.datetime.now()}] WARNING: Google Cloud STT unavailable ({http_ex.detail}), trying ElevenLabs fallback...")
                try:
                    # Reset audio stream for ElevenLabs
                    audio_content_stream.seek(0)
                    stt_result = await transcribe_audio_elevenlabs(audio_content_stream, language_code=source_language, expected_text=expected_text or "")
                    print(f"[{datetime.datetime.now()}] INFO: ElevenLabs STT fallback succeeded")
                except Exception as elevenlabs_ex:
                    print(f"[{datetime.datetime.now()}] ERROR: Both Google Cloud and ElevenLabs STT failed. ElevenLabs error: {elevenlabs_ex}")
                    raise HTTPException(status_code=503, detail="All STT services temporarily unavailable. Please try again.")
            else:
                # Re-raise non-timeout errors immediately
                raise http_ex
        except Exception as general_ex:
            print(f"[{datetime.datetime.now()}] ERROR: Unexpected error in Google Cloud STT: {general_ex}")
            raise HTTPException(status_code=500, detail=f"STT processing error: {str(general_ex)}")
        
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
        
        # Step 2: Translation
        translation_result = await translate_text(stt_result.text, target_language, source_language)
        
        # Step 3: Romanization (if source is Thai)
        romanization = ""
        if source_language in ["tha", "th"]:
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
                    translate_text(word, target_language, source_language) for word in words_to_process
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
                
                # Debug: Check for exceptions in results
                romanization_exceptions = [i for i, r in enumerate(romanization_results) if isinstance(r, Exception)]
                translation_exceptions = [i for i, r in enumerate(translation_results) if isinstance(r, Exception)]
                
                # Log sample results for debugging
                if translation_results:
                    for i, result in enumerate(translation_results[:3]):  # Log first 3 results
                        if isinstance(result, Exception):
                            continue
                        # Results are processed below in enhanced word confidence
                
                # Build enhanced word confidence
                for i, original_word_data in enumerate(stt_result.word_confidence):
                    enhanced_word = dict(original_word_data)  # Copy original data
                    word_text = original_word_data.get("word", "")
                    
                    # Add transliteration if available
                    if i < len(romanization_results) and not isinstance(romanization_results[i], Exception):
                        transliteration = romanization_results[i].get("romanized_text", "")
                        enhanced_word["transliteration"] = transliteration
                    else:
                        enhanced_word["transliteration"] = ""
                    
                    # Add translation if available
                    if i < len(translation_results) and not isinstance(translation_results[i], Exception):
                        translation = translation_results[i].get("translated_text", "")
                        enhanced_word["translation"] = translation
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
        else:
            # No STT result available - use empty enhanced word confidence
            enhanced_word_confidence = []
        
        # Step 5: Calculate pronunciation score based on word confidence
        pronunciation_score = 0.0
        if enhanced_word_confidence:
            confidence_scores = [word["confidence"] for word in enhanced_word_confidence]
            pronunciation_score = sum(confidence_scores) / len(confidence_scores)
        
        print(f"[{datetime.datetime.now()}] INFO: Translation successful. Result: '{translation_result}'")
        print(f"[{datetime.datetime.now()}] INFO: Pronunciation score: {pronunciation_score:.3f}")
        
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



# --- Parallel Transcription Comparison Endpoint (Legacy) ---
@app.post("/parallel-transcribe/", response_model=ParallelTranscriptionResponse)
async def parallel_transcribe_endpoint(
    audio_file: UploadFile = File(...),
    language_code: Optional[str] = Form("tha"),
    expected_text: Optional[str] = Form("")
):
    """
    Legacy parallel transcription endpoint that processes audio through both Google Cloud STT models
    (Chirp_2 vs short) for accuracy comparison and testing.
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
        parallel_results = await parallel_transcribe_audio(audio_content_stream, language_code, expected_text)
        
        # Convert STTResult objects to response format
        def convert_stt_result(stt_result: STTResult) -> STTServiceResult:
            # Calculate metrics from STTResult
            word_count = len(stt_result.word_confidence) if stt_result.word_confidence else len(stt_result.text.split())
            accuracy_score = sum(wc.get('confidence', 0.0) for wc in stt_result.word_confidence) / max(word_count, 1) if stt_result.word_confidence else stt_result.overall_confidence
            status = "success" if stt_result.text.strip() else "no_speech"
            
            # Extract English translation from expected text or leave empty
            english_translation = stt_result.expected_text if stt_result.expected_text else ""
            
            return STTServiceResult(
                service_name=stt_result.service_used,
                transcription=stt_result.text,
                english_translation=english_translation,
                processing_time=stt_result.processing_time,
                confidence_score=stt_result.overall_confidence,
                audio_duration=stt_result.audio_duration,
                real_time_factor=stt_result.real_time_factor,
                word_count=word_count,
                accuracy_score=accuracy_score,
                status=status,
                error=None
            )
        
        google_chirp2_result = convert_stt_result(parallel_results["google_chirp2"])
        google_short_result = convert_stt_result(parallel_results["google_short"])
        
        # Create processing summary
        processing_summary = {
            "total_processing_time": (datetime.datetime.now() - request_time).total_seconds(),
            "google_processing_time": google_chirp2_result.processing_time,
            "google_short_processing_time": google_short_result.processing_time,
            "google_success": bool(google_chirp2_result.transcription.strip()),
            "google_short_success": bool(google_short_result.transcription.strip()),
            "text_match": google_chirp2_result.transcription.strip() == google_short_result.transcription.strip(),
            "google_word_count": google_chirp2_result.word_count,
            "google_short_word_count": google_short_result.word_count
        }
        
        print(f"[{datetime.datetime.now()}] INFO: Parallel transcription completed.")
        
        return ParallelTranscriptionResponse(
            google=google_chirp2_result,
            elevenlabs=google_short_result,  # Using elevenlabs field for short model for frontend compatibility
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
        # Use the enhanced translate_and_syllabify function for context-aware processing
        syllable_result = await translate_and_syllabify_enhanced(request.english_text, request.target_language)
        
        # Extract target text from word mappings
        target_text = ' '.join([mapping['target'] for mapping in syllable_result['word_mappings']])
        
        # Generate audio for the full target text
        audio_result = await synthesize_speech(target_text, request.target_language)
        
        # Build response in the expected format (cleaned up - removed duplicates)
        response_payload = {
            "english_text": request.english_text,
            "target_text": target_text,
            "romanized_text": ' '.join([mapping['transliteration'] for mapping in syllable_result['word_mappings']]),
            "audio_base64": audio_result.get("audio_base64", ""),
            "word_mappings": syllable_result['word_mappings'],
            "target_language_name": get_language_name(request.target_language),
            "method": syllable_result.get('method', 'enhanced_context_aware')
        }
        
        return JSONResponse(content=response_payload)
    except HTTPException as e:
        # Re-raise HTTPException to let FastAPI handle it
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /gcloud-translate-tts/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- DeepL Translation Endpoint ---
@app.post("/deepl-translate-tts/", response_model=GoogleTranslationResponse)
async def deepl_translate_tts_endpoint(request: TranslationRequest):
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /deepl-translate-tts/ received request for text: '{request.english_text[:50]}...' in {request.target_language}")
    try:
        # Use the new translate_and_syllabify_deepl function for DeepL translation
        syllable_result = await translate_and_syllabify_deepl(request.english_text, request.target_language)
        
        # Extract target text from the result
        target_text = syllable_result['target_text']
        
        # Generate audio for the full target text using Google TTS (since DeepL doesn't have TTS)
        audio_result = await synthesize_speech(target_text, request.target_language)
        
        # Build response in the expected format (cleaned up - removed duplicates)
        response_payload = {
            "english_text": request.english_text,
            "target_text": target_text,
            "romanized_text": ' '.join([mapping['transliteration'] for mapping in syllable_result['word_mappings']]),
            "audio_base64": audio_result.get("audio_base64", ""),
            "word_mappings": syllable_result['word_mappings'],
            "target_language_name": get_language_name(request.target_language),
            "service": "deepl",
            "method": syllable_result.get('method', 'deepl_hybrid')
        }
        
        return JSONResponse(content=response_payload)
    except HTTPException as e:
        # Re-raise HTTPException to let FastAPI handle it
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /deepl-translate-tts/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- Enhanced Homograph-Aware Translation Endpoint ---
@app.post("/enhanced-translate-homographs/", response_model=GoogleTranslationResponse)
async def enhanced_translate_homographs_endpoint(request: TranslationRequest):
    """
    Enhanced translation endpoint with homograph detection and context-aware translation.
    Based on research from "Handling Homographs in Neural Machine Translation" (Liu et al., 2017)
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /enhanced-translate-homographs/ received request for text: '{request.english_text[:50]}...' in {request.target_language}")
    
    try:
        # Import homograph service
        from services.homograph_service import homograph_service
        
        # Standard translation first
        syllable_result = await translate_and_syllabify_enhanced(request.english_text, request.target_language)
        target_text = ' '.join([mapping['target'] for mapping in syllable_result['word_mappings']])
        
        # Enhanced homograph analysis
        homograph_analysis = homograph_service.analyze_sentence_homographs(target_text)
        
        # Enhance word mappings with homograph detection
        enhanced_word_mappings = homograph_service.get_word_mappings_enhanced(
            request.english_text,
            target_text,
            syllable_result['word_mappings']
        )
        
        # Generate audio for the target text
        audio_result = await synthesize_speech(target_text, request.target_language)
        
        # Build enhanced response
        response_payload = {
            "english_text": request.english_text,
            "target_text": target_text,
            "romanized_text": ' '.join([mapping.get('enhanced_romanization', mapping.get('transliteration', '')) for mapping in enhanced_word_mappings]),
            "audio_base64": audio_result.get("audio_base64", ""),
            "word_mappings": enhanced_word_mappings,
            "target_language_name": get_language_name(request.target_language),
            "method": "homograph_enhanced",
            # Enhanced homograph information
            "homograph_analysis": {
                "total_words": homograph_analysis['total_words'],
                "total_homographs": homograph_analysis['total_homographs'],
                "homograph_percentage": homograph_analysis['homograph_percentage'],
                "romanization_engine": homograph_analysis['romanization_engine']
            },
            "homograph_statistics": homograph_service.get_homograph_statistics()
        }
        
        return JSONResponse(content=response_payload)
        
    except ImportError:
        # Fallback to standard translation if homograph service not available
        print(f"[{datetime.datetime.now()}] WARNING: Homograph service not available, falling back to standard translation")
        return await gcloud_translate_tts_endpoint(request)
        
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /enhanced-translate-homographs/: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- Homograph Statistics Endpoint ---
@app.get("/homograph-statistics/")
async def get_homograph_statistics():
    """
    Get statistics about the homograph dictionary for monitoring and debugging.
    """
    try:
        from services.homograph_service import homograph_service
        return JSONResponse(content=homograph_service.get_homograph_statistics())
    except ImportError:
        raise HTTPException(status_code=503, detail="Homograph service not available")
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: in /homograph-statistics/: {e}")
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
    language: str = Form("th-TH"),
    user_id: Optional[str] = Form(None),
    session_id: Optional[str] = Form(None)
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
            language=language,
            user_id=user_id,
            session_id=session_id
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

@app.get("/sentry-debug")
async def trigger_error():
    """Test endpoint to verify Sentry integration is working"""
    division_by_zero = 1 / 0
    return {"message": "This should not be returned"}

# --- Azure Speech Services Tracking Endpoints ---

@app.get("/azure-speech/metrics")
async def get_azure_speech_metrics():
    """Get current Azure Speech Services tracking metrics"""
    try:
        tracker = get_azure_speech_tracker()
        metrics = tracker.get_metrics()
        return JSONResponse(content={
            "status": "success",
            "data": metrics,
            "message": "Azure Speech metrics retrieved successfully"
        })
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Failed to get Azure Speech metrics: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve metrics: {str(e)}")

@app.get("/azure-speech/costs")
async def get_azure_speech_costs(time_range_hours: int = 24):
    """Get Azure Speech Services cost summary for specified time range"""
    try:
        if time_range_hours < 1 or time_range_hours > 720:  # Max 30 days
            raise HTTPException(status_code=400, detail="time_range_hours must be between 1 and 720")
        
        tracker = get_azure_speech_tracker()
        cost_summary = tracker.get_cost_summary(time_range_hours)
        return JSONResponse(content={
            "status": "success",
            "data": cost_summary,
            "message": f"Azure Speech cost summary for last {time_range_hours} hours retrieved successfully"
        })
    except HTTPException:
        raise
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Failed to get Azure Speech costs: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve cost summary: {str(e)}")

# --- Multi-Service STT/Translation Test Endpoint ---

class MultiServiceTestRequest(BaseModel):
    """Request model for testing multiple STT/Translation service combinations"""
    test_name: str = "STT Translation Test"
    include_cloud_services: bool = True

class ServiceTestResult(BaseModel):
    """Individual service test result"""
    service_name: str
    stt_provider: str
    translation_provider: str
    transcription: str
    romanization: str
    translation: str
    processing_time_ms: int
    confidence_score: float
    is_offline: bool
    error: Optional[str] = None
    cost_estimate: float = 0.0

class MultiServiceTestResponse(BaseModel):
    """Response for multi-service test endpoint"""
    test_name: str
    audio_duration_seconds: float
    results: List[ServiceTestResult]
    fastest_service: str
    most_accurate_service: str
    cost_comparison: Dict[str, float]

@app.post("/test-stt-translation-combinations/", response_model=MultiServiceTestResponse)
async def test_stt_translation_combinations_endpoint(
    audio_file: UploadFile = File(...),
    source_language: str = Form("th"),
    target_language: str = Form("en"),
    test_name: str = Form("STT Translation Test"),
    include_cloud_services: bool = Form(True),
):
    """
    Test multiple STT and translation service combinations for comparison.
    Supports:
    - Google Cloud STT + Google Translate
    - ElevenLabs STT + Google Translate
    - OpenAI Whisper + Google Translate
    
    Note: Whisper (on-device) testing is handled client-side in Flutter.
    Note: OpenAI Whisper Direct Translation removed due to lower quality.
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /test-stt-translation-combinations/ endpoint hit. Source: {source_language}, Target: {target_language}")
    
    try:
        # Read audio file
        audio_bytes = await audio_file.read()
        await audio_file.close()
        
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file content is empty.")
        
        # Save audio temporarily for processing
        import tempfile
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_audio:
            temp_audio.write(audio_bytes)
            temp_audio_path = temp_audio.name
        
        results = []
        
        # Test Google Cloud STT + Google Translate
        if include_cloud_services:
            try:
                start_time = datetime.datetime.now()
                
                # Use existing backend functions
                audio_stream = io.BytesIO(audio_bytes)
                
                # Transcribe with Google Cloud STT
                stt_result = await transcribe_audio_advanced(
                    audio_stream,
                    language_code=source_language
                )
                
                # Translate the transcription
                if stt_result and stt_result.text:
                    translation_result = await translate_text(
                        text=stt_result.text,
                        target_language=target_language,
                        source_language=source_language
                    )
                    
                    # Generate romanization if source is Thai
                    romanization = ""
                    if source_language in ["th", "tha"]:
                        romanization_result = await romanize_target_text(stt_result.text, source_language)
                        romanization = romanization_result.get("romanized_text", "")
                    
                    google_result = {
                        'transcription': stt_result.text,
                        'romanization': romanization,
                        'translation': translation_result.get('translated_text', ''),
                        'confidence_score': stt_result.overall_confidence,
                        'word_confidence': stt_result.word_confidence
                    }
                else:
                    google_result = {
                        'transcription': '',
                        'romanization': '',
                        'translation': '',
                        'confidence_score': 0.0,
                        'word_confidence': []
                    }
                
                processing_time = (datetime.datetime.now() - start_time).total_seconds() * 1000
                
                results.append(ServiceTestResult(
                    service_name="Google Cloud STT + Google Translate",
                    stt_provider="Google Cloud STT",
                    translation_provider="Google Translate",
                    transcription=google_result.get('transcription', ''),
                    romanization=google_result.get('romanization', ''),
                    translation=google_result.get('translation', ''),
                    processing_time_ms=int(processing_time),
                    confidence_score=google_result.get('confidence_score', 0.0),
                    is_offline=False,
                    cost_estimate=0.016  # $0.016/min for Google Cloud STT
                ))
            except Exception as e:
                results.append(ServiceTestResult(
                    service_name="Google Cloud STT + Google Translate",
                    stt_provider="Google Cloud STT",
                    translation_provider="Google Translate",
                    transcription="",
                    romanization="",
                    translation="",
                    processing_time_ms=0,
                    confidence_score=0.0,
                    is_offline=False,
                    error=str(e)
                ))
        
        # Test ElevenLabs STT + Google Translate
        if include_cloud_services:
            try:
                start_time = datetime.datetime.now()
                
                # Use ElevenLabs STT directly
                audio_stream = io.BytesIO(audio_bytes)
                elevenlabs_result = await transcribe_audio_elevenlabs(
                    audio_stream,
                    language_code=source_language
                )
                
                # Translate using Google if we got transcription
                if elevenlabs_result and elevenlabs_result.text:
                    translation_result = await translate_text(
                        text=elevenlabs_result.text,
                        target_language=target_language,
                        source_language=source_language
                    )
                    
                    # Generate romanization if source is Thai
                    romanization = ""
                    if source_language in ["th", "tha"]:
                        romanization_result = await romanize_target_text(elevenlabs_result.text, source_language)
                        romanization = romanization_result.get("romanized_text", "")
                    
                    processing_time = (datetime.datetime.now() - start_time).total_seconds() * 1000
                    
                    results.append(ServiceTestResult(
                        service_name="ElevenLabs STT + Google Translate",
                        stt_provider="ElevenLabs STT",
                        translation_provider="Google Translate",
                        transcription=elevenlabs_result.text,
                        romanization=romanization,
                        translation=translation_result.get('translated_text', ''),
                        processing_time_ms=int(processing_time),
                        confidence_score=elevenlabs_result.overall_confidence,
                        is_offline=False,
                        cost_estimate=0.005  # Estimate for ElevenLabs
                    ))
                else:
                    results.append(ServiceTestResult(
                        service_name="ElevenLabs STT + Google Translate",
                        stt_provider="ElevenLabs STT",
                        translation_provider="Google Translate",
                        transcription="",
                        romanization="",
                        translation="",
                        processing_time_ms=int((datetime.datetime.now() - start_time).total_seconds() * 1000),
                        confidence_score=0.0,
                        is_offline=False,
                        error="No transcription received from ElevenLabs"
                    ))
            except Exception as e:
                results.append(ServiceTestResult(
                    service_name="ElevenLabs STT + Google Translate",
                    stt_provider="ElevenLabs STT",
                    translation_provider="Google Translate",
                    transcription="",
                    romanization="",
                    translation="",
                    processing_time_ms=0,
                    confidence_score=0.0,
                    is_offline=False,
                    error=str(e)
                ))
        
        
        # Test OpenAI Whisper transcription
        if include_cloud_services:
            try:
                start_time = datetime.datetime.now()
                
                # Transcribe with OpenAI Whisper
                audio_stream = io.BytesIO(audio_bytes)
                whisper_result = await transcribe_audio_openai(
                    audio_stream=audio_stream,
                    language_code=source_language
                )
                
                # Translate using Google Translate if needed
                translation_result = {}
                if target_language != source_language:
                    translation_result = await translate_text(
                        text=whisper_result.text,
                        target_language=target_language,
                        source_language=source_language
                    )
                
                # Generate romanization if source is Thai
                romanization = ""
                if source_language in ["th", "tha"]:
                    romanization_result = await romanize_target_text(whisper_result.text, source_language)
                    romanization = romanization_result.get("romanized_text", "")
                
                processing_time = (datetime.datetime.now() - start_time).total_seconds() * 1000
                
                results.append(ServiceTestResult(
                    service_name="OpenAI Whisper + Google Translate",
                    stt_provider="OpenAI Whisper",
                    translation_provider="Google Translate",
                    transcription=whisper_result.text,
                    romanization=romanization,
                    translation=translation_result.get('translated_text', ''),
                    processing_time_ms=int(processing_time),
                    confidence_score=0.0,  # OpenAI Whisper doesn't provide confidence scores
                    is_offline=False,
                    cost_estimate=whisper_result.cost_estimate
                ))
            except Exception as e:
                results.append(ServiceTestResult(
                    service_name="OpenAI Whisper + Google Translate",
                    stt_provider="OpenAI Whisper",
                    translation_provider="Google Translate",
                    transcription="",
                    romanization="",
                    translation="",
                    processing_time_ms=0,
                    confidence_score=0.0,
                    is_offline=False,
                    error=str(e)
                ))
        
        
        # Clean up temp file
        import os
        try:
            os.unlink(temp_audio_path)
        except:
            pass
        
        # Calculate audio duration (approximate based on file size)
        audio_duration_seconds = len(audio_bytes) / (16000 * 2)  # Assuming 16kHz, 16-bit mono
        
        # Determine fastest and most accurate services
        valid_results = [r for r in results if not r.error]
        
        fastest_service = min(valid_results, key=lambda r: r.processing_time_ms).service_name if valid_results else "None"
        most_accurate_service = max(valid_results, key=lambda r: r.confidence_score).service_name if valid_results else "None"
        
        # Cost comparison
        cost_comparison = {
            r.service_name: r.cost_estimate * (audio_duration_seconds / 60.0)
            for r in results
        }
        
        response = MultiServiceTestResponse(
            test_name=test_name,
            audio_duration_seconds=audio_duration_seconds,
            results=results,
            fastest_service=fastest_service,
            most_accurate_service=most_accurate_service,
            cost_comparison=cost_comparison
        )
        
        print(f"[{datetime.datetime.now()}] INFO: /test-stt-translation-combinations/ completed successfully")
        return response
        
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /test-stt-translation-combinations/ HTTPException: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /test-stt-translation-combinations/ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Unexpected error during multi-service test: {str(e)}")

@app.get("/azure-speech/health")
async def azure_speech_health_check():
    """Health check endpoint for Azure Speech Services tracking"""
    try:
        tracker = get_azure_speech_tracker()
        metrics = tracker.get_metrics()
        
        # Basic health indicators
        total_requests = sum(service.get('total_requests', 0) for service in metrics['services'].values())
        total_cost = metrics.get('total_cost_usd', 0.0)
        
        health_status = {
            "status": "healthy",
            "tracker_initialized": True,
            "total_requests_tracked": total_requests,
            "total_cost_tracked_usd": total_cost,
            "services_available": list(metrics['services'].keys()),
            "last_updated": metrics.get('last_updated'),
            "posthog_enabled": bool(os.getenv('POSTHOG_API_KEY')),
            "azure_credentials_configured": bool(os.getenv('AZURE_SPEECH_KEY')) and bool(os.getenv('AZURE_SPEECH_REGION'))
        }
        
        return JSONResponse(content=health_status)
    except Exception as e:
        print(f"[{datetime.datetime.now()}] ERROR: Azure Speech health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "error": str(e),
                "tracker_initialized": False
            }
        )

# OpenAI Whisper endpoints
@app.post("/openai-transcribe/")
async def openai_transcribe_endpoint(
    audio_file: UploadFile = File(...),
    language_code: str = Form("th"),
    prompt: str = Form(None)
):
    """
    Transcribe audio using OpenAI Whisper API.
    Maintains original language - Thai audio becomes Thai text.
    
    Args:
        audio_file: Audio file to transcribe
        language_code: Language code (e.g., 'th' for Thai)
        prompt: Optional prompt to guide transcription
    
    Returns:
        OpenAI Whisper transcription result with metrics
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /openai-transcribe/ endpoint hit. Language: {language_code}")
    
    try:
        # Read audio file into BytesIO stream
        audio_bytes = await audio_file.read()
        await audio_file.close()
        
        if len(audio_bytes) == 0:
            raise HTTPException(status_code=400, detail="Audio file is empty")
        
        audio_stream = io.BytesIO(audio_bytes)
        
        # Call OpenAI Whisper transcription service
        result = await transcribe_audio_openai(
            audio_stream=audio_stream,
            language_code=language_code,
            prompt=prompt if prompt else None
        )
        
        # Convert result to dict for JSON response
        response_data = {
            "text": result.text,
            "processing_time": result.processing_time,
            "service_used": result.service_used,
            "language_detected": result.language_detected,
            "model_used": result.model_used,
            "audio_duration": result.audio_duration,
            "real_time_factor": result.real_time_factor,
            "cost_estimate": result.cost_estimate,
            "is_translation": result.is_translation
        }
        
        print(f"[{datetime.datetime.now()}] INFO: /openai-transcribe/ completed successfully")
        return response_data
        
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /openai-transcribe/ HTTPException: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /openai-transcribe/ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"OpenAI Whisper transcription error: {str(e)}")

@app.post("/openai-translate/")
async def openai_translate_endpoint(
    audio_file: UploadFile = File(...),
    prompt: str = Form(None)
):
    """
    Translate audio using OpenAI Whisper API.
    Converts any language audio to English text.
    
    Args:
        audio_file: Audio file to translate
        prompt: Optional prompt to guide translation
    
    Returns:
        OpenAI Whisper translation result with metrics
    """
    request_time = datetime.datetime.now()
    print(f"[{request_time}] INFO: /openai-translate/ endpoint hit")
    
    try:
        # Read audio file into BytesIO stream
        audio_bytes = await audio_file.read()
        await audio_file.close()
        
        if len(audio_bytes) == 0:
            raise HTTPException(status_code=400, detail="Audio file is empty")
        
        audio_stream = io.BytesIO(audio_bytes)
        
        # Call OpenAI Whisper translation service
        result = await translate_audio_openai(
            audio_stream=audio_stream,
            prompt=prompt if prompt else None
        )
        
        # Convert result to dict for JSON response
        response_data = {
            "text": result.text,
            "processing_time": result.processing_time,
            "service_used": result.service_used,
            "language_detected": result.language_detected,
            "model_used": result.model_used,
            "audio_duration": result.audio_duration,
            "real_time_factor": result.real_time_factor,
            "cost_estimate": result.cost_estimate,
            "is_translation": result.is_translation
        }
        
        print(f"[{datetime.datetime.now()}] INFO: /openai-translate/ completed successfully")
        return response_data
        
    except HTTPException as e:
        print(f"[{datetime.datetime.now()}] ERROR: /openai-translate/ HTTPException: {e.detail}")
        raise e
    except Exception as e:
        print(f"[{datetime.datetime.now()}] CRITICAL: /openai-translate/ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"OpenAI Whisper translation error: {str(e)}")


if __name__ == "__main__":
    # Changed host from "127.0.0.1" to "0.0.0.0" to allow connections
    # from the Android emulator and other devices on the local network.
    uvicorn.run(app, host="0.0.0.0", port=8000) 