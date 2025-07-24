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
enum NPCResponseModalPage {
  translation,  // Translation helper page
  recording,    // Recording and results page
}

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
  final double pronunciationScore;
  final String expectedText;

  TranscriptionResult({
    required this.transcription,
    required this.translation,
    required this.romanization,
    required this.wordConfidence,
    this.wordComparisons = const [],
    required this.pronunciationScore,
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
  final Function(String) onSendResponse;
  final VoidCallback onClose;
  final String targetLanguage;
  final List<POSMapping>? npcPosMappings; // Word analysis data

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
  });

  @override
  ConsumerState<NPCResponseModal> createState() => _NPCResponseModalState();
}

class _NPCResponseModalState extends ConsumerState<NPCResponseModal>
    with TickerProviderStateMixin {
  // Page and modal state management
  NPCResponseModalPage _currentPage = NPCResponseModalPage.translation;
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
  
  // Enhanced translation with word mappings and audio
  List<Map<String, String>> _translationWordMappings = [];
  String _translationAudioBase64 = '';
  
  // NPC message toggles
  bool _showNpcEnglishTranslation = false;
  bool _showNpcWordAnalysis = false;
  bool _showNpcAudioReplay = true; // Show by default since audio is available
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // DEBUG: Log modal initialization
    print('DEBUG: NPCResponseModal initialized');
    print('DEBUG: Initial NPC message: "${widget.npcMessage}"');
    print('DEBUG: Initial state - transcriptionResult: ${_transcriptionResult ?? 'null'}');
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
    super.dispose();
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
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: '/tmp/recording.wav',
      );

      if (mounted) {
        setState(() {
          _modalState = NPCResponseModalState.recording;
          _isRecording = true;
        });
        
        // Provide haptic feedback
        HapticFeedback.lightImpact();
        
        // Start waveform animation
        _startWaveformAnimation();
        _scaleController.forward();
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
      // DEBUG: Log entry and initial state
      print('DEBUG: _processAudio called with path: $audioPath');
      print('DEBUG: Current _translatedText: "$_translatedText"');
      print('DEBUG: Current modal state: $_modalState');
      
      // Get expected text from translation helper if available
      String expectedText = '';
      if (_translatedText.isNotEmpty) {
        expectedText = _translatedText;
        print('DEBUG: Using expected text for comparison: $_translatedText');
      }
      
      // Call our new transcribe-and-translate endpoint with expected text comparison
      print('DEBUG: About to call ApiService.transcribeAndTranslate');
      final result = await ApiService.transcribeAndTranslate(
        audioPath: audioPath,
        sourceLanguage: widget.targetLanguage,
        targetLanguage: 'en',
        expectedText: expectedText,
      );

      if (mounted && result != null) {
        // DEBUG: Log the entire API response to understand what's being returned
        print('DEBUG: Full API response: $result');
        print('DEBUG: transcription: ${result['transcription']}');
        print('DEBUG: translation: ${result['translation']}');
        print('DEBUG: romanization: ${result['romanization']}');
        print('DEBUG: Full word_confidence: ${result['word_confidence']}');
        print('DEBUG: Full word_comparisons: ${result['word_comparisons']}');
        
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
          pronunciationScore: (result['pronunciation_score'] ?? 0.0).toDouble(),
          expectedText: result['expected_text'] ?? '',
        );
        
        // DEBUG: Log the final transcription result
        print('DEBUG: Created TranscriptionResult:');
        print('  - transcription: "${_transcriptionResult!.transcription}"');
        print('  - wordConfidence count: ${_transcriptionResult!.wordConfidence.length}');
        print('  - words: ${_transcriptionResult!.wordConfidence.map((w) => w.word).join(", ")}');
        print('  - wordComparisons count: ${_transcriptionResult!.wordComparisons.length}');

        setState(() {
          _modalState = NPCResponseModalState.results;
        });

        // Provide success haptic feedback
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('Failed to process audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process audio: $e')),
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
      widget.onSendResponse(_transcriptionResult!.transcription);
      widget.onClose();
    }
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
  void _goToRecordingPage() {
    setState(() {
      _currentPage = NPCResponseModalPage.recording;
      _modalState = NPCResponseModalState.initial;
    });
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }

  void _goToTranslationPage() {
    setState(() {
      _currentPage = NPCResponseModalPage.translation;
      _modalState = NPCResponseModalState.initial;
    });
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }
  
  void _playNpcAudio() {
    // TODO: Implement NPC audio playback
    HapticFeedback.lightImpact();
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
    });

    try {
      final result = await ApiService.translateText(
        englishText: englishText,
        targetLanguage: widget.targetLanguage,
      );

      if (mounted && result != null) {
        setState(() {
          _translatedText = result['target_text'] ?? '';
          _romanizedText = result['romanized_text'] ?? '';
          _translationAudioBase64 = result['audio_base64'] ?? '';
          
          // Parse word mappings if available
          if (result['word_mappings'] != null) {
            _translationWordMappings = [];
            for (var mapping in result['word_mappings']) {
              _translationWordMappings.add({
                'english': mapping['translation']?.toString() ?? '',
                'target': mapping['target']?.toString() ?? '',
                'romanized': mapping['transliteration']?.toString() ?? '',
              });
            }
          } else {
            _translationWordMappings = [];
          }
          
          _isTranslating = false;
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
                child: SingleChildScrollView(
                  child: _currentPage == NPCResponseModalPage.translation
                      ? _buildTranslationPage()
                      : _buildRecordingPage(),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: AssetImage(widget.npcData.dialoguePortraitPath),
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.npcData.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getStateDescription(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
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
        return 'Analyzing your pronunciation...';
      case NPCResponseModalState.results:
        return 'Great! Review your score or try again';
      case NPCResponseModalState.practice:
        return 'Practice mode - no pressure!';
      case NPCResponseModalState.sending:
        return 'Sending your response to ${widget.npcData.name}...';
    }
  }


  // Translation helper page (Page 1)
  Widget _buildTranslationPage() {
    return Padding(
      padding: const EdgeInsets.all(12), // Reduced from 20
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Constrained NPC reference to prevent overflow
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: _buildNpcReferenceSection(),
          ),
          const SizedBox(height: 16), // Reduced from 20
          
          // Expandable translation helper
          _buildTranslationHelperSection(),
          const SizedBox(height: 12), // Reduced from 20
        ],
      ),
    );
  }

  // Recording and results page (Page 2)
  Widget _buildRecordingPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Conditional target/reference display
        if (_translatedText.isNotEmpty)
          _buildTranslationTargetSection()
        else
          _buildNpcReferenceSection(),
        
        const SizedBox(height: 20),
        
        // Recording interface and results
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildRecordingInterface(),
        ),
      ],
    );
  }

  // Helper method for NPC reference section
  Widget _buildNpcReferenceSection() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title on its own row
          Text(
            '🗣️ ${widget.npcData.name}\'s Message:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
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
            Container(
              padding: const EdgeInsets.all(10), // Reduced from 12
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                widget.npcMessageEnglish,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue[800],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
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
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
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
                tooltip: 'Play pronunciation',
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
              'Pronunciation: $_romanizedText',
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
          _buildMicrophoneButton()
        else if (_modalState == NPCResponseModalState.recording)
          _buildRecordingContent()
        else if (_modalState == NPCResponseModalState.processing)
          _buildProcessingContent()
        else if (_modalState == NPCResponseModalState.results)
          _buildResultsContent(),
      ],
    );
  }

  Widget _buildContent() {
    switch (_modalState) {
      case NPCResponseModalState.initial:
        return _buildInitialContent();
      case NPCResponseModalState.recording:
        return _buildRecordingContent();
      case NPCResponseModalState.processing:
        return _buildProcessingContent();
      case NPCResponseModalState.results:
        return _buildResultsContent();
      case NPCResponseModalState.practice:
        return _buildPracticeContent();
      case NPCResponseModalState.sending:
        return _buildSendingContent();
    }
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
              maxHeight: (_showNpcEnglishTranslation || _showNpcWordAnalysis) ? 300 : 150,
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
                  Container(
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
                ],
              ],
            ),
            ),
          ),
          const SizedBox(height: 20),
          // Translation Helper Section
          _buildTranslationHelper(),
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

  Widget _buildTranslationHelper() {
    return Card(
      margin: const EdgeInsets.all(0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _showTranslationHelper ? Colors.blue[300]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Compact toggle header
          Material(
            color: _showTranslationHelper ? Colors.blue[50] : Colors.grey[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: InkWell(
              onTap: _toggleTranslationHelper,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      size: 18,
                      color: _showTranslationHelper ? Colors.blue[700] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Need help? Tap to translate',
                        style: TextStyle(
                          color: _showTranslationHelper ? Colors.blue[800] : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      _showTranslationHelper ? Icons.expand_less : Icons.expand_more,
                      color: _showTranslationHelper ? Colors.blue[700] : Colors.grey[600],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Expandable content
          if (_showTranslationHelper)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50]?.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact input section
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _translationController,
                            decoration: const InputDecoration(
                              hintText: 'Type in English...',
                              hintStyle: TextStyle(fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _isTranslating ? null : _translateText,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: _isTranslating
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Go',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Compact translation results
                  if (_translatedText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildCompactTranslationResults(),
                  ],
                ],
              ),
            ),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Show translation reference if available
          if (_translatedText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[300]!, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reference Translation:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _translatedText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (_romanizedText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _romanizedText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  // Audio replay button
                  if (_translationAudioBase64.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _playTranslationAudio,
                        icon: const Icon(Icons.volume_up, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[700],
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
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
          const SizedBox(height: 20),
          // Stop button
          _buildMicrophoneButton(),
          const SizedBox(height: 15),
          Text(
            'Tap to stop recording',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
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
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Processing your speech...',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 10),
          Text(
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
    if (_transcriptionResult == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Condensed header with score and actions
          _buildCondensedHeader(),
          const SizedBox(height: 16),
          
          // Streamlined word display
          _buildStreamlinedWordDisplay(),
          const SizedBox(height: 16),
          
          // Contextual tips section
          _buildContextualTips(),
          const SizedBox(height: 16),
          
          // Inline action buttons for recording page
          if (_currentPage == NPCResponseModalPage.recording)
            _buildInlineActionButtons(),
        ],
      ),
    );
  }

  // Inline action buttons for recording page results
  Widget _buildInlineActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _playRecording,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[700],
              side: BorderSide(color: Colors.blue[300]!, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _retryRecording,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange[700],
              side: BorderSide(color: Colors.orange[300]!, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCondensedHeader() {
    final score = _transcriptionResult!.pronunciationScore;
    final percentage = (score * 100).round();
    
    Color scoreColor;
    if (score >= 0.7) {
      scoreColor = Colors.green;
    } else if (score >= 0.5) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Row(
      children: [
        // Score indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scoreColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreamlinedWordDisplay() {
    final words = _transcriptionResult!.wordComparisons.isNotEmpty
        ? _transcriptionResult!.wordComparisons
        : _transcriptionResult!.wordConfidence.map((wc) => WordComparisonData(
            word: wc.word,
            confidence: wc.confidence,
            expected: '',
            matchType: 'no_reference',
            similarity: wc.confidence,
            startTime: wc.startTime,
            endTime: wc.endTime,
          )).toList();

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
          Text(
            '📝 What you said:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          // Single line word display
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: words.map((word) {
              final percentage = (word.confidence * 100).round();
              Color dotColor;
              if (word.confidence >= 0.7) {
                dotColor = Colors.green;
              } else if (word.confidence >= 0.5) {
                dotColor = Colors.orange;
              } else {
                dotColor = Colors.red;
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    word.word,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Romanization line
          Text(
            words.map((w) => _getWordRomanization(w.word)).join('  '),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          // Expected vs Got for errors
          if (words.any((w) => w.expected.isNotEmpty && w.expected != w.word)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: words
                    .where((w) => w.expected.isNotEmpty && w.expected != w.word)
                    .map((w) => Row(
                          children: [
                            const Icon(Icons.warning, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Text(
                              'Expected: ${w.expected} → Got: ${w.word}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContextualTips() {
    final words = _transcriptionResult!.wordComparisons.isNotEmpty
        ? _transcriptionResult!.wordComparisons
        : _transcriptionResult!.wordConfidence.map((wc) => WordComparisonData(
            word: wc.word,
            confidence: wc.confidence,
            expected: '',
            matchType: 'no_reference',
            similarity: wc.confidence,
            startTime: wc.startTime,
            endTime: wc.endTime,
          )).toList();

    final tips = <String>[];
    
    for (final word in words) {
      String tip = '';
      final romanization = _getWordRomanization(word.word);
      
      if (word.confidence >= 0.8) {
        tip = '• ${word.word}: Excellent pronunciation! 🎯';
      } else if (word.confidence >= 0.6) {
        tip = '• ${word.word}: Good job! Audio quality could be better 📱';
      } else if (word.expected.isNotEmpty && word.expected != word.word) {
        tip = '• ${word.word}: Try "${_getWordRomanization(word.expected)}" sound instead of "$romanization" 🔄';
      } else if (word.confidence < 0.4) {
        tip = '• ${word.word}: Practice the "$romanization" sound more clearly 🗣️';
      } else {
        tip = '• ${word.word}: Keep practicing the "$romanization" pronunciation 💪';
      }
      
      if (tip.isNotEmpty) tips.add(tip);
    }

    if (tips.isEmpty) {
      return const SizedBox();
    }

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
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
              SizedBox(width: 6),
              Text(
                'Quick tips:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._generateSmartTips(words).map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[800],
                height: 1.3,
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  List<String> _generateSmartTips(List<WordComparisonData> words) {
    final tips = <String>[];
    
    // Categorize issues to provide consolidated advice
    final lowConfidenceWords = words.where((w) => w.confidence < 0.5).toList();
    final mediumConfidenceWords = words.where((w) => w.confidence >= 0.5 && w.confidence < 0.7).toList();
    final mismatchedWords = words.where((w) => w.expected.isNotEmpty && w.expected != w.word).toList();
    
    // Provide consolidated tips rather than per-word repetition
    if (mismatchedWords.isNotEmpty) {
      if (mismatchedWords.length == 1) {
        final word = mismatchedWords.first;
        tips.add('🔄 Try pronouncing "${word.expected}" instead of "${word.word}"');
      } else {
        tips.add('🔄 ${mismatchedWords.length} words need pronunciation correction');
      }
    }
    
    if (lowConfidenceWords.isNotEmpty) {
      if (lowConfidenceWords.length <= 2) {
        tips.add('🗣️ Speak more clearly: ${lowConfidenceWords.map((w) => w.word).join(", ")}');
      } else {
        tips.add('🗣️ Try speaking more slowly and clearly overall');
      }
    }
    
    if (mediumConfidenceWords.isNotEmpty && mediumConfidenceWords.length <= 3) {
      tips.add('💪 Almost there with: ${mediumConfidenceWords.map((w) => w.word).join(", ")}');
    }
    
    // Audio quality suggestion if many words are borderline
    final borderlineCount = words.where((w) => w.confidence >= 0.4 && w.confidence < 0.7).length;
    if (borderlineCount >= words.length * 0.6) {
      tips.add('📱 Check microphone position and reduce background noise');
    }
    
    // Positive reinforcement
    final goodWords = words.where((w) => w.confidence >= 0.8).toList();
    if (goodWords.isNotEmpty && goodWords.length >= words.length * 0.4) {
      tips.add('🎯 Great pronunciation overall! Keep it up');
    }
    
    return tips.take(3).toList(); // Limit to 3 most important tips
  }
  
  List<Widget> _buildFeedbackSections(List<WordComparisonData> goodWords, List<WordComparisonData> needsWorkWords, 
                                      List<WordComparisonData> errorWords, List<WordComparisonData> poorWords) {
    List<Widget> sections = [];
    
    // Only show sections that have content
    if (errorWords.isNotEmpty) {
      sections.add(_buildFeedbackSection(
        'Corrections needed:', 
        errorWords, 
        Colors.red[100]!, 
        Colors.red[700]!,
        Icons.error_outline,
        true // Show expected vs got
      ));
      sections.add(const SizedBox(height: 8));
    }
    
    if (poorWords.isNotEmpty) {
      sections.add(_buildFeedbackSection(
        'Needs practice:', 
        poorWords, 
        Colors.orange[100]!, 
        Colors.orange[700]!,
        Icons.volume_up,
        false
      ));
      sections.add(const SizedBox(height: 8));
    }
    
    if (needsWorkWords.isNotEmpty) {
      sections.add(_buildFeedbackSection(
        'Almost there:', 
        needsWorkWords, 
        Colors.yellow[100]!, 
        Colors.orange[600]!,
        Icons.trending_up,
        false
      ));
      sections.add(const SizedBox(height: 8));
    }
    
    if (goodWords.isNotEmpty) {
      sections.add(_buildFeedbackSection(
        'Well done:', 
        goodWords, 
        Colors.green[100]!, 
        Colors.green[700]!,
        Icons.check_circle_outline,
        false
      ));
    }
    
    return sections;
  }
  
  Widget _buildFeedbackSection(String title, List<WordComparisonData> words, Color bgColor, Color textColor, IconData icon, bool showExpected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: words.map((word) {
              final percentage = (word.confidence * 100).round();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    word.word,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (!showExpected) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                  if (showExpected && word.expected.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '→ ${word.expected}',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _sendToNPC,
        icon: const Icon(Icons.send, size: 18),
        label: Text('Send to ${widget.npcData.name}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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

  Widget _buildPronunciationScore() {
    final score = _transcriptionResult!.pronunciationScore;
    final percentage = (score * 100).round();
    
    Color scoreColor;
    String scoreLabel;
    
    if (score >= 0.9) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent!';
    } else if (score >= 0.7) {
      scoreColor = Colors.yellow.shade700;
      scoreLabel = 'Good!';
    } else if (score >= 0.5) {
      scoreColor = Colors.orange;
      scoreLabel = 'Keep practicing!';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Try again!';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor,
            ),
            child: Center(
              child: Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pronunciation Score',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  scoreLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionDisplay() {
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
          Text(
            'What you said:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10.0,
            runSpacing: 12.0,
            alignment: WrapAlignment.center,
            children: _transcriptionResult!.wordComparisons.isNotEmpty
                ? _transcriptionResult!.wordComparisons.map((wordComp) {
                    // Create WordConfidence object for compatibility with existing card
                    final wordConf = WordConfidence(
                      word: wordComp.word,
                      confidence: wordComp.confidence,
                      startTime: wordComp.startTime,
                      endTime: wordComp.endTime,
                      transliteration: '',  // Word comparison data doesn't include these fields
                      translation: '',
                    );
                    return _buildWordConfidenceCard(wordConf, expectedWord: wordComp.expected);
                  }).toList()
                : _transcriptionResult!.wordConfidence.map((wordConf) {
                    // Fallback to basic word confidence if no comparison data
                    return _buildWordConfidenceCard(wordConf);
                  }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWordConfidenceCard(WordConfidence wordConf, {String expectedWord = ""}) {
    // Use real transliteration and translation from backend
    final transliteration = wordConf.transliteration;
    final translation = wordConf.translation;
    
    // Get smart color and status based on confidence and expected vs actual comparison
    final colorAndStatus = _getWordColorAndStatus(wordConf.confidence, expectedWord, wordConf.word);
    final Color cardColor = colorAndStatus['color'];
    final String status = colorAndStatus['status'];
    final String matchType = colorAndStatus['matchType'];
    final String contextMessage = colorAndStatus['contextMessage'];
    final bool isAudioIssue = colorAndStatus['isAudioIssue'] ?? false;
    
    // Determine if we should show expected vs actual comparison
    final bool showComparison = expectedWord.isNotEmpty && expectedWord != wordConf.word;
    
    return Container(
      constraints: const BoxConstraints(minWidth: 95, maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardColor.withOpacity(0.8),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enhanced confidence badge with smart indicators
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(wordConf.confidence * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  matchType == "exact" ? Icons.check_circle :
                  matchType == "close" ? Icons.check_circle_outline :
                  matchType == "partial" ? Icons.help_outline :
                  matchType == "no_reference" ? Icons.mic :
                  Icons.cancel_outlined,
                  size: 13,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          // Expected vs Actual comparison (enhanced design)
          if (showComparison) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: matchType == "exact" ? Colors.blue.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: matchType == "exact" ? Colors.blue.shade200 : Colors.red.shade200, 
                  width: 1
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        matchType == "exact" ? Icons.check_circle : Icons.compare_arrows,
                        size: 12,
                        color: matchType == "exact" ? Colors.blue.shade600 : Colors.red.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        matchType == "exact" ? 'Perfect!' : 'Expected vs Got',
                        style: TextStyle(
                          fontSize: 9,
                          color: matchType == "exact" ? Colors.blue.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (matchType != "exact") ...[
                    const SizedBox(height: 3),
                    Text(
                      '$expectedWord → ${wordConf.word}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.red.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // Thai word (prominent display)
          Text(
            wordConf.word,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cardColor.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          
          if (transliteration.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              transliteration,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          if (translation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              translation,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 8),
          
          // Smart status with context message
          Column(
            children: [
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  color: cardColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (contextMessage.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAudioIssue) 
                      Icon(
                        Icons.mic_external_off,
                        size: 10,
                        color: Colors.amber.shade700,
                      ),
                    if (isAudioIssue) const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        contextMessage,
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  

  /// Smart color and status determination that distinguishes STT confidence from pronunciation quality
  Map<String, dynamic> _getWordColorAndStatus(double confidence, String expectedWord, String actualWord) {
    // Add debugging
    print('DEBUG: Smart analysis - confidence: ${(confidence * 100).round()}%, expected: "$expectedWord", actual: "$actualWord"');
    
    // Calculate similarity between expected and actual words
    double similarity = 1.0;
    String matchType = "no_reference";
    
    if (expectedWord.isNotEmpty && actualWord.isNotEmpty) {
      // Enhanced similarity calculation
      if (expectedWord == actualWord) {
        similarity = 1.0;
        matchType = "exact";
      } else {
        // Simple similarity based on common characters
        final expected = expectedWord.toLowerCase();
        final actual = actualWord.toLowerCase();
        final maxLength = [expected.length, actual.length].reduce((a, b) => a > b ? a : b);
        int commonChars = 0;
        
        for (int i = 0; i < [expected.length, actual.length].reduce((a, b) => a < b ? a : b); i++) {
          if (i < expected.length && i < actual.length && expected[i] == actual[i]) {
            commonChars++;
          }
        }
        
        similarity = commonChars / maxLength;
        
        if (similarity >= 0.8) {
          matchType = "close";
        } else if (similarity >= 0.5) {
          matchType = "partial";
        } else {
          matchType = "mismatch";
        }
      }
    } else if (expectedWord.isEmpty) {
      matchType = "no_reference";
      similarity = confidence;
    }

    // SMART COLOR LOGIC: Distinguish technical issues from pronunciation errors
    Color color;
    String status;
    String contextMessage = "";
    
    if (expectedWord.isNotEmpty) {
      // CASE 1: Perfect word match - reward success regardless of audio quality
      if (matchType == "exact") {
        if (confidence >= 0.7) {
          color = Colors.green;
          status = "Perfect Match";
          contextMessage = "Excellent pronunciation!";
        } else if (confidence >= 0.5) {
          color = Colors.blue;
          status = "Good Match";
          contextMessage = "Correct word - audio quality could be better";
        } else if (confidence >= 0.3) {
          color = Colors.amber.shade600;
          status = "Match Despite Poor Audio";
          contextMessage = "Right word! Check microphone setup";
        } else {
          color = Colors.orange.shade700;
          status = "Match But Check Audio";
          contextMessage = "Correct pronunciation - improve audio quality";
        }
      }
      // CASE 2: Close pronunciation match
      else if (matchType == "close") {
        if (confidence >= 0.6) {
          color = Colors.lightGreen;
          status = "Very Close";
          contextMessage = "Almost perfect pronunciation";
        } else {
          color = Colors.amber.shade600;
          status = "Close Attempt";
          contextMessage = "Good try - practice a bit more";
        }
      }
      // CASE 3: Partial match - needs pronunciation work
      else if (matchType == "partial") {
        color = Colors.orange.shade600;
        status = "Needs Practice";
        contextMessage = "Keep practicing this word";
      }
      // CASE 4: Poor match - clear pronunciation error
      else {
        color = Colors.red;
        status = "Pronunciation Error";
        contextMessage = "Try pronouncing this word again";
      }
    } else {
      // No expected text - use confidence-based coloring (STT quality)
      if (confidence >= 0.9) {
        color = Colors.green;
        status = "Excellent";
        contextMessage = "Clear speech recognition";
      } else if (confidence >= 0.7) {
        color = Colors.lightGreen;
        status = "Good";
        contextMessage = "Good speech quality";
      } else if (confidence >= 0.5) {
        color = Colors.orange.shade600;
        status = "Fair";
        contextMessage = "Moderate speech quality";
      } else if (confidence >= 0.3) {
        color = Colors.orange.shade800;
        status = "Poor Quality";
        contextMessage = "Check audio setup";
      } else {
        color = Colors.red;
        status = "Very Poor";
        contextMessage = "Audio quality issue";
      }
    }
    
    print('DEBUG: Smart result - color: $color, status: $status, context: $contextMessage');
    
    return {
      'color': color,
      'status': status,
      'matchType': matchType,
      'similarity': similarity,
      'contextMessage': contextMessage,
      'isAudioIssue': matchType == "exact" && confidence < 0.7, // Flag audio vs pronunciation issues
    };
  }

  Widget _buildFullTranslationSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate,
                size: 18,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Text(
                'Full Translation',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // English Translation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Text(
              _transcriptionResult!.translation.isNotEmpty 
                  ? _transcriptionResult!.translation
                  : 'Translation not available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.blue[800],
                fontSize: 16,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Pronunciation Guide
          if (_transcriptionResult!.romanization.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  size: 16,
                  color: Colors.purple[600],
                ),
                const SizedBox(width: 6),
                Text(
                  'Pronunciation Guide:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.purple[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[100]!),
              ),
              child: Text(
                _transcriptionResult!.romanization,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.purple[800],
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPracticeContent() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 64, color: Colors.blue),
          SizedBox(height: 20),
          Text(
            'Practice Mode',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Practice as much as you want without affecting your conversation progress.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSendingContent() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Sending to NPC...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: _buildActionButtons(),
    );
  }

  Widget _buildActionButtons() {
    if (_currentPage == NPCResponseModalPage.translation) {
      // Page 1: Translation helper page
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _goToRecordingPage,
          icon: const Icon(Icons.mic),
          label: const Text('Record Response'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
        ),
      );
    } else {
      // Page 2: Recording page - different buttons based on modal state
      switch (_modalState) {
        case NPCResponseModalState.initial:
        case NPCResponseModalState.recording:
        case NPCResponseModalState.processing:
          // Show back button only
          return OutlinedButton.icon(
            onPressed: _goToTranslationPage,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        
        case NPCResponseModalState.results:
          // Show back button and send to NPC
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goToTranslationPage,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendToNPC,
                  icon: const Icon(Icons.send),
                  label: Text('Send to ${widget.npcData.name}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          );
        
        case NPCResponseModalState.practice:
        case NPCResponseModalState.sending:
          return const SizedBox();
      }
    }
  }
  
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
              enabled: true,
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
  
  Widget _buildCompactTranslationResults() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with audio button
          Row(
            children: [
              const Icon(Icons.translate, size: 14, color: Colors.teal),
              const SizedBox(width: 4),
              const Text(
                'Translation:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal,
                ),
              ),
              const Spacer(),
              if (_translationAudioBase64.isNotEmpty)
                InkWell(
                  onTap: _playTranslationAudio,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.volume_up, size: 16, color: Colors.teal),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Compact word mapping
          if (_translationWordMappings.isNotEmpty)
            _buildCompactWordMappings()
          else
            Text(
              _translatedText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildCompactWordMappings() {
    // Group words into rows for better space utilization
    final chunks = <List<Map<String, String>>>[];
    final chunkSize = 3; // 3 words per row
    
    for (int i = 0; i < _translationWordMappings.length; i += chunkSize) {
      chunks.add(_translationWordMappings.sublist(
        i, 
        math.min(i + chunkSize, _translationWordMappings.length)
      ));
    }
    
    return Column(
      children: chunks.map((chunk) => 
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: chunk.map((mapping) => 
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.teal[200]!, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mapping['target'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        mapping['romanized'] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.teal[600],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        mapping['english'] ?? '',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
            ).toList(),
          ),
        )
      ).toList(),
    );
  }
  
  // Keep the original method for backward compatibility
  Widget _buildTranslationResults() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal[300]!),
      ),
      child: Column(
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
                  tooltip: 'Play pronunciation',
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Word mapping cards
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
                'Pronunciation: $_romanizedText',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.teal[700],
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
  
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
        constraints: const BoxConstraints(maxHeight: 200),
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
      return Text(
        widget.npcMessage,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      );
    }
  }
}