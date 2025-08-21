import 'dart:async';
import 'package:flutter/material.dart';
import 'package:babblelon/services/game_asset_preload_service.dart';

/// Static game loader that survives widget recreation during navigation transitions
/// This singleton manages the game loading process independently of widget lifecycle
class StaticGameLoader {
  static final StaticGameLoader _instance = StaticGameLoader._internal();
  factory StaticGameLoader() => _instance;
  StaticGameLoader._internal();

  // Loading state that persists across widget instances
  static bool _isLoading = false;
  static bool _isLoaded = false;
  static String? _loadingCharacter;
  
  // Progress tracking
  static double _loadingProgress = 0.0;
  static String _loadingStep = '';
  
  // Completion callbacks for navigation
  static void Function()? _onLoadingComplete;
  static void Function(String error)? _onLoadingError;

  /// Check if game is currently loading
  bool get isLoading => _isLoading;
  
  /// Check if game is loaded and ready
  bool get isLoaded => _isLoaded;
  
  /// Get current loading progress (0.0 to 1.0)
  double get loadingProgress => _loadingProgress;
  
  /// Get current loading step description
  String get loadingStep => _loadingStep;

  /// Start the game loading process with widget-independent state management
  Future<bool> startLoading({
    required String selectedCharacter,
    required void Function() onComplete,
    required void Function(String error) onError,
    Function(double progress, String step)? onProgress,
  }) async {
    // Return early if already loading or loaded
    if (_isLoading) {
      debugPrint('🚫 StaticGameLoader: Already loading, ignoring duplicate request');
      return false;
    }
    
    if (_isLoaded && _loadingCharacter == selectedCharacter) {
      debugPrint('✅ StaticGameLoader: Assets already cached for character $selectedCharacter');
      
      // Animate progress from 0 to 100% for cached assets
      _isLoading = true;
      double animatedProgress = 0.0;
      
      Timer.periodic(const Duration(milliseconds: 20), (timer) {
        animatedProgress += 0.05;
        if (animatedProgress >= 1.0) {
          animatedProgress = 1.0;
          timer.cancel();
          _isLoading = false;
          debugPrint('✅ StaticGameLoader: Cached asset animation completed');
          onComplete();
        }
        onProgress?.call(animatedProgress, 'Loading cached assets...');
      });
      
      return true;
    }

    debugPrint('🎮 StaticGameLoader: Starting loading process for character: $selectedCharacter');
    
    // Set loading state
    _isLoading = true;
    _isLoaded = false;
    _loadingCharacter = selectedCharacter;
    _onLoadingComplete = onComplete;
    _onLoadingError = onError;
    _loadingProgress = 0.0;
    _loadingStep = 'Initializing...';

    try {
      // Preload game assets (0-100%)
      await _preloadAssets(onProgress);
      
      // Mark as complete
      _isLoading = false;
      _isLoaded = true;
      _updateProgress(1.0, 'Game ready!', onProgress);
      
      debugPrint('✅ StaticGameLoader: Asset loading completed successfully');
      _onLoadingComplete?.call();
      return true;
      
    } catch (error) {
      debugPrint('❌ StaticGameLoader: Asset loading failed - $error');
      _isLoading = false;
      _isLoaded = false;
      _onLoadingError?.call(error.toString());
      return false;
    }
  }

  /// Preload all game assets using GameAssetPreloadService
  Future<void> _preloadAssets(Function(double, String)? onProgress) async {
    debugPrint('📦 StaticGameLoader: Starting asset preloading...');
    
    final assetService = GameAssetPreloadService();
    
    await assetService.preloadGameAssets(
      onProgress: (progress, step) {
        // Asset loading is now 100% of total progress
        _updateProgress(progress, step, onProgress);
      },
    );
    
    debugPrint('✅ StaticGameLoader: Asset preloading completed');
  }


  /// Update loading progress and notify callbacks
  void _updateProgress(double progress, String step, Function(double, String)? onProgress) {
    _loadingProgress = progress;
    _loadingStep = step;
    onProgress?.call(progress, step);
    debugPrint('🎯 StaticGameLoader: ${(progress * 100).toInt()}% - $step');
  }

  /// Reset the loading state (for testing or character changes)
  void reset() {
    debugPrint('🔄 StaticGameLoader: Resetting state');
    _isLoading = false;
    _isLoaded = false;
    _loadingCharacter = null;
    _loadingProgress = 0.0;
    _loadingStep = '';
    _onLoadingComplete = null;
    _onLoadingError = null;
  }

  /// Clear loaded assets and reset state
  void clearAssets() {
    debugPrint('🧹 StaticGameLoader: Clearing loaded state');
    _isLoaded = false;
    _loadingCharacter = null;
    
    // Also reset the underlying GameAssetPreloadService to ensure consistency
    final assetService = GameAssetPreloadService();
    assetService.reset();
    debugPrint('🔄 StaticGameLoader: Reset underlying asset service state');
  }

  /// Get current loading statistics
  Map<String, dynamic> getLoadingStats() {
    return {
      'isLoading': _isLoading,
      'isLoaded': _isLoaded,
      'loadingProgress': _loadingProgress,
      'loadingStep': _loadingStep,
      'loadingCharacter': _loadingCharacter,
    };
  }
}