import 'package:isar/isar.dart';

part 'local_storage_models.g.dart';

@collection
class PlayerProfile {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String userId;
  
  // Basic profile info
  String? username;
  String? displayName;
  String? avatarUrl;
  int? age;
  DateTime? createdAt;
  DateTime? lastActiveAt;
  
  // Game progression
  int playerLevel = 1;
  int experiencePoints = 0;
  int gold = 0;
  
  // Onboarding and learning preferences  
  bool onboardingCompleted = false;
  String? nativeLanguage; // ISO language code (e.g., 'en', 'zh', 'es')
  String? learningMotivation; // 'travel', 'culture', 'business', 'family', 'personal'
  String? learningPace; // 'casual', 'moderate', 'intensive'
  String? learningStyle; // 'visual', 'auditory', 'kinesthetic', 'mixed'
  int dailyGoalMinutes = 15; // Daily practice goal in minutes
  String? thaiSkillLevel; // 'beginner', 'elementary', 'intermediate', 'advanced'
  
  // Notification preferences
  bool practiceRemindersEnabled = true;
  String? preferredPracticeTime; // 'morning', 'afternoon', 'evening'
  List<int> reminderDays = const [1, 2, 3, 4, 5]; // Monday-Friday by default
  
  // Privacy and consent
  bool privacyPolicyAccepted = false;
  bool dataCollectionConsented = false;
  DateTime? consentDate;
  
  // Tutorial progress
  bool gameplayTutorialCompleted = false;
  bool speechTutorialCompleted = false;
  bool tracingTutorialCompleted = false;
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
} 