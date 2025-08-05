import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import '../models/character_assessment_model.dart';

/// Service for character recognition and assessment using ML Kit Digital Ink Recognition
class CharacterRecognitionService {
  mlkit.DigitalInkRecognizer? _recognizer;
  bool _isInitialized = false;

  /// Initialize the ML Kit recognizer
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create recognizer for Thai language only
      _recognizer = mlkit.DigitalInkRecognizer(languageCode: 'th');
      _isInitialized = true;
      
      print('✅ Character recognition service initialized with Thai model');
    } catch (e) {
      print('❌ Failed to initialize Thai character recognition: $e');
      rethrow;
    }
  }

  /// Assess a single character tracing
  Future<CharacterAssessmentResult> assessCharacter(
    mlkit.Ink ink, 
    String expectedCharacter,
  ) async {
    // Ensure service is initialized
    if (!_isInitialized) {
      await initialize();
    }

    // Check if ink has any strokes
    if (ink.strokes.isEmpty) {
      return CharacterAssessmentResult.noStrokes(expectedCharacter);
    }

    if (_recognizer == null) {
      return CharacterAssessmentResult.recognitionFailed(expectedCharacter);
    }

    try {
      // Perform recognition
      final candidates = await _recognizer!.recognize(ink);
      
      if (candidates.isEmpty) {
        return CharacterAssessmentResult.recognitionFailed(expectedCharacter);
      }

      // Get the best candidate
      final bestCandidate = candidates.first;
      final recognizedText = bestCandidate.text;
      final confidenceScore = bestCandidate.score ?? 0.0;

      // Assess accuracy
      final assessment = _assessAccuracy(
        expectedCharacter, 
        recognizedText, 
        confidenceScore,
      );

      return CharacterAssessmentResult(
        expectedCharacter: expectedCharacter,
        recognizedText: recognizedText,
        confidenceScore: confidenceScore,
        candidates: candidates,
        isCorrect: assessment['isCorrect'],
        accuracyLevel: assessment['accuracyLevel'],
        accuracyPercentage: assessment['accuracyPercentage'],
        hasStrokes: true,
      );

    } catch (e) {
      print('❌ Character recognition error: $e');
      return CharacterAssessmentResult.recognitionFailed(expectedCharacter);
    }
  }

  /// Assess multiple characters and create overall assessment
  Future<TracingAssessmentResult> assessAllCharacters(
    Map<int, mlkit.Ink> characterInks,
    List<String> expectedCharacters,
  ) async {
    final characterResults = <int, CharacterAssessmentResult>{};

    // Assess each character
    for (int i = 0; i < expectedCharacters.length; i++) {
      final expectedChar = expectedCharacters[i];
      final ink = characterInks[i];

      if (ink != null) {
        characterResults[i] = await assessCharacter(ink, expectedChar);
      } else {
        characterResults[i] = CharacterAssessmentResult.noStrokes(expectedChar);
      }
    }

    return TracingAssessmentResult.fromCharacterResults(characterResults);
  }

  /// Assess accuracy based on expected vs recognized character
  Map<String, dynamic> _assessAccuracy(
    String expected, 
    String recognized, 
    double confidenceScore,
  ) {
    // Normalize strings for comparison
    final expectedNorm = expected.trim().toLowerCase();
    final recognizedNorm = recognized.trim().toLowerCase();

    bool isCorrect = false;
    String accuracyLevel = 'Failed';
    double accuracyPercentage = 0.0;

    // Exact match - highest score
    if (expectedNorm == recognizedNorm) {
      isCorrect = true;
      accuracyLevel = 'Excellent';
      accuracyPercentage = 100.0;
    }
    // Partial match - much more strict scoring
    else if (recognizedNorm.contains(expectedNorm) || expectedNorm.contains(recognizedNorm)) {
      isCorrect = false; // Partial matches are not "correct"
      accuracyLevel = 'Needs Improvement';
      accuracyPercentage = 45.0; // Reduced from 75% to 45%
    }
    // Similar characters (for Thai script fallbacks)
    else if (_areSimilarCharacters(expectedNorm, recognizedNorm)) {
      isCorrect = false;
      accuracyLevel = 'Needs Improvement';
      accuracyPercentage = 25.0; // Reduced from 60% to 25%
    }
    // No match
    else {
      isCorrect = false;
      accuracyLevel = 'Failed';
      accuracyPercentage = 0.0;
    }

    // Adjust based on confidence score (lower is better for ML Kit)
    // Confidence scores typically range from -5.0 to 5.0
    if (accuracyPercentage > 0 && confidenceScore != 0.0) {
      if (confidenceScore < -2.0) {
        // Very confident, boost score slightly
        accuracyPercentage = _clampPercentage(accuracyPercentage * 1.1);
      } else if (confidenceScore < -1.0) {
        // Somewhat confident, keep score
        accuracyPercentage = accuracyPercentage;
      } else if (confidenceScore < 1.0) {
        // Low confidence, reduce score
        accuracyPercentage = _clampPercentage(accuracyPercentage * 0.8);
      } else {
        // Very low confidence, significantly reduce score
        accuracyPercentage = _clampPercentage(accuracyPercentage * 0.5);
      }
    }

    // Only exact matches with high confidence are considered "correct"
    if (expectedNorm == recognizedNorm && confidenceScore < -1.0) {
      isCorrect = true;
    }

    return {
      'isCorrect': isCorrect,
      'accuracyLevel': accuracyLevel,
      'accuracyPercentage': accuracyPercentage,
    };
  }

  /// Check if characters are similar (for fuzzy matching)
  bool _areSimilarCharacters(String char1, String char2) {
    // This is a simplified similarity check
    // In a real implementation, you might use more sophisticated 
    // character similarity algorithms for Thai script
    
    if (char1.isEmpty || char2.isEmpty) return false;
    
    // Check first character similarity
    final first1 = char1[0];
    final first2 = char2[0];
    
    // Simple ASCII distance check
    return (first1.codeUnitAt(0) - first2.codeUnitAt(0)).abs() <= 2;
  }

  /// Clamp percentage to valid range
  double _clampPercentage(double percentage) {
    return percentage.clamp(0.0, 100.0);
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      await _recognizer?.close();
      _recognizer = null;
      _isInitialized = false;
      print('✅ Character recognition service disposed');
    } catch (e) {
      print('⚠️ Error disposing character recognition service: $e');
    }
  }
}

/// Singleton instance for easy access throughout the app
final characterRecognitionService = CharacterRecognitionService();