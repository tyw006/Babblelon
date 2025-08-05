import 'package:isar/isar.dart';

part 'local_storage_models.g.dart';

@collection
class PlayerProfile {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String userId;
  
  String? username;
  String? avatarUrl;
  int playerLevel = 1;
  int experiencePoints = 0;
  int gold = 0;
  
  // Core game progress (offline-first)
  int currentStreak = 0;
  int maxStreak = 0;
  DateTime? lastActiveAt;
  
  // Essential learning progress
  int totalWordsDiscovered = 0;
  int totalWordsMastered = 0;
  
  // Sync metadata
  DateTime? lastSyncedAt;
  bool needsSync = true;
  String? supabaseId; // UUID from Supabase
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