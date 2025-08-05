import '../models/local_storage_models.dart';
import 'isar_service.dart';
import 'sync_service.dart';
import 'supabase_service.dart';
import 'posthog_service.dart';

/// Service that provides sync-aware access to player data
/// This acts as a layer between providers and the underlying storage/sync services
class PlayerDataService {
  static final PlayerDataService _instance = PlayerDataService._internal();
  factory PlayerDataService() => _instance;
  PlayerDataService._internal();

  final IsarService _isarService = IsarService();
  final SyncService _syncService = SyncService();

  // Player Profile methods
  Future<PlayerProfile?> getPlayerProfile(String userId) async {
    final profile = await _isarService.getPlayerProfile(userId);
    
    // Trigger background sync if online
    if (await _syncService.hasConnectivity) {
      _syncService.syncPlayerProfile().catchError((error) {
        print('Background profile sync error: $error');
      });
    }
    
    return profile;
  }

  Future<void> updatePlayerProfile(PlayerProfile profile) async {
    profile.needsSync = true;
    await _isarService.savePlayerProfile(profile);
    
    // Trigger sync if online
    if (await _syncService.hasConnectivity) {
      _syncService.syncPlayerProfile().catchError((error) {
        print('Profile sync error: $error');
      });
    }
  }

  // Vocabulary Progress methods
  Future<List<MasteredPhrase>> getAllVocabularyProgress() async {
    final phrases = await _isarService.getAllMasteredPhrases();
    
    // Trigger background sync if online
    if (await _syncService.hasConnectivity) {
      _syncService.syncVocabularyProgress().catchError((error) {
        print('Background vocabulary sync error: $error');
      });
    }
    
    return phrases;
  }

  Future<MasteredPhrase?> getPhraseProgress(String phraseId) async {
    return await _isarService.getMasteredPhrase(phraseId);
  }

  Future<void> updatePhraseProgress(MasteredPhrase phrase) async {
    phrase.needsSync = true;
    await _isarService.saveMasteredPhrase(phrase);
    
    // Trigger sync if online
    if (await _syncService.hasConnectivity) {
      _syncService.syncVocabularyProgress().catchError((error) {
        print('Phrase sync error: $error');
      });
    }
  }

  // Custom Vocabulary methods
  Future<List<CustomVocabularyEntry>> getAllCustomVocabulary() async {
    final customWords = await _isarService.getAllCustomVocabulary();
    
    // Trigger background sync if online
    if (await _syncService.hasConnectivity) {
      _syncService.syncCustomVocabulary().catchError((error) {
        print('Background custom vocabulary sync error: $error');
      });
    }
    
    return customWords;
  }

  Future<CustomVocabularyEntry?> getCustomWord(String wordThai) async {
    return await _isarService.getCustomVocabulary(wordThai);
  }

  Future<void> addCustomWord(CustomVocabularyEntry word) async {
    word.needsSync = true;
    await _isarService.saveCustomVocabulary(word);
    
    // Trigger sync if online
    if (await _syncService.hasConnectivity) {
      _syncService.syncCustomVocabulary().catchError((error) {
        print('Custom word sync error: $error');
      });
    }
  }

  Future<void> updateCustomWord(CustomVocabularyEntry word) async {
    word.needsSync = true;
    await _isarService.saveCustomVocabulary(word);
    
    // Trigger sync if online
    if (await _syncService.hasConnectivity) {
      _syncService.syncCustomVocabulary().catchError((error) {
        print('Custom word update sync error: $error');
      });
    }
  }

  // Battle Session methods
  Future<void> recordBattleSession({
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
    // Upload battle session directly to Supabase
    await _syncService.uploadBattleSession(
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
  }

  // Sync methods
  Future<void> performFullSync() async {
    if (await _syncService.hasConnectivity) {
      await _syncService.syncAll();
    }
  }

  Future<bool> get isOnline => _syncService.hasConnectivity;

  // Analytics methods
  Future<Map<String, dynamic>> getVocabularyStats() async {
    final customWords = await getAllCustomVocabulary();
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
  }

  // Pronunciation History methods
  Future<void> recordPronunciationAttempt({
    String? phraseId,
    String? customWordId,
    required double pronunciationScore,
    required double accuracyScore,
    required double fluencyScore,
    required double completenessScore,
    List<Map<String, dynamic>>? wordErrors,
    required String sessionContext, // 'battle', 'dialogue', 'practice'
    String? sessionId,
  }) async {
    if (!await _syncService.hasConnectivity) return;

    try {
      await SupabaseService.client
          .from('pronunciation_history')
          .insert({
            'user_id': _syncService.currentUserId,
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
      print('Error recording pronunciation attempt: $e');
    }
  }

  // Vocabulary tracking with analytics
  Future<void> recordWordDiscovery({
    required String wordThai,
    String? wordEnglish,
    String? discoveredFromNpc,
    String? learningContext,
  }) async {
    // Update local vocabulary
    final customWord = CustomVocabularyEntry()
      ..wordThai = wordThai
      ..wordEnglish = wordEnglish
      ..discoveredFromNpc = discoveredFromNpc
      ..firstDiscoveredAt = DateTime.now()
      ..lastUsedAt = DateTime.now()
      ..needsSync = true;

    await _isarService.saveCustomVocabulary(customWord);
    
    // Track in PostHog
    PostHogService.trackVocabularyLearning(
      event: 'word_discovered',
      wordThai: wordThai,
      wordEnglish: wordEnglish,
      discoveredFromNpc: discoveredFromNpc,
      learningContext: learningContext,
    );
    
    // Update session progress
    final session = await getCurrentSession();
    if (session != null) {
      session.wordsDiscoveredThisSession += 1;
      await _isarService.saveCurrentSession(session);
    }
  }
  
  Future<void> recordWordMastery({
    required String wordThai,
    required double pronunciationScore,
    required int attemptNumber,
  }) async {
    // Mark word as mastered locally
    final word = await _isarService.getCustomVocabulary(wordThai);
    if (word != null) {
      word.isMastered = true;
      word.pronunciationScores.add(pronunciationScore);
      word.lastUsedAt = DateTime.now();
      word.needsSync = true;
      await _isarService.saveCustomVocabulary(word);
    }
    
    // Track in PostHog
    PostHogService.trackVocabularyLearning(
      event: 'word_mastered',
      wordThai: wordThai,
      pronunciationScore: pronunciationScore,
      attemptNumber: attemptNumber,
    );
  }

  Future<List<CustomVocabularyEntry>> getCustomWordsForNpc(String npcId) async {
    final allWords = await getAllCustomVocabulary();
    return allWords.where((w) => w.discoveredFromNpc == npcId).toList();
  }

  // Character Tracing methods (now tracked via PostHog)
  Future<void> recordCharacterTracingAttempt({
    required String phraseId,
    required int characterPosition,
    required String expectedCharacter,
    required bool isCorrect,
    required double accuracyPercentage,
    String? recognizedText,
    double? confidenceScore,
  }) async {
    // Track in PostHog for analytics
    PostHogService.trackCharacterTracing(
      event: isCorrect ? 'character_traced' : 'character_failed',
      character: expectedCharacter,
      phraseId: phraseId,
      characterPosition: characterPosition,
      isCorrect: isCorrect,
      accuracyPercentage: accuracyPercentage,
      recognizedText: recognizedText,
      confidenceScore: confidenceScore,
    );
    
    // If mastery threshold reached, track mastery event
    if (isCorrect && accuracyPercentage >= 80.0) {
      PostHogService.trackCharacterTracing(
        event: 'character_mastered',
        character: expectedCharacter,
        phraseId: phraseId,
        accuracyPercentage: accuracyPercentage,
      );
    }
  }

  // NPC Interaction methods (local game state + PostHog analytics)
  Future<void> recordNpcInteraction({
    required String npcId,
    required String interactionType,
    required int charmLevel,
    int charmChange = 0,
    List<String> wordsLearned = const [],
    double? pronunciationScore,
    bool conversationSuccess = true,
    String? questCompleted,
  }) async {
    // Update local NPC state (game state)
    final localNpcState = await _isarService.getNpcInteractionState(npcId) ?? 
        NpcInteractionState()..npcId = npcId;
    
    final previousCharm = localNpcState.charmLevel;
    localNpcState.charmLevel = charmLevel;
    localNpcState.lastInteractionAt = DateTime.now();
    localNpcState.totalInteractions += 1;
    
    if (questCompleted != null) {
      localNpcState.completedQuests.add(questCompleted);
    }
    
    await _isarService.saveNpcInteractionState(localNpcState);
    
    // Track analytics in PostHog
    PostHogService.trackNPCConversation(
      npcName: npcId,
      event: interactionType,
      charmLevel: charmLevel,
      additionalProperties: {
        'conversation_success': conversationSuccess,
        'words_learned_count': wordsLearned.length,
        if (pronunciationScore != null) 'pronunciation_score': pronunciationScore,
      },
    );
    
    // Track charm changes
    if (charmChange != 0) {
      PostHogService.trackNpcRelationship(
        event: charmChange > 0 ? 'charm_increased' : 'charm_decreased',
        npcId: npcId,
        charmBefore: previousCharm,
        charmAfter: charmLevel,
        charmChange: charmChange,
        wordsLearned: wordsLearned,
      );
    }
    
    // Track quest completion
    if (questCompleted != null) {
      PostHogService.trackNpcRelationship(
        event: 'quest_completed',
        npcId: npcId,
        questId: questCompleted,
        charmAfter: charmLevel,
      );
    }
  }

  // Session tracking methods (simplified for PostHog analytics)
  Future<void> startLearningSession({
    required String sessionId,
  }) async {
    final session = CurrentSession()
      ..sessionId = sessionId
      ..startTime = DateTime.now();

    await _isarService.saveCurrentSession(session);
    
    // Session start is tracked by PostHogService.initializeUser()
  }

  Future<void> endLearningSession() async {
    final session = await _isarService.getCurrentSession();
    if (session != null) {
      final duration = DateTime.now().difference(session.startTime).inSeconds;
      
      // Track learning session analytics in PostHog
      PostHogService.trackSessionEnd(
        wordsDiscovered: session.wordsDiscoveredThisSession,
        wordsImproved: session.wordsImprovedThisSession,
        durationSeconds: duration,
      );
      
      // Clear the current session
      await _isarService.clearCurrentSession();
    }
  }

  Future<CurrentSession?> getCurrentSession() async {
    return await _isarService.getCurrentSession();
  }
}