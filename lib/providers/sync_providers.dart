import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/local_storage_models.dart';
import '../services/isar_service.dart';
import '../services/sync_service.dart';
import '../services/vocabulary_detection_service.dart';

part 'sync_providers.g.dart';

// Provider for the SyncService instance
@riverpod
SyncService syncService(SyncServiceRef ref) {
  return SyncService();
}

// Provider for the VocabularyDetectionService instance
@riverpod
VocabularyDetectionService vocabularyDetectionService(VocabularyDetectionServiceRef ref) {
  return VocabularyDetectionService();
}

// Provider for the IsarService instance
@riverpod
IsarService isarService(IsarServiceRef ref) {
  return IsarService();
}

// Sync-aware PlayerProfile provider
@riverpod
class PlayerProfileSync extends _$PlayerProfileSync {
  @override
  Future<PlayerProfile?> build(String userId) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    // Try to get local profile first
    PlayerProfile? profile = await isarService.getPlayerProfile(userId);
    
    // Trigger background sync if online
    if (await syncService.hasConnectivity) {
      // Don't await this - let it sync in background
      syncService.syncPlayerProfile().catchError((error) {
        // Log error but don't block the UI
        print('Background sync error: $error');
      });
    }
    
    return profile;
  }
  
  // Update player profile locally and trigger sync
  Future<void> updateProfile(PlayerProfile profile) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    // Mark for sync
    profile.needsSync = true;
    
    // Save locally first
    await isarService.savePlayerProfile(profile);
    
    // Update provider state
    state = AsyncValue.data(profile);
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncPlayerProfile().catchError((error) {
        print('Profile sync error: $error');
      });
    }
  }
}

// Sync-aware Vocabulary Progress provider
@riverpod
class VocabularyProgressSync extends _$VocabularyProgressSync {
  @override
  Future<List<MasteredPhrase>> build() async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    // Get local data first
    final phrases = await isarService.getAllMasteredPhrases();
    
    // Trigger background sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncVocabularyProgress().catchError((error) {
        print('Vocabulary sync error: $error');
      });
    }
    
    return phrases;
  }
  
  // Update phrase progress locally and trigger sync
  Future<void> updatePhraseProgress(MasteredPhrase phrase) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    // Mark for sync
    phrase.needsSync = true;
    
    // Save locally first
    await isarService.saveMasteredPhrase(phrase);
    
    // Update provider state
    final currentPhrases = state.valueOrNull ?? [];
    final index = currentPhrases.indexWhere((p) => p.phraseEnglishId == phrase.phraseEnglishId);
    
    if (index >= 0) {
      currentPhrases[index] = phrase;
    } else {
      currentPhrases.add(phrase);
    }
    
    state = AsyncValue.data(List.from(currentPhrases));
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncVocabularyProgress().catchError((error) {
        print('Phrase sync error: $error');
      });
    }
  }
  
  // Get progress for a specific phrase
  MasteredPhrase? getPhraseProgress(String phraseId) {
    final phrases = state.valueOrNull ?? [];
    return phrases.where((p) => p.phraseEnglishId == phraseId).firstOrNull;
  }
}

// Sync-aware Custom Vocabulary provider
@riverpod
class CustomVocabularySync extends _$CustomVocabularySync {
  @override
  Future<List<CustomVocabularyEntry>> build() async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    // Get local custom vocabulary
    final customWords = await isarService.getAllCustomVocabulary();
    
    // Trigger background sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncCustomVocabulary().catchError((error) {
        print('Custom vocabulary sync error: $error');
      });
    }
    
    return customWords;
  }
  
  // Add new custom word locally and trigger sync
  Future<void> addCustomWord(CustomVocabularyEntry word) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    // Mark for sync
    word.needsSync = true;
    
    // Save locally first
    await isarService.saveCustomVocabulary(word);
    
    // Update provider state
    final currentWords = state.valueOrNull ?? [];
    currentWords.add(word);
    state = AsyncValue.data(List.from(currentWords));
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncCustomVocabulary().catchError((error) {
        print('Custom word sync error: $error');
      });
    }
  }
  
  // Update existing custom word
  Future<void> updateCustomWord(CustomVocabularyEntry word) async {
    final isarService = ref.read(isarServiceProvider);
    final syncService = ref.read(syncServiceProvider);
    
    // Mark for sync
    word.needsSync = true;
    
    // Save locally first
    await isarService.saveCustomVocabulary(word);
    
    // Update provider state
    final currentWords = state.valueOrNull ?? [];
    final index = currentWords.indexWhere((w) => w.wordThai == word.wordThai);
    
    if (index >= 0) {
      currentWords[index] = word;
      state = AsyncValue.data(List.from(currentWords));
    }
    
    // Trigger sync if online
    if (await syncService.hasConnectivity) {
      syncService.syncCustomVocabulary().catchError((error) {
        print('Custom word update sync error: $error');
      });
    }
  }
  
  // Get custom words for a specific NPC
  List<CustomVocabularyEntry> getWordsForNpc(String npcId) {
    final words = state.valueOrNull ?? [];
    return words.where((w) => w.npcContext?.contains(npcId) == true).toList();
  }
  
  // Get vocabulary statistics
  Map<String, dynamic> getVocabularyStats() {
    final words = state.valueOrNull ?? [];
    final masteredWords = words.where((w) => w.isMastered).length;
    final totalWords = words.length;
    final recentWords = words
        .where((w) => DateTime.now().difference(w.firstDiscoveredAt).inDays <= 7)
        .length;

    return {
      'totalCustomWords': totalWords,
      'masteredWords': masteredWords,
      'masteryPercentage': totalWords > 0 ? (masteredWords / totalWords * 100) : 0,
      'recentlyDiscovered': recentWords,
      'mostUsedWords': words
          .toList()
          ..sort((a, b) => b.timesUsed.compareTo(a.timesUsed))
          ..take(5)
          .map((w) => {'word': w.wordThai, 'timesUsed': w.timesUsed})
          .toList(),
    };
  }
}

// Sync status provider to show sync state in UI
@riverpod
class SyncStatus extends _$SyncStatus {
  @override
  SyncStatusData build() {
    return const SyncStatusData();
  }
  
  void setSyncing(bool isSyncing) {
    state = state.copyWith(isSyncing: isSyncing);
  }
  
  void setLastSyncTime(DateTime? lastSync) {
    state = state.copyWith(lastSyncTime: lastSync);
  }
  
  void setConnectionStatus(bool isOnline) {
    state = state.copyWith(isOnline: isOnline);
  }
  
  // Trigger manual sync
  Future<void> manualSync() async {
    final syncService = ref.read(syncServiceProvider);
    
    if (!await syncService.hasConnectivity) {
      // Could show offline message
      return;
    }
    
    setSyncing(true);
    
    try {
      await syncService.syncAll();
      setLastSyncTime(DateTime.now());
      
      // Refresh all sync providers
      ref.invalidate(vocabularyProgressSyncProvider);
      ref.invalidate(customVocabularySyncProvider);
    } catch (e) {
      print('Manual sync failed: $e');
    } finally {
      setSyncing(false);
    }
  }
}

// Data class for sync status
class SyncStatusData {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final bool isOnline;
  
  const SyncStatusData({
    this.isSyncing = false,
    this.lastSyncTime,
    this.isOnline = false,
  });
  
  SyncStatusData copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    bool? isOnline,
  }) {
    return SyncStatusData(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

// Helper provider for battle session tracking
@riverpod
class BattleSessionTracker extends _$BattleSessionTracker {
  @override
  void build() {
    // This provider manages battle session data for syncing
  }
  
  // Upload battle session after completion
  Future<void> uploadBattleSession({
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
    
    try {
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
    } catch (e) {
      print('Failed to upload battle session: $e');
      // Could implement local storage and retry logic here
    }
  }
}