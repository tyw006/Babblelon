import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';

/// Service for pre-loading boss fight assets during portal dialog
/// This eliminates the loading lag when transitioning to boss fights
class BossAssetPreloader {
  static final BossAssetPreloader _instance = BossAssetPreloader._internal();
  factory BossAssetPreloader() => _instance;
  BossAssetPreloader._internal();

  final Map<String, bool> _preloadedBosses = {};
  final Map<String, List<String>> _preloadingInProgress = {};

  /// Pre-load all assets for a boss fight
  /// Should be called when the portal dialog appears
  Future<void> preloadBossAssets({
    required BuildContext context,
    required WidgetRef ref,
    required BossData bossData,
  }) async {
    final bossKey = bossData.name.toLowerCase();
    
    // Don't preload if already done or in progress
    if (_preloadedBosses[bossKey] == true || 
        _preloadingInProgress.containsKey(bossKey)) {
      debugPrint('🚀 BossAssetPreloader: ${bossData.name} assets already loaded/loading');
      return;
    }

    debugPrint('🚀 BossAssetPreloader: Starting preload for ${bossData.name}...');
    _preloadingInProgress[bossKey] = [];

    final stopwatch = Stopwatch()..start();

    try {
      // Pre-load assets concurrently for maximum efficiency
      final futures = <Future<void>>[
        _preloadImage(context, bossData.spritePath, 'boss sprite'),
        _preloadImage(context, bossData.backgroundPath, 'boss background'),
        _preloadVocabulary(ref, bossData.vocabularyPath, 'boss vocabulary'),
      ];

      await Future.wait(futures);

      stopwatch.stop();
      _preloadedBosses[bossKey] = true;
      _preloadingInProgress.remove(bossKey);

      debugPrint('✅ BossAssetPreloader: ${bossData.name} preload complete in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      stopwatch.stop();
      _preloadingInProgress.remove(bossKey);
      debugPrint('❌ BossAssetPreloader: Failed to preload ${bossData.name}: $e');
      // Don't rethrow - let the boss fight screen handle loading normally
    }
  }

  /// Pre-load an image asset using Flutter's precacheImage
  Future<void> _preloadImage(BuildContext context, String assetPath, String description) async {
    try {
      final image = AssetImage(assetPath);
      await precacheImage(image, context);
      debugPrint('📸 BossAssetPreloader: Cached $description ($assetPath)');
    } catch (e) {
      debugPrint('❌ BossAssetPreloader: Failed to cache $description ($assetPath): $e');
      // Don't rethrow - let the boss fight screen handle loading normally
    }
  }

  /// Pre-load vocabulary data by triggering the provider
  Future<void> _preloadVocabulary(WidgetRef ref, String vocabularyPath, String description) async {
    try {
      // This triggers the bossVocabularyProvider to load and cache the data
      await ref.read(bossVocabularyProvider(vocabularyPath).future);
      debugPrint('📚 BossAssetPreloader: Cached $description ($vocabularyPath)');
    } catch (e) {
      debugPrint('❌ BossAssetPreloader: Failed to cache $description ($vocabularyPath): $e');
      // Don't rethrow - let the boss fight screen handle loading normally
    }
  }

  /// Check if a boss's assets are already preloaded
  bool isBossPreloaded(String bossName) {
    return _preloadedBosses[bossName.toLowerCase()] == true;
  }

  /// Check if a boss's assets are currently being preloaded
  bool isBossPreloading(String bossName) {
    return _preloadingInProgress.containsKey(bossName.toLowerCase());
  }

  /// Clear preload cache (useful for memory management)
  void clearCache() {
    _preloadedBosses.clear();
    _preloadingInProgress.clear();
    debugPrint('🗑️ BossAssetPreloader: Cache cleared');
  }

  /// Get preload status for debugging
  Map<String, String> getPreloadStatus() {
    final status = <String, String>{};
    for (final entry in _preloadedBosses.entries) {
      status[entry.key] = entry.value ? 'loaded' : 'failed';
    }
    for (final entry in _preloadingInProgress.entries) {
      status[entry.key] = 'loading';
    }
    return status;
  }
}