// Base class for game levels
class GameLevel {
  final String id;
  final String name;
  final int difficulty;
  final int targetScore;
  final bool isUnlocked;
  
  GameLevel({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.targetScore,
    this.isUnlocked = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'difficulty': difficulty,
      'targetScore': targetScore,
      'isUnlocked': isUnlocked,
    };
  }
  
  factory GameLevel.fromJson(Map<String, dynamic> json) {
    return GameLevel(
      id: json['id'],
      name: json['name'],
      difficulty: json['difficulty'],
      targetScore: json['targetScore'],
      isUnlocked: json['isUnlocked'],
    );
  }
}

// Player profile model with comprehensive onboarding data
class PlayerProfile {
  final String id;
  String? firstName;
  String? lastName;
  String? avatarUrl;
  int? age;
  
  // Computed display name from first and last name
  String get displayName => '${firstName ?? ""} ${lastName ?? ""}'.trim();
  
  // Game progression
  int playerLevel;
  int experiencePoints;
  int gold;
  int currentStreak;
  int maxStreak;
  int highScore;
  int totalGames;
  Map<String, int> levelScores;
  
  // Language settings
  String targetLanguage;
  String targetLanguageLevel;
  bool hasPriorLearning;
  String? priorLearningDetails;
  String? nativeLanguage;
  
  // Character customization
  String? selectedCharacter;
  Map<String, dynamic> characterCustomization;
  
  // Learning preferences
  String? learningMotivation;
  String? learningPace;
  String? learningStyle;
  String? learningContext;
  int dailyGoalMinutes;
  String? preferredPracticeTime;
  Map<String, dynamic> learningPreferences;
  
  // Consent & metadata
  bool voiceRecordingConsent;
  bool personalizedContentConsent;
  bool privacyPolicyAccepted;
  bool dataCollectionConsented;
  DateTime? consentDate;
  String? onboardingVersion;
  
  // Authentication (email-first signup only)
  // Note: All users now have email-verified accounts
  
  // Tutorial tracking
  Map<String, dynamic> tutorialsCompleted;
  
  // Timestamps
  DateTime? createdAt;
  DateTime? lastActiveAt;
  bool onboardingCompleted;
  DateTime? onboardingCompletedAt;
  
  PlayerProfile({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.age,
    this.playerLevel = 1,
    this.experiencePoints = 0,
    this.gold = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.highScore = 0,
    this.totalGames = 0,
    Map<String, int>? levelScores,
    this.targetLanguage = 'thai',
    this.targetLanguageLevel = 'beginner',
    this.hasPriorLearning = false,
    this.priorLearningDetails,
    this.nativeLanguage,
    this.selectedCharacter,
    Map<String, dynamic>? characterCustomization,
    this.learningMotivation,
    this.learningPace,
    this.learningStyle,
    this.learningContext,
    this.dailyGoalMinutes = 15,
    this.preferredPracticeTime,
    Map<String, dynamic>? learningPreferences,
    this.voiceRecordingConsent = false,
    this.personalizedContentConsent = true,
    this.privacyPolicyAccepted = false,
    this.dataCollectionConsented = false,
    this.consentDate,
    this.onboardingVersion = '1.0',
    // Note: isAnonymous and accountUpgradedAt fields removed - email-first signup only
    Map<String, dynamic>? tutorialsCompleted,
    this.createdAt,
    this.lastActiveAt,
    this.onboardingCompleted = false,
    this.onboardingCompletedAt,
  }) : levelScores = levelScores ?? {},
       characterCustomization = characterCustomization ?? {},
       learningPreferences = learningPreferences ?? {},
       tutorialsCompleted = tutorialsCompleted ?? {};
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': id, // Note: Supabase uses user_id not id
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'age': age,
      'level': playerLevel,
      'experience_points': experiencePoints,
      'coins': gold,
      'current_streak': currentStreak,
      'max_streak': maxStreak,
      'score': highScore,
      'total_games': totalGames,
      'level_scores': levelScores,
      'target_language': targetLanguage,
      'target_language_level': targetLanguageLevel,
      'has_prior_learning': hasPriorLearning,
      'prior_learning_details': priorLearningDetails,
      'native_language': nativeLanguage,
      'selected_character': selectedCharacter,
      'character_customization': characterCustomization,
      'learning_motivation': learningMotivation,
      'learning_pace': learningPace,
      'learning_style': learningStyle,
      'learning_context': learningContext,
      'daily_goal_minutes': dailyGoalMinutes,
      'preferred_practice_time': preferredPracticeTime,
      'learning_preferences': learningPreferences,
      'voice_recording_consent': voiceRecordingConsent,
      'personalized_content_consent': personalizedContentConsent,
      'privacy_policy_accepted': privacyPolicyAccepted,
      'data_collection_consented': dataCollectionConsented,
      'consent_date': consentDate?.toIso8601String(),
      'onboarding_version': onboardingVersion,
      // Note: isAnonymous and accountUpgradedAt fields removed - email-first signup only
      'tutorials_completed': tutorialsCompleted,
      'created_at': createdAt?.toIso8601String(),
      'last_active_at': lastActiveAt?.toIso8601String(),
      'onboarding_completed': onboardingCompleted,
      'onboarding_completed_at': onboardingCompletedAt?.toIso8601String(),
    };
  }
  
  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['user_id'] ?? json['id'], // Handle both formats
      firstName: json['first_name'],
      lastName: json['last_name'],
      avatarUrl: json['avatar_url'],
      age: json['age'],
      playerLevel: json['level'] ?? 1,
      experiencePoints: json['experience_points'] ?? 0,
      gold: json['coins'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      maxStreak: json['max_streak'] ?? 0,
      highScore: json['score'] ?? json['highScore'] ?? 0,
      totalGames: json['total_games'] ?? json['totalGames'] ?? 0,
      levelScores: Map<String, int>.from(json['level_scores'] ?? json['levelScores'] ?? {}),
      targetLanguage: json['target_language'] ?? 'thai',
      targetLanguageLevel: json['target_language_level'] ?? 'beginner',
      hasPriorLearning: json['has_prior_learning'] ?? false,
      priorLearningDetails: json['prior_learning_details'],
      nativeLanguage: json['native_language'],
      selectedCharacter: json['selected_character'],
      characterCustomization: Map<String, dynamic>.from(json['character_customization'] ?? {}),
      learningMotivation: json['learning_motivation'],
      learningPace: json['learning_pace'],
      learningStyle: json['learning_style'],
      learningContext: json['learning_context'],
      dailyGoalMinutes: json['daily_goal_minutes'] ?? 15,
      preferredPracticeTime: json['preferred_practice_time'],
      learningPreferences: Map<String, dynamic>.from(json['learning_preferences'] ?? {}),
      voiceRecordingConsent: json['voice_recording_consent'] ?? false,
      personalizedContentConsent: json['personalized_content_consent'] ?? true,
      privacyPolicyAccepted: json['privacy_policy_accepted'] ?? false,
      dataCollectionConsented: json['data_collection_consented'] ?? false,
      consentDate: json['consent_date'] != null ? DateTime.parse(json['consent_date']) : null,
      onboardingVersion: json['onboarding_version'] ?? '1.0',
      // Note: isAnonymous and accountUpgradedAt fields removed - email-first signup only
      tutorialsCompleted: Map<String, dynamic>.from(json['tutorials_completed'] ?? {}),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      lastActiveAt: json['last_active_at'] != null ? DateTime.parse(json['last_active_at']) : null,
      onboardingCompleted: json['onboarding_completed'] ?? false,
      onboardingCompletedAt: json['onboarding_completed_at'] != null ? DateTime.parse(json['onboarding_completed_at']) : null,
    );
  }
  
  void updateScore(String levelId, int score) {
    if (!levelScores.containsKey(levelId) || score > levelScores[levelId]!) {
      levelScores[levelId] = score;
    }
    
    if (score > highScore) {
      highScore = score;
    }
    
    totalGames++;
  }
}

// Game settings model
class GameSettings {
  bool soundEnabled;
  bool musicEnabled;
  double soundVolume;
  double musicVolume;
  bool vibrationEnabled;
  
  GameSettings({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.soundVolume = 0.7,
    this.musicVolume = 0.5,
    this.vibrationEnabled = true,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'soundEnabled': soundEnabled,
      'musicEnabled': musicEnabled,
      'soundVolume': soundVolume,
      'musicVolume': musicVolume,
      'vibrationEnabled': vibrationEnabled,
    };
  }
  
  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      soundEnabled: json['soundEnabled'] ?? true,
      musicEnabled: json['musicEnabled'] ?? true,
      soundVolume: json['soundVolume'] ?? 0.7,
      musicVolume: json['musicVolume'] ?? 0.5,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
    );
  }
}

class WordMapping {
  final String thai;
  final String transliteration;
  final String translation;

  WordMapping({
    required this.thai,
    required this.transliteration,
    required this.translation,
  });

  factory WordMapping.fromJson(Map<String, dynamic> json) {
    return WordMapping(
      thai: json['thai'],
      transliteration: json['transliteration'],
      translation: json['translation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thai': thai,
      'transliteration': transliteration,
      'translation': translation,
    };
  }
}

// Vocabulary model for language learning
class Vocabulary {
  final String english;
  final String thai;
  final String transliteration;
  final List<WordMapping> wordMapping;
  final int complexity;
  final String foodCategory;
  final String? details;
  final String? slang;
  final String? audioPath;

  Vocabulary({
    required this.english,
    required this.thai,
    required this.transliteration,
    required this.wordMapping,
    required this.complexity,
    required this.foodCategory,
    this.details,
    this.slang,
    this.audioPath,
  });

  factory Vocabulary.fromJson(Map<String, dynamic> json) {
    var wordMappingList = json['word_mapping'] as List;
    List<WordMapping> mappings = wordMappingList.map((i) => WordMapping.fromJson(i)).toList();

    return Vocabulary(
      english: json['english'],
      thai: json['thai'],
      transliteration: json['transliteration'],
      wordMapping: mappings,
      complexity: json['complexity'],
      foodCategory: json['food_category'] ?? '',
      details: json['details'],
      slang: json['slang'],
      audioPath: json['audio_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'thai': thai,
      'transliteration': transliteration,
      'word_mapping': wordMapping.map((item) => item.toJson()).toList(),
      'complexity': complexity,
      'food_category': foodCategory,
      'details': details,
      'slang': slang,
      'audioPath': audioPath,
    };
  }
}