import 'package:flutter/foundation.dart';

class PronunciationAssessmentResponse {
  final String rating;
  final double pronunciationScore;
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double attackMultiplier;
  final double defenseMultiplier;
  final List<WordResult> wordResults;
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
    required this.wordResults,
    required this.wordFeedback,
    required this.calculationBreakdown,
  });

  factory PronunciationAssessmentResponse.fromJson(Map<String, dynamic> json) {
    return PronunciationAssessmentResponse(
      rating: json['rating'] ?? 'N/A',
      pronunciationScore: (json['pronunciation_score'] ?? 0.0).toDouble(),
      accuracyScore: (json['accuracy_score'] ?? 0.0).toDouble(),
      fluencyScore: (json['fluency_score'] ?? 0.0).toDouble(),
      completenessScore: (json['completeness_score'] ?? 0.0).toDouble(),
      attackMultiplier: (json['attack_multiplier'] ?? 0.0).toDouble(),
      defenseMultiplier: (json['defense_multiplier'] ?? 0.0).toDouble(),
      wordResults: (json['word_results'] as List<dynamic>?)
          ?.map((wordJson) => WordResult.fromJson(wordJson))
          .toList() ?? [],
      wordFeedback: json['word_feedback'] ?? '',
      calculationBreakdown: DamageCalculationBreakdown.fromJson(json['calculation_breakdown'] ?? {}),
    );
  }
}

class WordResult {
  final String word;
  final double accuracyScore;
  final String errorType;

  WordResult({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
  });

  factory WordResult.fromJson(Map<String, dynamic> json) {
    return WordResult(
      word: json['word'] ?? 'N/A',
      accuracyScore: (json['accuracy_score'] ?? 0.0).toDouble(),
      errorType: json['error_type'] ?? 'None',
    );
  }
}



class DamageCalculationBreakdown {
  final double baseAttack;
  final double pronunciationMultiplier;
  final double complexityMultiplier;
  final double finalAttackMultiplier;
  final double finalDefenseMultiplier;

  DamageCalculationBreakdown({
    required this.baseAttack,
    required this.pronunciationMultiplier,
    required this.complexityMultiplier,
    required this.finalAttackMultiplier,
    required this.finalDefenseMultiplier,
  });

  factory DamageCalculationBreakdown.fromJson(Map<String, dynamic> json) {
    return DamageCalculationBreakdown(
      baseAttack: (json['base_attack'] ?? 0.0).toDouble(),
      pronunciationMultiplier: (json['pronunciation_multiplier'] ?? 0.0).toDouble(),
      complexityMultiplier: (json['complexity_multiplier'] ?? 0.0).toDouble(),
      finalAttackMultiplier: (json['final_attack_multiplier'] ?? 0.0).toDouble(),
      finalDefenseMultiplier: (json['final_defense_multiplier'] ?? 0.0).toDouble(),
    );
  }
} 