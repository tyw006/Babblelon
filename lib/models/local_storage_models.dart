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
  
  // Enhanced fields to match Supabase players table
  int totalPlaytime = 0;
  int currentStreak = 0;
  int maxStreak = 0;
  DateTime? lastActiveAt;
  
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

  // NEW: Character tracing tracking fields
  double? lastTracingScore; // Latest character drawing accuracy (0-100)
  int timesTraced = 0; // Count of character tracing attempts
  bool isCharacterMastered = false; // Character drawing mastery (60+ score)
  DateTime? lastTracedAt; // Last character tracing timestamp
  List<String> masteredCharacters = []; // Individual characters mastered
  double? lastConfidenceScore; // ML Kit confidence score (0.0-1.0)
  String? lastRecognizedCharacter; // Last character recognized by ML Kit
  
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
  String? npcContext; // Which NPC/conversation this was discovered in
  int timesUsed = 1;
  DateTime firstDiscoveredAt = DateTime.now();
  DateTime lastUsedAt = DateTime.now();
  double? pronunciationScore;
  bool isMastered = false;
  
  // Sync metadata
  DateTime? lastSyncedAt;
  bool needsSync = true;
  String? supabaseId; // UUID from Supabase
} 