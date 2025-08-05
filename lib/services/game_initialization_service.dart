import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;

/// Service responsible for preloading all game assets and models during initialization
/// to prevent lag during gameplay.
class GameInitializationService {
  static final GameInitializationService _instance = GameInitializationService._internal();
  factory GameInitializationService() => _instance;
  GameInitializationService._internal();

  // Initialization state tracking
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  // ML Kit models
  mlkit.DigitalInkRecognizerModelManager? _modelManager;
  bool _mlKitThaiModelReady = false;
  
  // NPC vocabulary cache
  final Map<String, Map<String, dynamic>> _npcVocabularyCache = {};
  final List<String> _npcIds = ['somchai', 'amara'];
  
  // Thai writing guide cache
  Map<String, dynamic>? _thaiWritingGuideCache;

  // Progress tracking
  double _initializationProgress = 0.0;
  String _currentInitializationStep = '';
  
  // Getters for status
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isMLKitModelReady => _mlKitThaiModelReady;
  double get initializationProgress => _initializationProgress;
  String get currentInitializationStep => _currentInitializationStep;

  /// Initialize all game assets and models
  /// Call this during app startup or loading screen
  Future<bool> initializeGame({
    Function(double progress, String step)? onProgress,
  }) async {
    if (_isInitialized) return true;
    if (_isInitializing) return false; // Already in progress
    
    _isInitializing = true;
    _initializationProgress = 0.0;
    
    try {
      // Step 1: Initialize ML Kit model manager (10% progress)
      _updateProgress(0.1, 'Initializing ML Kit...', onProgress);
      await _initializeMLKitManager();
      
      // Step 2: Download Thai ML Kit model (40% progress)
      _updateProgress(0.4, 'Downloading Thai character recognition model...', onProgress);
      await _downloadThaiMLKitModel();
      
      // Step 3: Preload Thai writing guide (60% progress)
      _updateProgress(0.6, 'Loading Thai writing guide...', onProgress);
      await _preloadThaiWritingGuide();
      
      // Step 4: Preload NPC vocabulary data (80% progress)
      _updateProgress(0.8, 'Loading NPC vocabulary data...', onProgress);
      await _preloadNPCVocabulary();
      
      // Step 5: Finalization (100% progress)
      _updateProgress(1.0, 'Initialization complete!', onProgress);
      
      _isInitialized = true;
      _isInitializing = false;
      
      print('🎮 Game initialization completed successfully');
      return true;
      
    } catch (e) {
      print('❌ Game initialization failed: $e');
      _isInitializing = false;
      _isInitialized = false;
      return false;
    }
  }

  /// Initialize ML Kit model manager
  Future<void> _initializeMLKitManager() async {
    try {
      _modelManager = mlkit.DigitalInkRecognizerModelManager();
      print('✅ ML Kit model manager initialized');
    } catch (e) {
      print('❌ Failed to initialize ML Kit model manager: $e');
      throw Exception('ML Kit initialization failed: $e');
    }
  }

  /// Download and prepare Thai ML Kit model for character tracing
  Future<void> _downloadThaiMLKitModel() async {
    try {
      if (_modelManager == null) {
        throw Exception('ML Kit model manager not initialized');
      }
      
      const String thaiModelIdentifier = 'th';
      
      // Add timeout to model download check and download
      final bool isDownloaded = await _modelManager!.isModelDownloaded(thaiModelIdentifier)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      
      if (!isDownloaded) {
        print('📥 Downloading Thai ML Kit model for character tracing...');
        final bool success = await _modelManager!.downloadModel(thaiModelIdentifier)
            .timeout(const Duration(seconds: 30), onTimeout: () => false);
        _mlKitThaiModelReady = success;
        
        if (success) {
          print('✅ Thai ML Kit model downloaded successfully');
        } else {
          print('⚠️ Thai ML Kit model download timed out or failed - character tracing may not work');
          // Don't throw exception, allow app to continue
          _mlKitThaiModelReady = false;
        }
      } else {
        _mlKitThaiModelReady = true;
        print('✅ Thai ML Kit model already available');
      }
    } catch (e) {
      print('❌ Error with Thai ML Kit model: $e');
      _mlKitThaiModelReady = false;
      throw Exception('Thai ML Kit model setup failed: $e');
    }
  }

  /// Preload Thai writing guide data into memory cache
  Future<void> _preloadThaiWritingGuide() async {
    try {
      print('📖 Loading Thai writing guide...');
      
      final String jsonString = await rootBundle.loadString('assets/data/thai_writing_guide.json');
      final Map<String, dynamic> thaiGuideData = json.decode(jsonString);
      
      _thaiWritingGuideCache = thaiGuideData;
      print('✅ Thai writing guide loaded successfully');
      print('📊 Guide sections: ${thaiGuideData.keys.join(', ')}');
      
    } catch (e) {
      print('❌ Error loading Thai writing guide: $e');
      throw Exception('Thai writing guide loading failed: $e');
    }
  }

  /// Preload all NPC vocabulary data into memory cache
  Future<void> _preloadNPCVocabulary() async {
    try {
      for (int i = 0; i < _npcIds.length; i++) {
        final npcId = _npcIds[i];
        final progress = 0.8 + (0.15 * (i / _npcIds.length)); // 80% to 95%
        
        print('📚 Loading vocabulary for NPC: $npcId');
        
        try {
          final vocabularyPath = 'assets/data/npc_vocabulary_$npcId.json';
          final String jsonString = await rootBundle.loadString(vocabularyPath);
          final Map<String, dynamic> vocabularyData = json.decode(jsonString);
          
          _npcVocabularyCache[npcId] = vocabularyData;
          print('✅ Vocabulary loaded for $npcId: ${vocabularyData['vocabulary']?.length ?? 0} items');
          
        } catch (e) {
          print('⚠️ Failed to load vocabulary for $npcId: $e');
          // Continue with other NPCs even if one fails
          _npcVocabularyCache[npcId] = {'vocabulary': []};
        }
      }
      
      print('✅ NPC vocabulary preloading completed');
      print('📊 Total NPCs cached: ${_npcVocabularyCache.length}');
      
    } catch (e) {
      print('❌ Error during NPC vocabulary preloading: $e');
      throw Exception('NPC vocabulary preloading failed: $e');
    }
  }

  /// Get cached vocabulary for a specific NPC
  Map<String, dynamic>? getCachedNPCVocabulary(String npcId) {
    return _npcVocabularyCache[npcId];
  }

  /// Get all cached NPC vocabulary data
  Map<String, Map<String, dynamic>> getAllCachedVocabulary() {
    return Map.from(_npcVocabularyCache);
  }

  /// Check if vocabulary is cached for a specific NPC
  bool isVocabularyCached(String npcId) {
    return _npcVocabularyCache.containsKey(npcId) && 
           _npcVocabularyCache[npcId]!.isNotEmpty;
  }

  /// Get ML Kit model manager instance
  mlkit.DigitalInkRecognizerModelManager? getMLKitModelManager() {
    return _modelManager;
  }

  /// Get cached Thai writing guide data
  Map<String, dynamic>? getCachedThaiWritingGuide() {
    return _thaiWritingGuideCache;
  }

  /// Check if Thai writing guide is cached
  bool isThaiWritingGuideCached() {
    return _thaiWritingGuideCache != null && _thaiWritingGuideCache!.isNotEmpty;
  }

  /// Reset initialization state (for testing or re-initialization)
  void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _mlKitThaiModelReady = false;
    _npcVocabularyCache.clear();
    _thaiWritingGuideCache = null;
    _initializationProgress = 0.0;
    _currentInitializationStep = '';
    _modelManager = null;
    print('🔄 Game initialization service reset');
  }

  /// Update progress and notify callback
  void _updateProgress(double progress, String step, Function(double, String)? onProgress) {
    _initializationProgress = progress;
    _currentInitializationStep = step;
    onProgress?.call(progress, step);
    print('🎯 Initialization: ${(progress * 100).toInt()}% - $step');
  }

  /// Get initialization statistics
  Map<String, dynamic> getInitializationStats() {
    return {
      'isInitialized': _isInitialized,
      'isInitializing': _isInitializing,
      'mlKitModelReady': _mlKitThaiModelReady,
      'thaiWritingGuideCached': isThaiWritingGuideCached(),
      'npcVocabularyCached': _npcVocabularyCache.keys.toList(),
      'totalVocabularyItems': _npcVocabularyCache.values
          .map((vocab) => vocab['vocabulary']?.length ?? 0)
          .reduce((a, b) => a + b),
      'initializationProgress': _initializationProgress,
      'currentStep': _currentInitializationStep,
    };
  }
}