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

// Player profile model
class PlayerProfile {
  final String id;
  String name;
  int highScore;
  int totalGames;
  Map<String, int> levelScores;
  
  PlayerProfile({
    required this.id,
    required this.name,
    this.highScore = 0,
    this.totalGames = 0,
    Map<String, int>? levelScores,
  }) : levelScores = levelScores ?? {};
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'highScore': highScore,
      'totalGames': totalGames,
      'levelScores': levelScores,
    };
  }
  
  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'],
      name: json['name'],
      highScore: json['highScore'],
      totalGames: json['totalGames'],
      levelScores: Map<String, int>.from(json['levelScores'] ?? {}),
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