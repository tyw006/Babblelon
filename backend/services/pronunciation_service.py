import os
import json
import asyncio
import time
import logging
from pydantic import BaseModel
from typing import List, Dict, Any
import azure.cognitiveservices.speech as speechsdk
import tempfile
from dotenv import load_dotenv
import wave
import requests  # For PostHog tracking
from typing import Optional
import uuid

# Import Azure Speech Tracker
from .azure_speech_tracker import get_azure_speech_tracker, AzureSpeechService

# Configure logging
logging.basicConfig(level=logging.INFO)

load_dotenv()

# PostHog Configuration
POSTHOG_API_KEY = os.getenv("POSTHOG_API_KEY")

def track_pronunciation_assessment_to_posthog(
    user_id: Optional[str] = None,
    session_id: Optional[str] = None,
    reference_text: str = "",
    pronunciation_score: float = 0.0,
    accuracy_score: float = 0.0,
    processing_time_ms: int = 0,
    item_type: str = "",
    complexity: int = 0,
    success: bool = True,
    error: Optional[str] = None
):
    """Track pronunciation assessment calls to PostHog for analytics"""
    if not POSTHOG_API_KEY:
        return
    
    try:
        event_data = {
            "api_key": POSTHOG_API_KEY,
            "event": "pronunciation_assessment",
            "properties": {
                "service": "azure_pronunciation",
                "reference_text_length": len(reference_text),
                "pronunciation_score": pronunciation_score,
                "accuracy_score": accuracy_score,
                "processing_time_ms": processing_time_ms,
                "item_type": item_type,
                "complexity": complexity,
                "success": success,
                "timestamp": time.time(),
            },
            "timestamp": time.time(),
        }
        
        if user_id:
            event_data["distinct_id"] = user_id
        if session_id:
            event_data["properties"]["session_id"] = session_id
        if error:
            event_data["properties"]["error"] = error
            
        # Send to PostHog
        requests.post(
            "https://app.posthog.com/capture/",
            json=event_data,
            timeout=5
        )
    except Exception as e:
        print(f"WARNING: Failed to track pronunciation assessment to PostHog: {e}")

# --- Transliteration Helper ---

def get_transliteration(thai_text: str, static_mapping: Dict[str, str]) -> str:
    """
    Get transliteration for Thai text using static mapping from vocabulary file.
    This replaces the previous pythainlp integration for better consistency.
    """
    print(f"\n🔤 TRANSLITERATION REQUEST for: '{thai_text}'")
    
    # Use static mapping from vocabulary file's word_mapping
    static_result = static_mapping.get(thai_text, thai_text)
    print(f"📚 STATIC MAPPING: '{thai_text}' -> '{static_result}'")
    return static_result



# --- Pydantic Models ---

class PronunciationAssessmentRequest(BaseModel):
    reference_text: str
    transliteration: str
    complexity: int
    item_type: str
    turn_type: str
    was_revealed: bool = False
    azure_pron_mapping: List[Dict[str, str]] = []

class WordFeedback(BaseModel):
    word: str
    accuracy_score: float
    error_type: str
    transliteration: str

class DamageCalculationBreakdown(BaseModel):
    base_value: float
    pronunciation_multiplier: float
    complexity_multiplier: float
    penalty: float
    explanation: str
    final_attack_bonus: float
    final_defense_reduction: float

class PronunciationAssessmentResponse(BaseModel):
    rating: str
    pronunciation_score: float
    accuracy_score: float
    fluency_score: float
    completeness_score: float
    attack_multiplier: float
    defense_multiplier: float
    detailed_feedback: List[WordFeedback]
    word_feedback: str
    calculation_breakdown: DamageCalculationBreakdown


# --- Service Logic ---

async def assess_pronunciation(
    audio_bytes: bytes,
    reference_text: str,
    transliteration: str,
    complexity: int,
    item_type: str,
    turn_type: str,
    was_revealed: bool,
    azure_pron_mapping: List[Dict[str, str]],
    language: str = "th-TH",
    user_id: Optional[str] = None,
    session_id: Optional[str] = None
) -> PronunciationAssessmentResponse:
    """
    Assesses pronunciation from audio bytes using Azure Speech SDK, calculates game logic,
    and returns a detailed response. Includes latency logging.
    """
    start_time = time.time()
    temp_wav_file = None
    
    # Initialize Azure Speech Tracker
    tracker = get_azure_speech_tracker()
    request_id = str(uuid.uuid4())
    
    # Calculate audio duration for cost tracking
    audio_duration_seconds = None
    try:
        # Quick estimate of audio duration from bytes (assuming 16kHz, 16-bit, mono WAV)
        # More accurate duration calculation could be done by parsing WAV headers
        audio_duration_seconds = len(audio_bytes) / (16000 * 2)  # bytes / (sample_rate * bytes_per_sample)
    except Exception:
        audio_duration_seconds = None
    
    # Start tracking the request
    tracker.start_request(
        request_id=request_id,
        service=AzureSpeechService.PRONUNCIATION_ASSESSMENT,
        user_id=user_id,
        session_id=session_id,
        audio_duration_seconds=audio_duration_seconds,
        reference_text=reference_text,
        language=language,
        region=os.getenv("AZURE_SPEECH_REGION")
    )
    
    try:
        # Log the received request data for debugging
        request_data = {
            "reference_text": reference_text,
            "transliteration": transliteration,
            "complexity": complexity,
            "item_type": item_type,
            "turn_type": turn_type,
            "was_revealed": was_revealed,
            "language": language,
        }
        logging.info(f"ASSESSMENT REQUEST DATA: {json.dumps(request_data, indent=2)}")
        
        logging.info(f"Received pronunciation assessment request for turn: {turn_type}")
        
        # --- 1. Setup Azure Speech Configuration ---
        speech_key = os.getenv("AZURE_SPEECH_KEY")
        speech_region = os.getenv("AZURE_SPEECH_REGION")
        if not speech_key or not speech_region:
            raise ValueError("Azure Speech API credentials are not configured in environment variables.")

        speech_config = speechsdk.SpeechConfig(subscription=speech_key, region=speech_region)
        speech_config.speech_recognition_language = language

        # --- 2. Setup Audio Configuration from Bytes by writing to a temporary file ---
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            tmp.write(audio_bytes)
            temp_wav_file = tmp.name
        
        audio_config = speechsdk.audio.AudioConfig(filename=temp_wav_file)

        # --- 3. Setup Pronunciation Assessment Configuration ---
        pronunciation_config = speechsdk.PronunciationAssessmentConfig(
            reference_text=reference_text,
            grading_system=speechsdk.PronunciationAssessmentGradingSystem.HundredMark,
            granularity=speechsdk.PronunciationAssessmentGranularity.Phoneme,
            enable_miscue=True
        )

        # --- 4. Create Speech Recognizer ---
        recognizer = speechsdk.SpeechRecognizer(
            speech_config=speech_config,
            audio_config=audio_config
        )
        pronunciation_config.apply_to(recognizer)

        # --- 5. Perform Recognition and Process Result ---
        logging.info("Sending request to Azure Speech SDK...")
        result = await asyncio.get_event_loop().run_in_executor(
            None, recognizer.recognize_once
        )
        azure_call_time = time.time()
        logging.info(f"Azure SDK call finished in {azure_call_time - start_time:.2f} seconds.")

        if result.reason == speechsdk.ResultReason.Canceled:
            cancellation_details = result.cancellation_details
            error_msg = f"Azure Speech service error: {cancellation_details.reason}. Details: {cancellation_details.error_details}"
            
            # End tracking with failure
            response_time_ms = int((time.time() - start_time) * 1000)
            tracker.end_request(
                request_id=request_id,
                success=False,
                response_time_ms=response_time_ms,
                error_code="AZURE_SERVICE_CANCELED",
                error_message=error_msg
            )
            
            # Track failed assessment to PostHog (legacy tracking)
            track_pronunciation_assessment_to_posthog(
                user_id=user_id,
                session_id=session_id,
                reference_text=reference_text,
                processing_time_ms=response_time_ms,
                item_type=item_type,
                complexity=complexity,
                success=False,
                error=error_msg
            )
            raise ConnectionError(error_msg)
        if result.reason == speechsdk.ResultReason.NoMatch:
            error_msg = "Speech could not be recognized. Please try again with clearer audio."
            
            # End tracking with failure
            response_time_ms = int((time.time() - start_time) * 1000)
            tracker.end_request(
                request_id=request_id,
                success=False,
                response_time_ms=response_time_ms,
                error_code="NO_SPEECH_RECOGNIZED",
                error_message=error_msg
            )
            
            # Track failed assessment to PostHog (legacy tracking)
            track_pronunciation_assessment_to_posthog(
                user_id=user_id,
                session_id=session_id,
                reference_text=reference_text,
                processing_time_ms=response_time_ms,
                item_type=item_type,
                complexity=complexity,
                success=False,
                error=error_msg
            )
            raise ValueError(error_msg)
        
        if result.reason != speechsdk.ResultReason.RecognizedSpeech:
            error_msg = f"Recognition failed with reason: {result.reason}"
            
            # End tracking with failure
            response_time_ms = int((time.time() - start_time) * 1000)
            tracker.end_request(
                request_id=request_id,
                success=False,
                response_time_ms=response_time_ms,
                error_code="RECOGNITION_FAILED",
                error_message=error_msg
            )
            
            # Track failed assessment to PostHog (legacy tracking)
            track_pronunciation_assessment_to_posthog(
                user_id=user_id,
                session_id=session_id,
                reference_text=reference_text,
                processing_time_ms=response_time_ms,
                item_type=item_type,
                complexity=complexity,
                success=False,
                error=error_msg
            )
            raise ValueError(error_msg)

        # --- 6. Parse Results and Apply Game Logic ---
        pron_result = speechsdk.PronunciationAssessmentResult(result)
        pronunciation_score = pron_result.pronunciation_score
        
        # Calculate game multipliers using the new centralized function
        attack_damage, defense_multiplier, calculation_breakdown_dict = calculate_multipliers(
            pronunciation_score,
            complexity,
            item_type,
            was_revealed
        )

        # Set the appropriate explanation based on turn type
        if turn_type == 'attack':
            calculation_breakdown_dict["explanation"] = calculation_breakdown_dict["attack_explanation"]
        else:  # defense
            calculation_breakdown_dict["explanation"] = calculation_breakdown_dict["defense_explanation"]

        # The attack_multiplier field in the response now represents final damage
        # The defense_multiplier represents the factor by which incoming damage is multiplied
        
        json_result = json.loads(result.properties.get(speechsdk.PropertyId.SpeechServiceResponse_JsonResult))

        # --- Detailed Word Analysis ---
        detailed_feedback_list = []
        translit_map = {word['thai']: word['transliteration'] for word in azure_pron_mapping}
        
        print(f"\n📝 WORD-BY-WORD ANALYSIS:")
        print(f"Static mapping available: {list(translit_map.keys())}")

        if 'NBest' in json_result and len(json_result['NBest']) > 0:
            words_data = json_result['NBest'][0].get('Words', [])
            print(f"Azure detected {len(words_data)} words: {[w.get('Word', 'N/A') for w in words_data]}")
            
            for word_info in words_data:
                word_text = word_info.get('Word', 'N/A')
                print(f"\nProcessing word: '{word_text}'")
                
                # Use the new transliteration function with fallback to static mapping
                transliteration = get_transliteration(word_text, translit_map)
                
                # Determine error type based on Azure's analysis
                error_type = word_info.get('PronunciationAssessment', {}).get('ErrorType', 'None')
                word_accuracy = word_info.get('PronunciationAssessment', {}).get('AccuracyScore', 0)
                
                # If accuracy is very low but no specific error type, classify as mispronunciation
                if error_type == 'None' and word_accuracy < 60:
                    error_type = 'Mispronunciation'
                
                print(f"  Word accuracy: {word_accuracy}, Error type: {error_type}")
                
                w_res = WordFeedback(
                    word=word_text,
                    accuracy_score=word_info.get('PronunciationAssessment', {}).get('AccuracyScore', 0),
                    error_type=error_type,
                    transliteration=transliteration,
                )
                detailed_feedback_list.append(w_res)
                print(f"Final result: '{word_text}' -> '{transliteration}' (score: {w_res.accuracy_score})")
        else:
            print("⚠️  No word-level data found in Azure response")

        # --- Generate Actionable Word-Level Feedback ---
        # Create a sorted copy for feedback generation without affecting the original order
        sorted_feedback_list = sorted(detailed_feedback_list, key=lambda x: x.accuracy_score)
        worst_words = [w for w in sorted_feedback_list if w.accuracy_score < 80][:3]
        
        feedback_lines = []
        if worst_words:
            # Generate specific improvement tips based on score range and errors
            if pronunciation_score >= 75:
                feedback_lines.append("Almost there! Fine-tune these sounds:")
            elif pronunciation_score >= 60:
                feedback_lines.append("Good foundation! Focus on these challenging words:")
            else:
                feedback_lines.append("Let's work on pronunciation basics with these words:")
            
            for word in worst_words:
                feedback_entry = f"- '{word.word}'"
                if word.transliteration:
                    feedback_entry += f" ({word.transliteration})"
                
                # Add specific tips based on error type and score
                if word.accuracy_score < 50:
                    feedback_entry += " - Break this into syllables and practice slowly"
                elif word.accuracy_score < 70:
                    feedback_entry += " - Focus on tone and vowel sounds"
                else:
                    feedback_entry += " - Almost perfect! Polish the final sounds"
                    
                feedback_lines.append(feedback_entry)

            # Add technique-specific advice based on overall score
            if pronunciation_score < 60:
                feedback_lines.append("\nTechnique tip: Listen to native speakers and repeat slowly, focusing on mouth position.")
            elif pronunciation_score < 75:
                feedback_lines.append("\nTechnique tip: Practice tonal patterns - Thai has 5 tones that change word meaning.")
            else:
                feedback_lines.append("\nTechnique tip: Work on natural rhythm and stress patterns for fluency.")

            if len(worst_words) < len(detailed_feedback_list):
                best_word = max(sorted_feedback_list, key=lambda x: x.accuracy_score)
                best_word_text = f"'{best_word.word}'"
                if best_word.transliteration:
                    best_word_text += f" ({best_word.transliteration})"
                feedback_lines.append(f"\n✨ You nailed {best_word_text} - excellent pronunciation!")
        else:
            # All words scored well
            if pronunciation_score >= 90:
                feedback_lines.append("Outstanding! Your pronunciation is near-native level. Keep practicing to maintain this excellence!")
            else:
                feedback_lines.append("Great job! All words pronounced well. Focus on natural rhythm and flow for even better results.")
        
        word_feedback = "\n".join(feedback_lines) if feedback_lines else "Great job! Your pronunciation is solid."
        
        # --- Construct Final Response ---
        # The calculation breakdown dict from the helper is used directly
        calculation_breakdown = DamageCalculationBreakdown(**calculation_breakdown_dict)

        response = PronunciationAssessmentResponse(
            rating=get_pronunciation_rating(pronunciation_score),
            pronunciation_score=pronunciation_score,
            accuracy_score=pron_result.accuracy_score,
            fluency_score=pron_result.fluency_score,
            completeness_score=pron_result.completeness_score,
            attack_multiplier=attack_damage, # This field now holds the final damage
            defense_multiplier=defense_multiplier,
            detailed_feedback=detailed_feedback_list,
            word_feedback=word_feedback,
            calculation_breakdown=calculation_breakdown,
        )
        
        # --- DETAILED BACKEND LOGGING (Similar to test_STT.ipynb format) ---
        print("\n" + "="*60)
        print("PRONUNCIATION ASSESSMENT RESULT")
        print("="*60)
        print(f"Reference Text: {reference_text}")
        print(f"Transliteration: {transliteration}")
        print(f"Turn Type: {turn_type.upper()}")
        print(f"Item Type: {item_type.capitalize()}")
        print(f"Card Revealed: {'YES' if was_revealed else 'NO'}")
        print(f"Complexity Level: {complexity}")
        print("-" * 40)
        print("SCORES:")
        print(f"  Overall Pronunciation: {pronunciation_score:.1f}% ({response.rating})")
        print(f"  Accuracy: {pron_result.accuracy_score:.1f}%")
        print(f"  Fluency: {pron_result.fluency_score:.1f}%")
        print(f"  Completeness: {pron_result.completeness_score:.1f}%")
        print("-" * 40)
        print("GAME IMPACT:")
        if turn_type == 'attack':
            print(f"  Final Attack Damage: {attack_damage:.1f}")
            print(f"  Base Damage: 50 (Regular) / 60 (Special)")
            print(f"  Attack Multiplier: {attack_damage / (60.0 if item_type == 'special' else 50.0):.2f}x")
        else:
            print(f"  Defense Multiplier: {defense_multiplier:.2f}")
            print(f"  Damage Taken: {15.0 * defense_multiplier:.1f} HP (from 15 base)")
            print(f"  Damage Reduction: {(1 - defense_multiplier) * 100:.1f}%")
        print("-" * 40)
        print("CALCULATION BREAKDOWN:")
        print(calculation_breakdown_dict["explanation" if turn_type == "attack" else "defense_explanation"])
        
        if detailed_feedback_list:
            print("-" * 40)
            print("WORD-LEVEL ANALYSIS:")
            for word_info in detailed_feedback_list:
                error_indicator = f" [{word_info.error_type}]" if word_info.error_type != 'None' else ""
                translit_display = f" ({word_info.transliteration})" if word_info.transliteration else ""
                print(f"  '{word_info.word}'{translit_display}: {word_info.accuracy_score:.1f}%{error_indicator}")
        
        print("-" * 40)
        print("FEEDBACK:")
        print(f"  {word_feedback}")
        print("="*60)
        
        processing_end_time = time.time()
        processing_time_ms = int((processing_end_time - start_time) * 1000)
        logging.info(f"Total processing time: {processing_end_time - start_time:.2f} seconds.")
        
        # End tracking with success
        tracker.end_request(
            request_id=request_id,
            success=True,
            response_time_ms=processing_time_ms,
            pronunciation_score=pronunciation_score,
            accuracy_score=pron_result.accuracy_score,
            confidence_score=getattr(pron_result, 'confidence_score', None)
        )
        
        # Track successful pronunciation assessment to PostHog (legacy tracking)
        track_pronunciation_assessment_to_posthog(
            user_id=user_id,
            session_id=session_id,
            reference_text=reference_text,
            pronunciation_score=pronunciation_score,
            accuracy_score=pron_result.accuracy_score,
            processing_time_ms=processing_time_ms,
            item_type=item_type,
            complexity=complexity,
            success=True
        )
        
        return response

    except Exception as e:
        # Global exception handler for any unhandled errors
        logging.error(f"Unhandled error in pronunciation assessment: {e}")
        
        # End tracking with failure if we have access to tracker
        try:
            response_time_ms = int((time.time() - start_time) * 1000)
            tracker.end_request(
                request_id=request_id,
                success=False,
                response_time_ms=response_time_ms,
                error_code="UNHANDLED_ERROR",
                error_message=str(e)
            )
        except NameError:
            # tracker not defined (shouldn't happen, but safety check)
            logging.warning("Tracker not available for error tracking")
        except Exception as tracker_error:
            logging.warning(f"Failed to track error to Azure Speech Tracker: {tracker_error}")
        
        # Re-raise the original exception
        raise e
    
    finally:
        # Clean up the temporary file
        if temp_wav_file and os.path.exists(temp_wav_file):
            os.unlink(temp_wav_file)
            logging.info(f"Temporary file {temp_wav_file} deleted.")

def get_pronunciation_rating(score):
    """Converts a numerical score to a qualitative rating."""
    if score >= 90:
        return 'Excellent'
    elif score >= 75:
        return 'Good'
    elif score >= 60:
        return 'Okay'
    else:
        return 'Needs Improvement'

def calculate_multipliers(pronunciation_score, complexity, item_type, was_revealed):
    """
    Calculates attack and defense multipliers based on the Final Rubric v2.0.
    
    Attack Formula: Base × (1.0 + Pronunciation Bonus + Complexity Bonus - Reveal Penalty)
    Defense Formula: clamp(1.0 + Pronunciation Bonus + Complexity Bonus + Reveal Penalty, 0.1, 1.0)
    """
    
    # Determine pronunciation rating and bonuses
    if pronunciation_score >= 90:
        pronunciation_rating = "Excellent"
        pronunciation_bonus_attack = 0.6
        pronunciation_bonus_defense_regular = -0.5
        pronunciation_bonus_defense_special = -0.7
    elif pronunciation_score >= 75:
        pronunciation_rating = "Good"
        pronunciation_bonus_attack = 0.3
        pronunciation_bonus_defense_regular = -0.3
        pronunciation_bonus_defense_special = -0.5
    elif pronunciation_score >= 60:
        pronunciation_rating = "Okay"
        pronunciation_bonus_attack = 0.1
        pronunciation_bonus_defense_regular = -0.1
        pronunciation_bonus_defense_special = -0.25
    else:
        pronunciation_rating = "Needs Improvement"
        pronunciation_bonus_attack = 0.0
        pronunciation_bonus_defense_regular = 0.0
        pronunciation_bonus_defense_special = 0.0
    
    # Select defense bonus based on item type
    pronunciation_bonus_defense = pronunciation_bonus_defense_special if item_type == 'special' else pronunciation_bonus_defense_regular
    
    # Determine complexity bonuses (gated by pronunciation score >= 60)
    if pronunciation_score >= 60:
        # Attack complexity bonuses (additive)
        complexity_bonus_attack_map = {1: 0.0, 2: 0.15, 3: 0.3, 4: 0.45, 5: 0.6}
        complexity_bonus_attack = complexity_bonus_attack_map.get(complexity, 0.0)
        
        # Defense complexity bonuses (subtractive)
        complexity_bonus_defense_map = {1: 0.0, 2: -0.05, 3: -0.1, 4: -0.15, 5: -0.2}
        complexity_bonus_defense = complexity_bonus_defense_map.get(complexity, 0.0)
    else:
        complexity_bonus_attack = 0.0
        complexity_bonus_defense = 0.0
    
    # Determine reveal penalty
    reveal_penalty_attack = -0.2 if was_revealed else 0.0
    
    # New defense reveal penalty logic
    reveal_penalty_defense = 0.0
    if was_revealed:
        # Penalty negates bonuses, capped at 0.2 (20%).
        # Bonuses are negative, so we take their absolute value for the sum.
        total_bonus_reduction = abs(pronunciation_bonus_defense) + abs(complexity_bonus_defense)
        reveal_penalty_defense = min(total_bonus_reduction, 0.2)

    # Always use the original bonuses for calculation; the penalty will counteract them if revealed.
    final_pronunciation_bonus_defense = pronunciation_bonus_defense
    final_complexity_bonus_defense = complexity_bonus_defense
    
    # Calculate Attack Damage
    base_damage = 60.0 if item_type == 'special' else 50.0
    attack_multiplier = 1.0 + pronunciation_bonus_attack + complexity_bonus_attack + reveal_penalty_attack
    final_attack_damage = base_damage * attack_multiplier
    
    # Calculate Defense Multiplier (how much damage player takes)
    defense_multiplier_raw = 1.0 + final_pronunciation_bonus_defense + final_complexity_bonus_defense + reveal_penalty_defense
    final_defense_multiplier = max(0.1, min(1.0, defense_multiplier_raw))  # Clamp between 0.1 and 1.0
    
    # Create breakdown explanations
    attack_explanation = f"""Base Damage: {int(base_damage)}
Pronunciation Bonus ({pronunciation_rating}): {pronunciation_bonus_attack*100:+.0f}%
Complexity Bonus (Level {complexity}): {complexity_bonus_attack*100:+.0f}%
Card Reveal Penalty: {reveal_penalty_attack*100:.0f}%
Final Attack Multiplier: 1.0 + ({pronunciation_bonus_attack*100:.0f}% {complexity_bonus_attack*100:+.0f}% {reveal_penalty_attack*100:+.0f}%) = {attack_multiplier:.2f}
Final Attack Damage: {int(base_damage)} × {attack_multiplier:.2f} = {final_attack_damage:.1f}"""
    
    defense_item_type = "Special" if item_type == 'special' else "Regular"
    
    # Correctly formatted f-string for defense explanation
    p_bonus_str = f"{final_pronunciation_bonus_defense*100:.0f}%"
    c_bonus_str = f"{final_complexity_bonus_defense*100:.0f}%"
    r_penalty_str = f"{reveal_penalty_defense*100:+.0f}%"

    defense_explanation = f"""Pronunciation Bonus ({pronunciation_rating}, {defense_item_type}): {p_bonus_str}
Complexity Bonus (Level {complexity}): {c_bonus_str}
Card Reveal Penalty: {r_penalty_str}
Raw Defense Multiplier: 1.0 + ({p_bonus_str} + {c_bonus_str} + {r_penalty_str}) = {defense_multiplier_raw:.2f}
Final Defense Multiplier: clamp({defense_multiplier_raw:.2f}, 0.1, 1.0) = {final_defense_multiplier:.2f}"""
    
    calculation_breakdown = {
        "base_value": base_damage,
        "pronunciation_multiplier": 1 + pronunciation_bonus_attack,  # For backward compatibility
        "complexity_multiplier": 1 + complexity_bonus_attack,        # For backward compatibility
        "penalty": 1 + reveal_penalty_attack,                        # For backward compatibility
        "explanation": attack_explanation,  # Will be overridden based on turn type
        "attack_explanation": attack_explanation,
        "defense_explanation": defense_explanation,
        "attack_pronunciation_bonus": pronunciation_bonus_attack,
        "attack_complexity_bonus": complexity_bonus_attack,
        "defense_pronunciation_bonus": final_pronunciation_bonus_defense,
        "defense_complexity_bonus": final_complexity_bonus_defense,
        "attack_reveal_penalty": reveal_penalty_attack,
        "defense_reveal_penalty": reveal_penalty_defense,
        "final_attack_bonus": attack_multiplier,
        "final_defense_reduction": final_defense_multiplier
    }

    return final_attack_damage, final_defense_multiplier, calculation_breakdown

 