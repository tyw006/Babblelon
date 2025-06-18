import os
import json
import asyncio
import time
import logging
from pydantic import BaseModel
from typing import List, Dict, Any
import azure.cognitiveservices.speech as speechsdk

# --- Pydantic Models ---

class PronunciationAssessmentRequest(BaseModel):
    reference_text: str
    transliteration: str
    complexity: str
    item_type: str
    turn_type: str
    was_revealed: bool = False

class WordResult(BaseModel):
    word: str
    accuracy_score: float
    error_type: str

class DamageCalculationBreakdown(BaseModel):
    base_attack: float
    pronunciation_multiplier: float
    complexity_multiplier: float
    defense_effect_multiplier: float
    final_attack_multiplier: float
    final_defense_multiplier: float

class PronunciationAssessmentResponse(BaseModel):
    rating: str
    pronunciation_score: float
    accuracy_score: float
    fluency_score: float
    completeness_score: float
    attack_multiplier: float
    defense_multiplier: float
    word_results: List[WordResult]
    word_feedback: str
    calculation_breakdown: DamageCalculationBreakdown


# --- Service Logic ---

async def assess_pronunciation(
    audio_bytes: bytes,
    reference_text: str,
    transliteration: str,
    complexity: str,
    item_type: str,
    turn_type: str,
    was_revealed: bool,
    language: str = "th-TH"
) -> PronunciationAssessmentResponse:
    """
    Assesses pronunciation from audio bytes using Azure Speech SDK, calculates game logic,
    and returns a detailed response. Includes latency logging.
    """
    start_time = time.time()
    logging.info(f"Received pronunciation assessment request for turn: {turn_type}")
    
    # --- 1. Setup Azure Speech Configuration ---
    speech_key = os.getenv("AZURE_SPEECH_KEY")
    speech_region = os.getenv("AZURE_SPEECH_REGION")
    if not speech_key or not speech_region:
        raise ValueError("Azure Speech API credentials are not configured in environment variables.")

    speech_config = speechsdk.SpeechConfig(subscription=speech_key, region=speech_region)
    speech_config.speech_recognition_language = language

    # --- 2. Setup Audio Configuration from Bytes ---
    # Create an in-memory audio stream from the uploaded bytes
    push_stream = speechsdk.audio.PushAudioInputStream()
    audio_config = speechsdk.audio.AudioConfig(stream=push_stream)
    push_stream.write(audio_bytes)
    push_stream.close() # Signal that we are done sending audio

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
    result = await asyncio.get_event_loop().run_in_executor(None, recognizer.recognize_once)
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
    json_result = json.loads(result.properties.get(speechsdk.PropertyId.SpeechServiceResponse_JsonResult))
    
    # --- Game Logic Calculations ---
    pronunciation_score = pron_result.pronunciation_score

    # Determine complexity multiplier
    if complexity.lower() == 'simple':
        complexity_multiplier = 1.0
    elif complexity.lower() == 'medium':
        complexity_multiplier = 1.2
    elif complexity.lower() == 'complex':
        complexity_multiplier = 1.4
    else:
        complexity_multiplier = 1.0 # Default to simple if invalid

    # Determine pronunciation multiplier
    if pronunciation_score > 90:
        rating = "Excellent"
        pronunciation_multiplier = 1.5
        defense_effect_multiplier = 0.5 # Takes 50% damage
    elif 75 <= pronunciation_score <= 89:
        rating = "Good"
        pronunciation_multiplier = 1.2
        defense_effect_multiplier = 0.8 # Takes 80% damage
    else:
        rating = "Okay"
        pronunciation_multiplier = 1.0
        defense_effect_multiplier = 1.0 # Takes 100% damage

    base_attack = 75.0 if item_type.lower() == "special" else 50.0
    
    # --- Final calculation based on turn type ---
    if turn_type.lower() == 'attack':
        final_attack_multiplier = base_attack * pronunciation_multiplier * complexity_multiplier
        final_defense_multiplier = 1.0 # Not a defense turn, so no damage reduction
    elif turn_type.lower() == 'defense':
        final_attack_multiplier = 0 # No attack bonus on defense turn
        # Higher complexity should increase damage reduction (lower multiplier)
        final_defense_multiplier = defense_effect_multiplier / complexity_multiplier if complexity_multiplier > 0 else defense_effect_multiplier
    else: # Default case if turn_type is invalid
        final_attack_multiplier = base_attack
        final_defense_multiplier = 1.0

    # Apply penalty if the card was revealed by the player
    if was_revealed:
        logging.info("Applying penalty because card was revealed.")
        if turn_type.lower() == 'attack':
            final_attack_multiplier *= 0.8 # 20% penalty
        elif turn_type.lower() == 'defense':
            final_defense_multiplier *= 1.2 # Takes 20% more damage

    # --- Detailed Word Analysis ---
    word_results_list = []
    if 'NBest' in json_result and len(json_result['NBest']) > 0:
        words_data = json_result['NBest'][0].get('Words', [])
        for word_info in words_data:
            w_res = WordResult(
                word=word_info.get('Word', 'N/A'),
                accuracy_score=word_info.get('PronunciationAssessment', {}).get('AccuracyScore', 0),
                error_type=word_info.get('PronunciationAssessment', {}).get('ErrorType', 'None')
            )
            word_results_list.append(w_res)

    # --- Generate Actionable Word-Level Feedback ---
    word_results_list.sort(key=lambda x: x.accuracy_score)
    worst_words = [w for w in word_results_list if w.accuracy_score < 80][:3]
    
    feedback_lines = []
    if worst_words:
        feedback_lines.append("To improve, focus on these words:")
        feedback_lines.append(f"In the phrase '{transliteration}':")
        for word in worst_words:
            feedback_lines.append(f"- '{word.word}' (accuracy: {word.accuracy_score:.0f}%)")
        if len(worst_words) < len(word_results_list):
            best_word = max(word_results_list, key=lambda x: x.accuracy_score)
            feedback_lines.append(f"You nailed '{best_word.word}' - great job!")
    
    word_feedback = " ".join(feedback_lines) if feedback_lines else "Great job! Your pronunciation is solid."
    
    # --- Construct Final Response ---
    calculation_breakdown = DamageCalculationBreakdown(
        base_attack=base_attack,
        pronunciation_multiplier=pronunciation_multiplier,
        complexity_multiplier=complexity_multiplier,
        defense_effect_multiplier=defense_effect_multiplier,
        final_attack_multiplier=final_attack_multiplier,
        final_defense_multiplier=final_defense_multiplier,
    )

    end_time = time.time()
    logging.info(f"Total processing time: {end_time - start_time:.2f} seconds.")
    return PronunciationAssessmentResponse(
        rating=rating,
        pronunciation_score=pron_result.pronunciation_score,
        accuracy_score=pron_result.accuracy_score,
        fluency_score=pron_result.fluency_score,
        completeness_score=pron_result.completeness_score,
        attack_multiplier=final_attack_multiplier,
        defense_multiplier=final_defense_multiplier,
        word_results=word_results_list,
        word_feedback=word_feedback,
        calculation_breakdown=calculation_breakdown
    ) 