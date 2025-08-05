import 'dart:math' as math;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;

/// Handles stroke order validation and character writing analysis for Thai characters
class StrokeOrderValidator {
  // Stroke tracking
  List<List<mlkit.StrokePoint>> _completedStrokes = [];
  Map<String, int> _characterMistakes = {};
  List<String> _strokeOrderHints = [];
  int _currentStrokeCount = 0;
  final double _strokeSpeedThreshold = 50.0; // pixels per second
  final double _strokeSmoothnessTolerance = 10.0; // deviation tolerance
  DateTime? _strokeStartTime;
  List<double> _strokeSpeeds = [];
  List<double> _strokeLengths = [];

  // Getters
  List<String> get strokeOrderHints => _strokeOrderHints;
  Map<String, int> get characterMistakes => _characterMistakes;
  int get currentStrokeCount => _currentStrokeCount;

  /// Reset all tracking data
  void reset() {
    _completedStrokes.clear();
    _currentStrokeCount = 0;
    _strokeSpeeds.clear();
    _strokeLengths.clear();
    _strokeOrderHints.clear();
    _strokeStartTime = null;
  }

  /// Called when a stroke starts
  void onStrokeStart(String character) {
    _strokeStartTime = DateTime.now();
    _currentStrokeCount++;
    _strokeOrderHints = getStrokeOrderHints(character, _currentStrokeCount);
  }

  /// Analyze stroke metrics for quality feedback
  void analyzeStrokeMetrics(mlkit.Stroke stroke) {
    if (stroke.points.length < 2) return;
    
    double totalDistance = 0.0;
    double totalTime = 0.0;
    
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      
      final distance = math.sqrt(
        math.pow(p2.x - p1.x, 2) + math.pow(p2.y - p1.y, 2)
      );
      totalDistance += distance;
      totalTime = (p2.t - stroke.points.first.t).toDouble();
    }
    
    if (totalTime > 0) {
      final speed = totalDistance / (totalTime / 1000); // pixels per second
      _strokeSpeeds.add(speed);
      _strokeLengths.add(totalDistance);
      
      // Check for stroke quality issues
      if (speed > _strokeSpeedThreshold * 2) {
        _trackMistake('too_fast');
      } else if (speed < _strokeSpeedThreshold * 0.3) {
        _trackMistake('too_slow');
      }
    }
  }

  /// Validate stroke order based on Thai writing principles
  void validateStrokeOrder(String character) {
    // Check stroke order based on Thai writing principles
    final expectedStrokeCount = getExpectedStrokeCount(character);
    if (_currentStrokeCount > expectedStrokeCount) {
      _trackMistake('too_many_strokes');
    }
    
    // Check if stroke follows general Thai writing patterns
    if (!isStrokeOrderCorrect(character, _currentStrokeCount)) {
      _trackMistake('incorrect_order');
    }
  }

  /// Track mistake and update hints
  void _trackMistake(String mistakeType) {
    final mistakeKey = '${mistakeType}_${_currentStrokeCount}';
    _characterMistakes[mistakeKey] = (_characterMistakes[mistakeKey] ?? 0) + 1;
    _updateStrokeOrderHints(mistakeType);
  }

  /// Get stroke order hints for specific character and stroke number
  List<String> getStrokeOrderHints(String character, int strokeNumber) {
    final hints = <String>[];
    
    switch (character) {
      case 'ก': // 'k' sound
        if (strokeNumber == 1) hints.add('Start with the top horizontal line');
        if (strokeNumber == 2) hints.add('Draw the vertical line downward');
        break;
      case 'ข': // 'kh' sound  
        if (strokeNumber == 1) hints.add('Begin with the loop at top');
        if (strokeNumber == 2) hints.add('Add the tail extending right');
        break;
      case 'น': // 'n' sound
        if (strokeNumber == 1) hints.add('Start with the curved bowl shape');
        if (strokeNumber == 2) hints.add('Add the small hook on the right');
        break;
      case 'ม': // 'm' sound
        if (strokeNumber == 1) hints.add('Draw the left vertical line first');
        if (strokeNumber == 2) hints.add('Add the curved connection');
        if (strokeNumber == 3) hints.add('Finish with right vertical line');
        break;
      case 'หมึก': // 'ink/squid' - for compound characters
        hints.add('Write characters left to right: ห → ม → ึ → ก');
        break;
      default:
        hints.add('Follow Thai writing order: circles first, then lines');
        hints.add('Write from top to bottom, left to right');
    }
    
    return hints;
  }

  /// Get expected stroke count for Thai characters
  int getExpectedStrokeCount(String character) {
    switch (character) {
      case 'ก': case 'ด': case 'ต': case 'น': case 'บ': case 'ป': case 'ผ': case 'ฝ': case 'พ': case 'ฟ': case 'ม': case 'ย': case 'ร': case 'ล': case 'ว': case 'ส': case 'ห': case 'อ':
        return 2;
      case 'ข': case 'ฃ': case 'ค': case 'ฅ': case 'ฆ': case 'ง': case 'จ': case 'ฉ': case 'ช': case 'ซ': case 'ฌ': case 'ญ': case 'ฎ': case 'ฏ': case 'ฐ': case 'ฑ': case 'ฒ': case 'ณ': case 'ถ': case 'ท': case 'ธ': case 'ภ': case 'ฬ': case 'ฮ':
        return 3;
      default:
        return 2; // Default assumption
    }
  }

  /// Check if stroke order is correct (simplified validation)
  bool isStrokeOrderCorrect(String character, int strokeNumber) {
    return strokeNumber <= getExpectedStrokeCount(character);
  }

  /// Update stroke order hints based on mistake type
  void _updateStrokeOrderHints(String mistakeType) {
    switch (mistakeType) {
      case 'too_fast':
        _strokeOrderHints.add('⚠️ Try writing more slowly for better control');
        break;
      case 'too_slow':
        _strokeOrderHints.add('💡 You can write a bit faster - confidence is key!');
        break;
      case 'too_many_strokes':
        _strokeOrderHints.add('🔄 This character needs fewer strokes. Try again!');
        break;
      case 'incorrect_order':
        _strokeOrderHints.add('📝 Check the stroke order - circles and curves first!');
        break;
    }
  }

  /// Get character-specific writing tips
  String getCharacterSpecificTips(String character) {
    switch (character) {
      case 'ก':
        return 'ก: Start with horizontal line, then vertical. Keep strokes connected.';
      case 'ข':
        return 'ข: Begin with the loop, then add the tail. Smooth curves are key.';
      case 'ค':
        return 'ค: Draw the vertical line first, then add the horizontal crossbar.';
      case 'ง':
        return 'ง: Start with the curved bowl, then add the small tail.';
      case 'จ':
        return 'จ: Begin with the circle, then add the vertical line downward.';
      case 'ฉ':
        return 'ฉ: Draw the base first, then add the top horizontal line.';
      case 'ช':
        return 'ช: Start with the main body, then add the small hook on top.';
      case 'ซ':
        return 'ซ: Begin with the circular part, then extend the line.';
      case 'ด':
        return 'ด: Draw the main curve first, then add the small circle on top.';
      case 'ต':
        return 'ต: Start with the base, then add the distinctive top element.';
      case 'ท':
        return 'ท: Begin with the vertical line, then add the horizontal elements.';
      case 'น':
        return 'น: Start with the curved bowl shape, then add the hook.';
      case 'บ':
        return 'บ: Draw the main body first, then add the small loop on top.';
      case 'ป':
        return 'ป: Begin with the vertical stroke, then add the horizontal line.';
      case 'ผ':
        return 'ผ: Start with the main curve, then add the small ascending stroke.';
      case 'ฝ':
        return 'ฝ: Draw the vertical line first, then add the curved top.';
      case 'พ':
        return 'พ: Begin with the base curve, then add the top horizontal line.';
      case 'ฟ':
        return 'ฟ: Start with the circular element, then add the connecting line.';
      case 'ภ':
        return 'ภ: Draw the main body first, then add the distinctive top hook.';
      case 'ม':
        return 'ม: Start left vertical line, add curve, finish with right line.';
      case 'ย':
        return 'ย: Begin with the main curve, then add the small tail.';
      case 'ร':
        return 'ร: Start with the vertical line, then add the curved top.';
      case 'ล':
        return 'ล: Draw the main curve first, then add the small circle.';
      case 'ว':
        return 'ว: Begin with the circular shape, keep it smooth and round.';
      case 'ศ':
        return 'ศ: Start with the main vertical line, then add side elements.';
      case 'ษ':
        return 'ษ: Draw the base first, then add the top curved elements.';
      case 'ส':
        return 'ส: Begin with the curved shape, then add the top line.';
      case 'ห':
        return 'ห: Start with the vertical line, then add the curved hook.';
      case 'อ':
        return 'อ: Draw the circular shape first, keep it round and even.';
      case 'ฮ':
        return 'ฮ: Begin with the main curve, then add the top horizontal line.';
      default:
        return 'General tip: Start with circles, write vowels after consonants, keep strokes smooth and flowing.';
    }
  }

  /// Clear stroke order hints
  void clearHints() {
    _strokeOrderHints.clear();
  }
}