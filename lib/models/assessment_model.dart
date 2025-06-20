import 'package:flutter/foundation.dart';

class PronunciationAssessmentResponse {
  final String rating;
  final double pronunciationScore;
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double attackMultiplier;
  final double defenseMultiplier;
  final List<WordFeedback> detailedFeedback;
  final String wordFeedback;
  final DamageCalculationBreakdown calculationBreakdown;

  PronunciationAssessmentResponse({
    required this.rating,
    required this.pronunciationScore,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.attackMultiplier,
    required this.defenseMultiplier,
    required this.detailedFeedback,
    required this.wordFeedback,
    required this.calculationBreakdown,
  });

  factory PronunciationAssessmentResponse.fromJson(Map<String, dynamic> json) {
    var detailedFeedbackList = (json['detailed_feedback'] as List<dynamic>?)
        ?.map((wordJson) => WordFeedback.fromJson(wordJson))
        .toList() ?? [];

    // Fallback for old `word_results` key
    if (detailedFeedbackList.isEmpty && json.containsKey('word_results')) {
       detailedFeedbackList = (json['word_results'] as List<dynamic>?)
          ?.map((wordJson) => WordFeedback.fromOldJson(wordJson))
          .toList() ?? [];
    }

    return PronunciationAssessmentResponse(
      rating: json['rating'] ?? 'N/A',
      pronunciationScore: (json['pronunciation_score'] ?? 0.0).toDouble(),
      accuracyScore: (json['accuracy_score'] ?? 0.0).toDouble(),
      fluencyScore: (json['fluency_score'] ?? 0.0).toDouble(),
      completenessScore: (json['completeness_score'] ?? 0.0).toDouble(),
      attackMultiplier: (json['attack_multiplier'] ?? 1.0).toDouble(),
      defenseMultiplier: (json['defense_multiplier'] ?? 1.0).toDouble(),
      detailedFeedback: detailedFeedbackList,
      wordFeedback: json['word_feedback'] ?? '',
      calculationBreakdown: DamageCalculationBreakdown.fromJson(json['calculation_breakdown'] ?? {}),
    );
  }
}

class WordFeedback {
  final String word;
  final double accuracyScore;
  final String errorType;
  final String transliteration;

  WordFeedback({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
    required this.transliteration,
  });

  factory WordFeedback.fromJson(Map<String, dynamic> json) {
    return WordFeedback(
      word: json['word'] ?? 'N/A',
      accuracyScore: (json['accuracy_score'] ?? 0.0).toDouble(),
      errorType: json['error_type'] ?? 'None',
      transliteration: json['transliteration'] ?? '',
    );
  }

  // Factory for old `WordResult` structure
  factory WordFeedback.fromOldJson(Map<String, dynamic> json) {
    return WordFeedback(
      word: json['word'] ?? 'N/A',
      accuracyScore: (json['accuracy_score'] ?? 0.0).toDouble(),
      errorType: json['error_type'] ?? 'None',
      transliteration: '', // Old format didn't have this
    );
  }
}

class DamageCalculationBreakdown {
  final double baseValue;
  final double pronunciationMultiplier;
  final double complexityMultiplier;
  final double itemMultiplier;
  final double penalty;
  final String explanation;
  
  // New detailed breakdown fields
  final String? attackExplanation;
  final String? defenseExplanation;
  final double? attackPronunciationBonus;
  final double? attackComplexityBonus;
  final double? defensePronunciationBonus;
  final double? defenseComplexityBonus;
  final double? cardRevealPenalty;
  final double? finalAttackBonus;
  final double? finalDefenseReduction;

  DamageCalculationBreakdown({
    required this.baseValue,
    required this.pronunciationMultiplier,
    required this.complexityMultiplier,
    required this.itemMultiplier,
    required this.penalty,
    required this.explanation,
    this.attackExplanation,
    this.defenseExplanation,
    this.attackPronunciationBonus,
    this.attackComplexityBonus,
    this.defensePronunciationBonus,
    this.defenseComplexityBonus,
    this.cardRevealPenalty,
    this.finalAttackBonus,
    this.finalDefenseReduction,
  });

  factory DamageCalculationBreakdown.fromJson(Map<String, dynamic> json) {
    return DamageCalculationBreakdown(
      baseValue: (json['base_value'] ?? 20.0).toDouble(),
      pronunciationMultiplier: (json['pronunciation_multiplier'] ?? 1.0).toDouble(),
      complexityMultiplier: (json['complexity_multiplier'] ?? 1.0).toDouble(),
      itemMultiplier: (json['item_multiplier'] ?? 1.0).toDouble(),
      penalty: (json['penalty'] ?? 0.0).toDouble(),
      explanation: json['explanation'] ?? 'No explanation provided.',
      attackExplanation: json['attack_explanation'],
      defenseExplanation: json['defense_explanation'],
      attackPronunciationBonus: json['attack_pronunciation_bonus']?.toDouble(),
      attackComplexityBonus: json['attack_complexity_bonus']?.toDouble(),
      defensePronunciationBonus: json['defense_pronunciation_bonus']?.toDouble(),
      defenseComplexityBonus: json['defense_complexity_bonus']?.toDouble(),
      cardRevealPenalty: json['card_reveal_penalty']?.toDouble(),
      finalAttackBonus: json['final_attack_bonus']?.toDouble(),
      finalDefenseReduction: json['final_defense_reduction']?.toDouble(),
    );
  }
} 