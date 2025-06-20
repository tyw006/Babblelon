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

load_dotenv()

# --- Pydantic Models ---

class PronunciationAssessmentRequest(BaseModel):
    reference_text: str
    transliteration: str
    complexity: int
    item_type: str
    turn_type: str
    was_revealed: bool = False
    word_mapping: List[Dict[str, str]] = []

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
    word_mapping: List[Dict[str, str]],
    language: str = "th-TH"
) -> PronunciationAssessmentResponse:
    """
    Assesses pronunciation from audio bytes using Azure Speech SDK, calculates game logic,
    and returns a detailed response. Includes latency logging.
    """
    start_time = time.time()
    temp_wav_file = None
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
            raise ConnectionError(f"Azure Speech service error: {cancellation_details.reason}. Details: {cancellation_details.error_details}")
        if result.reason == speechsdk.ResultReason.NoMatch:
            raise ValueError("Speech could not be recognized. Please try again with clearer audio.")
        
        if result.reason != speechsdk.ResultReason.RecognizedSpeech:
            raise ValueError(f"Recognition failed with reason: {result.reason}")

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
        translit_map = {word['thai']: word['transliteration'] for word in word_mapping}

        if 'NBest' in json_result and len(json_result['NBest']) > 0:
            words_data = json_result['NBest'][0].get('Words', [])
            for word_info in words_data:
                word_text = word_info.get('Word', 'N/A')
                w_res = WordFeedback(
                    word=word_text,
                    accuracy_score=word_info.get('PronunciationAssessment', {}).get('AccuracyScore', 0),
                    error_type=word_info.get('PronunciationAssessment', {}).get('ErrorType', 'None'),
                    transliteration=translit_map.get(word_text, '')
                )
                detailed_feedback_list.append(w_res)

        # --- Generate Actionable Word-Level Feedback ---
        detailed_feedback_list.sort(key=lambda x: x.accuracy_score)
        worst_words = [w for w in detailed_feedback_list if w.accuracy_score < 80][:3]
        
        feedback_lines = []
        if worst_words:
            feedback_lines.append("To improve, focus on these words:")
            for word in worst_words:
                feedback_entry = f"- '{word.word}'"
                if word.transliteration:
                    feedback_entry += f" ({word.transliteration})"
                feedback_entry += f" - accuracy: {word.accuracy_score:.0f}%"
                feedback_lines.append(feedback_entry)

            if len(worst_words) < len(detailed_feedback_list):
                best_word = max(detailed_feedback_list, key=lambda x: x.accuracy_score)
                best_word_text = f"'{best_word.word}'"
                if best_word.transliteration:
                    best_word_text += f" ({best_word.transliteration})"
                feedback_lines.append(f"You nailed {best_word_text} - great job!")
        
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
        
        processing_end_time = time.time()
        logging.info(f"Total processing time: {processing_end_time - start_time:.2f} seconds.")
        
        return response

    finally:
        # Clean up the temporary file
        if temp_wav_file and os.path.exists(temp_wav_file):
            os.unlink(temp_wav_file)
            logging.info(f"Temporary file {temp_wav_file} deleted.")

def get_pronunciation_rating(score):
    """Converts a numerical score to a qualitative rating."""
    if score > 90:
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
    reveal_penalty_attack = -0.2 if was_revealed else 0.0  # Reduces attack effectiveness
    reveal_penalty_defense = 0.2 if was_revealed else 0.0  # Reduces defense effectiveness
    
    # Calculate Attack Damage
    base_damage = 50.0 if item_type == 'special' else 40.0
    attack_multiplier = 1.0 + pronunciation_bonus_attack + complexity_bonus_attack + reveal_penalty_attack
    final_attack_damage = base_damage * attack_multiplier
    
    # Calculate Defense Multiplier (how much damage player takes)
    defense_multiplier_raw = 1.0 + pronunciation_bonus_defense + complexity_bonus_defense + reveal_penalty_defense
    final_defense_multiplier = max(0.1, min(1.0, defense_multiplier_raw))  # Clamp between 0.1 and 1.0
    
    # Create breakdown explanations
    attack_explanation = f"""Base Damage: {int(base_damage)}
Pronunciation Bonus ({pronunciation_rating}): {'+' if pronunciation_bonus_attack >= 0 else ''}{pronunciation_bonus_attack*100:.0f}%
Complexity Bonus (Level {complexity}): {'+' if complexity_bonus_attack >= 0 else ''}{complexity_bonus_attack*100:.0f}%
Card Reveal Penalty: {'+' if reveal_penalty_attack >= 0 else ''}{reveal_penalty_attack*100:.0f}%
Final Attack Multiplier: 1.0 + ({'+' if pronunciation_bonus_attack >= 0 else ''}{pronunciation_bonus_attack*100:.0f}% + {'+' if complexity_bonus_attack >= 0 else ''}{complexity_bonus_attack*100:.0f}% + {'+' if reveal_penalty_attack >= 0 else ''}{reveal_penalty_attack*100:.0f}%) = {attack_multiplier:.2f}
Final Attack Damage: {int(base_damage)} × {attack_multiplier:.2f} = {final_attack_damage:.1f}"""
    
    defense_item_type = "Special" if item_type == 'special' else "Regular"
    defense_explanation = f"""Pronunciation Bonus ({pronunciation_rating}, {defense_item_type}): {pronunciation_bonus_defense*100:.0f}%
Complexity Bonus (Level {complexity}): {complexity_bonus_defense*100:.0f}%
Card Reveal Penalty: {'+' if reveal_penalty_defense >= 0 else ''}{reveal_penalty_defense*100:.0f}%
Raw Defense Multiplier: 1.0 + ({pronunciation_bonus_defense*100:.0f}% + {complexity_bonus_defense*100:.0f}% + {'+' if reveal_penalty_defense >= 0 else ''}{reveal_penalty_defense*100:.0f}%) = {defense_multiplier_raw:.2f}
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
        "defense_pronunciation_bonus": pronunciation_bonus_defense,
        "defense_complexity_bonus": complexity_bonus_defense,
        "card_reveal_penalty": reveal_penalty_attack,
        "final_attack_bonus": attack_multiplier,
        "final_defense_reduction": final_defense_multiplier
    }

    return final_attack_damage, final_defense_multiplier, calculation_breakdown

 