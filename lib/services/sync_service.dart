import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/local_storage_models.dart';
import 'isar_service.dart';
import 'supabase_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final IsarService _isarService = IsarService();
  final Connectivity _connectivity = Connectivity();
  
  bool _isSyncing = false;
  
  // Check if device has internet connectivity
  Future<bool> get hasConnectivity async {
    final connectivityResults = await _connectivity.checkConnectivity();
    return !connectivityResults.contains(ConnectivityResult.none);
  }
  
  // Get current user ID
  String? get currentUserId => SupabaseService.client.auth.currentUser?.id;
  
  // Main sync method - sync all data types
  Future<void> syncAll() async {
    if (_isSyncing || !await hasConnectivity || currentUserId == null) return;
    
    _isSyncing = true;
    try {
      await Future.wait([
        syncPlayerProfile(),
        syncVocabularyProgress(),
        syncCustomVocabulary(),
        syncBattleSessions(),
      ]);
    } finally {
      _isSyncing = false;
    }
  }
  
  // Sync player profile data
  Future<void> syncPlayerProfile() async {
    if (currentUserId == null) return;
    
    final localProfile = await _isarService.getPlayerProfile(currentUserId!);
    if (localProfile == null) return;
    
    try {
      // Upload local changes to Supabase
      if (localProfile.needsSync) {
        await _uploadPlayerProfile(localProfile);
      }
      
      // Download and merge remote changes
      await _downloadPlayerProfile();
    } catch (e) {
      print('Error syncing player profile: $e');
    }
  }
  
  // Sync vocabulary progress
  Future<void> syncVocabularyProgress() async {
    if (currentUserId == null) return;
    
    try {
      // Upload local changes
      final localPhrases = await _isarService.getAllMasteredPhrases();
      for (final phrase in localPhrases.where((p) => p.needsSync)) {
        await _uploadVocabularyProgress(phrase);
      }
      
      // Download remote changes
      await _downloadVocabularyProgress();
    } catch (e) {
      print('Error syncing vocabulary progress: $e');
    }
  }
  
  // Sync custom vocabulary
  Future<void> syncCustomVocabulary() async {
    if (currentUserId == null) return;
    
    try {
      // Upload local changes
      final localCustomWords = await _isarService.getAllCustomVocabulary();
      for (final word in localCustomWords.where((w) => w.needsSync)) {
        await _uploadCustomVocabulary(word);
      }
      
      // Download remote changes
      await _downloadCustomVocabulary();
    } catch (e) {
      print('Error syncing custom vocabulary: $e');
    }
  }
  
  // Sync battle sessions (upload only - analytics data)
  Future<void> syncBattleSessions() async {
    if (currentUserId == null) return;
    
    try {
      // Upload pending battle sessions
      // Note: This would require storing battle sessions locally first
      // For now, we'll implement direct upload from battle completion
    } catch (e) {
      print('Error syncing battle sessions: $e');
    }
  }
  
  // Private helper methods for uploading data
  Future<void> _uploadPlayerProfile(PlayerProfile profile) async {
    try {
      final response = await SupabaseService.client
          .from('players')
          .upsert({
            'user_id': currentUserId,
            'username': profile.username,
            'score': 0, // Use existing score logic
            'coins': profile.gold,
            'level': profile.playerLevel,
            // 'total_playtime': profile.totalPlaytime, // Field doesn't exist in current model
            'current_streak': profile.currentStreak,
            'max_streak': profile.maxStreak,
            'experience_points': profile.experiencePoints,
            'last_active_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      // Update local record with sync metadata
      profile.supabaseId = response['id'];
      profile.lastSyncedAt = DateTime.now();
      profile.needsSync = false;
      await _isarService.savePlayerProfile(profile);
    } catch (e) {
      print('Error uploading player profile: $e');
      rethrow;
    }
  }
  
  Future<void> _uploadVocabularyProgress(MasteredPhrase phrase) async {
    try {
      await SupabaseService.client
          .from('vocabulary_progress')
          .upsert({
            'user_id': currentUserId,
            'phrase_id': phrase.phraseEnglishId,
            'pronunciation_score': phrase.lastScore,
            'times_practiced': phrase.timesPracticed,
            'is_mastered': phrase.isMastered,
            'last_practiced_at': phrase.lastPracticedAt?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      // Update local record
      phrase.lastSyncedAt = DateTime.now();
      phrase.needsSync = false;
      await _isarService.saveMasteredPhrase(phrase);
    } catch (e) {
      print('Error uploading vocabulary progress: $e');
      rethrow;
    }
  }
  
  Future<void> _uploadCustomVocabulary(CustomVocabularyEntry word) async {
    try {
      final response = await SupabaseService.client
          .from('custom_vocabulary')
          .upsert({
            'user_id': currentUserId,
            'word_thai': word.wordThai,
            'word_english': word.wordEnglish,
            'transliteration': word.transliteration,
            'pos_tag': word.posTag,
            'npc_context': word.discoveredFromNpc,
            'times_used': word.timesUsed,
            'first_discovered_at': word.firstDiscoveredAt.toIso8601String(),
            'last_used_at': word.lastUsedAt.toIso8601String(),
            'pronunciation_score': word.pronunciationScores.isNotEmpty ? word.pronunciationScores.last : null,
            'is_mastered': word.isMastered,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      // Update local record
      word.supabaseId = response['id'];
      word.lastSyncedAt = DateTime.now();
      word.needsSync = false;
      await _isarService.saveCustomVocabulary(word);
    } catch (e) {
      print('Error uploading custom vocabulary: $e');
      rethrow;
    }
  }
  
  // Private helper methods for downloading data
  Future<void> _downloadPlayerProfile() async {
    try {
      final response = await SupabaseService.client
          .from('players')
          .select()
          .eq('user_id', currentUserId!)
          .maybeSingle();
      
      if (response != null) {
        final localProfile = await _isarService.getPlayerProfile(currentUserId!);
        if (localProfile != null) {
          // Merge remote data with local data (conflict resolution)
          final updatedProfile = _mergePlayerProfile(localProfile, response);
          await _isarService.savePlayerProfile(updatedProfile);
        }
      }
    } catch (e) {
      print('Error downloading player profile: $e');
    }
  }
  
  Future<void> _downloadVocabularyProgress() async {
    try {
      final response = await SupabaseService.client
          .from('vocabulary_progress')
          .select()
          .eq('user_id', currentUserId!);
      
      for (final item in response) {
        final localPhrase = await _isarService.getMasteredPhrase(item['phrase_id']);
        if (localPhrase != null) {
          // Merge with local data
          final updatedPhrase = _mergeVocabularyProgress(localPhrase, item);
          await _isarService.saveMasteredPhrase(updatedPhrase);
        } else {
          // Create new local record
          final newPhrase = _createMasteredPhraseFromRemote(item);
          await _isarService.saveMasteredPhrase(newPhrase);
        }
      }
    } catch (e) {
      print('Error downloading vocabulary progress: $e');
    }
  }
  
  Future<void> _downloadCustomVocabulary() async {
    try {
      final response = await SupabaseService.client
          .from('custom_vocabulary')
          .select()
          .eq('user_id', currentUserId!);
      
      for (final item in response) {
        final localWord = await _isarService.getCustomVocabulary(item['word_thai']);
        if (localWord != null) {
          // Merge with local data
          final updatedWord = _mergeCustomVocabulary(localWord, item);
          await _isarService.saveCustomVocabulary(updatedWord);
        } else {
          // Create new local record
          final newWord = _createCustomVocabularyFromRemote(item);
          await _isarService.saveCustomVocabulary(newWord);
        }
      }
    } catch (e) {
      print('Error downloading custom vocabulary: $e');
    }
  }
  
  // Conflict resolution methods (last-write-wins with user data priority)
  PlayerProfile _mergePlayerProfile(PlayerProfile local, Map<String, dynamic> remote) {
    final remoteUpdatedAt = DateTime.parse(remote['updated_at']);
    final localUpdatedAt = local.lastSyncedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    
    // If remote is newer, update local with remote data
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      local.username = remote['username'] ?? local.username;
      local.gold = remote['coins'] ?? local.gold;
      local.playerLevel = remote['level'] ?? local.playerLevel;
      // local.totalPlaytime = remote['total_playtime'] ?? local.totalPlaytime; // Field doesn't exist in current model
      local.currentStreak = remote['current_streak'] ?? local.currentStreak;
      local.maxStreak = remote['max_streak'] ?? local.maxStreak;
      local.experiencePoints = remote['experience_points'] ?? local.experiencePoints;
      local.supabaseId = remote['id'];
      local.lastSyncedAt = remoteUpdatedAt;
      local.needsSync = false;
    }
    
    return local;
  }
  
  MasteredPhrase _mergeVocabularyProgress(MasteredPhrase local, Map<String, dynamic> remote) {
    final remoteUpdatedAt = DateTime.parse(remote['updated_at']);
    final localUpdatedAt = local.lastSyncedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    
    // Use most recent data
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      local.lastScore = remote['pronunciation_score']?.toDouble();
      local.timesPracticed = remote['times_practiced'] ?? local.timesPracticed;
      local.isMastered = remote['is_mastered'] ?? local.isMastered;
      local.lastPracticedAt = remote['last_practiced_at'] != null 
          ? DateTime.parse(remote['last_practiced_at']) 
          : local.lastPracticedAt;
      local.lastSyncedAt = remoteUpdatedAt;
      local.needsSync = false;
    }
    
    return local;
  }
  
  CustomVocabularyEntry _mergeCustomVocabulary(CustomVocabularyEntry local, Map<String, dynamic> remote) {
    final remoteUpdatedAt = DateTime.parse(remote['updated_at']);
    final localUpdatedAt = local.lastSyncedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    
    // Use most recent data
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      local.wordEnglish = remote['word_english'] ?? local.wordEnglish;
      local.transliteration = remote['transliteration'] ?? local.transliteration;
      local.posTag = remote['pos_tag'] ?? local.posTag;
      local.discoveredFromNpc = remote['npc_context'] ?? local.discoveredFromNpc;
      local.timesUsed = remote['times_used'] ?? local.timesUsed;
      if (remote['pronunciation_score'] != null) {
        local.pronunciationScores = [remote['pronunciation_score'].toDouble()];
      }
      local.isMastered = remote['is_mastered'] ?? local.isMastered;
      local.supabaseId = remote['id'];
      local.lastSyncedAt = remoteUpdatedAt;
      local.needsSync = false;
    }
    
    return local;
  }
  
  // Create new local records from remote data
  MasteredPhrase _createMasteredPhraseFromRemote(Map<String, dynamic> remote) {
    final phrase = MasteredPhrase()
      ..phraseEnglishId = remote['phrase_id']
      ..lastScore = remote['pronunciation_score']?.toDouble()
      ..timesPracticed = remote['times_practiced'] ?? 1
      ..isMastered = remote['is_mastered'] ?? false
      ..lastPracticedAt = remote['last_practiced_at'] != null 
          ? DateTime.parse(remote['last_practiced_at']) 
          : null
      ..lastSyncedAt = DateTime.parse(remote['updated_at'])
      ..needsSync = false;
    
    return phrase;
  }
  
  CustomVocabularyEntry _createCustomVocabularyFromRemote(Map<String, dynamic> remote) {
    final word = CustomVocabularyEntry()
      ..wordThai = remote['word_thai']
      ..wordEnglish = remote['word_english']
      ..transliteration = remote['transliteration']
      ..posTag = remote['pos_tag']
      ..discoveredFromNpc = remote['npc_context']
      ..timesUsed = remote['times_used'] ?? 1
      ..firstDiscoveredAt = DateTime.parse(remote['first_discovered_at'])
      ..lastUsedAt = DateTime.parse(remote['last_used_at'])
      ..pronunciationScores = remote['pronunciation_score'] != null ? [remote['pronunciation_score'].toDouble()] : []
      ..isMastered = remote['is_mastered'] ?? false
      ..supabaseId = remote['id']
      ..lastSyncedAt = DateTime.parse(remote['updated_at'])
      ..needsSync = false;
    
    return word;
  }
  
  // Upload battle session data (called from battle completion)
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
    if (currentUserId == null || !await hasConnectivity) return;
    
    try {
      await SupabaseService.client
          .from('battle_sessions')
          .insert({
            'user_id': currentUserId,
            'boss_id': bossId,
            'duration_seconds': durationSeconds,
            'avg_pronunciation_score': avgPronunciationScore,
            'total_damage': totalDamage,
            'turns_taken': turnsTaken,
            'grade': grade,
            'words_used': wordsUsed,
            'word_scores': wordScores,
            'max_streak': maxStreak,
            'final_player_health': finalPlayerHealth,
            'exp_gained': expGained,
            'gold_earned': goldEarned,
            'newly_mastered_words': newlyMasteredWords,
          });
    } catch (e) {
      print('Error uploading battle session: $e');
      // Could implement local storage and retry logic here
    }
  }
  
  // Auto-sync on app lifecycle events
  Future<void> onAppResume() async {
    await syncAll();
  }
  
  Future<void> onAppPause() async {
    await syncAll();
  }
}