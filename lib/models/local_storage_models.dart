import 'dart:convert';
import 'package:isar/isar.dart';

part 'local_storage_models.g.dart';

@collection
class PlayerProfile {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String userId;
  
  // Basic profile info
  String? firstName;
  String? lastName;
  String? avatarUrl;
  int? age;
  
  // Computed display name from first and last name
  String get displayName => '${firstName ?? ""} ${lastName ?? ""}'.trim();
  DateTime? createdAt;
  DateTime? lastActiveAt;
  
  // Game progression
  int playerLevel = 1;
  int experiencePoints = 0;
  int gold = 0;
  
  // Core game progress (offline-first)
  int currentStreak = 0;
  int maxStreak = 0;
  
  // Essential learning progress
  int totalWordsDiscovered = 0;
  int totalWordsMastered = 0;
  
  // Sync metadata
  DateTime? lastSyncedAt;
  bool needsSync = true;
  String? supabaseId; // UUID from Supabase
  
  // Onboarding and learning preferences  
  bool onboardingCompleted = false;
  DateTime? onboardingCompletedAt;
  String? onboardingVersion = '1.0';
  
  // Language settings
  String? targetLanguage = 'thai'; // 'thai', 'japanese', 'korean', 'mandarin', 'vietnamese'
  String? targetLanguageLevel = 'beginner'; // 'beginner', 'elementary', 'intermediate', 'advanced'
  bool hasPriorLearning = false;
  String? priorLearningDetails;
  String? nativeLanguage; // ISO language code (e.g., 'en', 'zh', 'es')
  
  // Character customization
  String? selectedCharacter; // Character ID/type
  String? characterCustomizationJson; // JSON string of customization options
  
  // Learning preferences
  String? learningMotivation; // 'travel', 'culture', 'business', 'family', 'personal', 'education'
  String? learningPace; // 'casual', 'moderate', 'intensive'
  String? learningStyle; // 'visual', 'auditory', 'kinesthetic', 'mixed'
  String? learningContext; // 'living_abroad', 'travel_prep', 'academic', 'business', 'cultural_interest'
  int dailyGoalMinutes = 15; // Daily practice goal in minutes
  String? learningPreferencesJson; // JSON string of flexible preferences storage
  
  // Notification preferences
  bool practiceRemindersEnabled = true;
  String? preferredPracticeTime; // 'morning', 'afternoon', 'evening'
  List<int> reminderDays = const [1, 2, 3, 4, 5]; // Monday-Friday by default
  
  // Privacy and consent
  bool privacyPolicyAccepted = false;
  bool dataCollectionConsented = false;
  bool voiceRecordingConsent = false;
  bool personalizedContentConsent = true;
  DateTime? consentDate;
  
  // Premium account tracking
  DateTime? accountUpgradedAt; // When user upgraded to premium
  
  // Authentication metadata (email-first signup only)
  // Note: All users now have email-based accounts
  
  // Tutorial progress (per language)
  String? tutorialsCompletedJson; // JSON string: {"thai_gameplay": true, "korean_writing": false}
  bool gameplayTutorialCompleted = false; // Legacy - kept for backwards compatibility
  bool speechTutorialCompleted = false; // Legacy - kept for backwards compatibility
  bool tracingTutorialCompleted = false; // Legacy - kept for backwards compatibility
  
  // Tutorial group progress tracking
  String? tutorialGroupsProgressJson; // JSON string: {"navigation": {"progress": 3, "total": 6, "completed": false}}
  String? tutorialCompletionMethodJson; // JSON string: {"tutorial_id": "viewed|skipped|auto_skipped"}
  
  // Helper methods for JSON fields
  @ignore
  Map<String, dynamic> get characterCustomization {
    if (characterCustomizationJson?.isEmpty ?? true) return {};
    try {
      return json.decode(characterCustomizationJson!) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
  
  set characterCustomization(Map<String, dynamic> value) {
    characterCustomizationJson = json.encode(value);
  }
  
  @ignore
  Map<String, dynamic> get learningPreferences {
    if (learningPreferencesJson?.isEmpty ?? true) return {};
    try {
      return json.decode(learningPreferencesJson!) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
  
  set learningPreferences(Map<String, dynamic> value) {
    learningPreferencesJson = json.encode(value);
  }
  
  @ignore
  Map<String, dynamic> get tutorialsCompleted {
    if (tutorialsCompletedJson?.isEmpty ?? true) return {};
    try {
      return json.decode(tutorialsCompletedJson!) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
  
  set tutorialsCompleted(Map<String, dynamic> value) {
    tutorialsCompletedJson = json.encode(value);
  }
  
  @ignore
  Map<String, dynamic> get tutorialGroupsProgress {
    if (tutorialGroupsProgressJson?.isEmpty ?? true) return {};
    try {
      return json.decode(tutorialGroupsProgressJson!) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
  
  set tutorialGroupsProgress(Map<String, dynamic> value) {
    tutorialGroupsProgressJson = json.encode(value);
  }
  
  @ignore
  Map<String, dynamic> get tutorialCompletionMethod {
    if (tutorialCompletionMethodJson?.isEmpty ?? true) return {};
    try {
      return json.decode(tutorialCompletionMethodJson!) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
  
  set tutorialCompletionMethod(Map<String, dynamic> value) {
    tutorialCompletionMethodJson = json.encode(value);
  }
}

@collection
class MasteredPhrase {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String phraseEnglishId;
  
  // Existing pronunciation tracking fields
  double? lastScore;
  int timesPracticed = 1;
  DateTime? lastPracticedAt;
  bool isMastered = false;
  List<double> scoreHistory = []; // Last 10 scores for trend analysis

  // Character tracing tracking fields
  double? lastTracingScore; // Latest character drawing accuracy (0-100)
  int timesTraced = 0; // Count of character tracing attempts
  bool isCharacterMastered = false; // Character drawing mastery (60+ score)
  DateTime? lastTracedAt; // Last character tracing timestamp
  List<String> masteredCharacters = []; // Individual characters mastered
  double? lastConfidenceScore; // ML Kit confidence score (0.0-1.0)
  String? lastRecognizedCharacter; // Last character recognized by ML Kit
  
  // Simplified context
  String? discoveredFromNpc; // Which NPC introduced this
  DateTime? firstPracticedAt;
  
  // Sync metadata
  DateTime? lastSyncedAt;
  bool needsSync = true;
}

@collection
class CustomVocabularyEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String wordThai;
  
  String? wordEnglish;
  String? transliteration;
  String? posTag; // Part of speech tag
  String? discoveredFromNpc; // NPC that introduced this word
  int timesUsed = 1;
  DateTime firstDiscoveredAt = DateTime.now();
  DateTime lastUsedAt = DateTime.now();
  List<double> pronunciationScores = []; // Score history
  bool isMastered = false;
  
  // Spaced repetition data
  DateTime? nextReviewDate;
  int reviewInterval = 1; // Days until next review
  
  // Sync metadata
  DateTime? lastSyncedAt;
  bool needsSync = true;
  String? supabaseId; // UUID from Supabase
}

@collection
class CurrentSession {
  Id id = Isar.autoIncrement;

  // Active session only (not historical)
  late String sessionId;
  DateTime startTime = DateTime.now();
  
  // Temporary learning progress
  int wordsDiscoveredThisSession = 0;
  int wordsImprovedThisSession = 0;
  
  // For offline sync when reconnected
  List<String> pendingSyncEvents = [];
}

@collection
class NpcInteractionState {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String npcId;
  
  // Quest state
  String categoriesAcceptedJson = '{}'; // JSON string for Map storage
  List<String> itemsGiven = [];
  bool scenarioComplete = false;
  int conversationTurns = 0;
  
  // Relationship data
  int charmLevel = 50; // 0-100
  List<int> charmHistory = []; // Track charm changes over time
  DateTime? lastInteractionAt;
  int totalInteractions = 0;
  
  // Essential NPC state only
  List<String> unlockedDialogueOptions = [];
  List<String> completedQuests = [];
  
  // Sync metadata  
  DateTime? lastSyncedAt;
  bool needsSync = true;
}

@collection
class GameSaveState {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true, replace: true)  // Only ONE save per level - auto-replaces old saves
  late String levelId;
  
  String gameType = 'babblelon_game'; // 'babblelon_game' or 'boss_fight'
  DateTime timestamp = DateTime.now();
  
  // BabblelonGame specific state
  String? playerPositionJson; // JSON: {"x": 100.0, "y": 200.0}
  String? inventoryJson; // JSON: {"attack": "path1", "defense": "path2"}
  String? conversationHistoryJson; // JSON: ["message1", "message2", ...] (last 10 only)
  List<String> cachedAudioPaths = []; // Asset paths for cleanup
  String? npcStatesJson; // JSON: compressed NPC interaction states
  
  // Boss Fight specific state  
  String? bossId;
  String? currentTurn; // 'player' or 'boss'
  int? playerHealth;
  int? bossHealth;
  String? usedFlashcardsJson; // JSON: [1, 3, 5] - indices of used flashcards
  String? activeFlashcardsJson; // JSON: [0, 2, 4, 7] - indices of the 4 cards currently on screen
  String? revealedCardsJson; // JSON: ["card_0", "card_2"] - IDs of cards that have been revealed/tapped
  String? battleMetricsJson; // JSON: serialized battle metrics
  
  // Resume metadata
  double progressPercentage = 0.0; // 0.0 to 100.0 for UI display
  int npcsVisited = 0;
  int itemsCollected = 0;
  
  // Automatic cleanup
  DateTime? expiresAt; // Auto-expire old saves after 7 days
  
  // Helper method to check if save is expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  
  // Helper method to set expiry (7 days from now)
  void setExpiry() {
    expiresAt = DateTime.now().add(const Duration(days: 7));
  }
  
  // Inventory data getter
  @ignore
  Map<String, String?> get inventoryData {
    if (inventoryJson?.isEmpty ?? true) return {};
    try {
      final decoded = json.decode(inventoryJson!) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value?.toString()));
    } catch (e) {
      return {};
    }
  }
} 