import '../models/character_assessment_model.dart';
import 'sync_service.dart';
import 'supabase_service.dart';

/// Service for tracking and analyzing character tracing data
class CharacterTracingAnalyticsService {
  static final CharacterTracingAnalyticsService _instance = CharacterTracingAnalyticsService._internal();
  factory CharacterTracingAnalyticsService() => _instance;
  CharacterTracingAnalyticsService._internal();

  final SyncService _syncService = SyncService();

  /// Record character tracing attempt for analytics
  Future<void> recordCharacterTracingAttempt({
    required String? phraseId,
    required int characterPosition,
    required String expectedCharacter,
    required CharacterAssessmentResult assessment,
    required String sessionContext, // 'battle', 'dialogue', 'practice'
    String? sessionId,
  }) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) return;

    try {
      // Convert recognition candidates to JSON
      final candidatesJson = assessment.candidates.map((candidate) => {
        'text': candidate.text,
        'score': candidate.score, // ML Kit uses 'score' not 'confidence'
      }).toList();

      await SupabaseService.client
          .from('character_tracing_history')
          .insert({
            'user_id': userId,
            'phrase_id': phraseId,
            'character_position': characterPosition,
            'expected_character': expectedCharacter,
            'session_context': sessionContext,
            'session_id': sessionId,
            'recognized_text': assessment.recognizedText,
            'confidence_score': assessment.confidenceScore,
            'recognition_candidates': candidatesJson,
            'is_correct': assessment.isCorrect,
            'accuracy_level': assessment.accuracyLevel,
            'accuracy_percentage': assessment.accuracyPercentage,
            'has_strokes': assessment.hasStrokes,
          });
    } catch (e) {
      print('Error recording character tracing attempt: $e');
    }
  }

  /// Record overall tracing assessment for phrase
  Future<void> recordTracingAssessment({
    required String phraseId,
    required TracingAssessmentResult assessment,
    required String sessionContext,
    String? sessionId,
  }) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) return;

    try {
      // Record each character result
      for (final entry in assessment.characterResults.entries) {
        final characterPosition = entry.key;
        final characterResult = entry.value;
        
        await recordCharacterTracingAttempt(
          phraseId: phraseId,
          characterPosition: characterPosition,
          expectedCharacter: characterResult.expectedCharacter,
          assessment: characterResult,
          sessionContext: sessionContext,
          sessionId: sessionId,
        );
      }
    } catch (e) {
      print('Error recording tracing assessment: $e');
    }
  }

  /// Get character tracing trends for a specific phrase
  Future<List<Map<String, dynamic>>> getCharacterTracingTrends({
    String? phraseId,
    int daysBack = 30,
  }) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) return [];

    try {
      dynamic query = SupabaseService.client
          .from('character_tracing_history')
          .select('accuracy_percentage, accuracy_level, recorded_at, expected_character')
          .eq('user_id', userId)
          .gte('recorded_at', DateTime.now().subtract(Duration(days: daysBack)).toIso8601String());

      if (phraseId != null) {
        query = query.eq('phrase_id', phraseId);
      }

      query = query.order('recorded_at');
      return await query;
    } catch (e) {
      print('Error getting character tracing trends: $e');
      return [];
    }
  }

  /// Get character tracing analytics summary
  Future<Map<String, dynamic>> getCharacterTracingAnalytics({
    int daysBack = 30,
  }) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) {
      return {
        'totalAttempts': 0,
        'averageAccuracy': 0.0,
        'improvementTrend': 0.0,
        'characterBreakdown': <String, Map<String, dynamic>>{},
        'weakestCharacters': <Map<String, dynamic>>[],
        'recentProgress': <Map<String, dynamic>>[],
      };
    }

    try {
      // Get overall stats
      final statsQuery = await SupabaseService.client
          .from('character_tracing_history')
          .select('accuracy_percentage, expected_character, is_correct, recorded_at')
          .eq('user_id', userId)
          .gte('recorded_at', DateTime.now().subtract(Duration(days: daysBack)).toIso8601String());

      if (statsQuery.isEmpty) {
        return {
          'totalAttempts': 0,
          'averageAccuracy': 0.0,
          'improvementTrend': 0.0,
          'characterBreakdown': <String, Map<String, dynamic>>{},
          'weakestCharacters': <Map<String, dynamic>>[],
          'recentProgress': <Map<String, dynamic>>[],
        };
      }

      // Calculate analytics
      final totalAttempts = statsQuery.length;
      final averageAccuracy = statsQuery.fold<double>(0.0, (sum, item) => 
          sum + (item['accuracy_percentage'] ?? 0.0)) / totalAttempts;

      // Character breakdown
      final Map<String, List<double>> characterScores = {};
      final Map<String, int> characterCounts = {};
      
      for (final item in statsQuery) {
        final character = item['expected_character'] as String;
        final accuracy = (item['accuracy_percentage'] ?? 0.0) as double;
        
        characterScores.putIfAbsent(character, () => []).add(accuracy);
        characterCounts[character] = (characterCounts[character] ?? 0) + 1;
      }

      // Build character breakdown
      final characterBreakdown = <String, Map<String, dynamic>>{};
      for (final character in characterScores.keys) {
        final scores = characterScores[character]!;
        final avgScore = scores.fold<double>(0.0, (sum, score) => sum + score) / scores.length;
        
        characterBreakdown[character] = {
          'average_accuracy': avgScore,
          'attempts': characterCounts[character],
          'improvement': scores.length > 1 ? scores.last - scores.first : 0.0,
        };
      }

      // Find weakest characters (lowest average accuracy)
      final weakestCharacters = characterBreakdown.entries
          .map((entry) => {
            'character': entry.key,
            'average_accuracy': entry.value['average_accuracy'],
            'attempts': entry.value['attempts'],
          })
          .toList()
        ..sort((a, b) => (a['average_accuracy'] as double).compareTo(b['average_accuracy'] as double));

      // Calculate improvement trend (first week vs last week)
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      final recentScores = statsQuery
          .where((item) => DateTime.parse(item['recorded_at']).isAfter(weekAgo))
          .map((item) => item['accuracy_percentage'] as double)
          .toList();

      final olderScores = statsQuery
          .where((item) {
            final date = DateTime.parse(item['recorded_at']);
            return date.isAfter(twoWeeksAgo) && date.isBefore(weekAgo);
          })
          .map((item) => item['accuracy_percentage'] as double)
          .toList();

      double improvementTrend = 0.0;
      if (recentScores.isNotEmpty && olderScores.isNotEmpty) {
        final recentAvg = recentScores.fold<double>(0.0, (sum, score) => sum + score) / recentScores.length;
        final olderAvg = olderScores.fold<double>(0.0, (sum, score) => sum + score) / olderScores.length;
        improvementTrend = recentAvg - olderAvg;
      }

      return {
        'totalAttempts': totalAttempts,
        'averageAccuracy': averageAccuracy,
        'improvementTrend': improvementTrend,
        'characterBreakdown': characterBreakdown,
        'weakestCharacters': weakestCharacters.take(5).toList(),
        'recentProgress': recentScores.length > 10 ? recentScores.sublist(recentScores.length - 10) : recentScores,
      };
    } catch (e) {
      print('Error getting character tracing analytics: $e');
      return {
        'totalAttempts': 0,
        'averageAccuracy': 0.0,
        'improvementTrend': 0.0,
        'characterBreakdown': <String, Map<String, dynamic>>{},
        'weakestCharacters': <Map<String, dynamic>>[],
        'recentProgress': <Map<String, dynamic>>[],
      };
    }
  }
}