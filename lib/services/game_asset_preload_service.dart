import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/flame.dart';
import 'package:flame_audio/flame_audio.dart';
import 'dart:async';

/// Service responsible for preloading game-specific assets during game loading screen
/// This handles all assets that were causing the -11800 error in BabblelonGame.onLoad()
class GameAssetPreloadService {
  static final GameAssetPreloadService _instance = GameAssetPreloadService._internal();
  factory GameAssetPreloadService() => _instance;
  GameAssetPreloadService._internal();

  // Preload state tracking
  bool _isPreloaded = false;
  bool _isPreloading = false;
  
  // Progress tracking
  double _preloadProgress = 0.0;
  String _currentPreloadStep = '';
  
  // Game-specific asset lists
  final List<String> _gameImages = [
    'player/sprite_male_tourist.png',
    'player/sprite_female_tourist.png',
    'player/capybara.png',
    'npcs/sprite_dimsum_vendor_female.png',
    'npcs/sprite_kwaychap_vendor.png',
    'npcs/sprite_noodle_vendor_female.png',
    'ui/speech_bubble_interact.png', // Speech bubble sprite for NPC interactions
    'bosses/tuktuk/portal.png',
    'bosses/tuktuk/sprite_tuktukmonster.png',
    'background/bossfight_tuktuk_bg.png',
    'background/yaowarat_bg2.png', // Main game background
  ];
  
  final List<String> _gameAudioFiles = [
    'bg/background_yaowarat.wav',
    'bg/background_tuktukbossfight.wav',
    'soundeffects/soundeffect_crispyporkbelly.mp3',
    'soundeffects/soundeffect_defeat.mp3',
    'soundeffects/soundeffect_victory.mp3',
    'soundeffects/soundeffect_portal_v2.mp3',
    'soundeffects/soundeffect_speechbubble.mp3',
  ];
  
  final List<String> _gameDataFiles = [
    'assets/data/thai_writing_guide.json',
    'assets/data/npc_vocabulary_somchai.json',
    'assets/data/npc_vocabulary_amara.json',
    'assets/data/beginner_food_vocabulary.json',
  ];

  // Getters for status
  bool get isPreloaded => _isPreloaded;
  bool get isPreloading => _isPreloading;
  double get preloadProgress => _preloadProgress;
  String get currentPreloadStep => _currentPreloadStep;

  /// Preload all game assets in phases
  Future<bool> preloadGameAssets({
    Function(double progress, String step)? onProgress,
    BuildContext? context,
  }) async {
    if (_isPreloaded) return true;
    if (_isPreloading) return false; // Already in progress
    
    _isPreloading = true;
    _preloadProgress = 0.0;
    
    try {
      // Phase 1: Initialize FlameAudio system (0-30%)
      await _initializeAudioSystem(onProgress);
      
      // Phase 2: Game sprites and backgrounds (30-60%)
      await _preloadGameImages(onProgress);
      
      // Phase 3: Game audio files (60-80%)
      await _preloadGameAudio(onProgress);
      
      // Phase 4: Game data files (80-100%)
      await _preloadGameData(onProgress);
      
      _updateProgress(1.0, 'Game assets ready!', onProgress);
      
      _isPreloaded = true;
      _isPreloading = false;
      
      debugPrint('🎮 Game asset preloading completed successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ Game asset preloading failed: $e');
      _isPreloading = false;
      _isPreloaded = false;
      rethrow;
    }
  }

  /// Initialize FlameAudio system to prevent -11800 error
  Future<void> _initializeAudioSystem(Function(double, String)? onProgress) async {
    _updateProgress(0.05, 'Initializing audio system...', onProgress);
    
    try {
      // Initialize FlameAudio BGM system
      FlameAudio.bgm.initialize();
      debugPrint('✅ FlameAudio BGM system initialized');
      
      // Small delay to ensure audio system is ready
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateProgress(0.3, 'Audio system ready', onProgress);
    } catch (e) {
      debugPrint('⚠️ Failed to initialize audio system: $e');
      // Continue despite error to prevent blocking
      _updateProgress(0.3, 'Audio system initialization skipped', onProgress);
    }
  }

  /// Preload game images using Flame's image cache
  Future<void> _preloadGameImages(Function(double, String)? onProgress) async {
    _updateProgress(0.3, 'Loading game graphics...', onProgress);
    
    for (int i = 0; i < _gameImages.length; i++) {
      final imagePath = _gameImages[i];
      
      try {
        await Flame.images.load(imagePath);
        debugPrint('✅ Loaded game image: $imagePath');
      } catch (error) {
        debugPrint('⚠️ Failed to preload game image $imagePath: $error');
        // Continue with other assets
      }
      
      // Update progress for each image
      final progress = 0.3 + (0.3 * ((i + 1) / _gameImages.length));
      _updateProgress(progress, 'Loading graphics... (${i + 1}/${_gameImages.length})', onProgress);
    }
    
    _updateProgress(0.6, 'Game graphics loaded', onProgress);
  }

  /// Preload game audio files using FlameAudio
  Future<void> _preloadGameAudio(Function(double, String)? onProgress) async {
    _updateProgress(0.6, 'Loading game audio...', onProgress);
    
    for (int i = 0; i < _gameAudioFiles.length; i++) {
      final audioPath = _gameAudioFiles[i];
      
      try {
        await FlameAudio.audioCache.load(audioPath);
        debugPrint('✅ Loaded game audio: $audioPath');
      } catch (error) {
        debugPrint('⚠️ Failed to preload game audio $audioPath: $error');
        // Continue with other assets
      }
      
      // Update progress for each audio file
      final progress = 0.6 + (0.2 * ((i + 1) / _gameAudioFiles.length));
      _updateProgress(progress, 'Loading audio... (${i + 1}/${_gameAudioFiles.length})', onProgress);
    }
    
    _updateProgress(0.8, 'Game audio loaded', onProgress);
  }

  /// Preload game data files into memory
  Future<void> _preloadGameData(Function(double, String)? onProgress) async {
    _updateProgress(0.8, 'Loading game data...', onProgress);
    
    for (int i = 0; i < _gameDataFiles.length; i++) {
      final dataPath = _gameDataFiles[i];
      
      try {
        final data = await rootBundle.loadString(dataPath);
        debugPrint('✅ Loaded game data: $dataPath (${data.length} characters)');
      } catch (error) {
        debugPrint('⚠️ Failed to preload game data $dataPath: $error');
        // Continue with other assets
      }
      
      // Update progress for each data file
      final progress = 0.8 + (0.2 * ((i + 1) / _gameDataFiles.length));
      _updateProgress(progress, 'Loading data... (${i + 1}/${_gameDataFiles.length})', onProgress);
    }
    
    _updateProgress(1.0, 'Game data loaded', onProgress);
  }

  /// Check if specific assets are preloaded
  bool areGameAssetsPreloaded() {
    return _isPreloaded;
  }

  /// Clear all cached game assets (for memory management)
  void clearGameAssetCache() {
    Flame.images.clearCache();
    FlameAudio.audioCache.clearAll();
    _isPreloaded = false;
    debugPrint('🧹 Game asset cache cleared');
  }

  /// Reset preload state (for testing or re-preloading)
  void reset() {
    _isPreloaded = false;
    _isPreloading = false;
    _preloadProgress = 0.0;
    _currentPreloadStep = '';
    debugPrint('🔄 Game asset preload service reset');
  }

  /// Update progress and notify callback
  void _updateProgress(double progress, String step, Function(double, String)? onProgress) {
    _preloadProgress = progress;
    _currentPreloadStep = step;
    onProgress?.call(progress, step);
    debugPrint('🎯 Game asset preload: ${(progress * 100).toInt()}% - $step');
  }

  /// Get preload statistics
  Map<String, dynamic> getPreloadStats() {
    return {
      'isPreloaded': _isPreloaded,
      'isPreloading': _isPreloading,
      'preloadProgress': _preloadProgress,
      'currentStep': _currentPreloadStep,
      'gameImages': _gameImages.length,
      'gameAudioFiles': _gameAudioFiles.length,
      'gameDataFiles': _gameDataFiles.length,
      'totalAssets': _gameImages.length + _gameAudioFiles.length + _gameDataFiles.length,
    };
  }
}