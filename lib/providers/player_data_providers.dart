import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/local_storage_models.dart';
import '../services/player_data_service.dart';

// Provider for the PlayerDataService instance
final playerDataServiceProvider = Provider<PlayerDataService>((ref) {
  return PlayerDataService();
});

// Provider for sync-aware player profile
final playerProfileProvider = FutureProvider.family<PlayerProfile?, String>((ref, userId) async {
  final service = ref.read(playerDataServiceProvider);
  return await service.getPlayerProfile(userId);
});

// Provider for sync-aware vocabulary progress
final vocabularyProgressProvider = FutureProvider<List<MasteredPhrase>>((ref) async {
  final service = ref.read(playerDataServiceProvider);
  return await service.getAllVocabularyProgress();
});

// Provider for sync-aware custom vocabulary
final customVocabularyProvider = FutureProvider<List<CustomVocabularyEntry>>((ref) async {
  final service = ref.read(playerDataServiceProvider);
  return await service.getAllCustomVocabulary();
});

// Provider for custom vocabulary for a specific NPC
final npcCustomVocabularyProvider = FutureProvider.family<List<CustomVocabularyEntry>, String>((ref, npcId) async {
  final service = ref.read(playerDataServiceProvider);
  return await service.getCustomWordsForNpc(npcId);
});

// Provider for vocabulary statistics
final vocabularyStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(playerDataServiceProvider);
  return await service.getVocabularyStats();
});

// Provider for connectivity status
final connectivityStatusProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(playerDataServiceProvider);
  return await service.isOnline;
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
    final service = ref.read(playerDataServiceProvider);
    await service.updatePlayerProfile(profile);
    
    // Invalidate provider to trigger refresh
    ref.invalidate(playerProfileProvider(profile.userId));
  }
  
  // Update phrase progress and refresh provider
  static Future<void> updatePhraseProgress(
    WidgetRef ref, 
    MasteredPhrase phrase
  ) async {
    final service = ref.read(playerDataServiceProvider);
    await service.updatePhraseProgress(phrase);
    
    // Invalidate provider to trigger refresh
    ref.invalidate(vocabularyProgressProvider);
  }
  
  // Add custom word and refresh provider
  static Future<void> addCustomWord(
    WidgetRef ref, 
    CustomVocabularyEntry word
  ) async {
    final service = ref.read(playerDataServiceProvider);
    await service.addCustomWord(word);
    
    // Invalidate providers to trigger refresh
    ref.invalidate(customVocabularyProvider);
    if (word.npcContext != null) {
      ref.invalidate(npcCustomVocabularyProvider(word.npcContext!));
    }
    ref.invalidate(vocabularyStatsProvider);
  }
  
  // Update custom word and refresh provider
  static Future<void> updateCustomWord(
    WidgetRef ref, 
    CustomVocabularyEntry word
  ) async {
    final service = ref.read(playerDataServiceProvider);
    await service.updateCustomWord(word);
    
    // Invalidate providers to trigger refresh
    ref.invalidate(customVocabularyProvider);
    if (word.npcContext != null) {
      ref.invalidate(npcCustomVocabularyProvider(word.npcContext!));
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
    final service = ref.read(playerDataServiceProvider);
    await service.recordBattleSession(
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
    final service = ref.read(playerDataServiceProvider);
    
    // Update sync status
    ref.read(syncStatusProvider.notifier).state = 
        ref.read(syncStatusProvider).copyWith(isSyncing: true);
    
    try {
      await service.performFullSync();
      
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
    final service = ref.read(playerDataServiceProvider);
    final isOnline = await service.isOnline;
    
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
    final service = ref.read(playerDataServiceProvider);
    await service.recordPronunciationAttempt(
      phraseId: phraseId,
      customWordId: customWordId,
      pronunciationScore: pronunciationScore,
      accuracyScore: accuracyScore,
      fluencyScore: fluencyScore,
      completenessScore: completenessScore,
      wordErrors: wordErrors,
      sessionContext: sessionContext,
      sessionId: sessionId,
    );
  }
}