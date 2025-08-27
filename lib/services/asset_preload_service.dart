import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/flame.dart';
import 'package:flame_audio/flame_audio.dart';
import 'dart:async';

/// Service responsible for preloading all game assets to prevent lag during gameplay
class AssetPreloadService {
  static final AssetPreloadService _instance = AssetPreloadService._internal();
  factory AssetPreloadService() => _instance;
  AssetPreloadService._internal();

  // Preload state tracking
  bool _isPreloaded = false;
  bool _isPreloading = false;
  
  // Progress tracking
  double _preloadProgress = 0.0;
  String _currentPreloadStep = '';
  
  // Asset lists - INTRO/NAVIGATION ONLY (game assets moved to GameAssetPreloadService)
  final List<String> _criticalImages = [
    'maps/map_thailand.png', // Thailand map for navigation
  ];
  
  final List<String> _introImages = [
    'maps/map_thailand.png', // Thailand map for navigation
  ];
  
  final List<String> _introAudioFiles = [
    'bg/background_introscreen.wav', // Intro screen music
    'soundeffects/soundeffect_button.mp3', // Button sounds for navigation
    'soundeffects/soundeffect_startgame.mp3', // Start game sound
  ];
  
  final List<String> _intro3DAssets = [
    'assets/images/main_screen/earth_3d.glb', // 3D Earth model for immediate display
  ];

  // Getters for status
  bool get isPreloaded => _isPreloaded;
  bool get isPreloading => _isPreloading;
  double get preloadProgress => _preloadProgress;
  String get currentPreloadStep => _currentPreloadStep;

  /// Preload all game assets in phases
  Future<bool> preloadAssets({
    Function(double progress, String step)? onProgress,
    BuildContext? context,
  }) async {
    if (_isPreloaded) return true;
    if (_isPreloading) return false; // Already in progress
    
    _isPreloading = true;
    _preloadProgress = 0.0;
    
    try {
      // Phase 1: Critical navigation assets (0-30%)
      await _preloadCriticalAssets(context, onProgress);
      
      // Phase 2: 3D Earth model (30-60%)
      await _preload3DAssets(onProgress);
      
      // Phase 3: Intro audio files (60-90%)
      await _preloadIntroAudioAssets(onProgress);
      
      // Phase 4: Navigation completion (90-100%)
      _updateProgress(1.0, 'Navigation ready!', onProgress);
      
      _isPreloaded = true;
      _isPreloading = false;
      
      print('🎮 Intro asset preloading completed successfully');
      return true;
      
    } catch (e) {
      print('❌ Asset preloading failed: $e');
      _isPreloading = false;
      _isPreloaded = false;
      rethrow;
    }
  }

  /// Preload critical UI assets using Flutter's precacheImage
  Future<void> _preloadCriticalAssets(
    BuildContext? context,
    Function(double, String)? onProgress,
  ) async {
    _updateProgress(0.05, 'Loading critical UI assets...', onProgress);
    
    // Skip Flutter precacheImage to avoid context disposal issues
    // Use Flame's image cache instead for better reliability
    for (int i = 0; i < _criticalImages.length; i++) {
      final imagePath = _criticalImages[i];
      
      // Convert full asset path to Flame-compatible path
      final flamePath = imagePath.replaceFirst('assets/images/', '');
      
      try {
        await Flame.images.load(flamePath);
      } catch (error) {
        debugPrint('⚠️ Failed to preload critical image $flamePath: $error');
        // Continue despite error - don't break the loading process
      }
      
      // Update progress for each image
      final progress = 0.05 + (0.25 * ((i + 1) / _criticalImages.length));
      _updateProgress(progress, 'Loading UI assets... (${i + 1}/${_criticalImages.length})', onProgress);
    }
    
    _updateProgress(0.3, 'Critical assets loaded', onProgress);
  }

  /// Preload 3D assets including earth model
  Future<void> _preload3DAssets(Function(double, String)? onProgress) async {
    _updateProgress(0.3, 'Loading 3D models...', onProgress);
    
    for (int i = 0; i < _intro3DAssets.length; i++) {
      final assetPath = _intro3DAssets[i];
      
      try {
        // For 3D assets, preload via rootBundle to ensure availability
        await rootBundle.load(assetPath);
        debugPrint('✅ Loaded 3D asset: $assetPath');
      } catch (error) {
        debugPrint('⚠️ Failed to preload 3D asset $assetPath: $error');
        // Continue with other assets
      }
      
      // Update progress for each asset
      final progress = 0.3 + (0.3 * ((i + 1) / _intro3DAssets.length));
      _updateProgress(progress, 'Loading 3D models... (${i + 1}/${_intro3DAssets.length})', onProgress);
    }
    
    _updateProgress(0.6, '3D assets loaded', onProgress);
  }

  /// Preload intro audio files using FlameAudio
  Future<void> _preloadIntroAudioAssets(Function(double, String)? onProgress) async {
    _updateProgress(0.6, 'Loading intro audio...', onProgress);
    
    for (int i = 0; i < _introAudioFiles.length; i++) {
      final audioPath = _introAudioFiles[i];
      
      try {
        await FlameAudio.audioCache.load(audioPath);
      } catch (error) {
        debugPrint('⚠️ Failed to preload intro audio $audioPath: $error');
        // Continue with other assets
      }
      
      // Update progress for each audio file
      final progress = 0.6 + (0.3 * ((i + 1) / _introAudioFiles.length));
      _updateProgress(progress, 'Loading intro audio... (${i + 1}/${_introAudioFiles.length})', onProgress);
    }
    
    _updateProgress(0.9, 'Intro audio loaded', onProgress);
  }


  /// Preload specific assets for a screen
  Future<void> preloadScreenAssets(String screenName) async {
    switch (screenName) {
      case 'boss_fight':
        await _preloadBossFightAssets();
        break;
      case 'dialogue':
        await _preloadDialogueAssets();
        break;
      case 'main_screen':
        await _preloadMainScreenAssets();
        break;
      default:
        print('⚠️ Unknown screen for asset preloading: $screenName');
    }
  }

  /// Preload boss fight specific assets
  Future<void> _preloadBossFightAssets() async {
    print('🎯 Preloading boss fight assets...');
    
    final bossAssets = [
      'bosses/tuktuk/sprite_tuktukmonster.png',
      'background/bossfight_tuktuk_bg.png',
      'bosses/tuktuk/portal.png',
    ];
    
    final futures = bossAssets.map((asset) => Flame.images.load(asset));
    await Future.wait(futures);
    
    // Preload boss fight audio
    await FlameAudio.audioCache.load('bg/background_tuktukbossfight.wav');
    
    print('✅ Boss fight assets preloaded');
  }

  /// Preload boss fight assets for a specific boss
  Future<void> preloadBossFightAssets({
    required dynamic bossData,
    required BuildContext context,
  }) async {
    debugPrint('🎯 Preloading boss fight assets for boss: ${bossData.name}');
    
    try {
      // Load boss-specific assets (sequentially to avoid overloading)
      final bossAssets = [
        'bosses/tuktuk/sprite_tuktukmonster.png',
        'background/bossfight_tuktuk_bg.png',
        'bosses/tuktuk/portal.png',
      ];
      
      for (final asset in bossAssets) {
        try {
          await Flame.images.load(asset);
        } catch (e) {
          debugPrint('⚠️ Failed to load boss asset $asset: $e');
          // Continue with other assets
        }
      }
      
      // Load boss fight audio
      final audioFiles = [
        'bg/background_tuktukbossfight.wav',
        'soundeffects/soundeffect_defeat.mp3',
        'soundeffects/soundeffect_victory.mp3',
      ];
      
      for (final audioFile in audioFiles) {
        try {
          await FlameAudio.audioCache.load(audioFile);
        } catch (e) {
          debugPrint('⚠️ Failed to load audio $audioFile: $e');
          // Continue with other assets
        }
      }
      
      // Load boss vocabulary data
      try {
        await rootBundle.loadString('assets/data/beginner_food_vocabulary.json');
      } catch (e) {
        debugPrint('⚠️ Failed to load boss vocabulary: $e');
        // Continue - not critical
      }
      
      debugPrint('✅ Boss fight assets preloaded successfully');
    } catch (e) {
      debugPrint('❌ Failed to preload boss fight assets: $e');
      // Don't rethrow - allow the game to continue with missing assets
    }
  }

  /// Preload dialogue specific assets
  Future<void> _preloadDialogueAssets() async {
    print('🎯 Preloading dialogue assets...');
    
    final dialogueAudio = [
      'soundeffects/soundeffect_speechbubble.mp3',
      'soundeffects/soundeffect_flashcardreveal.mp3',
    ];
    
    final futures = dialogueAudio.map((audio) => FlameAudio.audioCache.load(audio));
    await Future.wait(futures);
    
    print('✅ Dialogue assets preloaded');
  }

  /// Preload main screen specific assets
  Future<void> _preloadMainScreenAssets() async {
    debugPrint('🎯 Preloading main screen assets...');
    
    // These are already handled in critical assets, but we can add more specific ones
    await Future.wait([
      rootBundle.load('assets/images/main_screen/earth_3d.glb').catchError((e) {
        debugPrint('⚠️ 3D model not found, using fallback');
        return ByteData(0); // Return empty ByteData to satisfy the return type
      }),
    ]);
    
    debugPrint('✅ Main screen assets preloaded');
  }

  /// Preload 3D earth model specifically (optional - for future use)
  Future<bool> preload3DEarthModel() async {
    debugPrint('🌍 Preloading 3D earth model...');
    
    try {
      await rootBundle.load('assets/images/main_screen/earth_3d.glb');
      debugPrint('✅ 3D earth model preloaded successfully');
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to preload 3D earth model: $e');
      return false;
    }
  }

  /// Check if specific assets are preloaded
  bool areAssetsPreloaded(String screenName) {
    // For now, return the general preload status
    // In the future, this could track screen-specific preloading
    return _isPreloaded;
  }

  /// Clear all cached assets (for memory management)
  void clearAssetCache() {
    Flame.images.clearCache();
    FlameAudio.audioCache.clearAll();
    _isPreloaded = false;
    print('🧹 Asset cache cleared');
  }

  /// Reset preload state (for testing or re-preloading)
  void reset() {
    _isPreloaded = false;
    _isPreloading = false;
    _preloadProgress = 0.0;
    _currentPreloadStep = '';
    print('🔄 Asset preload service reset');
  }

  /// Update progress and notify callback
  void _updateProgress(double progress, String step, Function(double, String)? onProgress) {
    _preloadProgress = progress;
    _currentPreloadStep = step;
    onProgress?.call(progress, step);
    print('🎯 Asset preload: ${(progress * 100).toInt()}% - $step');
  }

  /// Get preload statistics
  Map<String, dynamic> getPreloadStats() {
    return {
      'isPreloaded': _isPreloaded,
      'isPreloading': _isPreloading,
      'preloadProgress': _preloadProgress,
      'currentStep': _currentPreloadStep,
      'criticalAssets': _criticalImages.length,
      'introImages': _introImages.length,
      'introAudioFiles': _introAudioFiles.length,
      'intro3DAssets': _intro3DAssets.length,
      'totalAssets': _criticalImages.length + _introImages.length + _introAudioFiles.length + _intro3DAssets.length,
    };
  }
}