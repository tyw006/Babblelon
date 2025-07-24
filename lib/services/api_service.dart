import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:babblelon/models/assessment_model.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:async';

class ApiService {
  // Base URL is determined by the platform at runtime.
  // - For Android emulator, use 10.0.2.2.
  // - For iOS simulator and other platforms in debug, use localhost.
  // NOTE: For a physical device, you must find your computer's local network IP
  // (e.g., 192.168.1.5) and set it here for both devices to communicate.
  final String _baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
  final _audioRecorder = AudioRecorder();

  Future<void> startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      debugPrint("Microphone permission not granted.");
      // In a real app, you would request permission here.
      throw Exception("Microphone permission not granted.");
    }
    
    final Directory tempDir = await getTemporaryDirectory();
    final String path = '${tempDir.path}/recording.m4a';

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc, // Using AAC for .m4a container
      sampleRate: 16000,           // 16kHz as recommended
      numChannels: 1,              // Mono
    );

    if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
    }

    await _audioRecorder.start(config, path: path);
    debugPrint("Recording started...");
  }

  Future<PronunciationAssessmentResponse?> stopRecordingAndGetAssessment({
    required String referenceText,
    required String transliteration,
    required int complexity,
    required String itemType,
    required String turnType,
  }) async {
    if (!await _audioRecorder.isRecording()) {
      debugPrint("No active recording to stop.");
      return null;
    }

    final path = await _audioRecorder.stop();
    if (path == null) {
      debugPrint("Failed to stop recording or no path found.");
      return null;
    }
    
    debugPrint("Recording stopped. File saved at: $path");
    final File audioFile = File(path);
    
    final uri = Uri.parse("$_baseUrl/pronunciation/assess/");
    final request = http.MultipartRequest('POST', uri)
      ..fields['reference_text'] = referenceText
      ..fields['transliteration'] = transliteration
      ..fields['complexity'] = complexity.toString()
      ..fields['item_type'] = itemType
      ..fields['turn_type'] = turnType
      ..fields['language'] = 'th-TH';

    request.files.add(
      await http.MultipartFile.fromPath(
        'audio_file',
        audioFile.path,
        contentType: MediaType('audio', 'm4a'),
      ),
    );

    try {
      debugPrint("Sending request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received response with status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        return PronunciationAssessmentResponse.fromJson(responseData);
      } else {
        debugPrint("Error from backend: ${response.body}");
        throw Exception("Failed to get assessment: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("An error occurred during API call: $e");
      rethrow;
    }
  }

  Future<PronunciationAssessmentResponse> assessPronunciation({
    required List<int> audioBytes,
    required String referenceText,
    required String transliteration,
    required int complexity,
    required String itemType,
    required String turnType,
    required bool wasRevealed,
    required List<Map<String, dynamic>> azurePronMapping,
    String language = 'th-TH',
  }) async {
    final uri = Uri.parse("$_baseUrl/pronunciation/assess/");
    final request = http.MultipartRequest('POST', uri)
      ..fields['reference_text'] = referenceText
      ..fields['transliteration'] = transliteration
      ..fields['complexity'] = complexity.toString()
      ..fields['item_type'] = itemType
      ..fields['turn_type'] = turnType
      ..fields['was_revealed'] = wasRevealed.toString()
      ..fields['azure_pron_mapping_json'] = jsonEncode(azurePronMapping)
      ..fields['language'] = language;

    // Add the audio bytes as a multipart file
    request.files.add(
      http.MultipartFile.fromBytes(
        'audio_file',
        audioBytes,
        filename: 'audio.wav',
        contentType: MediaType('audio', 'wav'),
      ),
    );

    try {
      debugPrint("Sending audio assessment request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received response with status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        return PronunciationAssessmentResponse.fromJson(responseData);
      } else {
        debugPrint("Error from backend: ${response.body}");
        throw Exception("Failed to get assessment: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("An error occurred during API call: $e");
      rethrow;
    }
  }

  /// Transcribe and translate audio using the new enhanced endpoint
  static Future<Map<String, dynamic>?> transcribeAndTranslate({
    required String audioPath,
    String sourceLanguage = 'tha',
    String targetLanguage = 'en',
    String expectedText = '',
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final File audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint("Audio file does not exist: $audioPath");
        return null;
      }

      final uri = Uri.parse("$baseUrl/transcribe-and-translate/");
      final request = http.MultipartRequest('POST', uri)
        ..fields['source_language'] = sourceLanguage
        ..fields['target_language'] = targetLanguage
        ..fields['expected_text'] = expectedText;

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      debugPrint("Sending transcribe-and-translate request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received response with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Transcribe-and-translate response: $responseData");
        return responseData;
      } else {
        debugPrint("Transcribe-and-translate request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during transcribe-and-translate request: $e");
      return null;
    }
  }

  /// Generate NPC response using enhanced STT (optional)
  static Future<Map<String, dynamic>?> generateNPCResponseEnhanced({
    required String audioPath,
    required String npcId,
    required String npcName,
    int charmLevel = 50,
    String targetLanguage = 'th',
    String previousConversationHistory = '',
    String questStateJson = '{}',
    bool useEnhancedSTT = true,
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final File audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint("Audio file does not exist: $audioPath");
        return null;
      }

      final uri = Uri.parse("$baseUrl/generate-npc-response/");
      final request = http.MultipartRequest('POST', uri)
        ..fields['npc_id'] = npcId
        ..fields['npc_name'] = npcName
        ..fields['charm_level'] = charmLevel.toString()
        ..fields['target_language'] = targetLanguage
        ..fields['previous_conversation_history'] = previousConversationHistory
        ..fields['quest_state_json'] = questStateJson
        ..fields['use_enhanced_stt'] = useEnhancedSTT.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      debugPrint("Sending enhanced NPC response request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received response with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Enhanced NPC response: $responseData");
        return responseData;
      } else {
        debugPrint("Enhanced NPC response request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during enhanced NPC response request: $e");
      return null;
    }
  }

  /// Parallel transcription using both Google Cloud STT and ElevenLabs
  static Future<Map<String, dynamic>?> parallelTranscribe({
    required String audioPath,
    String sourceLanguage = 'tha',
    String targetLanguage = 'en',
    String expectedText = '',
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final File audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint("Audio file does not exist: $audioPath");
        return null;
      }

      final uri = Uri.parse("$baseUrl/parallel-transcribe/");
      final request = http.MultipartRequest('POST', uri)
        ..fields['source_language'] = sourceLanguage
        ..fields['target_language'] = targetLanguage
        ..fields['expected_text'] = expectedText;

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      debugPrint("Sending parallel transcription request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received parallel transcription response with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Parallel transcription response: $responseData");
        return responseData;
      } else {
        debugPrint("Parallel transcription request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during parallel transcription request: $e");
      return null;
    }
  }

  /// Parallel transcription + translation comparison using both STT services
  static Future<Map<String, dynamic>?> parallelTranscribeTranslate({
    required String audioPath,
    String sourceLanguage = 'tha',
    String targetLanguage = 'en',
    String expectedText = '',
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final File audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint("Audio file does not exist: $audioPath");
        return null;
      }

      final uri = Uri.parse("$baseUrl/parallel-transcribe-translate/");
      final request = http.MultipartRequest('POST', uri)
        ..fields['source_language'] = sourceLanguage
        ..fields['target_language'] = targetLanguage
        ..fields['expected_text'] = expectedText;

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      debugPrint("Sending parallel transcribe-translate request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received parallel transcribe-translate response with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Parallel transcribe-translate response: $responseData");
        return responseData;
      } else {
        debugPrint("Parallel transcribe-translate request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during parallel transcribe-translate request: $e");
      return null;
    }
  }

  /// Translate English text to Thai with romanization
  static Future<Map<String, dynamic>?> translateText({
    required String englishText,
    String targetLanguage = 'th',
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final uri = Uri.parse("$baseUrl/gcloud-translate-tts/");
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      
      final requestBody = {
        'english_text': englishText,
        'target_language': targetLanguage,
      };
      
      request.body = json.encode(requestBody);
      
      debugPrint("Sending translation request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received translation response with status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Translation response: $responseData");
        return responseData;
      } else {
        debugPrint("Translation request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during translation request: $e");
      return null;
    }
  }

  Future<void> dispose() async {
    _audioRecorder.dispose();
  }
}

/// Service for creating echo effects on audio playback
class EchoAudioService {
  static final EchoAudioService _instance = EchoAudioService._internal();
  factory EchoAudioService() => _instance;
  EchoAudioService._internal();

  final List<just_audio.AudioPlayer> _activePlayers = [];

  /// Plays audio with echo effect - multiple delayed copies with decreasing volume
  Future<void> playWithEcho({
    required String assetPath,
    int echoCount = 3,
    Duration echoDelay = const Duration(milliseconds: 300),
    double volumeDecay = 0.6,
    double initialVolume = 1.0,
  }) async {
    try {
      // Clean up any existing players
      await stopAllEchoPlayers();

      for (int i = 0; i <= echoCount; i++) {
        // Calculate volume for this echo (each echo is quieter)
        double volume = initialVolume * (volumeDecay * i).clamp(0.0, 1.0);
        if (i == 0) volume = initialVolume; // First play at full volume
        
        // Calculate delay for this echo
        Duration delay = Duration(milliseconds: echoDelay.inMilliseconds * i);

        // Schedule the echo
        Timer(delay, () async {
          if (volume > 0.05) { // Only play if volume is audible
            final player = just_audio.AudioPlayer();
            _activePlayers.add(player);
            
            try {
              await player.setAsset('assets/audio/$assetPath');
              await player.setVolume(volume);
              await player.play();
              
              // Clean up player when audio finishes
              player.playerStateStream.listen((state) {
                if (state.processingState == just_audio.ProcessingState.completed) {
                  _activePlayers.remove(player);
                  player.dispose();
                }
              });
            } catch (e) {
              _activePlayers.remove(player);
              player.dispose();
            }
          }
        });
      }
    } catch (e) {
      print('Error playing echo audio: $e');
    }
  }

  /// Stops all active echo players
  Future<void> stopAllEchoPlayers() async {
    for (final player in _activePlayers) {
      try {
        await player.stop();
        player.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
    }
    _activePlayers.clear();
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await stopAllEchoPlayers();
  }
} 