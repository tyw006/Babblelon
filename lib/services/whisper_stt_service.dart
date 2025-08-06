import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class WhisperSTTService {
  Whisper? _whisper;
  WhisperModel _currentModel = WhisperModel.tiny;
  bool _isInitialized = false;
  
  // Model sizes for UI display
  static const Map<WhisperModel, int> modelSizesInMB = {
    WhisperModel.tiny: 39,
    WhisperModel.small: 150,
  };
  
  Future<bool> isModelDownloaded(WhisperModel model) async {
    // whisper_flutter_new handles model management internally
    // For now, return true to indicate models are "available"
    return true;
  }
  
  Future<void> downloadModel(WhisperModel model, Function(double) onProgress) async {
    // whisper_flutter_new handles model download automatically when initializing
    // We'll simulate download progress for UI compatibility
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress(i / 100.0);
    }
    debugPrint('Model download simulated for: $model');
  }
  
  Future<void> deleteModel(WhisperModel model) async {
    // whisper_flutter_new doesn't expose direct model deletion
    // This is a no-op for compatibility
    debugPrint('Model deletion not supported by whisper_flutter_new');
  }
  
  Future<void> initializeWhisper({required WhisperModel model}) async {
    try {
      _currentModel = model;
      
      // Initialize Whisper with whisper_flutter_new
      _whisper = Whisper(
        model: model,
        downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
      );
      
      _isInitialized = true;
      debugPrint('Whisper initialized with model: $model');
    } catch (e) {
      debugPrint('Error initializing Whisper: $e');
      _isInitialized = false;
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> transcribeAudio(String audioPath) async {
    if (!_isInitialized || _whisper == null) {
      throw Exception('Whisper not initialized. Call initializeWhisper() first.');
    }
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check if audio file exists
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found: $audioPath');
      }
      
      // Transcribe audio with whisper_flutter_new
      final transcription = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          isTranslate: false, // We want transcription, not translation
          isNoTimestamps: true, // No timestamps needed for our use case
          splitOnWord: true, // Better for Thai language
        ),
      );
      
      stopwatch.stop();
      
      debugPrint('Whisper transcription completed in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Transcription: $transcription');
      
      return {
        'transcription': transcription,
        'processing_time_ms': stopwatch.elapsedMilliseconds,
        'model': _currentModel.toString().split('.').last,
        'is_offline': true,
        'confidence_score': 0.0, // Whisper doesn't provide confidence scores
        'word_confidence': [], // Whisper doesn't provide word-level confidence
      };
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error during Whisper transcription: $e');
      
      return {
        'transcription': '',
        'processing_time_ms': stopwatch.elapsedMilliseconds,
        'model': _currentModel.toString().split('.').last,
        'is_offline': true,
        'error': e.toString(),
      };
    }
  }
  
  void dispose() {
    _whisper = null;
    _isInitialized = false;
  }
  
  bool get isInitialized => _isInitialized;
  WhisperModel get currentModel => _currentModel;
}