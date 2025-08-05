import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for handling audio playback of Thai character traditional names
/// and related cultural pronunciation examples.
class CharacterAudioService {
  static final CharacterAudioService _instance = CharacterAudioService._internal();
  factory CharacterAudioService() => _instance;
  CharacterAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _audioCache = {}; // Cache base64 audio data
  
  static const String baseUrl = 'http://localhost:8000';

  /// Play the traditional name audio for a Thai character
  /// Example: For 'ก', plays "ก ไก่" (gor gai - chicken)
  Future<bool> playTraditionalName(String character) async {
    try {
      print('CharacterAudioService: Playing traditional name for character: $character');
      
      // First, get the writing guidance to find traditional name
      final guidance = await _getWritingGuidance(character);
      final traditionalNames = guidance['traditional_names'] as List?;
      
      if (traditionalNames == null || traditionalNames.isEmpty) {
        print('CharacterAudioService: No traditional names found for $character');
        return false;
      }
      
      final traditionalName = traditionalNames.first as String;
      print('CharacterAudioService: Traditional name for $character is: $traditionalName');
      
      // Check cache first
      final cacheKey = 'traditional_$character';
      if (_audioCache.containsKey(cacheKey)) {
        print('CharacterAudioService: Using cached audio for $traditionalName');
        return await _playBase64Audio(_audioCache[cacheKey]!);
      }
      
      // Generate TTS for traditional name
      final audioBase64 = await _generateTTSAudio(traditionalName);
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        // Cache the audio
        _audioCache[cacheKey] = audioBase64;
        return await _playBase64Audio(audioBase64);
      }
      
      return false;
    } catch (e) {
      print('CharacterAudioService: Error playing traditional name for $character: $e');
      return false;
    }
  }

  /// Play an example word that contains the character
  /// Uses existing NPC vocabulary if available
  Future<bool> playExampleWord(String character, {String? exampleWord}) async {
    try {
      print('CharacterAudioService: Playing example word for character: $character');
      
      // If no specific example word provided, get one from guidance
      if (exampleWord == null) {
        final guidance = await _getWritingGuidance(character);
        final consonants = guidance['consonants'] as List?;
        
        if (consonants != null && consonants.isNotEmpty) {
          // Look for writing tips or example words in consonant data
          final consonantData = consonants.first as Map<String, dynamic>;
          // This would need to be enhanced based on the actual structure
          // For now, use traditional name as fallback
          return await playTraditionalName(character);
        }
      }
      
      if (exampleWord != null) {
        final audioBase64 = await _generateTTSAudio(exampleWord);
        if (audioBase64 != null && audioBase64.isNotEmpty) {
          return await _playBase64Audio(audioBase64);
        }
      }
      
      return false;
    } catch (e) {
      print('CharacterAudioService: Error playing example word for $character: $e');
      return false;
    }
  }

  /// Play audio for a component type (consonant, vowel, tone mark)
  /// Provides context-based pronunciation examples
  Future<bool> playComponentExample(String character, String componentType) async {
    try {
      print('CharacterAudioService: Playing component example for $character ($componentType)');
      
      // Generate appropriate example based on component type
      String exampleText;
      
      switch (componentType) {
        case 'consonant':
          // Use traditional name for consonants
          return await playTraditionalName(character);
          
        case 'vowel':
          // For vowels, create example with a standard consonant
          exampleText = 'ก$character'; // Example: กา, กิ, กู
          break;
          
        case 'tone_mark':
          // For tone marks, use with a standard syllable
          exampleText = 'กา$character'; // Example: ก่า, ก้า
          break;
          
        default:
          return await playTraditionalName(character);
      }
      
      final audioBase64 = await _generateTTSAudio(exampleText);
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        return await _playBase64Audio(audioBase64);
      }
      
      return false;
    } catch (e) {
      print('CharacterAudioService: Error playing component example for $character: $e');
      return false;
    }
  }

  /// Generate TTS audio using the backend service
  Future<String?> _generateTTSAudio(String text) async {
    try {
      print('CharacterAudioService: Generating TTS for: $text');
      
      final response = await http.post(
        Uri.parse('$baseUrl/synthesize-speech/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'target_language': 'th',
          'custom_voice': null, // Use default Thai voice
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final audioBase64 = data['audio_base64'] as String?;
        print('CharacterAudioService: TTS generation successful for: $text');
        return audioBase64;
      } else {
        print('CharacterAudioService: TTS generation failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('CharacterAudioService: Error generating TTS for $text: $e');
      return null;
    }
  }

  /// Get writing guidance data from backend
  Future<Map<String, dynamic>> _getWritingGuidance(String character) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/writing-guidance/$character?target_language=th'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('CharacterAudioService: Failed to get writing guidance for $character');
        return {};
      }
    } catch (e) {
      print('CharacterAudioService: Error getting writing guidance for $character: $e');
      return {};
    }
  }

  /// Play base64 encoded audio data
  Future<bool> _playBase64Audio(String base64Audio) async {
    try {
      // Convert base64 to bytes
      final audioBytes = base64Decode(base64Audio);
      
      // Stop any current playback
      await _audioPlayer.stop();
      
      // Play from bytes
      await _audioPlayer.play(BytesSource(audioBytes));
      
      print('CharacterAudioService: Audio playback started successfully');
      return true;
    } catch (e) {
      print('CharacterAudioService: Error playing base64 audio: $e');
      return false;
    }
  }

  /// Stop current audio playback
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      print('CharacterAudioService: Audio playback stopped');
    } catch (e) {
      print('CharacterAudioService: Error stopping audio: $e');
    }
  }

  /// Clear audio cache to free memory
  void clearCache() {
    _audioCache.clear();
    print('CharacterAudioService: Audio cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_items': _audioCache.length,
      'cache_keys': _audioCache.keys.toList(),
    };
  }

  /// Preload common character audio for better performance
  Future<void> preloadCommonCharacters() async {
    final commonCharacters = ['ก', 'ข', 'ค', 'ง', 'จ', 'ช', 'น', 'บ', 'ป', 'ม', 'ย', 'ร', 'ล', 'ว', 'ส', 'ห', 'อ'];
    
    print('CharacterAudioService: Preloading audio for ${commonCharacters.length} common characters...');
    
    for (final character in commonCharacters) {
      try {
        // This will cache the traditional name audio
        await playTraditionalName(character);
        // Small delay to avoid overwhelming the backend
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('CharacterAudioService: Error preloading character $character: $e');
      }
    }
    
    print('CharacterAudioService: Preloading completed. Cache now contains ${_audioCache.length} items');
  }

  /// Dispose of resources
  void dispose() {
    _audioPlayer.dispose();
    clearCache();
    print('CharacterAudioService: Service disposed');
  }
}