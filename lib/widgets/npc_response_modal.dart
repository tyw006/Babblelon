import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import '../models/npc_data.dart';
import '../services/api_service.dart';
import '../overlays/dialogue_overlay/dialogue_models.dart';
import '../providers/game_providers.dart';

// POS Color Mapping (same as dialogue_overlay.dart)
final Map<String, Color> posColorMapping = {
  'ADJ': Colors.orange.shade700, // Adjective
  'ADP': Colors.purple.shade700, // Adposition (e.g., prepositions, postpositions)
  'ADV': Colors.green.shade700, // Adverb
  'AUX': Colors.blue.shade700, // Auxiliary verb
  'CCONJ': Colors.cyan.shade700, // Coordinating conjunction
  'DET': Colors.lime.shade700, // Determiner
  'INTJ': Colors.pink.shade700, // Interjection
  'NOUN': Colors.red.shade700, // Noun
  'NUM': Colors.indigo.shade700, // Numeral
  'PART': Colors.brown.shade700, // Particle
  'PRON': Colors.amber.shade700, // Pronoun
  'PROPN': Colors.deepOrange.shade700, // Proper noun
  'PUNCT': Colors.grey.shade600, // Punctuation
  'SCONJ': Colors.lightBlue.shade700, // Subordinating conjunction
  'SYM': Colors.teal.shade700, // Symbol
  'VERB': Colors.lightGreen.shade700, // Verb
  'OTHER': Colors.black54, // Other
};

// Enhanced modal states for comprehensive learning flow
enum NPCResponseModalState {
  initial,      // Show NPC message with reference
  recording,    // Recording user audio with waveform
  processing,   // Processing STT + Translation
  results,      // Show transcription with confidence
  practice,     // Additional practice mode
  sending,      // Sending to NPC
}

// Model for transcription results with confidence data
class WordComparisonData {
  final String word;
  final double confidence;
  final String expected;
  final String matchType;
  final double similarity;
  final double startTime;
  final double endTime;

  WordComparisonData({
    required this.word,
    required this.confidence,
    this.expected = '',
    this.matchType = 'no_reference',
    this.similarity = 1.0,
    this.startTime = 0.0,
    this.endTime = 0.0,
  });
}

class TranscriptionResult {
  final String transcription;
  final String translation;
  final String romanization;
  final List<WordConfidence> wordConfidence;
  final List<WordComparisonData> wordComparisons;
  final double confidenceScore;
  final String expectedText;

  TranscriptionResult({
    required this.transcription,
    required this.translation,
    required this.romanization,
    required this.wordConfidence,
    this.wordComparisons = const [],
    required this.confidenceScore,
    this.expectedText = '',
  });
}

class WordConfidence {
  final String word;
  final double confidence;
  final double startTime;
  final double endTime;
  final String transliteration;
  final String translation;

  WordConfidence({
    required this.word,
    required this.confidence,
    required this.startTime,
    required this.endTime,
    this.transliteration = '',
    this.translation = '',
  });

  // Color coding based on confidence levels
  Color get confidenceColor {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.yellow.shade700;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  // Confidence category for UI feedback
  String get confidenceCategory {
    if (confidence >= 0.9) return 'Excellent';
    if (confidence >= 0.7) return 'Good';
    if (confidence >= 0.5) return 'Needs Work';
    return 'Try Again';
  }
}

class NPCResponseModal extends ConsumerStatefulWidget {
  final NpcData npcData;
  final String npcMessage;
  final String npcMessageEnglish;
  final bool showEnglish;
  final bool showTransliteration;
  final Function(String, String?) onSendResponse; // (transcription, audioPath)
  final VoidCallback onClose;
  final String targetLanguage;
  final List<POSMapping>? npcPosMappings; // Word analysis data
  final String? npcAudioPath; // NPC audio file path
  final String? npcAudioBytes; // NPC audio base64 data

  const NPCResponseModal({
    super.key,
    required this.npcData,
    required this.npcMessage,
    required this.npcMessageEnglish,
    required this.showEnglish,
    required this.showTransliteration,
    required this.onSendResponse,
    required this.onClose,
    this.targetLanguage = 'th',
    this.npcPosMappings,
    this.npcAudioPath,
    this.npcAudioBytes,
  });

  @override
  ConsumerState<NPCResponseModal> createState() => _NPCResponseModalState();
}

class _NPCResponseModalState extends ConsumerState<NPCResponseModal>
    with TickerProviderStateMixin {
  // Modal state management
  NPCResponseModalState _modalState = NPCResponseModalState.initial;
  
  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;
  bool _isRecording = false;
  
  // Animation controllers
  late AnimationController _waveformController;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  
  // Audio waveform simulation
  List<double> _waveformData = [];
  Timer? _waveformTimer;
  
  // Results data
  TranscriptionResult? _transcriptionResult;
  
  
  // Audio playback
  just_audio.AudioPlayer? _audioPlayer;
  
  // Translation helper
  final TextEditingController _translationController = TextEditingController();
  String _translatedText = '';
  String _romanizedText = '';
  bool _isTranslating = false;
  bool _showTranslationHelper = false;
  bool _translationHelperWasUsed = false; // Track if user actually used translation helper
  bool _userChoseDirectRecording = false; // Track if user opted for direct recording without using helper
  
  // Enhanced translation with word mappings and audio
  List<Map<String, String>> _translationWordMappings = [];
  String _translationAudioBase64 = '';
  
  // NPC message toggles
  bool _showNpcEnglishTranslation = false;
  bool _showNpcWordAnalysis = false;
  
  // User transcription word analysis toggle
  
  // STT attempt tracking for fallback feature
  int _sttAttemptCount = 0;
  static const int _maxAttemptsBeforeFallback = 3;
  
  // Scroll controller for auto-scrolling
  late ScrollController _scrollController;
  
  // Toggle state for unified translation breakdown
  bool _showingExpectedMessage = true;
  
  // Flag to prevent translation helper from overriding user-initiated resets
  bool _userInitiatedReset = false;
  
  // Translation helper fallback system
  bool _shouldShowTranslationPrompt = false;
  bool _translationPromptDismissed = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeAnimations();
    
    // Force complete state reset for fresh session - ensures total isolation from previous modal instances
    _forceCompleteReset();
    
    // DEBUG: Log modal initialization
    print('DEBUG: NPCResponseModal initialized with aggressive state reset');
    print('DEBUG: Initial NPC message: "${widget.npcMessage}"');
    print('DEBUG: Initial npcPosMappings passed to modal: ${widget.npcPosMappings?.length ?? 'null'}');
    if (widget.npcPosMappings?.isNotEmpty == true) {
      print('DEBUG: First POS mapping in modal - word: "${widget.npcPosMappings!.first.wordTarget}", pos: "${widget.npcPosMappings!.first.pos}"');
    }
    print('DEBUG: Complete reset applied - transcriptionResult: ${_transcriptionResult ?? 'null'}');
  }

  // Aggressive complete reset method for modal initialization - ensures total state isolation
  void _forceCompleteReset() {
    print('DEBUG: _forceCompleteReset() - BEFORE reset:');
    print('  - _modalState: $_modalState');
    print('  - _transcriptionResult: ${_transcriptionResult != null ? "EXISTS" : "null"}');
    print('  - _translatedText: "$_translatedText"');
    print('  - _showTranslationHelper: $_showTranslationHelper');
    print('  - _translationHelperWasUsed: $_translationHelperWasUsed');
    print('  - _sttAttemptCount: $_sttAttemptCount');
    
    // Reset core modal state
    _modalState = NPCResponseModalState.initial;
    _transcriptionResult = null;
    _sttAttemptCount = 0;
    _audioPath = null;
    _isRecording = false;
    _isTranslating = false;
    
    // AGGRESSIVE RESET: Clear ALL translation helper state unconditionally
    _showTranslationHelper = false;
    _translatedText = '';
    _romanizedText = '';
    _translationAudioBase64 = '';
    _translationWordMappings.clear();
    _translationHelperWasUsed = false;
    _userChoseDirectRecording = false;
    
    // Set user-initiated flag to bypass automatic state logic
    _userInitiatedReset = true;
    
    // Reset translation helper fallback state
    _shouldShowTranslationPrompt = false;
    _translationPromptDismissed = false;
    
    print('DEBUG: _forceCompleteReset() - AFTER reset:');
    print('  - _modalState: $_modalState');
    print('  - _transcriptionResult: ${_transcriptionResult != null ? "EXISTS" : "null"}');
    print('  - _translatedText: "$_translatedText"');
    print('  - _showTranslationHelper: $_showTranslationHelper');
    print('  - _translationHelperWasUsed: $_translationHelperWasUsed');
    print('  - _userInitiatedReset: $_userInitiatedReset');
    print('  - _sttAttemptCount: $_sttAttemptCount');
  }

  // Centralized state reset method for consistency (preserves existing behavior for Try Again)
  void _resetAllState() {
    print('DEBUG: _resetAllState() - BEFORE reset:');
    print('  - _modalState: $_modalState');
    print('  - _transcriptionResult: ${_transcriptionResult != null ? "EXISTS" : "null"}');
    print('  - _translatedText: "$_translatedText"');
    print('  - _showTranslationHelper: $_showTranslationHelper');
    print('  - _sttAttemptCount: $_sttAttemptCount');
    
    _modalState = NPCResponseModalState.initial;
    _transcriptionResult = null;
    _sttAttemptCount = 0;
    _audioPath = null;
    _isRecording = false;
    _isTranslating = false;
    
    // Only clear translation helper state if it wasn't actually used
    if (!_translationHelperWasUsed) {
      _showTranslationHelper = false;
      _translatedText = '';
      _romanizedText = '';
      _translationAudioBase64 = '';
      _translationWordMappings.clear();
      _userChoseDirectRecording = false; // Reset direct recording choice on Try Again
    }
    
    // Reset user-initiated flag
    _userInitiatedReset = false;
    
    // Reset translation helper fallback state
    _shouldShowTranslationPrompt = false;
    _translationPromptDismissed = false;
    
    print('DEBUG: _resetAllState() - AFTER reset:');
    print('  - _modalState: $_modalState');
    print('  - _transcriptionResult: ${_transcriptionResult != null ? "EXISTS" : "null"}');
    print('  - _translatedText: "$_translatedText"');
    print('  - _showTranslationHelper: $_showTranslationHelper');
    print('  - _sttAttemptCount: $_sttAttemptCount');
  }

  void _initializeAnimations() {
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    _waveformTimer?.cancel();
    _audioPlayer?.dispose();
    _audioRecorder.dispose();
    _translationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls to the bottom of the modal content
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _startRecording() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }

    try {
      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // Optimal for STT APIs
          numChannels: 1,     // Mono
        ),
        path: '/tmp/recording.wav',
      );

      if (mounted) {
        setState(() {
          _modalState = NPCResponseModalState.recording;
          _isRecording = true;
          
          // Clear user-initiated reset flag when starting new recording
          _userInitiatedReset = false;
          print('DEBUG: Recording started - Reset _userInitiatedReset = false');
          
          // If user starts recording without using translation helper, mark as direct recording choice
          if (!_translationHelperWasUsed && _translatedText.isEmpty) {
            _userChoseDirectRecording = true;
          }
        });
        
        // Provide haptic feedback
        HapticFeedback.lightImpact();
        
        // Start waveform animation
        _startWaveformAnimation();
        _scaleController.forward();
        
        // Auto-scroll to bottom to expose stop button
        _scrollToBottom();
      }
    } catch (e) {
      print('Failed to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      
      if (mounted) {
        setState(() {
          _modalState = NPCResponseModalState.processing;
          _isRecording = false;
          _audioPath = path;
        });
        
        // Auto-scroll to bottom during processing
        _scrollToBottom();
        
        // Provide haptic feedback
        HapticFeedback.mediumImpact();
        
        // Stop waveform animation
        _stopWaveformAnimation();
        _scaleController.reverse();
        
        // Process the audio
        if (path != null) {
          await _processAudio(path);
        }
      }
    } catch (e) {
      print('Failed to stop recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }

  Future<void> _processAudio(String audioPath) async {
    try {
      // Note: We only increment attempt counter on successful STT, not on service errors
      
      // DEBUG: Log entry and initial state
      print('DEBUG: _processAudio called with path: $audioPath (Attempt $_sttAttemptCount/$_maxAttemptsBeforeFallback)');
      print('DEBUG: Current _translatedText: "$_translatedText"');
      print('DEBUG: Current modal state: $_modalState');
      
      // Get expected text from translation helper if available
      String expectedText = '';
      if (_translatedText.isNotEmpty) {
        expectedText = _translatedText;
        print('DEBUG: Using expected text for comparison: $_translatedText');
      }
      
      // Check if parallel processing is enabled in dialogue settings
      final dialogueSettings = ref.read(dialogueSettingsProvider);
      final bool useParallelProcessing = dialogueSettings.enableParallelProcessing;
      
      print('DEBUG: Parallel processing enabled: $useParallelProcessing');
      
      // Use the DeepL-enhanced transcribe and translate endpoint
      final result = await ApiService.transcribeAndTranslateWithDeepL(
        audioPath: audioPath,
        sourceLanguage: widget.targetLanguage,
        targetLanguage: 'en',
        expectedText: expectedText,
      );
      
      print('DEBUG: API endpoint used: transcribe-and-translate');

      if (mounted && result != null) {
        // DEBUG: Log the entire API response to understand what's being returned
        print('DEBUG: Full API response: $result');
        print('DEBUG: transcription: "${result['transcription']}" (length: ${(result['transcription'] ?? '').toString().length})');
        print('DEBUG: translation: "${result['translation']}" (length: ${(result['translation'] ?? '').toString().length})');
        print('DEBUG: romanization: "${result['romanization']}" (length: ${(result['romanization'] ?? '').toString().length})');
        print('DEBUG: Full word_confidence: ${result['word_confidence']}');
        print('DEBUG: Full word_comparisons: ${result['word_comparisons']}');
        
        // Check for potential field name variations
        final allKeys = result.keys.toList();
        print('DEBUG: All API response keys: $allKeys');
        
        // Check if transcription is actually empty vs null
        if (result['transcription'] == null) {
          print('DEBUG: WARNING - transcription field is NULL');
        } else if (result['transcription'].toString().isEmpty) {
          print('DEBUG: WARNING - transcription field is EMPTY STRING');
        } else {
          print('DEBUG: SUCCESS - transcription contains: "${result['transcription']}"');
        }
        
        // Parse the response into our model
        final wordConfidenceList = (result['word_confidence'] as List?)
            ?.map((item) => WordConfidence(
                  word: item['word'] ?? '',
                  confidence: (item['confidence'] ?? 0.0).toDouble(),
                  startTime: (item['start_time'] ?? 0.0).toDouble(),
                  endTime: (item['end_time'] ?? 0.0).toDouble(),
                  transliteration: item['transliteration'] ?? '',
                  translation: item['translation'] ?? '',
                ))
            .toList() ?? [];

        // Parse enhanced word comparison data
        final wordComparisonsList = (result['word_comparisons'] as List?)
            ?.map((item) => WordComparisonData(
                  word: item['word'] ?? '',
                  confidence: (item['confidence'] ?? 0.0).toDouble(),
                  expected: item['expected'] ?? '',
                  matchType: item['match_type'] ?? 'no_reference',
                  similarity: (item['similarity'] ?? 1.0).toDouble(),
                  startTime: (item['start_time'] ?? 0.0).toDouble(),
                  endTime: (item['end_time'] ?? 0.0).toDouble(),
                ))
            .toList() ?? [];

        _transcriptionResult = TranscriptionResult(
          transcription: result['transcription'] ?? '',
          translation: result['translation'] ?? '',
          romanization: result['romanization'] ?? '',
          wordConfidence: wordConfidenceList,
          wordComparisons: wordComparisonsList,
          confidenceScore: (result['confidence_score'] ?? result['pronunciation_score'] ?? 0.0).toDouble(),
          expectedText: result['expected_text'] ?? '',
        );
        
        // Increment attempt counter only on successful STT processing
        setState(() {
          _sttAttemptCount++;
          
          // Check if we should show translation helper prompt after reaching max attempts
          if (_sttAttemptCount >= _maxAttemptsBeforeFallback && 
              !_translationHelperWasUsed && 
              !_translationPromptDismissed) {
            _shouldShowTranslationPrompt = true;
            print('DEBUG: STT attempt $_sttAttemptCount reached, showing translation helper prompt');
          }
        });
        
        // DEBUG: Log the final transcription result
        print('DEBUG: Created TranscriptionResult:');
        print('  - transcription: "${_transcriptionResult!.transcription}"');
        print('  - wordConfidence count: ${_transcriptionResult!.wordConfidence.length}');
        print('  - words: ${_transcriptionResult!.wordConfidence.map((w) => w.word).join(", ")}');
        print('  - wordComparisons count: ${_transcriptionResult!.wordComparisons.length}');

        setState(() {
          _modalState = NPCResponseModalState.results;
        });

        // Auto-scroll to bottom to show results
        _scrollToBottom();

        // Provide success haptic feedback
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('Failed to process audio: $e');
      if (mounted) {
        // Check if this is a service unavailable error
        String errorMessage = 'Failed to process audio: $e';
        if (e.toString().toLowerCase().contains('unavailable') || 
            e.toString().toLowerCase().contains('timed out') ||
            e.toString().toLowerCase().contains('503')) {
          errorMessage = 'Service temporarily unavailable. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: e.toString().toLowerCase().contains('unavailable') ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _modalState = NPCResponseModalState.initial;
        });
      }
    }
  }

  void _startWaveformAnimation() {
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _isRecording) {
        setState(() {
          // Simulate waveform data (in a real app, you'd get this from the audio recorder)
          _waveformData = List.generate(20, (index) => math.Random().nextDouble());
        });
        _waveformController.forward().then((_) => _waveformController.reset());
      }
    });
  }

  void _stopWaveformAnimation() {
    _waveformTimer?.cancel();
    if (mounted) {
      setState(() {
        _waveformData.clear();
      });
    }
  }

  Future<void> _playRecording() async {
    if (_audioPath == null) return;

    try {
      _audioPlayer ??= just_audio.AudioPlayer();
      await _audioPlayer!.setFilePath(_audioPath!);
      await _audioPlayer!.play();
      
      // Provide haptic feedback
      HapticFeedback.selectionClick();
    } catch (e) {
      print('Failed to play recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play audio recording')),
        );
      }
    }
  }

  void _retryRecording() {
    // DEBUG: Log state clearing
    print('DEBUG: _retryRecording called - clearing all state');
    print('DEBUG: Previous transcription was: "${_transcriptionResult?.transcription ?? 'null'}"');
    
    setState(() {
      _modalState = NPCResponseModalState.initial;
      _transcriptionResult = null;
      _audioPath = null;
      // Clear any cached translation data
      _translatedText = '';
      _romanizedText = '';
      _translationAudioBase64 = '';
      _translationWordMappings.clear();
      _isTranslating = false;
    });
    
    print('DEBUG: State cleared - transcriptionResult is now null');
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }

  void _sendToNPC() {
    if (_transcriptionResult != null) {
      widget.onSendResponse(_transcriptionResult!.transcription, _audioPath);
      // Let parent handle modal closure - don't call widget.onClose()
    }
  }

  void _sendTranslationToNPC() {
    // Send the translated text from translation helper instead of STT result
    if (_translatedText.isNotEmpty) {
      widget.onSendResponse(_translatedText, null); // No audio path for translation helper
      // Let parent handle modal closure - don't call widget.onClose()
    }
  }

  void _retrySTT() {
    print('DEBUG: _retrySTT() - TRY AGAIN button clicked');
    print('DEBUG: _retrySTT() - About to call setState...');
    
    setState(() {
      print('DEBUG: _retrySTT() - Inside setState callback');
      
      // Reset all state except attempt counter (persists across retries)
      final int currentAttemptCount = _sttAttemptCount;
      print('DEBUG: _retrySTT() - Preserving attempt count: $currentAttemptCount');
      
      _resetAllState();
      _sttAttemptCount = currentAttemptCount; // Restore attempt counter
      
      // Set user-initiated reset flag AFTER _resetAllState to prevent automatic overrides
      _userInitiatedReset = true;
      print('DEBUG: _retrySTT() - Set _userInitiatedReset = true AFTER reset');
      
      print('DEBUG: _retrySTT() - Final state after reset:');
      print('  - _modalState: $_modalState');
      print('  - _transcriptionResult: ${_transcriptionResult != null ? "EXISTS" : "null"}');
      print('  - _translatedText: "$_translatedText"');
      print('  - _sttAttemptCount: $_sttAttemptCount');
      print('  - _userInitiatedReset: $_userInitiatedReset');
    });
    
    print('DEBUG: _retrySTT() - setState completed, providing haptic feedback');
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    print('DEBUG: _retrySTT() - Method completed');
  }

  void _confirmAndSendToNPC() {
    if (_transcriptionResult == null) return;
    
    // Send directly without confirmation dialog
    HapticFeedback.heavyImpact();
    _sendToNPC();
  }


  void _toggleTranslationHelper() {
    setState(() {
      _showTranslationHelper = !_showTranslationHelper;
    });
    
    // Provide haptic feedback
    HapticFeedback.selectionClick();
  }
  
  void _toggleNpcEnglishTranslation() {
    setState(() {
      _showNpcEnglishTranslation = !_showNpcEnglishTranslation;
    });
    
    // Provide haptic feedback
    HapticFeedback.selectionClick();
  }
  
  void _toggleNpcWordAnalysis() {
    setState(() {
      _showNpcWordAnalysis = !_showNpcWordAnalysis;
    });
    
    // Provide haptic feedback
    HapticFeedback.selectionClick();
  }

  // Page navigation methods
  
  Future<void> _playNpcAudio() async {
    try {
      _audioPlayer ??= just_audio.AudioPlayer();
      await _audioPlayer!.stop();
      
      if (widget.npcAudioPath != null && widget.npcAudioPath!.isNotEmpty) {
        if (widget.npcAudioPath!.startsWith('assets/')) {
          await _audioPlayer!.setAsset(widget.npcAudioPath!);
        } else {
          await _audioPlayer!.setAudioSource(just_audio.AudioSource.uri(Uri.file(widget.npcAudioPath!)));
        }
      } else if (widget.npcAudioBytes != null) {
        // Decode base64 to bytes and create temporary file
        final audioBytes = base64Decode(widget.npcAudioBytes!);
        final tempDir = await getTemporaryDirectory();
        final audioFile = File('${tempDir.path}/npc_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
        await audioFile.writeAsBytes(audioBytes);
        await _audioPlayer!.setAudioSource(just_audio.AudioSource.uri(Uri.file(audioFile.path)));
      } else {
        print("No NPC audio data to play.");
        return;
      }
      
      await _audioPlayer!.play();
      
      // Provide haptic feedback
      HapticFeedback.selectionClick();
    } catch (e) {
      print('Failed to play NPC audio: $e');
      // Still provide haptic feedback even if audio fails
      HapticFeedback.lightImpact();
    }
  }
  
  Future<void> _playTranslationAudio() async {
    if (_translationAudioBase64.isEmpty) return;
    
    try {
      _audioPlayer ??= just_audio.AudioPlayer();
      
      // Convert base64 to bytes
      final audioBytes = base64Decode(_translationAudioBase64);
      
      // Create a temporary file for the audio
      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/translation_audio.wav');
      await audioFile.writeAsBytes(audioBytes);
      
      // Play the audio
      await _audioPlayer!.setFilePath(audioFile.path);
      await _audioPlayer!.play();
      
      // Provide haptic feedback
      HapticFeedback.selectionClick();
    } catch (e) {
      print('Failed to play translation audio: $e');
    }
  }

  Future<void> _translateText() async {
    final englishText = _translationController.text.trim();
    if (englishText.isEmpty) return;

    setState(() {
      _isTranslating = true;
      
      // Clear transcription result state when starting translation to prevent contamination
      _transcriptionResult = null;
    });

    try {
      // Use the DeepL translation method for more natural translations
      // This provides word-by-word breakdown with individual Thai words, romanization, and English meanings
      final result = await ApiService.translateTextWithDeepL(
        englishText: englishText,
        targetLanguage: widget.targetLanguage,
      );

      if (mounted && result != null) {
        setState(() {
          _translatedText = result['target_text'] ?? '';
          _romanizedText = result['romanized_text'] ?? '';
          _translationAudioBase64 = result['audio_base64'] ?? '';
          
          // Parse word mappings from translate_and_syllabify function
          // This creates individual word cards with Thai, romanization, and English
          print("=== TRANSLATION DEBUG ===");
          print("Full result keys: ${result.keys.toList()}");
          print("Word mappings available: ${result['word_mappings'] != null}");
          print("Word mappings type: ${result['word_mappings'].runtimeType}");
          print("Word mappings: ${result['word_mappings']}");
          print("Word mappings count: ${result['word_mappings']?.length ?? 0}");
          
          if (result['word_mappings'] != null && result['word_mappings'].isNotEmpty) {
            _translationWordMappings = [];
            for (var mapping in result['word_mappings']) {
              print("Processing mapping: $mapping");
              final wordCard = {
                'english': mapping['translation']?.toString() ?? '',      // English meaning
                'target': mapping['target']?.toString() ?? '',            // Thai word
                'romanized': mapping['transliteration']?.toString() ?? '', // Romanization
              };
              _translationWordMappings.add(wordCard);
              print("Added word card: $wordCard");
            }
            print("Final word mappings count: ${_translationWordMappings.length}");
            print("Sample word mapping: ${_translationWordMappings.isNotEmpty ? _translationWordMappings[0] : 'none'}");
          } else {
            print("No word mappings found - result['word_mappings'] is null or empty");
            _translationWordMappings = [];
          }
          
          _isTranslating = false;
          _translationHelperWasUsed = true; // Mark that user actually used translation helper
          
          // Set modal state to results so "Your Response" panel shows for translation helper
          print('DEBUG: Translation helper - checking if should set modal state to results');
          print('  - _translatedText.isNotEmpty: ${_translatedText.isNotEmpty}');
          print('  - Current _modalState: $_modalState');
          print('  - _userInitiatedReset: $_userInitiatedReset');
          
          if (_translatedText.isNotEmpty && !_userInitiatedReset) {
            print('DEBUG: Translation helper - OVERRIDING modal state to results');
            _modalState = NPCResponseModalState.results;
            print('DEBUG: Translation helper - New _modalState: $_modalState');
          } else if (_userInitiatedReset) {
            print('DEBUG: Translation helper - SKIPPING state override due to user-initiated reset');
          }
        });

        // Provide success haptic feedback
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('Translation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e')),
        );
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: _buildUnifiedInterface(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 20), // Increased vertical padding
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        // Enhanced visual hierarchy with subtle shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Enhanced back button with better touch target
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Add haptic feedback
                HapticFeedback.lightImpact();
                widget.onClose();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12), // Larger touch target
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: const Icon(Icons.arrow_back, size: 24),
              ),
            ),
          ),
          
          // Centered title with enhanced avatar and typography
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Enhanced avatar with subtle glow effect
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundImage: AssetImage(widget.npcData.dialoguePortraitPath),
                    radius: 24, // Slightly larger for better visual presence
                  ),
                ),
                const SizedBox(width: 16), // Increased spacing
                // Enhanced typography with better mobile readability
                Text(
                  widget.npcData.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22, // Slightly larger for mobile
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          
          // Balanced spacing for perfect centering
          const SizedBox(width: 72), // Adjusted for new button width
        ],
      ),
    );
  }

  String _getStateDescription() {
    switch (_modalState) {
      case NPCResponseModalState.initial:
        return _showTranslationHelper 
            ? 'Use translation help or record directly'
            : 'Need help? Tap above or record directly';
      case NPCResponseModalState.recording:
        return 'Listening... speak clearly in Thai';
      case NPCResponseModalState.processing:
        return 'Analyzing your speech...';
      case NPCResponseModalState.results:
        return 'Great! Review your score or try again';
      case NPCResponseModalState.practice:
        return 'Practice mode - no pressure!';
      case NPCResponseModalState.sending:
        return 'Sending your response to ${widget.npcData.name}...';
    }
  }


  // Translation helper page (Page 1)
  // Unified interface combining translation helper and recording
  Widget _buildUnifiedInterface() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always show NPC message for context
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: _buildNpcReferenceSection(),
          ),
          const SizedBox(height: 16),
          
          // Inline translation helper - show by default, hide only if user chose direct recording without using it
          if (!_userChoseDirectRecording || (_translationHelperWasUsed && _translatedText.isNotEmpty))
            _buildInlineTranslationHelper(),
          const SizedBox(height: 16),
          
          // Recording interface and results
          _buildRecordingInterface(),
          
          // Show unified translation breakdown when we have translation or transcription results
          // Direct action buttons without Learning Assistant container
          // DEBUG: Log display condition evaluation
          ...() {
            final bool showCondition = _modalState == NPCResponseModalState.results && 
                (_transcriptionResult != null || _translatedText.isNotEmpty);
            print('DEBUG: Display condition evaluation:');
            print('  - _modalState: $_modalState');
            print('  - _transcriptionResult != null: ${_transcriptionResult != null}');
            print('  - _translatedText.isNotEmpty: ${_translatedText.isNotEmpty}');
            print('  - Show Your Response panel: $showCondition');
            
            if (showCondition) {
              return [
                const SizedBox(height: 16),
                _buildUnifiedActionButtons(),
              ];
            } else {
              return <Widget>[];
            }
          }(),
        ],
      ),
    );
  }

  // Prominent translation helper notification - positioned between Your Response and action buttons
  Widget _buildProminentTranslationNotification() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * animationValue),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // Use attention-grabbing gradient
              gradient: LinearGradient(
                colors: [
                  Colors.amber[100]!,
                  Colors.amber[50]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber[400]!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated icon for attention
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, pulseValue, child) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber[200]?.withOpacity(0.7 + (0.3 * pulseValue)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.translate,
                        color: Colors.amber[800],
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Translation Helper Available',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Having trouble? Try the Translation Helper on your next turn',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[800],
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _translationPromptDismissed = true;
                      });
                      HapticFeedback.lightImpact();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: Colors.amber[600],
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // Full-width Your Response Panel (optimized for mobile)
  Widget _buildFullWidthUserResponsePanel() {
    if (_transcriptionResult == null) return const SizedBox();
    
    final overallConfidence = _transcriptionResult!.confidenceScore;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel title with confidence score and audio playback
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Response',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Audio playback button
                  if (_audioPath != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _playRecording();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.blue[600],
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  if (_audioPath != null) const SizedBox(width: 8),
                  _buildSTTConfidenceBadge(overallConfidence),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Main transcribed text (larger for full width)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue[300]!),
            ),
            child: Text(
              _transcriptionResult!.transcription.isNotEmpty 
                  ? _transcriptionResult!.transcription
                  : '(No transcription detected)',
              style: TextStyle(
                fontSize: 22, // Larger text for full width
                fontWeight: FontWeight.bold,
                color: _transcriptionResult!.transcription.isNotEmpty 
                    ? Colors.black87
                    : Colors.grey[600],
                fontStyle: _transcriptionResult!.transcription.isNotEmpty 
                    ? FontStyle.normal 
                    : FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          
          // Word breakdown cards with better spacing for full width
          if (_transcriptionResult!.wordConfidence.isNotEmpty) ...[
            Text(
              'Word-by-word Analysis:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 8),
            _buildSTTConfidenceWordCards(_convertWordConfidenceToMappings(), isReference: false),
            const SizedBox(height: 16),
          ],
          
          // Detected translation
          _buildTranslationSection(_transcriptionResult!.translation, isReference: false),
          
          const SizedBox(height: 12),
          
          // Low confidence warnings
          _buildConfidenceWarnings(),
        ],
      ),
    );
  }

  // Expected Response Panel (reference/target) - keeping for backwards compatibility
  Widget _buildExpectedResponsePanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel title
          Text(
            'Expected Response',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          
          // Main Thai text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              _translatedText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          
          // Word breakdown cards with reference styling
          if (_translationWordMappings.isNotEmpty)
            _buildSTTConfidenceWordCards(_translationWordMappings, isReference: true),
          
          const SizedBox(height: 12),
          
          // Full translation
          _buildTranslationSection(_getExpectedTranslation(), isReference: true),
        ],
      ),
    );
  }

  // Unified Your Response Panel (STT results or translation results)
  Widget _buildUserResponsePanel() {
    // Show for either transcription result or translation result
    if (_transcriptionResult == null && _translatedText.isEmpty) return const SizedBox();
    
    // Determine which source to use
    final bool hasTranscription = _transcriptionResult != null;
    final bool hasTranslation = _translatedText.isNotEmpty;
    
    final overallConfidence = hasTranscription ? _transcriptionResult!.confidenceScore : 1.0;
    final confidencePercentage = (overallConfidence * 100).round();
    final String responseText = hasTranscription ? _transcriptionResult!.transcription : _translatedText;
    // Remove parenthetical text to prevent UI overflow
    final String responseType = '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel title with confidence score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Response',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Audio playback button
                  if (_audioPath != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _playRecording();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.volume_up,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  if (_audioPath != null) const SizedBox(width: 8),
                  _buildSTTConfidenceBadge(overallConfidence),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Main transcribed text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue[300]!),
            ),
            child: Text(
              responseText.isNotEmpty 
                  ? responseText
                  : '(No response detected)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: responseText.isNotEmpty 
                    ? Colors.black87
                    : Colors.grey[600],
                fontStyle: responseText.isNotEmpty 
                    ? FontStyle.normal 
                    : FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          
          // Word breakdown cards (only for actual STT transcription results)
          if (hasTranscription && _transcriptionResult!.wordConfidence.isNotEmpty)
            _buildSTTConfidenceWordCards(_convertWordConfidenceToMappings(), isReference: false),
          
          const SizedBox(height: 12),
          
          // Translation section (only for transcription results)
          if (hasTranscription)
            _buildTranslationSection(_transcriptionResult!.translation, isReference: false),
          
          const SizedBox(height: 8),
          
          // Low confidence warnings (only for transcription results)
          if (hasTranscription)
            _buildConfidenceWarnings(),
          
        ],
      ),
    );
  }

  // Animated Progress Light Widget
  Widget _buildAnimatedProgressLight({
    required int index,
    required bool isCompleted,
    required bool isActive,
    double size = 32,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: isCompleted ? 300 : 600),
      tween: Tween<double>(
        begin: 0.0,
        end: isCompleted ? 1.0 : (isActive ? 0.6 : 0.0),
      ),
      builder: (context, animationValue, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: size > 25 ? 6 : 3),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted 
                ? Colors.green[600]
                : (isActive 
                    ? Colors.amber[400]?.withOpacity(0.3 + (animationValue * 0.7))
                    : Colors.grey[300]),
            boxShadow: isActive || isCompleted ? [
              BoxShadow(
                color: (isCompleted ? Colors.green[400]! : Colors.amber[400]!)
                    .withOpacity(0.4 * animationValue),
                blurRadius: 8 * animationValue,
                spreadRadius: 2 * animationValue,
              ),
            ] : null,
          ),
          child: isCompleted 
              ? Icon(
                  Icons.check,
                  color: Colors.white,
                  size: size * 0.6,
                )
              : (isActive 
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber[600]?.withOpacity(animationValue),
                      ),
                    )
                  : null),
        );
      },
    );
  }

  // Translation word cards for translation helper results
  Widget _buildTranslationWordCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Word Breakdown:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _translationWordMappings.map((mapping) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thai word
                  Text(
                    mapping['target'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  // Romanization
                  if (mapping['romanized']?.isNotEmpty == true)
                    Text(
                      mapping['romanized']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  // English meaning
                  Text(
                    mapping['english'] ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Toggle button for switching between expected and user response (kept for backwards compatibility)
  Widget _buildResponseToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('Expected', _showingExpectedMessage, () {
            setState(() {
              _showingExpectedMessage = true;
            });
          }),
          _buildToggleOption('Your Try', !_showingExpectedMessage, () {
            setState(() {
              _showingExpectedMessage = false;
            });
          }),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[600] : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Expected response content (from translation helper)
  Widget _buildExpectedResponseContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thai text display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            _translatedText,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        
        // Word breakdown using existing translation mappings
        if (_translationWordMappings.isNotEmpty)
          _buildWordBreakdownCards(_translationWordMappings, isExpected: true),
      ],
    );
  }

  // User response content (from transcription)
  Widget _buildUserResponseContent() {
    if (_transcriptionResult == null) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio quality indicator and Thai text
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Text(
                  _transcriptionResult!.transcription.isNotEmpty 
                      ? _transcriptionResult!.transcription
                      : '(No transcription available)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _transcriptionResult!.transcription.isNotEmpty 
                        ? Colors.black87
                        : Colors.grey[600],
                    fontStyle: _transcriptionResult!.transcription.isNotEmpty 
                        ? FontStyle.normal 
                        : FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactAudioQualityBadge(),
          ],
        ),
        const SizedBox(height: 12),
        
        // Word breakdown from transcription
        if (_transcriptionResult!.wordConfidence.isNotEmpty)
          _buildWordBreakdownCards(_convertWordConfidenceToMappings(), isExpected: false),
      ],
    );
  }

  // Unified word breakdown cards (replaces separate word card methods)
  Widget _buildWordBreakdownCards(List<Map<String, String>> mappings, {required bool isExpected}) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: mappings.map((mapping) {
        Color borderColor = isExpected ? Colors.teal[300]! : Colors.blue[300]!;
        
        // Apply quality color for transcription results
        if (!isExpected && mapping.containsKey('confidence')) {
          final confidence = double.tryParse(mapping['confidence'] ?? '0') ?? 0.0;
          borderColor = _getAudioQualityColor(confidence);
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thai text
              Text(
                mapping['target'] ?? mapping['thai'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Romanization
              if ((mapping['romanized'] ?? mapping['romanization'] ?? '').isNotEmpty)
                Text(
                  mapping['romanized'] ?? mapping['romanization'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 2),
              // English translation
              if ((mapping['english'] ?? mapping['translation'] ?? '').isNotEmpty)
                Text(
                  mapping['english'] ?? mapping['translation'] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // STT Confidence-based word cards with color coding
  Widget _buildSTTConfidenceWordCards(List<Map<String, String>> mappings, {required bool isReference}) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: mappings.map((mapping) {
        Color borderColor;
        String? confidenceText;
        
        if (isReference) {
          // Reference cards use neutral gray
          borderColor = Colors.grey[400]!;
        } else {
          // STT confidence color coding
          final confidence = double.tryParse(mapping['confidence'] ?? '0') ?? 0.0;
          borderColor = _getSTTConfidenceColor(confidence);
          confidenceText = '${(confidence * 100).round()}%';
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 3), // Thicker border for confidence
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Confidence indicator for STT results
              if (!isReference && confidenceText != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Tooltip(
                          message: 'Audio Confidence',
                          child: Text(
                            'AC',
                            style: TextStyle(
                              fontSize: 8,
                              color: borderColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        _getConfidenceIcon(double.tryParse(mapping['confidence'] ?? '0') ?? 0.0),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      confidenceText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              
              // Thai text
              Text(
                mapping['target'] ?? mapping['thai'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              // Romanization
              if ((mapping['romanized'] ?? mapping['romanization'] ?? '').isNotEmpty)
                Text(
                  mapping['romanized'] ?? mapping['romanization'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 2),
              
              // English translation
              if ((mapping['english'] ?? mapping['translation'] ?? '').isNotEmpty)
                Text(
                  mapping['english'] ?? mapping['translation'] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Get STT confidence color based on percentage
  Color _getSTTConfidenceColor(double confidence) {
    if (confidence >= 0.85) return Colors.green[600]!;  // High confidence: Green (85-100%)
    if (confidence >= 0.60) return Colors.orange[600]!; // Medium confidence: Yellow/Orange (60-84%)
    return Colors.red[600]!;                            // Low confidence: Red (0-59%)
  }

  // Get confidence icon based on level
  Widget _getConfidenceIcon(double confidence) {
    if (confidence >= 0.85) return Icon(Icons.check_circle, color: Colors.green[600], size: 12);
    if (confidence >= 0.60) return Icon(Icons.warning, color: Colors.orange[600], size: 12);
    return Icon(Icons.error, color: Colors.red[600], size: 12);
  }

  // STT confidence badge for overall score
  Widget _buildSTTConfidenceBadge(double confidence) {
    final percentage = (confidence * 100).round();
    final color = _getSTTConfidenceColor(confidence);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Overall Audio Confidence',
            child: Text(
              'OAC',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _getConfidenceIcon(confidence),
          const SizedBox(width: 4),
          Text(
            '$percentage%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


  // Translation section
  Widget _buildTranslationSection(String translation, {required bool isReference}) {
    if (translation.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isReference ? 'Translation:' : 'Detected Translation:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isReference ? Colors.grey[600] : Colors.blue[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          translation,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  // Confidence warnings for low STT confidence words
  Widget _buildConfidenceWarnings() {
    if (_transcriptionResult == null) return const SizedBox();
    
    final lowConfidenceWords = _transcriptionResult!.wordConfidence
        .where((word) => word.confidence < 0.60)
        .toList();
    
    if (lowConfidenceWords.isEmpty) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning, color: Colors.orange[600], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low STT confidence detected:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lowConfidenceWords.map((w) => w.word).join(', '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Consider speaking more clearly and re-recording',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for translation

  String _getExpectedTranslation() {
    return _translationWordMappings
        .map((mapping) => mapping['english'] ?? '')
        .where((text) => text.isNotEmpty)
        .join(' ');
  }


  // Compact audio quality badge (fixes overflow issues)
  Widget _buildCompactAudioQualityBadge() {
    if (_transcriptionResult == null) return const SizedBox();
    
    final quality = _transcriptionResult!.confidenceScore;
    final percentage = (quality * 100).round();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _getAudioQualityColor(quality),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Visual attempt progress lights
  Widget _buildAttemptLights() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final bool isCompleted = index < _sttAttemptCount;
          final bool isActive = index == _sttAttemptCount && _isRecording;
          
          return _buildAnimatedProgressLight(
            index: index,
            isCompleted: isCompleted,
            isActive: isActive,
            size: 32,
          );
        }),
      ),
    );
  }

  // Simplified action buttons for Your Response panel
  Widget _buildUnifiedActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Your Response panel - shows transcription/translation results
        _buildUserResponsePanel(),
        
        const SizedBox(height: 12),
        
        // PROMINENT TRANSLATION NOTIFICATION - positioned between Your Response and action buttons
        if (_shouldShowTranslationPrompt && !_translationPromptDismissed)
          _buildProminentTranslationNotification(),
        
        const SizedBox(height: 16),
        
        // Action buttons row
        Row(
          children: [
            // Try Again button - left side, wider for text
            Expanded(
              flex: 2, // Make Try Again button wider
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _retrySTT();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  side: BorderSide(color: Colors.orange[400]!, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.orange[50],
                  minimumSize: const Size(0, 48), // Ensure consistent height with Send Message button
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Send Message button - right side
            Expanded(
              flex: 3, // Balance with wider Try Again button
              child: ElevatedButton(
                onPressed: _transcriptionResult != null ? () {
                  HapticFeedback.mediumImpact();
                  _confirmAndSendToNPC(); // Send transcription result normally
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _transcriptionResult != null 
                      ? Colors.green[600] // Green when ready to send
                      : Colors.grey[400], // Grey when disabled
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: (_sttAttemptCount >= _maxAttemptsBeforeFallback ? Colors.teal : Colors.green).withOpacity(0.3),
                  minimumSize: const Size(0, 48), // Ensure consistent height with Try Again button
                ),
                child: Text(
                  'Send Message',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Enhanced translation helper with instant preview
  Widget _buildInlineTranslationHelper() {
    // Add visual emphasis when translation prompt is shown
    final bool shouldHighlight = _shouldShowTranslationPrompt && !_translationPromptDismissed;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0.0, end: shouldHighlight ? 1.0 : 0.0),
      builder: (context, pulseValue, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: shouldHighlight 
                ? Colors.blue[50]?.withOpacity(0.7 + (0.3 * pulseValue))
                : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: shouldHighlight 
                  ? Colors.blue[400]!.withOpacity(0.6 + (0.4 * pulseValue))
                  : Theme.of(context).colorScheme.outline,
              width: shouldHighlight ? 2.0 + (pulseValue * 1.0) : 1.0,
            ),
            boxShadow: shouldHighlight ? [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2 * pulseValue),
                blurRadius: 8 * pulseValue,
                spreadRadius: 2 * pulseValue,
              ),
            ] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
          Row(
            children: [
              Icon(Icons.translate, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Text(
                'Translation Helper',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Input section
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _translationController,
                  decoration: InputDecoration(
                    hintText: 'Type in English...',
                    hintStyle: const TextStyle(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                  onChanged: (_) {
                    // Clear previous translation when typing
                    if (_translatedText.isNotEmpty) {
                      setState(() {
                        _translatedText = '';
                        _translationWordMappings.clear();
                        _translationAudioBase64 = '';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isTranslating ? null : _translateText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _isTranslating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Translate', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          
          // Translation Section
          if (_translatedText.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInstantPreview(),
          ],
          ],
        ),
      );
    },
    );
  }

  // Enhanced translation preview with improved mobile UX
  Widget _buildInstantPreview() {
    return Container(
      padding: const EdgeInsets.all(16), // Larger padding for mobile
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12), // Larger border radius
        border: Border.all(color: Colors.teal[300]!, width: 2), // More prominent border
        // Add subtle shadow for depth
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced preview header with better mobile interaction
          Row(
            children: [
              Icon(Icons.preview, color: Colors.teal[700], size: 20), // Larger icon
              const SizedBox(width: 8), // Increased spacing
              Text(
                'Translation',
                style: TextStyle(
                  color: Colors.teal[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 15, // Larger text for mobile readability
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (_translationAudioBase64.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick(); // Haptic feedback
                      _playTranslationAudio();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8), // Larger touch target
                      child: Icon(
                        Icons.volume_up, 
                        color: Colors.teal[700], 
                        size: 22, // Larger icon
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Main Thai text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.teal[300]!),
            ),
            child: Text(
              _translatedText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[900],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          
          // Word breakdown preview - wrapped layout
          if (_translationWordMappings.isNotEmpty) ...[
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _translationWordMappings.map((mapping) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Thai text
                      Text(
                        mapping['target'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Romanization
                      if ((mapping['romanized'] ?? '').isNotEmpty)
                        Text(
                          mapping['romanized'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.teal[700],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      // English meaning with model confidence indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 8,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            mapping['english'] ?? '',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          
          // Lights and Send button on same row
          const SizedBox(height: 12),
          Row(
            children: [
              // Small animated attempt lights on left
              Row(
                children: List.generate(3, (index) {
                  final bool isCompleted = index < _sttAttemptCount;
                  final bool isActive = index == _sttAttemptCount && _isRecording;
                  
                  return _buildAnimatedProgressLight(
                    index: index,
                    isCompleted: isCompleted,
                    isActive: isActive,
                    size: 20,
                  );
                }),
              ),
              
              const SizedBox(width: 12),
              
              // Send Translation button on right
              Expanded(
                child: ElevatedButton(
                  onPressed: _sttAttemptCount >= _maxAttemptsBeforeFallback ? () {
                    HapticFeedback.mediumImpact();
                    _sendTranslationToNPC(); // Send translation after 3 attempts
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sttAttemptCount >= _maxAttemptsBeforeFallback 
                        ? Colors.green[600] // Green when ready to send translation (same as Send Message)
                        : Colors.grey[700], // Solid grey for better visibility
                    disabledBackgroundColor: Colors.grey[700], // Force grey when disabled
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _sttAttemptCount >= _maxAttemptsBeforeFallback 
                            ? Colors.green[700]! 
                            : Colors.grey[600]!, 
                        width: 1,
                      ),
                    ),
                    elevation: _sttAttemptCount >= _maxAttemptsBeforeFallback ? 2 : 1,
                    minimumSize: const Size(0, 40),
                  ),
                  child: Text(
                    'Send Translation',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }



  // Helper method for NPC reference section
  Widget _buildNpcReferenceSection() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: () {
          // Base height calculation using screen height for better responsiveness
          final screenHeight = MediaQuery.of(context).size.height;
          final baseHeight = screenHeight * 0.3; // 30% of screen height as base
          
          if (_showNpcEnglishTranslation && _showNpcWordAnalysis) {
            return math.min(baseHeight * 1.5, 700.0).toDouble(); // Both features - up to 700px max
          } else if (_showNpcEnglishTranslation || _showNpcWordAnalysis) {
            return math.min(baseHeight * 1.2, 500.0).toDouble(); // One feature - up to 500px max
          } else {
            return math.min(baseHeight * 0.8, 250.0).toDouble(); // No features - up to 250px max
          }
        }(),
      ),
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Title on its own row
          Text(
            '🗣️ ${widget.npcData.name}\'s Message:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          
          // Toggle bar above the actual message (like dialogue_overlay)
          _buildNpcMessageToggleBar(),
          const SizedBox(height: 8),
          
          // NPC message with conditional word analysis
          _buildNpcMessageWithAnalysis(),
          
          // Conditional English translation
          if (_showNpcEnglishTranslation && widget.npcMessageEnglish.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(10), // Reduced from 12
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Text(
                    widget.npcMessageEnglish,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  // Helper method for translation target section (when user has translated)
  Widget _buildTranslationTargetSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Your Target Response:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 12),
          _buildTranslationDisplaySection(),
        ],
      ),
    );
  }

  // Helper method for expandable translation section
  Widget _buildTranslationHelperSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[400]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          '💡 Need help? Tap to translate',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.blue[800],
          ),
        ),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.blue[50],
        iconColor: Colors.blue[700],
        collapsedIconColor: Colors.blue[700],
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _translationController,
                  decoration: InputDecoration(
                    hintText: 'Type in English...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  onSubmitted: (_) => _translateText(),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isTranslating ? null : _translateText,
                    icon: _isTranslating 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.translate, size: 16),
                    label: Text(_isTranslating ? 'Translating...' : 'Translate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_translatedText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildTranslationDisplaySection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for displaying translation results
  Widget _buildTranslationDisplaySection() {
    print("=== DISPLAY DEBUG ===");
    print("_translationWordMappings.length: ${_translationWordMappings.length}");
    print("_translationWordMappings.isEmpty: ${_translationWordMappings.isEmpty}");
    print("Will show word cards: ${_translationWordMappings.isNotEmpty}");
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Translation:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            if (_translationAudioBase64.isNotEmpty)
              IconButton(
                icon: Icon(Icons.volume_up, color: Colors.teal[700]),
                onPressed: _playTranslationAudio,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Play audio',
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Word mapping cards or simple text display  
        if (_translationWordMappings.isNotEmpty) ...[
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: _translationWordMappings.map((mapping) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.teal.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thai text
                    Text(
                      mapping['target'] ?? '',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Romanization
                    if ((mapping['romanized'] ?? '').isNotEmpty)
                      Text(
                        mapping['romanized'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.teal[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 2),
                    // English meaning
                    Text(
                      mapping['english'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ] else ...[
          // Fallback to simple text display
          Text(
            _translatedText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.teal[900],
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          if (_romanizedText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Romanization: $_romanizedText',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.teal[700],
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ],
    );
  }

  // Helper method for recording interface that combines mic and results
  Widget _buildRecordingInterface() {
    return Column(
      children: [
        // Microphone button or recording state
        if (_modalState == NPCResponseModalState.initial)
          Center(child: _buildMicrophoneButton())
        else if (_modalState == NPCResponseModalState.recording)
          _buildRecordingContent()
        else if (_modalState == NPCResponseModalState.processing)
          _buildProcessingContent()
        else if (_modalState == NPCResponseModalState.results)
          _buildResultsContent(),
      ],
    );
  }


  Widget _buildInitialContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // NPC Message Toggle Bar
          _buildNpcMessageToggleBar(),
          const SizedBox(height: 8),
          // NPC Message Reference
          Container(
            constraints: BoxConstraints(
              maxHeight: () {
                // Base height calculation using screen height for better responsiveness
                final screenHeight = MediaQuery.of(context).size.height;
                final baseHeight = screenHeight * 0.3; // 30% of screen height as base
                
                if (_showNpcEnglishTranslation && _showNpcWordAnalysis) {
                  return math.min(baseHeight * 1.5, 700.0).toDouble(); // Both features - up to 700px max
                } else if (_showNpcEnglishTranslation || _showNpcWordAnalysis) {
                  return math.min(baseHeight * 1.2, 500.0).toDouble(); // One feature - up to 500px max
                } else {
                  return math.min(baseHeight * 0.8, 250.0).toDouble(); // No features - up to 250px max
                }
              }(),
            ),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.npcData.name}\'s Last Message',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNpcMessageWithAnalysis(),
                if (_showNpcEnglishTranslation && widget.npcMessageEnglish.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'English Translation:',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.npcMessageEnglish,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.blue[800],
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
          const SizedBox(height: 20),
          // Dynamic Instructions
          Text(
            _translatedText.isNotEmpty 
                ? 'Perfect! Now record yourself saying: "$_translatedText"'
                : _showTranslationHelper 
                    ? 'Translate your response above, then record'
                    : 'Ready to respond? Tap the microphone',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _translatedText.isNotEmpty ? Colors.green[700] : Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Large Mic Button
          _buildMicrophoneButton(),
        ],
      ),
    );
  }


  Widget _buildMicrophoneButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return ScaleTransition(
            scale: _scaleController.drive(
              Tween(begin: 1.0, end: 1.1).chain(
                CurveTween(curve: Curves.elasticOut),
              ),
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording 
                    ? Colors.red.withOpacity(0.8 + 0.2 * _pulseController.value)
                    : Theme.of(context).primaryColor.withOpacity(0.8),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : Theme.of(context).primaryColor)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: _isRecording ? 5 + 10 * _pulseController.value : 5,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), // Extra bottom padding to avoid close button
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Recording indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recording...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Waveform visualization
          _buildWaveform(),
          const SizedBox(height: 30), // Increased spacing
          // Stop button (centered) with extra visual emphasis
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildMicrophoneButton(),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _waveformData.map((amplitude) {
          return Container(
            width: 4,
            height: math.max(4, amplitude * 50),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProcessingContent() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Processing your speech...',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 10),
          const Text(
            'This may take a few seconds',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    // Results are now handled in the unified interface
    return const SizedBox();
  }



  
  


  // Expected Message Card (Optional) - shows translation helper result
  Widget _buildOptionalExpectedMessageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Expected Message (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          
          // Main translated text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              _translatedText,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          
          // Word breakdown cards
          if (_translationWordMappings.isNotEmpty)
            _buildWordMiniCards(_translationWordMappings, isExpected: true),
          const SizedBox(height: 16),
          
          // Removed attempt lights and progressive send button - using simplified unified button approach
        ],
      ),
    );
  }

  // Your Message Card - shows transcription result
  Widget _buildYourMessageCard() {
    if (_transcriptionResult == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with audio quality
          Row(
            children: [
              Text(
                'Your Message',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const Spacer(),
              _buildAudioQualityIndicator(),
              const SizedBox(width: 12),
              // Always active send button
              ElevatedButton(
                onPressed: _transcriptionResult != null ? _confirmAndSendToNPC : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Main transcription text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[300]!),
            ),
            child: Text(
              _transcriptionResult!.transcription.isNotEmpty 
                  ? _transcriptionResult!.transcription
                  : '(No transcription available - please try again)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _transcriptionResult!.transcription.isNotEmpty 
                    ? Colors.black87
                    : Colors.grey[600],
                fontStyle: _transcriptionResult!.transcription.isNotEmpty 
                    ? FontStyle.normal 
                    : FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          
          // Word breakdown cards from transcription
          if (_transcriptionResult!.wordConfidence.isNotEmpty)
            _buildWordMiniCards(_convertWordConfidenceToMappings(), isExpected: false),
          const SizedBox(height: 12),
          
          // Educational note
          Text(
            'Note: Colors show audio transcription quality',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getWordRomanization(String thaiWord) {
    // Use existing transliteration data if available
    final wordData = _transcriptionResult?.wordConfidence
        .firstWhere((w) => w.word == thaiWord, orElse: () => WordConfidence(
              word: thaiWord,
              confidence: 0,
              startTime: 0,
              endTime: 0,
            ));
    
    if (wordData?.transliteration.isNotEmpty == true) {
      return wordData!.transliteration;
    }
    
    // Fallback romanization mapping
    final romanizationMap = {
      'ฉัน': 'chan',
      'อยาก': 'yaak', 
      'จะ': 'ja',
      'ช่วย': 'chuay',
      'สวัสดี': 'sawasdee',
      'ครับ': 'khrap',
      'ค่ะ': 'kha',
      'ใช่': 'chai',
      'ไม่': 'mai',
      'เป็น': 'pen',
      'อะไร': 'arai',
    };
    
    return romanizationMap[thaiWord] ?? thaiWord;
  }

  // Removed _buildAttemptLights() method - no longer needed with simplified UI

  // Removed _buildProgressiveSendButton() method - replaced with unified button logic

  // Audio quality indicator - shows transcription confidence as "audio quality"
  Widget _buildAudioQualityIndicator() {
    if (_transcriptionResult == null) return const SizedBox();
    
    final quality = _transcriptionResult!.confidenceScore;
    final percentage = (quality * 100).round();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getAudioQualityColor(quality),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Audio Quality: $percentage%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // Get color for audio quality (not pronunciation)
  Color _getAudioQualityColor(double quality) {
    if (quality >= 0.8) return Colors.green;
    if (quality >= 0.6) return Colors.orange;
    return Colors.red;
  }

  // Word mini-cards component for both expected and actual messages
  Widget _buildWordMiniCards(List<Map<String, String>> mappings, {required bool isExpected}) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: mappings.map((mapping) {
        Color cardColor = isExpected ? Colors.white : Colors.white;
        Color borderColor = isExpected ? Colors.grey[300]! : Colors.blue[300]!;
        
        // For transcription results, apply quality color
        if (!isExpected && mapping.containsKey('confidence')) {
          final confidence = double.tryParse(mapping['confidence'] ?? '0') ?? 0.0;
          borderColor = _getAudioQualityColor(confidence);
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thai text (larger, bold)
              Text(
                mapping['target'] ?? mapping['thai'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              // Romanization (smaller, italic)
              if ((mapping['romanized'] ?? mapping['romanization'] ?? '').isNotEmpty)
                Text(
                  mapping['romanized'] ?? mapping['romanization'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 2),
              // English translation (smallest, gray)
              if ((mapping['english'] ?? mapping['translation'] ?? '').isNotEmpty)
                Text(
                  mapping['english'] ?? mapping['translation'] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Convert WordConfidence to mappings format for consistency
  List<Map<String, String>> _convertWordConfidenceToMappings() {
    if (_transcriptionResult == null) return [];
    
    return _transcriptionResult!.wordConfidence.map((word) {
      return {
        // Use keys that match _buildWordBreakdownCards expectations
        'target': word.word,                    // Thai text (primary display)
        'thai': word.word,                      // Thai text (fallback)
        'romanized': word.transliteration.isNotEmpty 
            ? word.transliteration 
            : _getWordRomanization(word.word),  // Romanization (secondary display)
        'romanization': word.transliteration.isNotEmpty 
            ? word.transliteration 
            : _getWordRomanization(word.word),  // Romanization (fallback)
        'english': word.translation,            // English translation (tertiary display)
        'translation': word.translation,        // English translation (fallback)
        'confidence': word.confidence.toString(),
      };
    }).toList();
  }


  
  





  // Removed _buildActions() method - using header back button instead

  // Removed _buildActionButtons() method - redundant close button, using header back button instead
  
  Widget _buildNpcMessageToggleBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIntegratedControlButton(
              icon: Icons.volume_up,
              onTap: _playNpcAudio,
              enabled: widget.npcAudioPath != null || widget.npcAudioBytes != null,
            ),
            _buildIntegratedToggleButton(
              text: "EN",
              isActive: _showNpcEnglishTranslation,
              onTap: _toggleNpcEnglishTranslation,
            ),
            _buildIntegratedToggleButton(
              text: "ท",
              isActive: _showNpcWordAnalysis,
              onTap: _toggleNpcWordAnalysis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIntegratedControlButton({
    required IconData icon,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled 
            ? Colors.grey.shade200
            : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled 
              ? Colors.grey.shade400 
              : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: enabled 
            ? Colors.grey.shade700 
            : Colors.grey.shade400,
          size: 18,
        ),
      ),
    );
  }
  
  Widget _buildIntegratedToggleButton({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive 
            ? Colors.teal.shade600
            : Colors.grey.shade200,
          border: Border.all(
            color: isActive 
              ? Colors.teal.shade700 
              : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive 
                ? Colors.white 
                : Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  
  // Keep the original method for backward compatibility
  
  // Helper method to display NPC message with conditional word analysis (like dialogue_overlay.dart)
  Widget _buildNpcMessageWithAnalysis() {
    // Check if we should show word analysis and have mapping data
    if (_showNpcWordAnalysis && widget.npcPosMappings != null && widget.npcPosMappings!.isNotEmpty) {
      // Build word analysis display using Wrap to prevent overflow
      List<Widget> wordWidgets = widget.npcPosMappings!.map((mapping) {
        List<Widget> wordParts = [
          Text(
            mapping.wordTarget, 
            style: TextStyle(
              color: posColorMapping[mapping.pos] ?? Colors.black, 
              fontSize: 18, 
              fontWeight: FontWeight.w500
            )
          ),
        ];
        
        // Add transliteration if available
        if (mapping.wordTranslit.isNotEmpty) {
          wordParts.add(const SizedBox(height: 1));
          wordParts.add(Text(
            mapping.wordTranslit, 
            style: TextStyle(
              fontSize: 12, 
              color: posColorMapping[mapping.pos] ?? Colors.black54
            )
          ));
        }
        
        // Add English translation if available
        if (mapping.wordEng.isNotEmpty) {
          wordParts.add(const SizedBox(height: 1));
          wordParts.add(Text(
            mapping.wordEng, 
            style: TextStyle(
              fontSize: 12, 
              color: posColorMapping[mapping.pos] ?? Colors.blueGrey.shade600, 
              fontStyle: FontStyle.italic
            )
          ));
        }
        
        return Padding(
          padding: const EdgeInsets.only(right: 3.0, bottom: 2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            mainAxisSize: MainAxisSize.min, 
            children: wordParts
          ),
        );
      }).toList();
      
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 450), // Increased from 300 to 450
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            children: wordWidgets,
          ),
        ),
      );
    } else {
      // Show plain text when analysis is disabled or no mappings available
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 450), // Increased for consistency
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.npcMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              // Show helpful message when word analysis is toggled but no data available
              if (_showNpcWordAnalysis && (widget.npcPosMappings == null || widget.npcPosMappings!.isEmpty)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Word analysis not available for this message',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.amber[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
}