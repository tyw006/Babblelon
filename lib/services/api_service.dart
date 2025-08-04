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
import 'package:babblelon/services/posthog_service.dart';

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
    final String path = '${tempDir.path}/recording.wav';

    const config = RecordConfig(
      encoder: AudioEncoder.wav,   // Using WAV format for consistent audio processing
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
        contentType: MediaType('audio', 'wav'),
      ),
    );

    try {
      debugPrint("Sending request to backend...");
      final startTime = DateTime.now();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      debugPrint("Received response with status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        final assessmentResponse = PronunciationAssessmentResponse.fromJson(responseData);
        
        // Track successful pronunciation assessment
        PostHogService.trackPronunciationAssessment(
          event: 'api_call_success',
          referenceText: referenceText,
          pronunciationScore: assessmentResponse.pronunciationScore,
          accuracyScore: assessmentResponse.accuracyScore,
          itemType: itemType,
          complexity: complexity,
          success: true,
          additionalProperties: {
            'api_duration_ms': duration,
            'turn_type': turnType,
            'response_status': response.statusCode,
          },
        );
        
        return assessmentResponse;
      } else {
        // Track failed pronunciation assessment
        PostHogService.trackPronunciationAssessment(
          event: 'api_call_failed',
          referenceText: referenceText,
          itemType: itemType,
          complexity: complexity,
          success: false,
          additionalProperties: {
            'api_duration_ms': duration,
            'turn_type': turnType,
            'response_status': response.statusCode,
            'error_body': response.body,
          },
        );
        
        debugPrint("Error from backend: ${response.body}");
        throw Exception("Failed to get assessment: ${response.statusCode}");
      }
    } catch (e) {
      // Track API error
      PostHogService.trackPronunciationAssessment(
        event: 'api_call_error',
        referenceText: referenceText,
        itemType: itemType,
        complexity: complexity,
        success: false,
        additionalProperties: {
          'turn_type': turnType,
          'error': e.toString(),
        },
      );
      
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
    String sourceLanguage = 'th',
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
      final startTime = DateTime.now();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      debugPrint("Received response with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Transcribe-and-translate response: $responseData");
        
        // Track successful transcribe-and-translate
        PostHogService.trackAudioInteraction(
          service: 'transcribe_translate',
          event: 'api_call_success',
          durationMs: duration,
          success: true,
          additionalProperties: {
            'source_language': sourceLanguage,
            'target_language': targetLanguage,
            'has_expected_text': expectedText.isNotEmpty,
            'response_status': response.statusCode,
          },
        );
        
        return responseData;
      } else {
        debugPrint("Transcribe-and-translate request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        
        // Track failed transcribe-and-translate
        PostHogService.trackAudioInteraction(
          service: 'transcribe_translate',
          event: 'api_call_failed',
          durationMs: duration,
          success: false,
          additionalProperties: {
            'source_language': sourceLanguage,
            'target_language': targetLanguage,
            'response_status': response.statusCode,
            'error_body': response.body,
          },
        );
        
        return null;
      }
    } catch (e) {
      debugPrint("Error during transcribe-and-translate request: $e");
      
      // Track transcribe-and-translate error
      PostHogService.trackAudioInteraction(
        service: 'transcribe_translate',
        event: 'api_call_error',
        success: false,
        error: e.toString(),
        additionalProperties: {
          'source_language': sourceLanguage,
          'target_language': targetLanguage,
        },
      );
      
      return null;
    }
  }

  static Future<Map<String, dynamic>?> transcribeAndTranslateWithDeepL({
    required String audioPath,
    String sourceLanguage = 'th',
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

      final uri = Uri.parse("$baseUrl/transcribe-translate-deepl/");
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

      debugPrint("Sending transcribe-translate-deepl request to backend...");
      final startTime = DateTime.now();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      debugPrint("Received response with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        
        // Track successful transcribe-and-translate with DeepL
        PostHogService.trackAudioInteraction(
          service: 'transcribe_translate_deepl',
          event: 'api_call_success',
          durationMs: duration,
          success: true,
          additionalProperties: {
            'source_language': sourceLanguage,
            'target_language': targetLanguage,
            'has_expected_text': expectedText.isNotEmpty,
            'transcription_length': responseData['transcription']?.toString().length ?? 0,
            'translation_length': responseData['translation']?.toString().length ?? 0,
            'word_confidence_count': (responseData['word_confidence'] as List?)?.length ?? 0,
            'confidence_score': responseData['pronunciation_score'] ?? 0.0,
          },
        );
        
        return responseData;
      } else {
        debugPrint("Transcribe-translate-deepl request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        
        // Track failed transcribe-and-translate with DeepL
        PostHogService.trackAudioInteraction(
          service: 'transcribe_translate_deepl',
          event: 'api_call_failed',
          durationMs: duration,
          success: false,
          additionalProperties: {
            'source_language': sourceLanguage,
            'target_language': targetLanguage,
            'response_status': response.statusCode,
            'error_body': response.body,
          },
        );
        
        return null;
      }
    } catch (e) {
      debugPrint("Error during transcribe-translate-deepl request: $e");
      
      // Track transcribe-and-translate error
      PostHogService.trackAudioInteraction(
        service: 'transcribe_translate_deepl',
        event: 'api_call_error',
        success: false,
        error: e.toString(),
        additionalProperties: {
          'source_language': sourceLanguage,
          'target_language': targetLanguage,
        },
      );
      
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
        ..fields['use_enhanced_stt'] = useEnhancedSTT.toString()
        ..fields['user_id'] = PostHogService.userId ?? 'unknown_user'
        ..fields['session_id'] = PostHogService.sessionId ?? 'unknown_session';

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      debugPrint("Sending enhanced NPC response request to backend...");
      final startTime = DateTime.now();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      
      debugPrint("Received response with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Enhanced NPC response: $responseData");
        
        // Track successful NPC response generation
        PostHogService.trackNPCConversation(
          npcName: npcId,
          event: 'api_response_success',
          charmLevel: charmLevel,
          additionalProperties: {
            'api_duration_ms': duration,
            'npc_display_name': npcName,
            'target_language': targetLanguage,
            'use_enhanced_stt': useEnhancedSTT,
            'has_conversation_history': previousConversationHistory.isNotEmpty,
            'response_status': response.statusCode,
          },
        );
        
        return responseData;
      } else {
        debugPrint("Enhanced NPC response request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        
        // Track failed NPC response generation
        PostHogService.trackNPCConversation(
          npcName: npcId,
          event: 'api_response_failed',
          charmLevel: charmLevel,
          additionalProperties: {
            'api_duration_ms': duration,
            'npc_display_name': npcName,
            'target_language': targetLanguage,
            'response_status': response.statusCode,
            'error_body': response.body,
          },
        );
        
        return null;
      }
    } catch (e) {
      debugPrint("Error during enhanced NPC response request: $e");
      
      // Track NPC response error
      PostHogService.trackNPCConversation(
        npcName: npcId,
        event: 'api_response_error',
        charmLevel: charmLevel,
        additionalProperties: {
          'npc_display_name': npcName,
          'target_language': targetLanguage,
          'error': e.toString(),
        },
      );
      
      return null;
    }
  }

  /// Parallel transcription using both Google Cloud STT and ElevenLabs
  static Future<Map<String, dynamic>?> parallelTranscribe({
    required String audioPath,
    String sourceLanguage = 'th',
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

  /// Translate English text to Thai with enhanced homograph detection
  static Future<Map<String, dynamic>?> translateTextWithHomographs({
    required String englishText,
    String targetLanguage = 'th',
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final uri = Uri.parse("$baseUrl/enhanced-translate-homographs/");
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      
      final requestBody = {
        'english_text': englishText,
        'target_language': targetLanguage,
      };
      
      request.body = json.encode(requestBody);
      
      debugPrint("Sending enhanced homograph translation request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received enhanced translation response with status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Enhanced translation response: $responseData");
        return responseData;
      } else {
        debugPrint("Enhanced translation request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during enhanced translation request: $e");
      return null;
    }
  }

  /// Translate English text to Thai using DeepL with romanization
  static Future<Map<String, dynamic>?> translateTextWithDeepL({
    required String englishText,
    String targetLanguage = 'th',
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final uri = Uri.parse("$baseUrl/deepl-translate-tts/");
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      
      final requestBody = {
        'english_text': englishText,
        'target_language': targetLanguage,
      };
      
      request.body = json.encode(requestBody);
      
      debugPrint("Sending DeepL translation request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received DeepL translation response with status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("DeepL translation response: $responseData");
        return responseData;
      } else {
        debugPrint("DeepL translation request failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during DeepL translation request: $e");
      return null;
    }
  }

  /// Test multiple STT/Translation service combinations
  static Future<Map<String, dynamic>?> testSTTTranslationCombinations({
    required String audioPath,
    String sourceLanguage = 'th',
    String targetLanguage = 'en',
    String testName = 'STT Translation Test',
    bool includeCloudServices = true,
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final File audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint("Audio file does not exist: $audioPath");
        return null;
      }
      
      final uri = Uri.parse("$baseUrl/test-stt-translation-combinations/");
      final request = http.MultipartRequest('POST', uri)
        ..fields['source_language'] = sourceLanguage
        ..fields['target_language'] = targetLanguage
        ..fields['test_name'] = testName
        ..fields['include_cloud_services'] = includeCloudServices.toString();
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );
      
      debugPrint("Sending multi-service test request to backend...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint("Received multi-service test response with status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("Multi-service test completed successfully");
        return responseData;
      } else {
        debugPrint("Multi-service test failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during multi-service test: $e");
      return null;
    }
  }

  /// Transcribe audio using OpenAI Whisper API
  static Future<Map<String, dynamic>?> transcribeWithOpenAIWhisper({
    required String audioPath,
    String languageCode = 'th',
    String? prompt,
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final File audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint("Audio file not found: $audioPath");
        return null;
      }

      final uri = Uri.parse("$baseUrl/openai-transcribe/");
      final request = http.MultipartRequest('POST', uri)
        ..fields['language_code'] = languageCode;
      
      if (prompt != null && prompt.isNotEmpty) {
        request.fields['prompt'] = prompt;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      debugPrint("Sending OpenAI Whisper transcription request...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("OpenAI Whisper transcription successful");
        return responseData;
      } else {
        debugPrint("OpenAI Whisper transcription failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during OpenAI Whisper transcription: $e");
      return null;
    }
  }


  /// Translate audio using OpenAI Whisper API (direct translation to English)
  static Future<Map<String, dynamic>?> translateWithOpenAIWhisper({
    required String audioPath,
    String? prompt,
  }) async {
    final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://127.0.0.1:8000";
    
    try {
      final File audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        debugPrint("Audio file not found: $audioPath");
        return null;
      }

      final uri = Uri.parse("$baseUrl/openai-translate/");
      final request = http.MultipartRequest('POST', uri);
      
      if (prompt != null && prompt.isNotEmpty) {
        request.fields['prompt'] = prompt;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      debugPrint("Sending OpenAI Whisper translation request...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("OpenAI Whisper translation successful");
        return responseData;
      } else {
        debugPrint("OpenAI Whisper translation failed with status: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error during OpenAI Whisper translation: $e");
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