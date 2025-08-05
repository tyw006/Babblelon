import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;

/// Represents the assessment result for a single character tracing
class CharacterAssessmentResult {
  /// The character that was expected to be traced
  final String expectedCharacter;
  
  /// The text that was recognized by ML Kit
  final String recognizedText;
  
  /// The confidence score from ML Kit (lower is better)
  final double confidenceScore;
  
  /// All recognition candidates from ML Kit
  final List<mlkit.RecognitionCandidate> candidates;
  
  /// Whether the recognition was considered correct
  final bool isCorrect;
  
  /// Accuracy level: 'Excellent', 'Good', 'Needs Improvement', 'Failed'
  final String accuracyLevel;
  
  /// Numerical accuracy percentage (0-100)
  final double accuracyPercentage;
  
  /// Whether this character had any strokes traced
  final bool hasStrokes;

  const CharacterAssessmentResult({
    required this.expectedCharacter,
    required this.recognizedText,
    required this.confidenceScore,
    required this.candidates,
    required this.isCorrect,
    required this.accuracyLevel,
    required this.accuracyPercentage,
    required this.hasStrokes,
  });

  /// Factory constructor for when a character has no strokes
  factory CharacterAssessmentResult.noStrokes(String expectedCharacter) {
    return CharacterAssessmentResult(
      expectedCharacter: expectedCharacter,
      recognizedText: '',
      confidenceScore: 0.0,
      candidates: [],
      isCorrect: false,
      accuracyLevel: 'No Strokes',
      accuracyPercentage: 0.0,
      hasStrokes: false,
    );
  }

  /// Factory constructor for when ML Kit recognition fails
  factory CharacterAssessmentResult.recognitionFailed(String expectedCharacter) {
    return CharacterAssessmentResult(
      expectedCharacter: expectedCharacter,
      recognizedText: '',
      confidenceScore: 0.0,
      candidates: [],
      isCorrect: false,
      accuracyLevel: 'Failed',
      accuracyPercentage: 0.0,
      hasStrokes: true,
    );
  }

  /// Get color for UI display based on accuracy level
  int getDisplayColor() {
    switch (accuracyLevel) {
      case 'Excellent':
        return 0xFF4CAF50; // Green
      case 'Good':
        return 0xFF8BC34A; // Light Green
      case 'Needs Improvement':
        return 0xFFFF9800; // Orange
      case 'Failed':
        return 0xFFF44336; // Red
      case 'No Strokes':
        return 0xFF9E9E9E; // Gray
      default:
        return 0xFF9E9E9E; // Gray
    }
  }
}

/// Represents the overall assessment result for all character tracings
class TracingAssessmentResult {
  /// Assessment results for each character index
  final Map<int, CharacterAssessmentResult> characterResults;
  
  /// Overall accuracy percentage (0-100)
  final double overallAccuracy;
  
  /// Number of characters with correct recognition
  final int correctCount;
  
  /// Total number of characters assessed
  final int totalCount;
  
  /// Overall grade: S, A, B, C, D
  final String overallGrade;
  
  /// Whether any characters were traced
  final bool hasAnyStrokes;
  
  /// List of character indices that need practice
  final List<int> charactersThatNeedPractice;
  
  /// Optional transliteration for word breakdown
  final String? transliteration;
  
  /// Optional translation for word breakdown
  final String? translation;

  const TracingAssessmentResult({
    required this.characterResults,
    required this.overallAccuracy,
    required this.correctCount,
    required this.totalCount,
    required this.overallGrade,
    required this.hasAnyStrokes,
    required this.charactersThatNeedPractice,
    this.transliteration,
    this.translation,
  });

  /// Factory constructor to create assessment from character results
  factory TracingAssessmentResult.fromCharacterResults(
    Map<int, CharacterAssessmentResult> results, {
    String? transliteration,
    String? translation,
  }) {
    if (results.isEmpty) {
      return const TracingAssessmentResult(
        characterResults: {},
        overallAccuracy: 0.0,
        correctCount: 0,
        totalCount: 0,
        overallGrade: 'D',
        hasAnyStrokes: false,
        charactersThatNeedPractice: [],
        transliteration: null,
        translation: null,
      );
    }

    // Calculate overall stats
    final totalCount = results.length;
    final correctCount = results.values.where((r) => r.isCorrect).length;
    final hasAnyStrokes = results.values.any((r) => r.hasStrokes);
    final tracedCount = results.values.where((r) => r.hasStrokes).length;
    
    // Calculate overall accuracy with strict penalties for untraced characters
    double overallAccuracy = 0.0;
    
    if (totalCount > 0) {
      // Base completion penalty: start with completion rate
      final completionRate = tracedCount / totalCount;
      
      // Calculate average accuracy of traced characters only
      double tracedAccuracy = 0.0;
      if (tracedCount > 0) {
        final tracedResults = results.values.where((r) => r.hasStrokes);
        final totalTracedAccuracy = tracedResults
            .map((r) => r.accuracyPercentage)
            .reduce((a, b) => a + b);
        tracedAccuracy = totalTracedAccuracy / tracedCount;
      }
      
      // Apply strict completion penalty
      // - If less than 50% traced: maximum 30% overall score
      // - If less than 80% traced: maximum 60% overall score
      // - Full score only available when 100% traced
      
      if (completionRate < 0.5) {
        // Less than half traced - severe penalty
        overallAccuracy = (tracedAccuracy * completionRate * 0.6).clamp(0.0, 30.0);
      } else if (completionRate < 0.8) {
        // Less than 80% traced - moderate penalty
        overallAccuracy = (tracedAccuracy * completionRate * 0.75).clamp(0.0, 60.0);
      } else if (completionRate < 1.0) {
        // Almost complete - small penalty
        overallAccuracy = (tracedAccuracy * completionRate * 0.9).clamp(0.0, 85.0);
      } else {
        // All characters traced - use traced accuracy
        overallAccuracy = tracedAccuracy;
      }
    }
    
    // Determine overall grade
    final overallGrade = _calculateGrade(overallAccuracy);
    
    // Find characters that need practice (accuracy < 60% or not traced)
    final charactersThatNeedPractice = results.entries
        .where((entry) => entry.value.accuracyPercentage < 60.0 || !entry.value.hasStrokes)
        .map((entry) => entry.key)
        .toList();

    return TracingAssessmentResult(
      characterResults: results,
      overallAccuracy: overallAccuracy,
      correctCount: correctCount,
      totalCount: totalCount,
      overallGrade: overallGrade,
      hasAnyStrokes: hasAnyStrokes,
      charactersThatNeedPractice: charactersThatNeedPractice,
      transliteration: transliteration,
      translation: translation,
    );
  }

  /// Calculate grade based on accuracy percentage - more strict grading
  static String _calculateGrade(double accuracy) {
    if (accuracy >= 90.0) return 'S'; // Raised from 95% to 90%
    if (accuracy >= 75.0) return 'A'; // Raised from 85% to 75%
    if (accuracy >= 60.0) return 'B'; // Raised from 75% to 60%
    if (accuracy >= 40.0) return 'C'; // Raised from 65% to 40%
    return 'D';
  }

  /// Get color for overall grade display
  int getGradeColor() {
    switch (overallGrade) {
      case 'S':
        return 0xFFFFD700; // Gold
      case 'A':
        return 0xFF4CAF50; // Green
      case 'B':
        return 0xFF8BC34A; // Light Green
      case 'C':
        return 0xFFFF9800; // Orange
      case 'D':
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Gray
    }
  }

  /// Get the number of characters that were traced
  int getTracedCount() {
    return characterResults.values.where((r) => r.hasStrokes).length;
  }

  /// Get the number of characters that were not traced
  int getUntracedCount() {
    return characterResults.values.where((r) => !r.hasStrokes).length;
  }
}