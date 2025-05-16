class AppConstants {
  // App Info
  static const String appName = 'Babblelon';
  static const String appVersion = '0.1.0';
  
  // Game Settings
  static const int defaultLives = 3;
  static const double playerSpeed = 150.0;
  static const double gameGravity = 9.8;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Animation Constants
  static const double animationDuration = 0.3;
  
  // Game Mechanics
  static const int scorePerWord = 10;
  static const int bonusScoreMultiplier = 2;
  
  // Audio
  static const String backgroundMusicPath = 'audio/background_music.mp3';
  static const String collectSoundPath = 'audio/collect.mp3';
  static const String gameOverSoundPath = 'audio/game_over.mp3';
  
  // Assets
  static const String playerSpritePath = 'images/player.png';
  static const String backgroundImagePath = 'images/background.png';
  
  // API Endpoints
  static const String leaderboardEndpoint = '/leaderboard';
  static const String userProfileEndpoint = '/profile';
} 