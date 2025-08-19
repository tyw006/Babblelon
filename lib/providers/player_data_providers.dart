import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/local_storage_models.dart';
import '../services/isar_service.dart';
import '../services/sync_service.dart';
import '../services/supabase_service.dart';

// Provider for the IsarService instance
final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

// Provider for the SyncService instance
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

// Provider for sync-aware player profile
final playerProfileProvider = FutureProvider.family<PlayerProfile?, String>((ref, userId) async {
  final isarService = ref.read(isarServiceProvider);
  final syncService = ref.read(syncServiceProvider);
  
  final profile = await isarService.getPlayerProfile(userId);
  
  // Trigger background sync if online
  if (await syncService.hasConnectivity) {
    syncService.syncPlayerProfile().catchError((error) {
      debugPrint('Background profile sync error: $error');
    });
  }
  
  return profile;
});

// Provider for sync-aware vocabulary progress
final vocabularyProgressProvider = FutureProvider<List<MasteredPhrase>>((ref) async {
  final isarService = ref.read(isarServiceProvider);
  final syncService = ref.read(syncServiceProvider);
  
  final phrases = await isarService.getAllMasteredPhrases();
  
  // Trigger background sync if online
  if (await syncService.hasConnectivity) {
    syncService.syncVocabularyProgress().catchError((error) {
      debugPrint('Background vocabulary sync error: $error');
    });
  }
  
  return phrases;
});

// Provider for sync-aware custom vocabulary
final customVocabularyProvider = FutureProvider<List<CustomVocabularyEntry>>((ref) async {
  final isarService = ref.read(isarServiceProvider);
  final syncService = ref.read(syncServiceProvider);
  
  final customWords = await isarService.getAllCustomVocabulary();
  
  // Trigger background sync if online
  if (await syncService.hasConnectivity) {
    syncService.syncCustomVocabulary().catchError((error) {
      debugPrint('Background custom vocabulary sync error: $error');
    });
  }
  
  return customWords;
});

// Provider for custom vocabulary for a specific NPC
final npcCustomVocabularyProvider = FutureProvider.family<List<CustomVocabularyEntry>, String>((ref, npcId) async {
  final isarService = ref.read(isarServiceProvider);
  final allWords = await isarService.getAllCustomVocabulary();
  return allWords.where((w) => w.discoveredFromNpc == npcId).toList();
});

// Provider for vocabulary statistics
final vocabularyStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final isarService = ref.read(isarServiceProvider);
  final customWords = await isarService.getAllCustomVocabulary();
  final masteredWords = customWords.where((w) => w.isMastered).length;
  final totalWords = customWords.length;
  final recentWords = customWords
      .where((w) => DateTime.now().difference(w.firstDiscoveredAt).inDays <= 7)
      .length;

  return {
    'totalCustomWords': totalWords,
    'masteredWords': masteredWords,
    'masteryPercentage': totalWords > 0 ? (masteredWords / totalWords * 100) : 0,
    'recentlyDiscovered': recentWords,
    'mostUsedWords': customWords
        .toList()
        ..sort((a, b) => b.timesUsed.compareTo(a.timesUsed))
        ..take(5)
        .map((w) => {'word': w.wordThai, 'timesUsed': w.timesUsed})
        .toList(),
  };
});

// Provider for connectivity status
final connectivityStatusProvider = FutureProvider<bool>((ref) async {
  final syncService = ref.read(syncServiceProvider);
  return await syncService.hasConnectivity;
});

// Provider for sync status (using StateProvider for real-time updates)
final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return const SyncStatus();
});

// Data class for sync status
class SyncStatus {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final bool isOnline;
  final String? lastError;
  
  const SyncStatus({
    this.isSyncing = false,
    this.lastSyncTime,
    this.isOnline = false,
    this.lastError,
  });
  
  SyncStatus copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    bool? isOnline,
    String? lastError,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isOnline: isOnline ?? this.isOnline,
      lastError: lastError ?? this.lastError,
    );
  }
}

// Helper methods for updating data through providers
class PlayerDataHelpers {
  // Update player profile and refresh provider
  static Future<void> updatePlayerProfile(
    WidgetRef ref, 
    PlayerProfile profile
  ) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    profile.needsSync = true;
    await isarService.savePlayerProfile(profile);
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncPlayerProfile().catchError((error) {
        debugPrint('Profile sync error: $error');
      });
    }
    
    // Invalidate provider to trigger refresh
    ref.invalidate(playerProfileProvider(profile.userId));
  }
  
  // Update phrase progress and refresh provider
  static Future<void> updatePhraseProgress(
    WidgetRef ref, 
    MasteredPhrase phrase
  ) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    phrase.needsSync = true;
    await isarService.saveMasteredPhrase(phrase);
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncVocabularyProgress().catchError((error) {
        debugPrint('Phrase sync error: $error');
      });
    }
    
    // Invalidate provider to trigger refresh
    ref.invalidate(vocabularyProgressProvider);
  }
  
  // Add custom word and refresh provider
  static Future<void> addCustomWord(
    WidgetRef ref, 
    CustomVocabularyEntry word
  ) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    word.needsSync = true;
    await isarService.saveCustomVocabulary(word);
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncCustomVocabulary().catchError((error) {
        debugPrint('Custom word sync error: $error');
      });
    }
    
    // Invalidate providers to trigger refresh
    ref.invalidate(customVocabularyProvider);
    if (word.discoveredFromNpc != null) {
      ref.invalidate(npcCustomVocabularyProvider(word.discoveredFromNpc!));
    }
    ref.invalidate(vocabularyStatsProvider);
  }
  
  // Update custom word and refresh provider
  static Future<void> updateCustomWord(
    WidgetRef ref, 
    CustomVocabularyEntry word
  ) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    word.needsSync = true;
    await isarService.saveCustomVocabulary(word);
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncCustomVocabulary().catchError((error) {
        debugPrint('Custom word update sync error: $error');
      });
    }
    
    // Invalidate providers to trigger refresh
    ref.invalidate(customVocabularyProvider);
    if (word.discoveredFromNpc != null) {
      ref.invalidate(npcCustomVocabularyProvider(word.discoveredFromNpc!));
    }
    ref.invalidate(vocabularyStatsProvider);
  }
  
  // Record battle session
  static Future<void> recordBattleSession(
    WidgetRef ref, {
    required String bossId,
    required int durationSeconds,
    required double avgPronunciationScore,
    required double totalDamage,
    required int turnsTaken,
    required String grade,
    required Map<String, dynamic> wordsUsed,
    required Map<String, double> wordScores,
    required int maxStreak,
    required int finalPlayerHealth,
    required int expGained,
    required int goldEarned,
    required List<String> newlyMasteredWords,
  }) async {
    final syncService = ref.read(syncServiceProvider);
    
    // Upload battle session directly to Supabase
    await syncService.uploadBattleSession(
      bossId: bossId,
      durationSeconds: durationSeconds,
      avgPronunciationScore: avgPronunciationScore,
      totalDamage: totalDamage,
      turnsTaken: turnsTaken,
      grade: grade,
      wordsUsed: wordsUsed,
      wordScores: wordScores,
      maxStreak: maxStreak,
      finalPlayerHealth: finalPlayerHealth,
      expGained: expGained,
      goldEarned: goldEarned,
      newlyMasteredWords: newlyMasteredWords,
    );
    
    // Refresh relevant providers
    ref.invalidate(vocabularyProgressProvider);
    ref.invalidate(vocabularyStatsProvider);
  }
  
  // Perform manual sync
  static Future<void> performManualSync(WidgetRef ref) async {
    final syncService = ref.read(syncServiceProvider);
    
    // Update sync status
    ref.read(syncStatusProvider.notifier).state = 
        ref.read(syncStatusProvider).copyWith(isSyncing: true);
    
    try {
      if (await syncService.hasConnectivity) {
        await syncService.syncAll();
      }
      
      // Update sync status with success
      ref.read(syncStatusProvider.notifier).state = 
          ref.read(syncStatusProvider).copyWith(
            isSyncing: false,
            lastSyncTime: DateTime.now(),
            lastError: null,
          );
      
      // Invalidate all data providers to refresh with synced data
      ref.invalidate(vocabularyProgressProvider);
      ref.invalidate(customVocabularyProvider);
      ref.invalidate(vocabularyStatsProvider);
      
    } catch (e) {
      // Update sync status with error
      ref.read(syncStatusProvider.notifier).state = 
          ref.read(syncStatusProvider).copyWith(
            isSyncing: false,
            lastError: e.toString(),
          );
    }
  }
  
  // Update connectivity status
  static Future<void> updateConnectivityStatus(WidgetRef ref) async {
    final syncService = ref.read(syncServiceProvider);
    final isOnline = await syncService.hasConnectivity;
    
    ref.read(syncStatusProvider.notifier).state = 
        ref.read(syncStatusProvider).copyWith(isOnline: isOnline);
  }

  // Record pronunciation attempt for analytics
  static Future<void> recordPronunciationAttempt(
    WidgetRef ref, {
    String? phraseId,
    String? customWordId,
    required double pronunciationScore,
    required double accuracyScore,
    required double fluencyScore,
    required double completenessScore,
    List<Map<String, dynamic>>? wordErrors,
    required String sessionContext,
    String? sessionId,
  }) async {
    final syncService = ref.read(syncServiceProvider);
    
    if (!await syncService.hasConnectivity) return;

    try {
      await SupabaseService.client
          .from('pronunciation_history')
          .insert({
            'user_id': syncService.currentUserId,
            'phrase_id': phraseId,
            'custom_word_id': customWordId,
            'pronunciation_score': pronunciationScore,
            'accuracy_score': accuracyScore,
            'fluency_score': fluencyScore,
            'completeness_score': completenessScore,
            'word_errors': wordErrors,
            'session_context': sessionContext,
            'session_id': sessionId,
          });
    } catch (e) {
      debugPrint('Error recording pronunciation attempt: $e');
    }
  }
}