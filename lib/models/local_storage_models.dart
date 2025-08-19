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
  
  // Authentication metadata (email-first signup only)
  // Note: All users now have email-based accounts
  
  // Tutorial progress (per language)
  String? tutorialsCompletedJson; // JSON string: {"thai_gameplay": true, "korean_writing": false}
  bool gameplayTutorialCompleted = false; // Legacy - kept for backwards compatibility
  bool speechTutorialCompleted = false; // Legacy - kept for backwards compatibility
  bool tracingTutorialCompleted = false; // Legacy - kept for backwards compatibility
  
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