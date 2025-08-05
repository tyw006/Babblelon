import '../models/assessment_model.dart';
import 'sync_service.dart';
import 'supabase_service.dart';

/// Service for tracking and analyzing pronunciation data
class PronunciationAnalyticsService {
  static final PronunciationAnalyticsService _instance = PronunciationAnalyticsService._internal();
  factory PronunciationAnalyticsService() => _instance;
  PronunciationAnalyticsService._internal();

  final SyncService _syncService = SyncService();

  /// Record pronunciation attempt for analytics
  Future<void> recordPronunciationAttempt({
    required String? phraseId,
    required String? customWordId,
    required PronunciationAssessmentResponse assessment,
    required String sessionContext, // 'battle', 'dialogue', 'practice'
    String? sessionId,
  }) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) return;

    try {
      // Extract word errors from detailed feedback
      final wordErrors = assessment.detailedFeedback.map((feedback) => {
        'word': feedback.word,
        'accuracy_score': feedback.accuracyScore,
        'error_type': feedback.errorType,
        'transliteration': feedback.transliteration,
      }).toList();

      await SupabaseService.client
          .from('pronunciation_history')
          .insert({
            'user_id': userId,
            'phrase_id': phraseId,
            'custom_word_id': customWordId,
            'pronunciation_score': assessment.pronunciationScore,
            'accuracy_score': assessment.accuracyScore,
            'fluency_score': assessment.fluencyScore,
            'completeness_score': assessment.completenessScore,
            'word_errors': wordErrors,
            'session_context': sessionContext,
            'session_id': sessionId,
          });
    } catch (e) {
      print('Error recording pronunciation attempt: $e');
    }
  }

  /// Get pronunciation trends for a specific phrase
  Future<List<Map<String, dynamic>>> getPronunciationTrends({
    String? phraseId,
    String? customWordId,
    int daysBack = 30,
  }) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) return [];

    try {
      dynamic query = SupabaseService.client
          .from('pronunciation_history')
          .select('pronunciation_score, accuracy_score, fluency_score, recorded_at')
          .eq('user_id', userId)
          .gte('recorded_at', DateTime.now().subtract(Duration(days: daysBack)).toIso8601String());

      if (phraseId != null) {
        query = query.eq('phrase_id', phraseId);
      }
      if (customWordId != null) {
        query = query.eq('custom_word_id', customWordId);
      }

      query = query.order('recorded_at');

      return await query;
    } catch (e) {
      print('Error getting pronunciation trends: $e');
      return [];
    }
  }

  /// Get pronunciation analytics summary
  Future<Map<String, dynamic>> getPronunciationAnalytics({
    int daysBack = 30,
  }) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) {
      return {
        'totalAttempts': 0,
        'averageScore': 0.0,
        'improvementTrend': 0.0,
        'sessionBreakdown': <String, int>{},
        'weakestWords': <Map<String, dynamic>>[],
        'recentProgress': <Map<String, dynamic>>[],
      };
    }

    try {
      // Get total attempts and average score
      final basicStats = await SupabaseService.client
          .from('pronunciation_history')
          .select('pronunciation_score, session_context')
          .eq('user_id', userId)
          .gte('recorded_at', DateTime.now().subtract(Duration(days: daysBack)).toIso8601String());

      if (basicStats.isEmpty) {
        return {
          'totalAttempts': 0,
          'averageScore': 0.0,
          'improvementTrend': 0.0,
          'sessionBreakdown': <String, int>{},
          'weakestWords': <Map<String, dynamic>>[],
          'recentProgress': <Map<String, dynamic>>[],
        };
      }

      final totalAttempts = basicStats.length;
      final averageScore = basicStats
          .map((row) => row['pronunciation_score'] as double)
          .reduce((a, b) => a + b) / totalAttempts;

      // Calculate improvement trend (compare first half vs second half)
      final halfPoint = totalAttempts ~/ 2;
      final firstHalfAvg = halfPoint > 0 
          ? basicStats.take(halfPoint)
              .map((row) => row['pronunciation_score'] as double)
              .reduce((a, b) => a + b) / halfPoint
          : 0.0;
      final secondHalfAvg = halfPoint > 0
          ? basicStats.skip(halfPoint)
              .map((row) => row['pronunciation_score'] as double)
              .reduce((a, b) => a + b) / (totalAttempts - halfPoint)
          : 0.0;
      final improvementTrend = secondHalfAvg - firstHalfAvg;

      // Session breakdown
      final sessionBreakdown = <String, int>{};
      for (final row in basicStats) {
        final context = row['session_context'] as String;
        sessionBreakdown[context] = (sessionBreakdown[context] ?? 0) + 1;
      }

      // Get weakest words (lowest average scores)
      final weakWords = await SupabaseService.client
          .rpc('get_pronunciation_weak_words', params: {
            'user_id_param': userId,
            'days_back': daysBack,
            'limit_count': 5,
          });

      // Get recent progress (daily averages for chart)
      final recentProgress = await SupabaseService.client
          .rpc('get_daily_pronunciation_progress', params: {
            'user_id_param': userId,
            'days_back': daysBack,
          });

      return {
        'totalAttempts': totalAttempts,
        'averageScore': averageScore,
        'improvementTrend': improvementTrend,
        'sessionBreakdown': sessionBreakdown,
        'weakestWords': weakWords ?? [],
        'recentProgress': recentProgress ?? [],
      };
    } catch (e) {
      print('Error getting pronunciation analytics: $e');
      return {
        'totalAttempts': 0,
        'averageScore': 0.0,
        'improvementTrend': 0.0,
        'sessionBreakdown': <String, int>{},
        'weakestWords': <Map<String, dynamic>>[],
        'recentProgress': <Map<String, dynamic>>[],
      };
    }
  }

  /// Get pronunciation patterns by time of day
  Future<Map<String, double>> getPronunciationPatternsByTime() async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) return {};

    try {
      final data = await SupabaseService.client
          .from('pronunciation_history')
          .select('pronunciation_score, recorded_at')
          .eq('user_id', userId)
          .gte('recorded_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());

      final hourlyScores = <int, List<double>>{};
      
      for (final row in data) {
        final recordedAt = DateTime.parse(row['recorded_at']);
        final hour = recordedAt.hour;
        final score = row['pronunciation_score'] as double;
        
        hourlyScores.putIfAbsent(hour, () => []).add(score);
      }

      final hourlyAverages = <String, double>{};
      hourlyScores.forEach((hour, scores) {
        final average = scores.reduce((a, b) => a + b) / scores.length;
        hourlyAverages['${hour.toString().padLeft(2, '0')}:00'] = average;
      });

      return hourlyAverages;
    } catch (e) {
      print('Error getting pronunciation patterns by time: $e');
      return {};
    }
  }

  /// Get error patterns analysis
  Future<Map<String, int>> getCommonErrors({int daysBack = 30}) async {
    final userId = _syncService.currentUserId;
    if (userId == null || !await _syncService.hasConnectivity) return {};

    try {
      final data = await SupabaseService.client
          .from('pronunciation_history')
          .select('word_errors')
          .eq('user_id', userId)
          .gte('recorded_at', DateTime.now().subtract(Duration(days: daysBack)).toIso8601String());

      final errorCounts = <String, int>{};
      
      for (final row in data) {
        final wordErrors = row['word_errors'] as List<dynamic>?;
        if (wordErrors != null) {
          for (final error in wordErrors) {
            final errorType = error['error_type'] as String?;
            if (errorType != null && errorType != 'None') {
              errorCounts[errorType] = (errorCounts[errorType] ?? 0) + 1;
            }
          }
        }
      }

      return errorCounts;
    } catch (e) {
      print('Error getting common errors: $e');
      return {};
    }
  }
}