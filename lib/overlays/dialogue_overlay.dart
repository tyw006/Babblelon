import 'dart:async'; // Added for Timer
import 'dart:math' as math; // Added for math.min
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // Added for File
import 'package:http/http.dart' as http; // Added for http
import 'dart:convert'; // Added for json encoding/decoding
import 'package:flutter/services.dart'; // Added for DefaultAssetBundle
import 'package:flutter/scheduler.dart'; // Added for SchedulerBinding
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import 'package:lottie/lottie.dart';

import '../game/babblelon_game.dart';
import '../models/npc_data.dart'; // Using the new unified NPC data model
import '../models/local_storage_models.dart'; // For MasteredPhrase
import '../providers/game_providers.dart'; // Ensure this import is present
import '../services/isar_service.dart'; // For database operations
import '../widgets/dialogue_ui.dart';
import '../widgets/character_tracing_widget.dart';
import '../widgets/npc_response_modal.dart';
import 'dialogue_overlay/dialogue_models.dart';
import '../services/posthog_service.dart';
import '../services/tutorial_service.dart';

// --- Sanitization Helper ---
String _sanitizeString(String text) {
  // Re-encoding and decoding with allowMalformed: true replaces invalid sequences
  // with the Unicode replacement character (U+FFFD), preventing rendering errors.
  return utf8.decode(utf8.encode(text), allowMalformed: true);
}
// --- End Sanitization Helper ---

// --- Recording State Enum ---
enum RecordingState {
  idle,
  recording,
  reviewing,
}
// --- End Recording State Enum ---


// --- POS Color Mapping ---
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
// --- End POS Color Mapping ---

// --- Initial NPC Greeting Model ---
@immutable
class InitialNPCGreeting {
  final String responseTarget;
  final String responseAudioPath;
  final String responseEnglish;
  final String responseTranslit;
  final List<POSMapping> responseMapping;

  const InitialNPCGreeting({
    required this.responseTarget,
    required this.responseAudioPath,
    required this.responseEnglish,
    required this.responseTranslit,
    required this.responseMapping,
  });

  factory InitialNPCGreeting.fromJson(Map<String, dynamic> json) {
    var mappingsList = json['response_mapping'] as List?;
    List<POSMapping> mappings = mappingsList != null
        ? mappingsList.map((i) => POSMapping.fromJson(i as Map<String, dynamic>)).toList()
        : [];

    return InitialNPCGreeting(
      responseTarget: _sanitizeString(json['response_target'] as String? ?? ''),
      responseAudioPath: json['response_audio_path'] as String,
      responseEnglish: _sanitizeString(json['response_english'] as String? ?? ''), 
      responseTranslit: _sanitizeString(json['response_translit'] as String? ?? ''),
      responseMapping: mappings,
    );
  }
}
// --- End Initial NPC Greeting Model ---

// --- Dialogue Entry Model ---
@immutable
class DialogueEntry {
  final String id; // Unique ID for the entry
  final String text;
  final String englishText; // To store the full English translation
  final String speaker;
  final String? audioPath; // For player's recorded audio
  final Uint8List? audioBytes; // For NPC's TTS audio
  final bool isNpc;
  final List<POSMapping>? posMappings; // Added for POS tagging
  final String? playerTranscriptionForHistory; // Store player's own transcription here for history dialog

  // Constructor modified to accept an optional customId
  DialogueEntry({
    String? customId, // Use a different name to avoid conflict with field 'id'
    required this.text,
    required this.englishText,
    required this.speaker,
    this.audioPath,
    this.audioBytes,
    required this.isNpc,
    this.posMappings,
    this.playerTranscriptionForHistory,
  }) : id = customId ?? _generateId(); // Assign or generate

  // Helper to create a unique ID - made slightly more robust
  static String _generateId() => "${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(99999)}";

  // Factory constructors for convenience
  factory DialogueEntry.player(String transcribedText, String audioPath, {List<POSMapping>? inputMappings, String? englishTranslation}) {
    return DialogueEntry(
      // customId will be null, so _generateId() is used by the main constructor
      text: transcribedText, // Player's own transcribed text
      englishText: englishTranslation ?? transcribedText,
      speaker: 'Player',
      audioPath: audioPath,
      isNpc: false,
      posMappings: inputMappings, // Now player entries can have POS mappings from input_mapping
      playerTranscriptionForHistory: transcribedText, // Explicitly set for history
    );
  }

  factory DialogueEntry.npc({
    String? id, // Allow factory to take an ID
    required String text,
    required String englishText,
    String? audioPath, 
    Uint8List? audioBytes, 
    required String npcName, 
    List<POSMapping>? posMappings
  }) {
    return DialogueEntry(
      customId: id, // Pass it to the main constructor
      text: text,
      englishText: englishText,
      speaker: npcName, // Use dynamic NPC name
      audioPath: audioPath,
      audioBytes: audioBytes,
      isNpc: true,
      posMappings: posMappings, // Added
      playerTranscriptionForHistory: null, // Not applicable for NPC entries
    );
  }
}
// --- End Dialogue Entry Model ---

// Provider for the FULL conversation history (Player and NPC turns) for a specific NPC
final fullConversationHistoryProvider = StateProvider.family<List<DialogueEntry>, String>((ref, npcId) => []);

// Provider for the CURRENT NPC entry being displayed/animated in the main dialogue box
final currentNpcDisplayEntryProvider = StateProvider<DialogueEntry?>((ref) => null);

// Provider for the audio player used for replaying dialogue lines
final dialogueReplayPlayerProvider = Provider<just_audio.AudioPlayer>((ref) => just_audio.AudioPlayer());

// --- Language Name Helper ---
String getLanguageName(String code) {
  switch (code.toLowerCase()) {
    case 'th':
      return 'Thai';
    case 'vi':
      return 'Vietnamese';
    case 'zh':
      return 'Chinese';
    case 'ja':
      return 'Japanese';
    case 'ko':
      return 'Korean';
    default:
      return code.toUpperCase();
  }
}

// Convert to ConsumerStatefulWidget to access ref
class DialogueOverlay extends ConsumerStatefulWidget {
  final BabblelonGame game;
  final String npcId; // NPC ID is now passed in

  const DialogueOverlay({
    super.key, 
    required this.game,
    required this.npcId, // Make npcId required
  });

  @override
  ConsumerState<DialogueOverlay> createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends ConsumerState<DialogueOverlay> with TickerProviderStateMixin {
  final ScrollController _mainDialogueScrollController = ScrollController();
  final ScrollController _historyDialogScrollController = ScrollController(); // For history dialog
  final ScrollController _wordTracingScrollController = ScrollController(); // For horizontal word tracing navigation
  bool _showScrollArrow = true; // Show/hide scroll indicator arrow
  
  // --- Recording State ---
  RecordingState _recordingState = RecordingState.idle;
  String? _lastRecordingPath;
  final just_audio.AudioPlayer _reviewPlayer = just_audio.AudioPlayer();
  // We keep _isRecording for now to avoid breaking existing animation logic that relies on it.
  // It will be kept in sync with _recordingState.
  bool _isRecording = false;

  // --- State for Translation Dialog ---
  final TextEditingController _translationEnglishController = TextEditingController();
  final TextEditingController _customItemController = TextEditingController();
  
  // Custom item data notifier
  final ValueNotifier<Map<String, dynamic>?> _customItemDataNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<List<Map<String, String>>> _translationMappingsNotifier = ValueNotifier<List<Map<String, String>>>([]);
  final ValueNotifier<String> _translationAudioNotifier = ValueNotifier<String>("");
  final ValueNotifier<bool> _translationIsLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _translationErrorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _customItemIsLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _translationDialogTitleNotifier = ValueNotifier<String>('Language Tools'); // Default title
  final ValueNotifier<bool> _isTranscribing = ValueNotifier<bool>(false);
  
  // Category-based vocabulary selection state
  String? _selectedCategory;
  Map<String, dynamic>? _selectedVocabularyItem;
  Map<String, List<Map<String, dynamic>>> _categorizedItems = {};
  bool _vocabularyDataLoaded = false;
  Future<void>? _vocabularyLoadingFuture;

  // State for the new practice recording feature
  final AudioRecorder _practiceAudioRecorder = AudioRecorder();
  final ValueNotifier<RecordingState> _practiceRecordingState = ValueNotifier<RecordingState>(RecordingState.idle);
  final ValueNotifier<String?> _lastPracticeRecordingPath = ValueNotifier<String?>(null);
  final just_audio.AudioPlayer _practiceReviewPlayer = just_audio.AudioPlayer();

  // --- ML Kit Digital Ink Recognition State ---
  late mlkit.DigitalInkRecognizer _digitalInkRecognizer;
  late mlkit.DigitalInkRecognizerModelManager _modelManager;
  final mlkit.Ink _ink = mlkit.Ink();
  mlkit.Stroke? _currentStroke;
  List<mlkit.StrokePoint> _currentStrokePoints = []; // For real-time preview
  String? _targetCharacter;
  String _lastRecognitionResult = '';
  
  // --- Stroke Order Validation and Mistake Tracking ---
  List<List<mlkit.StrokePoint>> _completedStrokes = [];
  Map<String, int> _characterMistakes = {};
  List<String> _strokeOrderHints = [];
  bool _isAnalyzingStrokes = false;
  int _currentStrokeCount = 0;
  double _strokeSpeedThreshold = 50.0; // pixels per second
  double _strokeSmoothnessTolerance = 10.0; // deviation tolerance
  DateTime? _strokeStartTime;
  List<double> _strokeSpeeds = [];
  List<double> _strokeLengths = [];
  
  // Multi-character tracing state
  List<Map<String, dynamic>> _currentWordMapping = [];
  int _currentCharacterIndex = 0;
  PageController _characterPageController = PageController();
  Map<int, bool> _characterCompletionStatus = {};
  Map<int, String> _characterRecognitionResults = {};
  Map<String, Map<String, dynamic>> _characterAnalysisCache = {}; // Cache for PyThaiNLP analysis
  
  // Simple test drawing state (Flutter docs pattern)
  
  bool _isModelDownloaded = false;

  // --- Audio Recording State ---
  late final AudioRecorder _audioRecorder;
  late final just_audio.AudioPlayer _replayPlayer;

  // --- Animation State ---
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  late final AnimationController _giftIconAnimationController;
  // --- End Animation State ---

  Timer? _activeTextStreamTimer;
  String _currentlyAnimatingEntryId = "";
  String _displayedTextForAnimation = "";
  int _currentCharIndexForAnimation = 0;
  final Map<String, String> _fullyAnimatedMainNpcTexts = {};

  // --- Conversation tracking ---
  late final DateTime _conversationStartTime; 

  bool _isProcessingBackend = false;

  InitialNPCGreeting? _initialGreetingData;
  late NpcData _npcData; // Store the current NPC's data

  @override
  void initState() {
    super.initState();
    _preRequestMicPermission();
    _audioRecorder = AudioRecorder();
    _replayPlayer = ref.read(dialogueReplayPlayerProvider);

    // Look up the NPC data using the widget's npcId
    _npcData = npcDataMap[widget.npcId]!;

    // Initialize conversation tracking
    _conversationStartTime = DateTime.now();

    // Show first dialogue session tutorial only on the very first NPC dialogue encounter
    // The greeting will be loaded separately by the existing addPostFrameCallback below

    // Track conversation start
    PostHogService.trackNPCConversation(
      npcName: widget.npcId,
      event: 'start',
      additionalProperties: {
        'npc_display_name': _npcData?.name ?? 'Unknown',
      },
    );

    // --- ML Kit Initialization ---
    _initializeMLKit();

    // --- Scroll Listener for Arrow Indicator ---
    _wordTracingScrollController.addListener(_onScrollChanged);

    // --- Animation Initialization ---
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
    _giftIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    // --- End Animation Initialization ---

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check if we should show the first dialogue tutorial
      final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
      final hasEncounteredNpc = ref.read(firstNpcDialogueEncounteredProvider);
      
      // Only show tutorial if this is the first NPC ever and tutorial hasn't been completed
      if (!hasEncounteredNpc && !tutorialProgressNotifier.isStepCompleted('first_dialogue_session')) {
        // Mark that we've now encountered our first NPC
        ref.read(firstNpcDialogueEncounteredProvider.notifier).state = true;
        
        final tutorialManager = TutorialManager(
          context: context,
          ref: ref,
          npcId: widget.npcId,
        );
        
        // Show first dialogue session tutorial and wait for it to complete
        await tutorialManager.startTutorial(TutorialTrigger.firstDialogueSession);
      }
      
      // Now load the initial greeting data (after tutorial if shown)
      await _loadInitialGreetingData();

      final history = ref.read(fullConversationHistoryProvider(widget.npcId));
      final currentNpcDisplayNotifier = ref.read(currentNpcDisplayEntryProvider.notifier);
      final fullHistoryNotifier = ref.read(fullConversationHistoryProvider(widget.npcId).notifier);

      if (_initialGreetingData == null) {
        print("Error: ${_npcData.name}'s initial greeting data could not be loaded.");
        final errorEntry = DialogueEntry.npc(text: "ขออภัยค่า เกิดข้อผิดพลาดในการโหลดข้อมูล", englishText: "Error loading greeting.", npcName: _npcData.name);
        currentNpcDisplayNotifier.state = errorEntry;
        if (history.isEmpty) {
          fullHistoryNotifier.state = [errorEntry];
        }
        return;
      }
      
      if (history.isEmpty) {
        // First-time interaction: Animate the initial greeting.
        final placeholderForAnimation = DialogueEntry.npc(
          id: 'greeting_${widget.npcId}', // Use a predictable ID
          text: '',
          englishText: '',
          npcName: _npcData.name,
          posMappings: _initialGreetingData!.responseMapping, // Use the actual POS mappings from JSON
        );
        // Debug: Log POS mappings being set in placeholder
        print("DEBUG: Created placeholder with ${placeholderForAnimation.posMappings?.length ?? 0} POS mappings");
        // ONLY set the current display entry. Do NOT add the placeholder to the full history yet.
        currentNpcDisplayNotifier.state = placeholderForAnimation;
        
        _startNpcTextAnimation(
          idForAnimation: placeholderForAnimation.id,
          speakerName: _npcData.name,
          fullText: _initialGreetingData!.responseTarget, 
          englishText: _initialGreetingData!.responseEnglish,
          audioPathToPlayWhenDone: _initialGreetingData!.responseAudioPath,
          posMappings: _initialGreetingData!.responseMapping,
          // This callback now adds the COMPLETED entry to the history for the first time.
          onAnimationComplete: (finalAnimatedEntry) {
            fullHistoryNotifier.update((history) => [...history, finalAnimatedEntry]);
          }
        );
      } else {
        // Returning to an existing conversation, restore the last state.
        final lastEntry = history.last;
        currentNpcDisplayNotifier.state = lastEntry;
        if (lastEntry.isNpc) {
          // Ensure the text is fully displayed and not in an intermediate animation state
          _fullyAnimatedMainNpcTexts[lastEntry.id] = lastEntry.text;
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mainDialogueScrollController.hasClients) {
        _scrollToBottom(_mainDialogueScrollController);
      }
    });
  }

  Future<void> _preRequestMicPermission() async {
    await Permission.microphone.request();
  }

  Future<void> _loadInitialGreetingData() async {
    final npcId = widget.npcId;
    // Load the initial dialogue data from JSON
    final jsonString = await rootBundle.loadString('assets/data/npc_initial_dialogues.json');
    final Map<String, dynamic> allGreetings = json.decode(jsonString);
    final greetingData = allGreetings[npcId];

    if (greetingData != null) {
      _initialGreetingData = InitialNPCGreeting.fromJson(greetingData);
      // Debug: Log POS mappings count from initial dialogue JSON
      print("DEBUG: Loaded ${_initialGreetingData?.responseMapping?.length ?? 0} POS mappings from initial dialogue JSON for $npcId");
      if (_initialGreetingData?.responseMapping?.isNotEmpty == true) {
        print("DEBUG: First POS mapping - word: '${_initialGreetingData!.responseMapping.first.wordTarget}', pos: '${_initialGreetingData!.responseMapping.first.pos}'");
      }
    } else {
      print("Error: No initial greeting data found for NPC: $npcId");
      _initialGreetingData = null; // Ensure it's null if not found
    }
  }

  void _scrollToBottom(ScrollController controller) {
    if (controller.hasClients) {
      Future.delayed(Duration(milliseconds: 50), () {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Calculate conversation duration in seconds
  int _getConversationDuration() {
    return DateTime.now().difference(_conversationStartTime).inSeconds;
  }

  @override
  void dispose() {
    // Track conversation end
    PostHogService.trackNPCConversation(
      npcName: widget.npcId,
      event: 'end',
      additionalProperties: {
        'conversation_duration_seconds': _getConversationDuration(),
      },
    );

    _replayPlayer.stop(); // Stop any playing audio on exit
    _audioRecorder.dispose();
    _animationController?.dispose();
    _giftIconAnimationController.dispose();
    _activeTextStreamTimer?.cancel();
    _mainDialogueScrollController.dispose();
    _historyDialogScrollController.dispose();
    _wordTracingScrollController.dispose();
    
    // Dispose review player
    _reviewPlayer.dispose();

    // Dispose translation dialog state
    _translationEnglishController.dispose();
    _translationMappingsNotifier.dispose();
    _translationAudioNotifier.dispose();
    _translationIsLoadingNotifier.dispose();
    _translationErrorNotifier.dispose();
    _customItemIsLoadingNotifier.dispose();
    _translationDialogTitleNotifier.dispose();
    
    // Dispose practice recording state
    _practiceAudioRecorder.dispose();
    _practiceRecordingState.dispose();
    _lastPracticeRecordingPath.dispose();
    _practiceReviewPlayer.dispose();

    super.dispose();
  }

  void _onScrollChanged() {
    // Check if user has scrolled to the end
    if (_wordTracingScrollController.hasClients) {
      final position = _wordTracingScrollController.position;
      final isAtEnd = position.pixels >= position.maxScrollExtent - 10; // 10px threshold
      
      setState(() {
        _showScrollArrow = !isAtEnd;
      });
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print("Microphone permission denied");
      // Optionally, show a dialog to the user explaining why you need the permission.
      return;
    }

    // Check if this is the first time using voice interaction and show tutorial
    final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
    if (!tutorialProgressNotifier.isStepCompleted('voice_setup_guide') && 
        !tutorialProgressNotifier.isStepCompleted('pronunciation_confidence_guide')) {
      // Show voice interaction tutorials for first-time users
      final tutorialManager = TutorialManager(
        context: context,
        ref: ref,
        npcId: widget.npcId,
      );
      
      // Start both voice-related tutorials
      await tutorialManager.startTutorial(TutorialTrigger.firstVoiceInteraction);
    }

    // Track recording start
    PostHogService.trackAudioInteraction(
      service: 'recording',
      event: 'start',
      additionalProperties: {
        'npc_name': widget.npcId,
      },
    );

    // Clean up previous recording if user decides to re-record
    if (_lastRecordingPath != null) {
      final file = File(_lastRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _lastRecordingPath = null;
    }

    setState(() {
      _recordingState = RecordingState.recording;
      _isRecording = true; // Sync for animation
    });
    _animationController?.repeat(reverse: true);

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/c_input_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Add the path to the provider to be cleaned up later
    ref.read(tempFilePathsProvider.notifier).update((state) => [...state, path]);

    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // Optimal for STT APIs
          numChannels: 1,     // Mono
        ), 
        path: path
      );
      print("Recording started at path: $path");
    } catch (e) {
      print("Error starting recording: $e");
      setState(() {
        _recordingState = RecordingState.idle;
        _isRecording = false; // Sync for animation
      });
      _animationController?.stop();
    }
  }

  Future<void> _stopRecordingAndReview() async {
    if (_recordingState != RecordingState.recording) return;

    _animationController?.stop();

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        print("Recording stopped for review, file at: $path");
        
        // Track recording stop
        PostHogService.trackAudioInteraction(
          service: 'recording',
          event: 'stop',
          success: true,
          additionalProperties: {
            'npc_name': widget.npcId,
            'has_audio_file': true,
          },
        );

        setState(() {
          _lastRecordingPath = path;
          _recordingState = RecordingState.reviewing;
          _isRecording = false; // Sync for animation
        });
      } else {
        print("Error: Recording path is null after stopping.");
        
        // Track recording failure
        PostHogService.trackAudioInteraction(
          service: 'recording',
          event: 'stop',
          success: false,
          error: 'Recording path is null',
          additionalProperties: {
            'npc_name': widget.npcId,
          },
        );

        setState(() {
          _recordingState = RecordingState.idle;
          _isRecording = false; // Sync for animation
        });
      }
    } catch (e) {
      print("Error stopping recording: $e");
      
      // Track recording error
      PostHogService.trackAudioInteraction(
        service: 'recording',
        event: 'stop',
        success: false,
        error: e.toString(),
        additionalProperties: {
          'npc_name': widget.npcId,
        },
      );

      setState(() {
        _recordingState = RecordingState.idle;
        _isRecording = false; // Sync for animation
      });
    }
  }

  // --- New functions for review mode ---
  Future<void> _playLastRecording() async {
    if (_lastRecordingPath == null) return;
    try {
      await _reviewPlayer.stop();
      await _reviewPlayer.setAudioSource(just_audio.AudioSource.uri(Uri.file(_lastRecordingPath!)));
      await _reviewPlayer.play();
    } catch (e) {
      print("Error playing review audio: $e");
    }
  }

  void _reRecord() {
    // Simply go back to the recording state. _startRecording will handle cleanup.
    _startRecording();
  }

  void _sendApprovedRecording() {
    if (_lastRecordingPath != null) {
      // Track recording approval
      PostHogService.trackAudioInteraction(
        service: 'recording',
        event: 'approved',
        success: true,
        additionalProperties: {
          'npc_name': widget.npcId,
        },
      );

      // First transcribe the audio to show user response, then send to NPC
      _transcribeAndSendRecording(_lastRecordingPath!);
      setState(() {
        _recordingState = RecordingState.idle;
        _lastRecordingPath = null;
      });
    }
  }

  Future<void> _transcribeAndSendRecording(String audioPath) async {
    print("Transcribing recorded audio before sending to NPC...");
    setState(() { _isProcessingBackend = true; });

    final File audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      print("Error: Audio file does not exist at path: $audioPath");
      setState(() { _isProcessingBackend = false; });
      return;
    }

    try {
      // Transcribe audio using the same endpoint as modal
      var uri = Uri.parse('http://127.0.0.1:8000/transcribe-and-translate/');
      var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('audio_file', audioFile.path))
        ..fields['source_language'] = 'th'
        ..fields['target_language'] = 'en';

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final String transcription = result['transcription'] ?? '';
        final String translation = result['translation'] ?? '';
        
        if (transcription.isNotEmpty) {
          // Create unique audio file copy for conversation history to prevent audio conflicts
          String? uniqueDirectAudioPath;
          try {
            final tempDir = await getTemporaryDirectory();
            final entryId = DialogueEntry._generateId();
            uniqueDirectAudioPath = '${tempDir.path}/player_direct_${entryId}.wav';
            
            // Copy the original audio file to the unique conversation-specific path
            final originalFile = File(audioPath);
            if (await originalFile.exists()) {
              await originalFile.copy(uniqueDirectAudioPath);
              print("Created unique direct audio for history: $uniqueDirectAudioPath");
              
              // Add to temp files for cleanup on level exit
              ref.read(tempFilePathsProvider.notifier).update((state) => [...state, uniqueDirectAudioPath!]);
            } else {
              print("Original direct audio file not found: $audioPath");
              uniqueDirectAudioPath = audioPath; // Fall back to original if copy fails
            }
          } catch (e) {
            print("Error creating unique direct audio file: $e");
            uniqueDirectAudioPath = audioPath; // Fall back to original if copy fails
          }

          // Create and display user response entry with unique audio path
          final userEntry = DialogueEntry.player(transcription, uniqueDirectAudioPath!, englishTranslation: translation.isNotEmpty ? translation : null);
          
          // Add to conversation history for display
          final fullHistoryNotifier = ref.read(fullConversationHistoryProvider(widget.npcId).notifier);
          fullHistoryNotifier.update((history) => [...history, userEntry]);
          
          print("User transcription: '$transcription'");
          
          // Now send the transcription to NPC (same as modal flow)
          // Note: Direct recording flow already created player entry with audio path,
          // so we don't need to pass it again here
          _sendTranscriptionToNPC(transcription);
        } else {
          print("Empty transcription received");
          setState(() { _isProcessingBackend = false; });
        }
      } else {
        print("Transcription failed with status: ${response.statusCode}");
        setState(() { _isProcessingBackend = false; });
      }
    } catch (e, stackTrace) {
      print("Exception during transcription: $e\\n$stackTrace");
      setState(() { _isProcessingBackend = false; });
    }
  }
  // --- End new functions ---

  Future<void> _sendAudioToBackend(String audioPath) async {
    print("Mic button action triggered. Sending audio to new endpoint.");
    setState(() { _isProcessingBackend = true; });

    final startTime = DateTime.now();

    final File audioFileToSend = File(audioPath);

    if (!await audioFileToSend.exists()) {
        print("Error: Recorded audio file does not exist at path: $audioPath");
        
        // Track STT failure
        PostHogService.trackAudioInteraction(
          service: 'stt',
          event: 'request',
          success: false,
          error: 'Audio file does not exist',
          additionalProperties: {
            'npc_name': widget.npcId,
          },
        );

        setState(() { _isProcessingBackend = false; });
        return;
    }

    try {
      print("Recorded audio prepared: ${audioFileToSend.path}. Sending to backend.");
      
      // --- Construct previous_conversation_history for the backend ---
      final currentFullHistory = ref.read(fullConversationHistoryProvider(widget.npcId));
      List<String> historyLinesForBackend = [];
      for (var entry in currentFullHistory) {
          // For player entries, use their stored transcription.
          // For NPC entries, use their main text.
          String textForHistory = entry.isNpc ? entry.text : (entry.playerTranscriptionForHistory ?? entry.text);
          if (_fullyAnimatedMainNpcTexts.containsKey(entry.id) && entry.isNpc) {
            textForHistory = _fullyAnimatedMainNpcTexts[entry.id]!; // Use fully animated text for NPC if available
          }
          historyLinesForBackend.add("${entry.speaker}: $textForHistory");
      }
      String previousHistoryPayload = historyLinesForBackend.join("\\n");
      // --- End history construction ---

      final charmLevelForRequest = ref.read(currentCharmLevelProvider(widget.npcId)); // Read from provider

      var uri = Uri.parse('http://127.0.0.1:8000/generate-npc-response/');
    var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('audio_file', audioFileToSend.path))
        ..fields['npc_id'] = _npcData.id
        ..fields['npc_name'] = _npcData.name
        ..fields['charm_level'] = charmLevelForRequest.toString() // Use provider value
        ..fields['previous_conversation_history'] = previousHistoryPayload
        ..fields['user_id'] = PostHogService.userId ?? 'unknown_user'
        ..fields['session_id'] = PostHogService.sessionId ?? 'unknown_session';
      
      print("Sending audio and data to /generate-npc-response/...");
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Track successful STT request
        final processingTimeMs = DateTime.now().difference(startTime).inMilliseconds;
        PostHogService.trackAudioInteraction(
          service: 'stt',
          event: 'request',
          success: true,
          durationMs: processingTimeMs,
          additionalProperties: {
            'npc_name': widget.npcId,
          },
        );

        Uint8List npcAudioBytes = response.bodyBytes;
        String? npcResponseDataJsonB64 = response.headers['x-npc-response-data'];

            // Backend response received

        if (npcResponseDataJsonB64 == null) {
          print("Error: X-NPC-Response-Data header is missing.");
          setState(() { _isProcessingBackend = false; });
          return;
        }
        
        String npcResponseDataJson = utf8.decode(base64Decode(npcResponseDataJsonB64));
        

        var responsePayload = json.decode(npcResponseDataJson);
        
        String playerTranscription = _sanitizeString(responsePayload['input_target'] ?? "Transcription unavailable");
        String playerEnglishTranslation = _sanitizeString(responsePayload['input_english'] ?? "");
        String npcText = _sanitizeString(responsePayload['response_target'] ?? '...');
        List<POSMapping> npcPosMappings = (responsePayload['response_mapping'] as List? ?? [])
            .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();
        List<POSMapping> playerInputMappings = (responsePayload['input_mapping'] as List? ?? [])
            .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();

        // Track NPC response received
        PostHogService.trackNPCConversation(
          npcName: widget.npcId,
          event: 'response_received',
          playerMessage: playerTranscription,
          npcResponse: npcText,
          additionalProperties: {
            'player_english': playerEnglishTranslation,
            'response_has_audio': npcAudioBytes.isNotEmpty,
          },
        );

                  // Processing NPC response data

        int charmDelta = 0;
        String charmReason = '';
        bool justReachedMaxCharm = false;
        // Update charm level from backend
        if (responsePayload.containsKey('charm_delta')) { // This comes from NPCResponse model
            charmDelta = responsePayload['charm_delta'] ?? 0;
            charmReason = _sanitizeString(responsePayload['charm_reason'] as String? ?? '');
            final charmNotifier = ref.read(currentCharmLevelProvider(widget.npcId).notifier);
            final oldCharm = charmNotifier.state;
            int newCharm = (oldCharm + charmDelta).clamp(0, 100);

            // Show tutorials for charm milestones
            final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
            if (newCharm >= 60 && oldCharm < 60 && !tutorialProgressNotifier.isStepCompleted('charm_thresholds_explained')) {
              // First time reaching 60 charm - show milestone tutorial
              final tutorialManager = TutorialManager(
                context: context,
                ref: ref,
                npcId: widget.npcId,
              );
              
              tutorialManager.startTutorial(TutorialTrigger.firstCharmMilestone);
            }

            if (newCharm >= 60 && oldCharm < 60 && !tutorialProgressNotifier.isStepCompleted('item_giving_tutorial')) {
              // First time eligible for an item - show item eligibility tutorial
              final tutorialManager = TutorialManager(
                context: context,
                ref: ref,
                npcId: widget.npcId,
              );
              
              tutorialManager.startTutorial(TutorialTrigger.firstItemEligibility);
            }

            if (newCharm == 100 && oldCharm < 100) {
              justReachedMaxCharm = true;
              
              // Show special item tutorial if they haven't seen it
              if (!tutorialProgressNotifier.isStepCompleted('special_item_celebration')) {
                final tutorialManager = TutorialManager(
                  context: context,
                  ref: ref,
                  npcId: widget.npcId,
                );
                
                tutorialManager.startTutorial(TutorialTrigger.firstSpecialItem);
              }
            }
            
            charmNotifier.state = newCharm;
            // Charm level updated
        }

        // Save NPC audio to a temporary file
        String? tempNpcAudioPath;
        try {
          final tempDir = await getTemporaryDirectory();
          tempNpcAudioPath = '${tempDir.path}/npc_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
          await File(tempNpcAudioPath).writeAsBytes(npcAudioBytes);
        } catch (e) {
          print("Error saving NPC audio to temp file: $e");
        }

        // Create unique audio file copy for conversation history to prevent audio conflicts
        String? uniquePlayerAudioPath;
        try {
          final tempDir = await getTemporaryDirectory();
          final entryId = DialogueEntry._generateId();
          uniquePlayerAudioPath = '${tempDir.path}/player_history_${entryId}.wav';
          
          // Copy the original audio file to the unique conversation-specific path
          final originalFile = File(audioFileToSend.path);
          if (await originalFile.exists()) {
            await originalFile.copy(uniquePlayerAudioPath);
            print("Created unique player audio for history: $uniquePlayerAudioPath");
            
            // Add to temp files for cleanup on level exit
            ref.read(tempFilePathsProvider.notifier).update((state) => [...state, uniquePlayerAudioPath!]);
          } else {
            print("Original audio file not found: ${audioFileToSend.path}");
            uniquePlayerAudioPath = audioFileToSend.path; // Fall back to original if copy fails
          }
        } catch (e) {
          print("Error creating unique player audio file: $e");
          uniquePlayerAudioPath = audioFileToSend.path; // Fall back to original if copy fails
        }

        // Create entries for full history with unique audio path
        final playerEntryForHistory = DialogueEntry.player(playerTranscription, uniquePlayerAudioPath!, inputMappings: playerInputMappings, englishTranslation: playerEnglishTranslation.isNotEmpty ? playerEnglishTranslation : null);
        
        // Generate a stable ID for the NPC entry BEFORE creating it
        final String npcEntryId = DialogueEntry._generateId();

        // The NPC entry for display should be created with the FULL text for history purposes
        final npcEntryForDisplayAndHistory = DialogueEntry.npc(
          id: npcEntryId, // Use the pre-generated ID
          text: npcText, // Use the full text immediately for the history
          englishText: responsePayload['response_english'] ?? '',
          npcName: _npcData.name,
          audioPath: tempNpcAudioPath, // This is the path to the NPC's audio file
          audioBytes: npcAudioBytes, // This is the actual audio data for NPC
          posMappings: npcPosMappings, 
        );

        // Update full conversation history with both the player's entry and the NPC's full entry.
        final fullHistoryNotifier = ref.read(fullConversationHistoryProvider(widget.npcId).notifier);
        fullHistoryNotifier.update((history) => [...history, playerEntryForHistory, npcEntryForDisplayAndHistory]);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(_historyDialogScrollController));

        // Clear stale text cache entries to ensure fresh display
        _fullyAnimatedMainNpcTexts.clear();
        
        // Set current NPC display entry for the main box and start animation
        print("DEBUG: Setting currentNpcDisplayEntry with full data - ID: ${npcEntryForDisplayAndHistory.id}, hasAudio: ${npcEntryForDisplayAndHistory.audioBytes?.isNotEmpty == true || npcEntryForDisplayAndHistory.audioPath?.isNotEmpty == true}");
        ref.read(currentNpcDisplayEntryProvider.notifier).state = npcEntryForDisplayAndHistory;
        _startNpcTextAnimation(
          idForAnimation: npcEntryId, // Pass the pre-generated ID
          speakerName: _npcData.name, // Pass speaker name
          fullText: npcText,
          englishText: responsePayload['response_english'] ?? '',
          audioPathToPlayWhenDone: tempNpcAudioPath, // Pass audio path
          audioBytesToPlayWhenDone: npcAudioBytes,   // Pass audio bytes
          posMappings: npcPosMappings,
          charmDelta: charmDelta,
          charmReason: charmReason,
          justReachedMaxCharm: justReachedMaxCharm,
          onAnimationComplete: (finalAnimatedEntry) {
            // Update the display provider with the final animated entry
            ref.read(currentNpcDisplayEntryProvider.notifier).state = finalAnimatedEntry;
            // Also update the text map for correct display on rebuild
            _fullyAnimatedMainNpcTexts[finalAnimatedEntry.id] = finalAnimatedEntry.text;
          }
        );

      } else {
        print("Backend processing failed. Status: ${response.statusCode}, Body: ${response.body}");
        
        // Track failed STT request
        final processingTimeMs = DateTime.now().difference(startTime).inMilliseconds;
        PostHogService.trackAudioInteraction(
          service: 'stt',
          event: 'request',
          success: false,
          durationMs: processingTimeMs,
          error: 'HTTP ${response.statusCode}',
          additionalProperties: {
            'npc_name': widget.npcId,
            'status_code': response.statusCode,
          },
        );
        
        String errorMessage = "An unexpected error occurred.";
        try {
          final errorBody = json.decode(response.body);
          final detail = errorBody['detail'];
          if (detail is String) {
            // Regex to find 'message': '...'
            final messageRegex = RegExp(r"'message':\s*'([^']*)'");
            final messageMatch = messageRegex.firstMatch(detail);

            if (messageMatch != null) {
              errorMessage = messageMatch.group(1)!;
            } else {
              // Regex to find 'status': '...' as a fallback
              final statusRegex = RegExp(r"'status':\s*'([^']*)'");
              final statusMatch = statusRegex.firstMatch(detail);
              if (statusMatch != null) {
                String status = statusMatch.group(1)!.replaceAll('_', ' ');
                errorMessage = status[0].toUpperCase() + status.substring(1);
              } else {
                 // Fallback to the start of the detail string if it's simple
                errorMessage = detail.split(':').first;
              }
            }
          } else if (detail != null) {
            errorMessage = detail.toString();
          }
        } catch (e) {
          // If JSON parsing fails, use the raw body for diagnostics, but maybe not for the user.
          // For the user, a generic message is better if parsing fails.
          errorMessage = "Could not process error response from server.";
          print("Error parsing backend error response: $e");
        }

        if (mounted) {
          _showErrorDialog(errorMessage);
        }
      }
    } catch (e, stackTrace) {
      print("Exception in _sendAudioToBackend: $e\\n$stackTrace");
      
      // Track exception in STT request
      final processingTimeMs = DateTime.now().difference(startTime).inMilliseconds;
      PostHogService.trackAudioInteraction(
        service: 'stt',
        event: 'request',
        success: false,
        durationMs: processingTimeMs,
        error: e.toString(),
        additionalProperties: {
          'npc_name': widget.npcId,
          'error_type': 'exception',
        },
      );

      if (mounted) {
        _showErrorDialog("A client-side error occurred: ${e.toString()}");
      }
    } finally {
      setState(() { _isProcessingBackend = false; });
      // The recorded file is no longer deleted here.
      // It will be cleaned up on game exit.
    }
  }
  
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _playDialogueAudio(DialogueEntry entry) async {
    print("DEBUG: _playDialogueAudio called - Entry ID: ${entry.id}, hasAudioPath: ${entry.audioPath?.isNotEmpty == true}, hasAudioBytes: ${entry.audioBytes?.isNotEmpty == true}");
    
    // Check if widget is still mounted before proceeding with audio playback
    if (!mounted) {
      print("DEBUG: Widget no longer mounted, skipping audio playback");
      return;
    }
    
    final player = ref.read(dialogueReplayPlayerProvider);
    await player.stop();

    try {
      if (entry.audioPath != null && entry.audioPath!.isNotEmpty) {
        if (entry.audioPath!.startsWith('assets/')) {
          await player.setAsset(entry.audioPath!);
          } else {
            await player.setAudioSource(just_audio.AudioSource.uri(Uri.file(entry.audioPath!)));
        }
      } else if (entry.audioBytes != null && entry.audioBytes!.isNotEmpty) {
        await player.setAudioSource(_MyCustomStreamAudioSource.fromBytes(entry.audioBytes!));
      } else {
        print("No audio data to play for entry ID ${entry.id}.");
        return;
      }
      await player.play();
    } catch (e) {
      print("Error playing dialogue audio for entry ID ${entry.id}: $e");
    }
  }

  Future<void> _playVocabularyAudio(String audioPath) async {
    final player = ref.read(dialogueReplayPlayerProvider);
    await player.stop();

    try {
      if (audioPath.startsWith('assets/')) {
        await player.setAsset(audioPath);
      } else if (audioPath.startsWith('data:') || audioPath.length > 1000) {
        // Handle base64 audio data
        String base64Data = audioPath;
        if (audioPath.startsWith('data:')) {
          // Extract base64 part from data URL
          base64Data = audioPath.split(',').last;
        }
        
        try {
          final audioBytes = base64Decode(base64Data);
          await player.setAudioSource(_MyCustomStreamAudioSource.fromBytes(audioBytes));
        } catch (e) {
          print("Error decoding base64 audio: $e");
          return;
        }
      } else {
        await player.setAudioSource(just_audio.AudioSource.uri(Uri.file(audioPath)));
      }
      await player.play();
    } catch (e) {
      print("Error playing vocabulary audio: $e");
    }
  }

  // Tutorial-aware toggle handlers
  void _handleTransliterationToggle() {
    final dialogueSettings = ref.read(dialogueSettingsProvider);
    final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
    
    // If turning ON transliteration for the first time, show tutorial
    if (!dialogueSettings.showTransliteration && !tutorialProgressNotifier.isStepCompleted('transliteration_system')) {
      final tutorialManager = TutorialManager(
        context: context,
        ref: ref,
        npcId: widget.npcId,
      );
      
      // Show transliteration tutorial
      tutorialManager.startTutorial(TutorialTrigger.firstDialogueAnalysis);
    }
    
    // Perform the actual toggle
    ref.read(dialogueSettingsProvider.notifier).toggleShowTransliteration();
  }
  
  void _handleWordAnalysisToggle() {
    final dialogueSettings = ref.read(dialogueSettingsProvider);
    final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
    
    // If turning ON word analysis for the first time, show tutorial
    if (!dialogueSettings.showWordByWordAnalysis && !tutorialProgressNotifier.isStepCompleted('pos_color_system')) {
      final tutorialManager = TutorialManager(
        context: context,
        ref: ref,
        npcId: widget.npcId,
      );
      
      // Show POS color system tutorial
      tutorialManager.startTutorial(TutorialTrigger.firstDialogueAnalysis);
    }
    
    // Perform the actual toggle
    ref.read(dialogueSettingsProvider.notifier).toggleWordByWordAnalysis();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final dialogueSettings = ref.watch(dialogueSettingsProvider);
    final currentNpcDisplayEntry = ref.watch(currentNpcDisplayEntryProvider);
    final bool showEnglishTranslation = dialogueSettings.showEnglishTranslation;
    final bool showWordByWordAnalysis = dialogueSettings.showWordByWordAnalysis;
    final int displayedCharmLevel = ref.watch(currentCharmLevelProvider(widget.npcId));

    final bool isAnimatingThisNpcEntry = (currentNpcDisplayEntry != null && currentNpcDisplayEntry.id == _currentlyAnimatingEntryId);

    Widget npcContentWidget;
    if (currentNpcDisplayEntry == null) {
      npcContentWidget = const SizedBox.shrink();
    } else {
      // Always build the main content first
      Widget mainContent;
      String textToDisplayForNpc = isAnimatingThisNpcEntry ? _displayedTextForAnimation : (_fullyAnimatedMainNpcTexts[currentNpcDisplayEntry.id] ?? currentNpcDisplayEntry.text);
      bool useCenteredLayout = !showWordByWordAnalysis && textToDisplayForNpc.length < 40 && !isAnimatingThisNpcEntry && (currentNpcDisplayEntry.posMappings == null || currentNpcDisplayEntry.posMappings!.isEmpty);

      if (useCenteredLayout) {
        mainContent = Center(
          child: Text(
            textToDisplayForNpc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w500),
          ),
        );
      } else if (isAnimatingThisNpcEntry) {
        mainContent = Text(
          textToDisplayForNpc,
          textAlign: TextAlign.left,
          style: const TextStyle(color: Colors.black, fontSize: 20),
        );
      } else if (currentNpcDisplayEntry.isNpc && currentNpcDisplayEntry.posMappings != null && currentNpcDisplayEntry.posMappings!.isNotEmpty) {
        List<InlineSpan> wordSpans = currentNpcDisplayEntry.posMappings!.map((mapping) {
          List<Widget> wordParts = [
            Text(mapping.wordTarget, style: TextStyle(color: showWordByWordAnalysis ? (posColorMapping[mapping.pos] ?? Colors.black) : Colors.black, fontSize: 20, fontWeight: FontWeight.w500)),
          ];
          if (showWordByWordAnalysis) {
            if (mapping.wordTranslit.isNotEmpty) {
              wordParts.add(const SizedBox(height: 1));
              wordParts.add(Text(mapping.wordTranslit, style: TextStyle(fontSize: 12, color: posColorMapping[mapping.pos] ?? Colors.black54)));
            }
            if (mapping.wordEng.isNotEmpty) {
              wordParts.add(const SizedBox(height: 1));
              wordParts.add(Text(mapping.wordEng, style: TextStyle(fontSize: 12, color: posColorMapping[mapping.pos] ?? Colors.blueGrey.shade600, fontStyle: FontStyle.italic)));
            }
          }
          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 3.0, bottom: 2.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: wordParts),
            ),
          );
        }).toList();
        mainContent = RichText(textAlign: TextAlign.left, text: TextSpan(children: wordSpans));
      } else {
        mainContent = Text(textToDisplayForNpc, style: const TextStyle(fontSize: 18, color: Colors.black87));
      }
      
      // Now, wrap the main content in a Column and conditionally add the English translation below it.
      npcContentWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: useCenteredLayout ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          mainContent,
          if (showEnglishTranslation && currentNpcDisplayEntry.englishText.isNotEmpty && !isAnimatingThisNpcEntry)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                currentNpcDisplayEntry.englishText,
                textAlign: useCenteredLayout ? TextAlign.center : TextAlign.left,
                style: const TextStyle(fontSize: 18, color: Colors.black54, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      );
    }

    return DialogueUI(
      npcData: _npcData,
      displayedCharmLevel: displayedCharmLevel,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      npcContentWidget: npcContentWidget,
      topRightAction: null,
      giftIconAnimationController: _giftIconAnimationController,
      onRequestItem: () => _showGiveItemDialog(context),
      onGiftIconTap: () => _showRequestItemDialog(context),
      onResumeGame: () {
        widget.game.overlays.remove('dialogue');
        widget.game.resumeGame(ref);
      },
      onShowTranslation: () => _showLanguageToolsWithTutorial(context),
      micControls: _buildMicOrReviewControls(),
      isProcessingBackend: _isProcessingBackend,
      mainDialogueScrollController: _mainDialogueScrollController,
      onShowHistory: () => _showFullConversationHistoryDialog(context),
      showEnglish: dialogueSettings.showEnglishTranslation,
      showTransliteration: dialogueSettings.showTransliteration,
      showWordAnalysis: dialogueSettings.showWordByWordAnalysis,
      onToggleEnglish: () => ref.read(dialogueSettingsProvider.notifier).toggleShowEnglishTranslation(),
      onToggleTransliteration: () => _handleTransliterationToggle(),
      onToggleWordAnalysis: () => _handleWordAnalysisToggle(),
      onReplayAudio: (currentNpcDisplayEntry?.isNpc ?? false) && (currentNpcDisplayEntry?.audioPath != null || currentNpcDisplayEntry?.audioBytes != null)
        ? () => _playDialogueAudio(currentNpcDisplayEntry!)
        : null,
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap, double size = 28, double padding = 12}) {
    return _AnimatedPressWrapper(
      onTap: () {
        ref.playButtonSound();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  Widget _buildMicButton() {
    return ScaleTransition(
      scale: _scaleAnimation ?? const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red.withOpacity(0.8) : Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(Icons.mic, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildMicOrReviewControls() {
    switch (_recordingState) {
      case RecordingState.recording:
        return _AnimatedPressWrapper(
          onTap: () {
            ref.playButtonSound();
            _stopRecordingAndReview();
          },
          child: _buildMicButton(),
        );
      case RecordingState.reviewing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(icon: Icons.replay, onTap: () {
              _reRecord();
            }, padding: 16),
            const SizedBox(width: 20),
            _buildControlButton(icon: Icons.play_arrow, onTap: () {
              _playLastRecording();
            }, padding: 16),
            const SizedBox(width: 20),
            _buildControlButton(icon: Icons.send, onTap: () {
              _sendApprovedRecording();
            }, padding: 16),
          ],
        );
      case RecordingState.idle:
      default:
        return _AnimatedPressWrapper(
          onTap: () {
            ref.playButtonSound();
            _showRecordingModal();
          },
          child: _buildMicButton(),
        );
    }
  }

  // --- Recording Modal ---
  void _showRecordingModal() async {
    final dialogueSettings = ref.read(dialogueSettingsProvider);
    
    // Get the most recent NPC message for context
    final currentFullHistory = ref.read(fullConversationHistoryProvider(widget.npcId));
    String npcMessage = "สวัสดีค่า ฉันช่วยอะไรได้บ้างคะ?";
    String npcMessageEnglish = "Hi! How can I help you?";
    
    String? npcAudioPath;
    String? npcAudioBytes;
    List<POSMapping>? npcPosMappings;
    
    if (currentFullHistory.isNotEmpty) {
      // Debug: Log conversation history search
      print("DEBUG: Searching through ${currentFullHistory.length} entries in conversation history");
      
      // Find the most recent NPC message
      for (int i = currentFullHistory.length - 1; i >= 0; i--) {
        final entry = currentFullHistory[i];
        print("DEBUG: Entry $i - isNpc: ${entry.isNpc}, text: '${entry.text.substring(0, math.min(entry.text.length, 30))}...', posMappings: ${entry.posMappings?.length ?? 'null'}");
        if (entry.isNpc) {
          npcMessage = entry.text;
          npcMessageEnglish = entry.englishText.isNotEmpty ? entry.englishText : entry.text;
          npcAudioPath = entry.audioPath;
          npcAudioBytes = entry.audioBytes != null ? base64Encode(entry.audioBytes!) : null;
          npcPosMappings = entry.posMappings;
          // Debug: Log POS mappings retrieval from conversation history
          print("DEBUG: Retrieved ${npcPosMappings?.length ?? 0} POS mappings from conversation history for modal");
          print("DEBUG: Using NPC message: '${npcMessage.substring(0, math.min(npcMessage.length, 50))}...'");
          break;
        }
      }
    } else {
      print("DEBUG: No conversation history found, using fallback message");
      // If no conversation history but we have initial greeting data, use that instead of fallback
      if (_initialGreetingData != null) {
        npcMessage = _initialGreetingData!.responseTarget;
        npcMessageEnglish = _initialGreetingData!.responseEnglish;
        npcPosMappings = _initialGreetingData!.responseMapping;
        // Try to find the audio path/bytes (may not be available immediately)
        npcAudioPath = _initialGreetingData!.responseAudioPath;
        print("DEBUG: Using initial greeting data - message: '${npcMessage.substring(0, math.min(npcMessage.length, 50))}...', posMappings: ${npcPosMappings?.length ?? 'null'}");
      } else {
        print("DEBUG: No initial greeting data available either, using fallback");
      }
      print("DEBUG: Final fallback - npcMessage: '$npcMessage', npcPosMappings: ${npcPosMappings?.length ?? 'null'}");
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NPCResponseModal(
          npcData: _npcData,
          npcMessage: npcMessage,
          npcMessageEnglish: npcMessageEnglish,
          showEnglish: dialogueSettings.showEnglishTranslation,
          showTransliteration: dialogueSettings.showTransliteration,
          onSendResponse: (String transcription, String? audioPath) {
            Navigator.of(context).pop(); // Close the modal
            _handleModalResponse(transcription, audioPath);
          },
          onClose: () {
            Navigator.of(context).pop(); // Close the modal
          },
          npcAudioPath: npcAudioPath,
          npcAudioBytes: npcAudioBytes,
          npcPosMappings: npcPosMappings,
        );
      },
    );
  }

  void _handleModalResponse(String transcription, String? audioPath) {
    // Send the approved transcription through the existing NPC flow
    _sendTranscriptionToNPC(transcription, audioPath);
  }

  void _sendTranscriptionToNPC(String transcription, [String? audioPath]) async {
    print("Sending approved transcription to NPC: $transcription");
    
    // Check if widget is still mounted before proceeding
    if (!mounted) {
      print("Widget disposed, cancelling _sendTranscriptionToNPC");
      return;
    }
    
    setState(() { _isProcessingBackend = true; });

    try {
      // Construct conversation history for the backend (same as existing flow)
      final currentFullHistory = ref.read(fullConversationHistoryProvider(widget.npcId));
      List<String> historyLinesForBackend = [];
      
      for (var entry in currentFullHistory) {
        if (entry.isNpc) {
          historyLinesForBackend.add("NPC: ${entry.text}");
        } else {
          // Use the stored transcription for player entries
          String playerContent = entry.playerTranscriptionForHistory ?? entry.text;
          historyLinesForBackend.add("Player: $playerContent");
        }
      }

      String previousHistoryPayload = historyLinesForBackend.join('\n');
      print("Sending history to backend: $previousHistoryPayload");

      // Get current charm level
      final int currentCharmLevel = ref.read(currentCharmLevelProvider(widget.npcId));
      int charmLevelForRequest = math.max(0, math.min(100, currentCharmLevel));

      // Send custom message to backend (adapted from existing pattern)
      var uri = Uri.parse('http://127.0.0.1:8000/generate-npc-response/');
      var request = http.MultipartRequest('POST', uri)
        ..fields['npc_id'] = _npcData.id
        ..fields['npc_name'] = _npcData.name
        ..fields['charm_level'] = charmLevelForRequest.toString()
        ..fields['previous_conversation_history'] = previousHistoryPayload
        ..fields['custom_message'] = transcription // Send transcription as custom message
        ..fields['user_id'] = PostHogService.userId ?? 'unknown_user'
        ..fields['session_id'] = PostHogService.sessionId ?? 'unknown_session';

      print('Sending request to backend: ${uri.toString()}');
      var response = await request.send();
      
      if (response.statusCode == 200) {
        print('Backend request succeeded with status: ${response.statusCode}');
        
        // Read the response body (audio bytes)
        var responseBytes = await response.stream.toBytes();
        
        // Extract NPC response metadata from headers
        var npcResponseDataHeader = response.headers['x-npc-response-data'];
        if (npcResponseDataHeader == null) {
          throw Exception('Missing NPC response data in headers');
        }
        
        var npcResponseDataJson = utf8.decode(base64.decode(npcResponseDataHeader));
        var responsePayload = json.decode(npcResponseDataJson);
        
        String playerTranscription = responsePayload['input_target'] ?? transcription;
        String playerEnglishTranslation = responsePayload['input_english'] ?? '';
        String npcText = responsePayload['response_target'] ?? 'Sorry, I did not understand.';
        String englishTranslation = responsePayload['response_english'] ?? '';
        
        List<POSMapping> npcPosMappings = (responsePayload['response_mapping'] as List<dynamic>?)
          ?.map((mapping) => POSMapping.fromJson(mapping))
          .toList() ?? [];
        
        List<POSMapping> playerInputMappings = (responsePayload['input_mapping'] as List<dynamic>?)
          ?.map((mapping) => POSMapping.fromJson(mapping))
          .toList() ?? [];
        
        int charmDelta = responsePayload['charm_delta'] ?? 0;
        String charmReason = responsePayload['charm_reason'] ?? '';

        // Update charm level
        if (charmDelta != 0 && mounted) {
          ref.read(currentCharmLevelProvider(widget.npcId).notifier).update((current) => 
            math.max(0, math.min(100, current + charmDelta))
          );
        }

        // Create dialogue entries
        final String playerId = DateTime.now().millisecondsSinceEpoch.toString() + '_player';
        final String npcId = DateTime.now().millisecondsSinceEpoch.toString() + '_npc';

        final playerEntry = DialogueEntry(
          customId: playerId,
          text: playerTranscription,
          englishText: playerEnglishTranslation,
          speaker: 'Player',
          audioPath: audioPath, // Use the provided audio path from final recording
          audioBytes: null,
          isNpc: false,
          posMappings: playerInputMappings,
          playerTranscriptionForHistory: playerTranscription,
        );

        final npcEntry = DialogueEntry(
          customId: npcId,
          text: npcText,
          englishText: englishTranslation,
          speaker: _npcData.name,
          audioPath: null,
          audioBytes: responseBytes,
          isNpc: true,
          posMappings: npcPosMappings,
          playerTranscriptionForHistory: null,
        );

        // Update conversation history
        if (mounted) {
          final fullHistoryNotifier = ref.read(fullConversationHistoryProvider(widget.npcId).notifier);
          fullHistoryNotifier.update((history) => [...history, playerEntry, npcEntry]);
        }

        // Clear stale text cache entries to ensure fresh display
        _fullyAnimatedMainNpcTexts.clear();
        
        // Set current NPC display entry for the main box and start animation
        print("DEBUG: Setting currentNpcDisplayEntry with full data - ID: ${npcEntry.id}, hasAudio: ${npcEntry.audioBytes?.isNotEmpty == true || npcEntry.audioPath?.isNotEmpty == true}");
        ref.read(currentNpcDisplayEntryProvider.notifier).state = npcEntry;
        _startNpcTextAnimation(
          idForAnimation: npcId, // Use the generated ID
          speakerName: _npcData.name, // Pass speaker name
          fullText: npcText,
          englishText: englishTranslation,
          audioPathToPlayWhenDone: null, // No path since we have bytes
          audioBytesToPlayWhenDone: responseBytes, // Pass audio bytes
          posMappings: npcPosMappings,
          charmDelta: charmDelta,
          charmReason: charmReason,
          justReachedMaxCharm: charmDelta > 0 && (ref.read(currentCharmLevelProvider(widget.npcId)) == 100),
          onAnimationComplete: (finalAnimatedEntry) {
            // Update the display provider with the final animated entry
            ref.read(currentNpcDisplayEntryProvider.notifier).state = finalAnimatedEntry;
            // Also update the text map for correct display on rebuild
            _fullyAnimatedMainNpcTexts[finalAnimatedEntry.id] = finalAnimatedEntry.text;
          }
        );

        print("NPC response successfully processed and added to conversation");

      } else {
        String responseBody = await response.stream.bytesToString();
        throw Exception('Backend returned ${response.statusCode}: $responseBody');
      }
      
    } catch (e, stackTrace) {
      print("Exception in _sendTranscriptionToNPC: $e\n$stackTrace");
      if (mounted) {
        _showErrorDialog("A client-side error occurred: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() { _isProcessingBackend = false; });
      }
    }
  }

  // --- Item Request Dialogs ---
  Future<void> _showRequestItemDialog(BuildContext context) async {
    final int currentCharm = ref.read(currentCharmLevelProvider(widget.npcId));
    final NpcData? itemData = npcDataMap[widget.npcId];

    if (itemData == null) {
      print("Error: No item data found for NPC ID: ${widget.npcId}");
      return;
    }

    String dialogTitle = "Request an item from ${itemData.name}?";
    String dialogContent;

    if (currentCharm >= 100) {
        dialogContent = "You have reached maximum charm! You can receive a special item. This will end the conversation.";
    } else {
        dialogContent = "Your charm is high enough to request an item. Request the regular item now, or wait until your charm is 100 to receive a special item? Requesting an item will end the conversation.";
    }

    return showDialog<void>(
        context: context,
        barrierDismissible: false, // User must make a choice
        builder: (BuildContext dialogContext) {
            return AlertDialog(
                title: Text(dialogTitle),
                content: Text(dialogContent),
                actions: <Widget>[
                    TextButton(
                        child: const Text('Wait'),
                        onPressed: () {
                            Navigator.of(dialogContext).pop();
                        },
                    ),
                    ElevatedButton(
                        child: Text(currentCharm >= 100 ? 'Receive Special Item' : 'Request Regular Item'),
                        onPressed: () {
                            Navigator.of(dialogContext).pop(); // Close this dialog
                            final isSpecial = currentCharm >= 100;
                            String receivedItem = isSpecial ? itemData.specialItemName : itemData.regularItemName;
                            String receivedItemAsset = isSpecial ? itemData.specialItemAsset : itemData.regularItemAsset;
                            String receivedItemType = isSpecial ? itemData.specialItemType : itemData.regularItemType;
                            _showItemReceivedDialog(context, receivedItem, receivedItemAsset, receivedItemType, isSpecial);
                        },
                    ),
                ],
            );
        },
    );
  }

  Future<void> _showItemReceivedDialog(BuildContext context, String itemName, String itemAsset, String itemType, bool isSpecial) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
            return AlertDialog(
                title: Text("Item Received!"),
                content: Text("You have received: $itemName"),
                actions: <Widget>[
                    TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                            // Update inventory state
                            ref.read(inventoryProvider.notifier).update((state) {
                              final newState = Map<String, String?>.from(state);
                              newState[itemType] = itemAsset; // Use itemType as the key
                              return newState;
                            });

                            // If it's a special item, mark it as received AND hide the speech bubble immediately.
                            if (isSpecial) {
                              ref.read(specialItemReceivedProvider(widget.npcId).notifier).state = true;
                              widget.game.hideSpeechBubbleFor(widget.npcId);
                            }
                            
                            // Set providers for new item notification
                            ref.read(gameStateProvider.notifier).setNewItem();

                            Navigator.of(dialogContext).pop(); // Close this dialog first

                            // Then close the main dialogue overlay and resume game
                            widget.game.overlays.remove('dialogue');
                            widget.game.resumeGame(ref);
                        },
                    ),
                ],
            );
        },
    );
  }

  // --- Max Charm Notification ---
  Future<void> _showMaxCharmNotification(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Max Charm Reached!"),
          content: Text("You have reached the maximum charm level with ${_npcData.name}! You can now request a special item."),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- Charm Change Notification ---
  Future<void> _showCharmChangeNotification(BuildContext context, int charmDelta, String charmReason) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Charm Changed!"),
          content: _CharmChangeDialogContent(
            charmDelta: charmDelta,
            charmReason: charmReason,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


  // --- Full Conversation History Dialog ---
  Future<void> _showFullConversationHistoryDialog(BuildContext context) async {
    final historyEntries = ref.watch(fullConversationHistoryProvider(widget.npcId)); // Watch for live updates
    final dialogueSettings = ref.watch(dialogueSettingsProvider);
    final bool showEnglishTranslationInHistory = dialogueSettings.showEnglishTranslation;
    final bool showWordByWordAnalysisInHistory = dialogueSettings.showWordByWordAnalysis;

    // Ensure scroll to bottom when dialog opens or updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_historyDialogScrollController.hasClients) {
            _scrollToBottom(_historyDialogScrollController);
        }
    });

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[100], // Lighter background for better text readability
          title: const Text('Full Conversation History'),
          contentPadding: EdgeInsets.all(10), // Adjust padding
          content: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.8, // 80% of screen width
            height: MediaQuery.of(dialogContext).size.height * 0.6, // 60% of screen height
            child: Scrollbar(
              thumbVisibility: true,
              controller: _historyDialogScrollController,
              child: ListView.builder(
                controller: _historyDialogScrollController,
                itemCount: historyEntries.length,
                itemBuilder: (context, index) {
                  final entry = historyEntries[index];
                  Widget mainContentWidget;
                  Widget? englishTranslationWidget;

                  // Conditionally create the English translation widget to be added later
                  if (showEnglishTranslationInHistory && entry.englishText.isNotEmpty) {
                    englishTranslationWidget = Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        entry.englishText,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: entry.isNpc ? Colors.black54 : Colors.deepPurple.shade300,
                        ),
                      ),
                    );
                  }

                  // Build the main content (Thai or Word Analysis)
                  if (entry.isNpc) {
                    if (entry.posMappings != null && entry.posMappings!.isNotEmpty && showWordByWordAnalysisInHistory) {
                      // NPC with word analysis
                      List<InlineSpan> wordSpans = entry.posMappings!.map((mapping) {
                        List<Widget> wordParts = [
                          Text(mapping.wordTarget, style: TextStyle(color: posColorMapping[mapping.pos] ?? Colors.black87, fontSize: 18, fontWeight: FontWeight.w500)),
                        ];
                        if (mapping.wordTranslit.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordTranslit, style: TextStyle(fontSize: 12, color: posColorMapping[mapping.pos] ?? Colors.black54)));
                        }
                        if (mapping.wordEng.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordEng, style: TextStyle(fontSize: 12, color: posColorMapping[mapping.pos] ?? Colors.blueGrey.shade600, fontStyle: FontStyle.italic)));
                        }
                        return WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3.0, bottom: 2.0),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: wordParts),
                          ),
                        );
                      }).toList();
                      mainContentWidget = RichText(textAlign: TextAlign.left, text: TextSpan(children: wordSpans));
                    } else {
                      // Plain NPC text
                      mainContentWidget = Text(entry.text, style: TextStyle(fontSize: 18, color: Colors.black87));
                    }
                  } else {
                    // Player's transcribed text
                    bool isItemGivingAction = entry.text.startsWith('User gives ') && entry.text.contains(' to ');
                    if (entry.posMappings != null && entry.posMappings!.isNotEmpty && showWordByWordAnalysisInHistory && !isItemGivingAction) {
                      // Player with word analysis
                      List<InlineSpan> wordSpans = entry.posMappings!.map((mapping) {
                        List<Widget> wordParts = [
                          Text(mapping.wordTarget, style: TextStyle(color: posColorMapping[mapping.pos] ?? Colors.deepPurple.shade700, fontSize: 18, fontWeight: FontWeight.w500)),
                        ];
                        if (mapping.wordTranslit.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordTranslit, style: TextStyle(fontSize: 12, color: posColorMapping[mapping.pos] ?? Colors.deepPurple.shade400)));
                        }
                        if (mapping.wordEng.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordEng, style: TextStyle(fontSize: 12, color: posColorMapping[mapping.pos] ?? Colors.deepPurple.shade300, fontStyle: FontStyle.italic)));
                        }
                        return WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3.0, bottom: 2.0),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: wordParts),
                          ),
                        );
                      }).toList();
                      mainContentWidget = RichText(textAlign: TextAlign.left, text: TextSpan(children: wordSpans));
                    } else {
                      // Plain player text
                      mainContentWidget = Text(entry.playerTranscriptionForHistory ?? entry.text, style: TextStyle(fontSize: 18, color: Colors.deepPurple.shade700));
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.speaker,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: entry.isNpc ? Colors.teal.shade600 : Colors.indigo.shade600,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  mainContentWidget, // Always show main content
                                  if (englishTranslationWidget != null) englishTranslationWidget, // Conditionally show English translation
                                ],
                              ),
                            ),
                            if (entry.audioPath != null || entry.audioBytes != null)
                              IconButton(
                                icon: Icon(Icons.volume_up, color: Colors.black45),
                                iconSize: 18,
                                 padding: EdgeInsets.only(left: 6, top: 0, bottom: 0, right: 0),
                                constraints: BoxConstraints(),
                                onPressed: () => _playDialogueAudio(entry),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
  
  // --- Simple Give Item Dialog ---
  Future<void> _showGiveItemDialog(BuildContext context, {String targetLanguage = "th"}) async {
    // Reset giving item state when dialog opens
    setState(() {
      _selectedCategory = null;
      _selectedVocabularyItem = null;
      _categorizedItems.clear();
      _vocabularyDataLoaded = false;
      _vocabularyLoadingFuture = _loadAndCategorizeVocabulary();
    });
    print("DEBUG: Reset giving item state for direct dialog");
    
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Give Item'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: _buildItemGivingTab(dialogContext, targetLanguage),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Language tools with tutorial support
  Future<void> _showLanguageToolsWithTutorial(BuildContext context) async {
    final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
    
    // Show language tools tutorial if this is the first time accessing it
    if (!tutorialProgressNotifier.isStepCompleted('first_language_tools_tutorial')) {
      final tutorialManager = TutorialManager(context: context, ref: ref, npcId: widget.npcId);
      await tutorialManager.startTutorial(TutorialTrigger.firstLanguageTools);
    }
    
    // Then show the language tools dialog
    _showEnglishToTargetLanguageTranslationDialog(context);
  }

  // --- New Dialog for English to Target Language Translation Input ---
  Future<void> _showEnglishToTargetLanguageTranslationDialog(BuildContext context, {String targetLanguage = "th", int initialTabIndex = 0}) async {
    // Reset state when opening the dialog
    _translationEnglishController.clear();
    _translationMappingsNotifier.value = [];
    _translationAudioNotifier.value = "";
    _translationErrorNotifier.value = null;
    _practiceRecordingState.value = RecordingState.idle;
    _lastPracticeRecordingPath.value = null;
    
    // Reset giving item state as well since this dialog includes the giving item tab
    setState(() {
      _selectedCategory = null;
      _selectedVocabularyItem = null;
      _categorizedItems.clear();
      _vocabularyDataLoaded = false;
      _vocabularyLoadingFuture = _loadAndCategorizeVocabulary();
    });
    print("DEBUG: Reset giving item state for translation dialog");

    // Set initial title when dialog is opened.
    _translationDialogTitleNotifier.value = 'Language Tools';

    // Get the audio player from Riverpod
    final audioPlayer = ref.read(dialogueReplayPlayerProvider);

    void playTranslatedAudio(String audioBase64) async {
      if (audioBase64.isEmpty) return;
      try {
        await audioPlayer.stop();
        final audioBytes = base64Decode(audioBase64);
        // Use a custom audio source that can play from bytes
        await audioPlayer.setAudioSource(_MyCustomStreamAudioSource.fromBytes(audioBytes));
        await audioPlayer.play();
      } catch (e) {
        print("Error playing translated audio: $e");
        _translationErrorNotifier.value = "Error playing audio.";
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.1),
      builder: (BuildContext dialogContext) {
        return DefaultTabController(
          length: 2,
          initialIndex: initialTabIndex,
          child: Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  ValueListenableBuilder<String>(
                    valueListenable: _translationDialogTitleNotifier,
                    builder: (context, title, child) => Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Tab content
                  Expanded(
                    child: Column(
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            tabBarTheme: TabBarThemeData(
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.white.withOpacity(0.6),
                              indicator: UnderlineTabIndicator(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          child: TabBar(
                            tabs: [
                              Tab(text: 'Translate'),
                              Tab(text: 'Give Item'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildTranslationTab(playTranslatedAudio, targetLanguage),
                              _buildItemGivingTab(dialogContext, targetLanguage),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Actions
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Tab Content Methods ---
  
  Widget _buildTranslationTab(Function(String) playTranslatedAudio, String targetLanguage) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter English text to translate:'),
            SizedBox(height: 8),
            TextField(
              controller: _translationEnglishController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type here...',
              ),
              minLines: 3,
              maxLines: 5,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              child: const Text('Translate'),
              onPressed: () async {
                final String englishText = _translationEnglishController.text;
                if (englishText.trim().isEmpty) return;

                _translationIsLoadingNotifier.value = true;
                _translationErrorNotifier.value = null;
                _practiceRecordingState.value = RecordingState.idle;

                try {
                  final response = await http.post(
                    Uri.parse('http://127.0.0.1:8000/gcloud-translate-tts/'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'english_text': englishText,
                      'target_language': targetLanguage
                    }),
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    
                    // Keep consistent title regardless of language
                    _translationDialogTitleNotifier.value = 'Language Tools';
                    
                    _translationAudioNotifier.value = data['audio_base64'] ?? "";
                    
                    if (data['word_mappings'] != null) {
                      List<Map<String, String>> mappings = [];
                      for (var mapping in data['word_mappings']) {
                        mappings.add({
                          'english': mapping['english']?.toString() ?? '',
                          'target': mapping['target']?.toString() ?? '',
                          'romanized': mapping['romanized']?.toString() ?? '',
                        });
                      }
                      _translationMappingsNotifier.value = mappings;
                    } else {
                      _translationMappingsNotifier.value = [];
                    }
                  } else {
                    String errorMessage = "Error: ${response.statusCode}";
                    try {
                       final errorData = jsonDecode(response.body);
                       errorMessage += ": ${errorData['detail'] ?? 'Unknown backend error'}";
                    } catch(_) {}
                    _translationErrorNotifier.value = errorMessage;
                    print("Backend translation error: ${response.body}");
                  }
                } catch (e) {
                  _translationErrorNotifier.value = "Error: Could not connect to translation service.";
                  print("Network or other error calling translation backend: $e");
                }

                _translationIsLoadingNotifier.value = false;
              },
            ),
            SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: _translationIsLoadingNotifier,
              builder: (context, isLoading, child) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: _translationErrorNotifier,
                      builder: (context, error, child) {
                        if (error != null) {
                          return Text(error, style: TextStyle(color: Colors.red));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    ValueListenableBuilder<List<Map<String, String>>>(
                      valueListenable: _translationMappingsNotifier,
                      builder: (context, wordMappings, child) {
                        if (wordMappings.isEmpty) return const SizedBox.shrink();
                        
                        return Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(4),
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal[800],
                                        ),
                                      ),
                                      ValueListenableBuilder<String>(
                                        valueListenable: _translationAudioNotifier,
                                        builder: (context, audioBase64, child) {
                                          if (audioBase64.isEmpty) return const SizedBox.shrink();
                                          return IconButton(
                                            icon: Icon(Icons.volume_up, color: Colors.teal[700]),
                                            onPressed: () => playTranslatedAudio(audioBase64),
                                          );
                                        }
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: wordMappings.map((mapping) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(180),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.teal.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              mapping['target'] ?? '',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[800],
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              mapping['romanized'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.teal[600],
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              mapping['english'] ?? '',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blueGrey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPracticeMicControls(),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGivingTab(BuildContext dialogContext, String targetLanguage) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Select or translate a word to give as an item:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Category-based NPC Vocabulary Selection
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              // Loading/Error State Handler
              FutureBuilder<void>(
                future: _vocabularyLoadingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Loading vocabulary...'),
                      ],
                    );
                  }
                  
                  if (snapshot.hasError) {
                    print("DEBUG: Error loading vocabulary: ${snapshot.error}");
                    return Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Failed to load vocabulary: ${snapshot.error}'),
                      ],
                    );
                  }
                  
                  if (_categorizedItems.isEmpty) {
                    return const Text('No vocabulary items found.');
                  }
                  
                  // Data loaded successfully, return empty widget since UI is handled below
                  return const SizedBox.shrink();
                },
              ),
              
              // StatefulBuilder Pattern - Guaranteed Local Rebuilds
              StatefulBuilder(
                builder: (context, localSetState) {
                  print("DEBUG: StatefulBuilder rebuilding - Selected category: $_selectedCategory");
                  print("DEBUG: StatefulBuilder - Vocabulary loaded: $_vocabularyDataLoaded, Items count: ${_categorizedItems.length}");
                  
                  return Column(
                    children: [
                      // Category Dropdown - Inline with localSetState
                      if (_vocabularyDataLoaded && _categorizedItems.isNotEmpty) ...[
                        () {
                          final categories = _categorizedItems.keys.toList()..sort();
                          print("DEBUG: Building category dropdown - Categories: $categories, Selected: $_selectedCategory");
                          
                          return DropdownButtonFormField<String>(
                            key: ValueKey('category_dropdown_${_categorizedItems.length}'),
                            decoration: const InputDecoration(
                              labelText: 'Select Category...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            isExpanded: true,
                            value: _selectedCategory,
                            items: categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  category,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (selectedCategory) {
                              print("DEBUG: Category selected: $selectedCategory");
                              localSetState(() {
                                _selectedCategory = selectedCategory;
                                _selectedVocabularyItem = null; // Reset item selection when category changes
                              });
                              print("DEBUG: Local state updated, triggering StatefulBuilder rebuild");
                              print("DEBUG: New state - Selected: $_selectedCategory, Available items: ${_categorizedItems[selectedCategory]?.length ?? 0}");
                            },
                          );
                        }(),
                      ],
                      
                      // Vocabulary Dropdown - Conditional inline with guaranteed rebuild
                      if (_vocabularyDataLoaded && _categorizedItems.isNotEmpty && _selectedCategory != null) ...[
                        () {
                          final itemCount = _categorizedItems[_selectedCategory!]?.length ?? 0;
                          print("DEBUG: Building vocabulary dropdown for category: $_selectedCategory with $itemCount items");
                          print("DEBUG: Vocabulary dropdown key: vocab_$_selectedCategory");
                          
                          return Column(
                            children: [
                              const SizedBox(height: 12),
                              DropdownButtonFormField<Map<String, dynamic>>(
                                key: ValueKey('vocab_$_selectedCategory'),
                                decoration: const InputDecoration(
                                  labelText: 'Select Item...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                isExpanded: true,
                                value: _selectedVocabularyItem,
                                items: (_categorizedItems[_selectedCategory!] ?? []).map((item) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: item,
                                    child: Text(
                                      '${item['thai'] ?? item['target'] ?? ''} - ${item['english']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (selectedItem) {
                                  print("DEBUG: Vocabulary item selected: ${selectedItem?['english']}");
                                  localSetState(() {
                                    _selectedVocabularyItem = selectedItem;
                                  });
                                  if (selectedItem != null) {
                                    _handleWordSelection(selectedItem, dialogContext, targetLanguage);
                                  }
                                },
                              ),
                            ],
                          );
                        }(),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('OR'),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Custom translation section
        Expanded(
          child: _buildCustomItemTracing(dialogContext, targetLanguage),
        ),
      ],
    );
  }


  Widget _buildCustomItemTracing(BuildContext dialogContext, String targetLanguage) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Translate and trace any word:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _customItemController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter English word...',
                  suffixIcon: ValueListenableBuilder<bool>(
                    valueListenable: _customItemIsLoadingNotifier,
                    builder: (context, isLoading, child) {
                      return IconButton(
                        icon: isLoading 
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                          : Icon(Icons.language),
                        onPressed: isLoading ? null : () => _translateCustomItem(targetLanguage),
                      );
                    },
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (value) {
                  if (!_customItemIsLoadingNotifier.value) {
                    _translateCustomItem(targetLanguage);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: _customItemDataNotifier,
              builder: (context, itemData, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _customItemIsLoadingNotifier,
                  builder: (context, isLoading, child) {
                    if (isLoading && itemData == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Processing your word...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }
                    if (itemData == null) {
                      return Center(
                        child: Text(
                          'Enter a word above to see translation',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    
                    return SingleChildScrollView(
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Translation:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Center(
                                child: Text(
                                  itemData['target'] ?? itemData['thai'] ?? '',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 8),
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      itemData['english'] ?? '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      itemData['transliteration'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              // Only show Trace Character button for custom translations
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _startCharacterTracing(itemData, dialogContext, targetLanguage),
                                  icon: Icon(Icons.edit, size: 18),
                                  label: Text('Trace Character', style: TextStyle(fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4ECCA3),
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }


  // --- Quick Select and Character Display Methods ---
  


  // --- Multi-character Navigation and Helper Methods ---
  
  void _handleWordSelection(Map<String, dynamic> selectedItem, BuildContext dialogContext, String targetLanguage) {
    // Directly start character tracing instead of showing middle popup
    _startCharacterTracing(selectedItem, dialogContext, targetLanguage);
  }
  
  void _previousCharacter() {
    if (_currentCharacterIndex > 0) {
      setState(() {
        _currentCharacterIndex--;
      });
      _clearCanvas();
      // Update the tracing area with the new character
      _updateTracingArea();
    }
  }
  
  void _nextCharacter() {
    if (_currentCharacterIndex < _currentWordMapping.length - 1) {
      setState(() {
        _currentCharacterIndex++;
      });
      _clearCanvas();
      // Update the tracing area with the new character
      _updateTracingArea();
    }
  }
  
  void _updateTracingArea() {
    // Trigger a rebuild of the tracing area with the new character
    setState(() {});
  }
  
  Map<String, dynamic> _getCurrentCharacter() {
    if (_currentWordMapping.isNotEmpty && _currentCharacterIndex < _currentWordMapping.length) {
      return _currentWordMapping[_currentCharacterIndex];
    }
    return {'thai': '', 'transliteration': '', 'translation': '', 'english': ''};
  }
  
  void _showCharacterWritingTips(Map<String, dynamic> character) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Writing Tips: ${character['thai']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Character: ${character['thai']}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Sound: ${character['transliteration']}'),
              Text('Meaning: ${character['translation'] ?? character['english']}'),
              const SizedBox(height: 16),
              const Text(
                'Thai Writing Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Start with circular elements'),
              const Text('• Write vowels after consonants'),
              const Text('• Top-to-bottom, left-to-right'),
              const Text('• Keep strokes smooth and flowing'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showCharacterPronunciationTips(Map<String, dynamic> character) {
    final thaiChar = character['thai'] ?? '';
    final transliteration = character['transliteration'] ?? character['romanized'] ?? '';
    final translation = character['translation'] ?? character['english'] ?? '';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1F1F1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4ECCA3).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Character display
                Row(
                  children: [
                    Text(
                      thaiChar,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4ECCA3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (transliteration.isNotEmpty)
                            Text(
                              transliteration,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          if (translation.isNotEmpty)
                            Text(
                              translation,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Pronunciation tips
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.record_voice_over,
                            color: Color(0xFF4ECCA3),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pronunciation Tips',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4ECCA3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getCharacterSpecificPronunciationTips(thaiChar, transliteration),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECCA3),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
  
  String _getCharacterSpecificPronunciationTips(String thaiChar, String transliteration) {
    // Return character-specific pronunciation guidance
    switch (thaiChar) {
      case 'ก':
        return 'Pronounced like "k" in "cat". Keep your tongue at the back and make a sharp, crisp sound without breathing out.';
      case 'ข':
        return 'Like "kh" - similar to "k" but with a puff of air. Place your tongue at the back and exhale slightly.';
      case 'ค':
        return 'Another "kh" sound, identical to ข. Practice the difference through context and listening.';
      case 'ง':
        return 'Like "ng" in "sing". This sound can start Thai syllables, unlike in English where it only ends words.';
      case 'จ':
        return 'Like "j" in "jump". Touch your tongue to the roof of your mouth and release with voice.';
      case 'ฉ':
        return 'Like "ch" in "church" but with more air. Similar to จ but unvoiced and breathy.';
      case 'ช':
        return 'Also like "ch" in "church". Practice distinguishing from ฉ through listening.';
      case 'ซ':
        return 'Like "s" in "sun". Keep your tongue behind your teeth and let air flow smoothly.';
      case 'ด':
        return 'Like "d" in "dog". Touch your tongue tip to the roof of your mouth briefly.';
      case 'ต':
        return 'Like "t" in "top". Similar to ด but without voice - just a quick tongue tap.';
      case 'ท':
        return 'Like "th" in "top" with aspiration. Touch tongue tip to teeth and release with air.';
      case 'น':
        return 'Like "n" in "no". Touch your tongue tip to the roof of your mouth and hum.';
      case 'บ':
        return 'Like "b" in "big". Press your lips together and release with voice.';
      case 'ป':
        return 'Like "p" in "pat". Similar to บ but without voice - just lip release.';
      case 'ผ':
        return 'Like "ph" in "phone" but as one sound. Not "p" + "h" but a single aspirated "p".';
      case 'ฝ':
        return 'Like "f" in "food". Place your bottom lip against your top teeth and blow air.';
      case 'พ':
        return 'Another "ph" sound, identical to ผ. Listen for context differences.';
      case 'ฟ':
        return 'Another "f" sound, identical to ฝ. Practice distinguishing through context.';
      case 'ม':
        return 'Like "m" in "mom". Close your lips and hum with your nose.';
      case 'ย':
        return 'Like "y" in "yes". Keep your tongue relaxed and glide into the next sound.';
      case 'ร':
        return 'Rolled "r" like Spanish. Tap your tongue tip against the roof lightly and rapidly.';
      case 'ล':
        return 'Like "l" in "love". Touch your tongue tip to the roof and let air flow around sides.';
      case 'ว':
        return 'Like "w" in "water". Round your lips and glide into the next sound.';
      case 'ส':
        return 'Like "s" in "sun". Keep airflow smooth and tongue behind teeth.';
      case 'ห':
        return 'Like "h" in "house". Breathe out gently - it\'s just air flow.';
      case 'อ':
        return 'A glottal stop - like the pause in "uh-oh". Brief closure in your throat.';
      default:
        if (transliteration.contains('th')) {
          return 'For "th" sounds: Touch your tongue tip to your teeth and breathe out gently. Not like English "th".';
        } else if (transliteration.contains('ph')) {
          return 'For "ph" sounds: Like "p" with a puff of air, not an "f" sound. One unified sound.';
        } else if (transliteration.contains('ng')) {
          return 'For "ng" sounds: Like the end of "sing" but can start Thai syllables. Practice holding the sound.';
        } else {
          return 'Listen carefully to native pronunciation. Thai has 5 tones, so pitch changes meaning. Practice with tone awareness.';
        }
    }
  }

  Color _getRecognitionFeedbackColor() {
    final currentChar = _getCurrentCharacter();
    final expectedChar = currentChar['thai'] ?? '';
    
    if (_lastRecognitionResult.isEmpty) {
      return Colors.grey[100]!;
    } else if (_lastRecognitionResult == expectedChar) {
      return Colors.green[100]!;
    } else if (_lastRecognitionResult == 'Not recognized') {
      return Colors.orange[100]!;
    } else {
      return Colors.red[100]!;
    }
  }
  
  String _getRecognitionFeedbackText() {
    final currentChar = _getCurrentCharacter();
    final expectedChar = currentChar['thai'] ?? '';
    
    if (_lastRecognitionResult.isEmpty) {
      return 'Ready to trace...';
    } else if (_lastRecognitionResult == expectedChar) {
      return '✓ Perfect! Character traced correctly!';
    } else if (_lastRecognitionResult == 'Not recognized') {
      return '? Character not recognized. Try again.';
    } else {
      return '✗ Recognized: $_lastRecognitionResult (Expected: $expectedChar)';
    }
  }

  IconData _getRecognitionFeedbackIcon() {
    final currentChar = _getCurrentCharacter();
    final expectedChar = currentChar['thai'] ?? '';
    
    if (_lastRecognitionResult.isEmpty) {
      return Icons.edit;
    } else if (_lastRecognitionResult == expectedChar) {
      return Icons.check_circle;
    } else if (_lastRecognitionResult == 'Not recognized') {
      return Icons.help_outline;
    } else {
      return Icons.error_outline;
    }
  }

  Color _getRecognitionFeedbackIconColor() {
    final currentChar = _getCurrentCharacter();
    final expectedChar = currentChar['thai'] ?? '';
    
    if (_lastRecognitionResult.isEmpty) {
      return Colors.grey[600]!;
    } else if (_lastRecognitionResult == expectedChar) {
      return Colors.green[600]!;
    } else if (_lastRecognitionResult == 'Not recognized') {
      return Colors.orange[600]!;
    } else {
      return Colors.red[600]!;
    }
  }
  
  bool _canGiveItem() {
    // Check if all characters in the word have been completed
    for (int i = 0; i < _currentWordMapping.length; i++) {
      if (!(_characterCompletionStatus[i] ?? false)) {
        return false;
      }
    }
    return _currentWordMapping.isNotEmpty;
  }
  
  String _getSubmitButtonText() {
    if (_currentWordMapping.length <= 1) {
      return _characterCompletionStatus[0] ?? false ? 'Give Item' : 'Complete Tracing';
    }
    
    final completedCount = _characterCompletionStatus.values.where((v) => v).length;
    if (completedCount == _currentWordMapping.length) {
      return 'Give Item';
    } else {
      return 'Complete All Characters ($completedCount/${_currentWordMapping.length})';
    }
  }
  

  // --- Helper Methods for Item Giving ---
  

  Future<List<Map<String, dynamic>>> _fetchNPCVocabulary() async {
    try {
      final String npcId = widget.npcId.toLowerCase();
      final String fileName = 'npc_vocabulary_$npcId.json';
      
      final String jsonString = await DefaultAssetBundle.of(context).loadString('assets/data/$fileName');
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      return List<Map<String, dynamic>>.from(data['vocabulary'] ?? []);
    } catch (e) {
      print("Error loading NPC vocabulary: $e");
      return [];
    }
  }

  Future<void> _loadAndCategorizeVocabulary() async {
    if (_vocabularyDataLoaded) {
      print("DEBUG: Vocabulary data already loaded, skipping");
      return;
    }

    try {
      print("DEBUG: Loading and categorizing vocabulary data");
      final items = await _fetchNPCVocabulary();
      
      if (items.isEmpty) {
        print("DEBUG: No vocabulary items found");
        return;
      }

      // Group items by category and store in class variable
      _categorizedItems.clear();
      for (final item in items) {
        final category = item['category'] ?? 'Uncategorized';
        _categorizedItems.putIfAbsent(category, () => []).add(item);
      }
      
      _vocabularyDataLoaded = true;
      print("DEBUG: Vocabulary categorized into ${_categorizedItems.keys.length} categories: ${_categorizedItems.keys.toList()}");
      
      // Trigger rebuild to show categories
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      print("ERROR: Failed to load and categorize vocabulary: $error");
      // Reset state on error
      _vocabularyDataLoaded = false;
      _categorizedItems.clear();
      rethrow; // Let FutureBuilder handle the error display
    }
  }

  /// Builds the category dropdown widget
  Widget _buildCategoryDropdown() {
    print("DEBUG: Building category dropdown (method called)");
    
    if (!_vocabularyDataLoaded || _categorizedItems.isEmpty) {
      print("DEBUG: Category dropdown not ready - vocabularyLoaded: $_vocabularyDataLoaded, items: ${_categorizedItems.length}");
      return const SizedBox.shrink();
    }

    final categories = _categorizedItems.keys.toList()..sort();
    print("DEBUG: Category dropdown ready - Categories: $categories, Selected: $_selectedCategory");
    
    return DropdownButtonFormField<String>(
      key: ValueKey('category_dropdown_${_categorizedItems.length}'),
      decoration: const InputDecoration(
        labelText: 'Select Category...',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      value: _selectedCategory,
      items: categories.map((category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(
            category,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (selectedCategory) {
        print("DEBUG: Category selected: $selectedCategory");
        setState(() {
          _selectedCategory = selectedCategory;
          _selectedVocabularyItem = null; // Reset item selection when category changes
        });
        print("DEBUG: State updated. Selected category: $_selectedCategory, Available items: ${_categorizedItems[selectedCategory]?.length ?? 0}");
      },
    );
  }

  /// Builds the vocabulary dropdown widget
  Widget _buildVocabularyDropdown(BuildContext dialogContext, String targetLanguage) {
    print("DEBUG: Building vocabulary dropdown (method called) - Selected category: $_selectedCategory");
    
    if (_selectedCategory == null) {
      print("DEBUG: No category selected, returning empty widget");
      return const SizedBox.shrink();
    }
    
    final itemCount = _categorizedItems[_selectedCategory!]?.length ?? 0;
    print("DEBUG: Vocabulary dropdown for category: $_selectedCategory with $itemCount items");
    
    if (itemCount == 0) {
      print("DEBUG: No vocabulary items found for category: $_selectedCategory");
      return const SizedBox.shrink();
    }
    
    print("DEBUG: Creating vocabulary dropdown widget");
    
    return Column(
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<Map<String, dynamic>>(
          key: ValueKey('vocab_dropdown_$_selectedCategory'),
          decoration: const InputDecoration(
            labelText: 'Select Item...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isExpanded: true,
          value: _selectedVocabularyItem,
          items: (_categorizedItems[_selectedCategory!] ?? []).map((item) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: item,
              child: Text(
                '${item['thai'] ?? item['target'] ?? ''} - ${item['english']}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (selectedItem) {
            print("DEBUG: Vocabulary item selected: ${selectedItem?['english']}");
            setState(() {
              _selectedVocabularyItem = selectedItem;
            });
            if (selectedItem != null) {
              _handleWordSelection(selectedItem, dialogContext, targetLanguage);
            }
          },
        ),
      ],
    );
  }

  Future<void> _translateCustomItem(String targetLanguage) async {
    final String englishText = _customItemController.text.trim();
    if (englishText.isEmpty) return;

    _customItemIsLoadingNotifier.value = true;

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/gcloud-translate-tts/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'english_text': englishText,
          'target_language': targetLanguage
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Transform word_mappings from backend format to app format, handling compound words
        List<Map<String, dynamic>> transformedMappings = [];
        if (data['word_mappings'] != null) {
          for (var mapping in data['word_mappings'] as List) {
            final isCompound = mapping['is_compound'] == true;
            final wordTranslation = mapping['translation'] as String? ?? '';
            
            if (mapping['syllable_mappings'] != null && (mapping['syllable_mappings'] as List).isNotEmpty) {
              for (var syl in mapping['syllable_mappings']) {
                String syllableTranslation;
                
                if (isCompound) {
                  // For compound words, show contextual translation like "(part of Korea)"
                  syllableTranslation = '(part of $wordTranslation)';
                } else {
                  // For non-compound words, show individual syllable translation
                  syllableTranslation = syl['translation'] as String? ?? '';
                }
                
                transformedMappings.add({
                  'target': syl['syllable'] ?? '',
                  'transliteration': syl['romanization'] ?? '',
                  'translation': syllableTranslation,
                  'is_compound': isCompound,
                  'word_translation': wordTranslation, // Keep the full word translation for reference
                });
              }
            } else {
              transformedMappings.add({
                'target': mapping['target'] ?? '',
                'transliteration': mapping['romanized'] ?? '',
                'translation': wordTranslation,
                'is_compound': isCompound,
                'word_translation': wordTranslation,
              });
            }
          }
        }
        
        // Format the data for item giving and character tracing
        print('DEBUG: API response structure: ${data.keys.toList()}');
        print('DEBUG: target_text: ${data['target_text']}');
        print('DEBUG: romanized_text: ${data['romanized_text']}');
        
        _customItemDataNotifier.value = {
          'target': data['target_text'] ?? '',            // Fixed: was 'translated_text'
          'thai': data['target_text'] ?? '',              // Fixed: was 'translated_text'
          'transliteration': data['romanized_text'] ?? '', // Fixed: was 'transliteration'
          'translation': englishText,
          'english': englishText,
          'audio_path': data['audio_base64'] ?? '', // This will be base64 data for custom items
          'target_language': targetLanguage,
          'syllable_mapping': transformedMappings,
          'word_mapping': transformedMappings, // Use same data for both
        };
        
        print('Custom item processed: ${_customItemDataNotifier.value}');
      } else {
        print('Translation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Translation error: $e');
    } finally {
      _customItemIsLoadingNotifier.value = false;
    }
  }

  Future<void> _translateForTracing(String targetLanguage) async {
    // Use the same translation logic as _translateCustomItem since it now provides word_mapping
    await _translateCustomItem(targetLanguage);
  }

  Future<void> _startDirectCharacterTracing(Map<String, dynamic> itemData, BuildContext dialogContext, String targetLanguage) async {
    Navigator.of(dialogContext).pop(); // Close translation dialog
    
    // Clear any previous ink strokes
    _ink.strokes.clear();
    _currentStroke = null;
    
    // Start downloading Thai model if not already downloaded
    if (!_isModelDownloaded) {
      _downloadThaiModel();
    }
    
    // Show character tracing dialog - goes directly to tracing without returning to tabs
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _buildDirectCharacterTracingDialog(itemData, targetLanguage),
    );
  }

  Widget _buildDirectCharacterTracingDialog(Map<String, dynamic> itemData, String targetLanguage) {
    // Parse word mapping for canvas splitting
    final wordMapping = List<Map<String, dynamic>>.from(itemData['word_mapping'] ?? [itemData]);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: CharacterTracingWidget(
        wordMapping: wordMapping,
        originalVocabularyItem: itemData, // Pass original item for audio_path
        onBack: () {
          Navigator.of(context).pop(); // Close character tracing
          // Return to language tools dialog with Trace Chars tab selected
          _showEnglishToTargetLanguageTranslationDialog(context, targetLanguage: targetLanguage, initialTabIndex: 2);
        },
        onComplete: () {
          Navigator.of(context).pop(); // Close character tracing
          // Show completion message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Character tracing completed!'),
              backgroundColor: Color(0xFF4ECCA3),
            ),
          );
        },
        showBackButton: true,
        showWritingTips: true,
      ),
    );
  }

  Future<void> _startCharacterTracing(Map<String, dynamic> itemData, BuildContext dialogContext, String targetLanguage) async {
    Navigator.of(dialogContext).pop(); // Close translation dialog
    
    // Show tutorial for first-time character tracing users
    final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
    if (!tutorialProgressNotifier.isStepCompleted('character_tracing_tutorial')) {
      final tutorialManager = TutorialManager(
        context: context,
        ref: ref,
        npcId: widget.npcId,
      );
      
      // Show character tracing tutorial
      await tutorialManager.startTutorial(TutorialTrigger.firstCharacterTracing);
    }
    
    // Clear any previous ink strokes
    _ink.strokes.clear();
    _currentStroke = null;
    
    // Start downloading Thai model if not already downloaded
    if (!_isModelDownloaded) {
      _downloadThaiModel();
    }
    
    // Show character tracing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _buildCharacterTracingDialog(itemData, targetLanguage),
    );
  }

  /// Helper method to map vocabulary format to app format
  Map<String, dynamic> _mapVocabularyToAppFormat(Map<String, dynamic> vocabItem) {
    print('DEBUG _mapVocabularyToAppFormat input: ${vocabItem.keys}');
    print('DEBUG vocabItem[english] = ${vocabItem['english']}');
    
    return {
      ...vocabItem,
      'target': vocabItem['thai'] ?? vocabItem['target'], // Support both formats
      'english': vocabItem['english'] ?? vocabItem['translation'], // Preserve english field
      'audio_path': vocabItem['audio_path'], // Preserve audio_path field
      'target_language': 'th', // Will be dynamic in future
      'azure_pron_mapping': vocabItem['azure_pron_mapping']?.map<Map<String, dynamic>>((item) => {
        'target': item['thai'] ?? item['target'],
        'transliteration': item['transliteration'],
        'translation': item['translation'],
        'english': vocabItem['english'], // Add the parent english field to each azure pronunciation mapping
        'audio_path': item['audio_path'], // Preserve audio_path in mappings too
      }).toList(),
      'word_mapping': vocabItem['word_mapping']?.map<Map<String, dynamic>>((item) => {
        'target': item['thai'] ?? item['target'],
        'transliteration': item['transliteration'],
        'translation': item['translation'],
        'english': vocabItem['english'], // Add the parent english field to each word mapping
        'audio_path': item['audio_path'], // Preserve audio_path in mappings too
      }).toList(),
      'syllable_mapping': vocabItem['syllable_mapping']?.map<Map<String, dynamic>>((item) => {
        'target': item['thai'] ?? item['target'],
        'transliteration': item['transliteration'],
        'translation': item['translation'],
        'english': vocabItem['english'], // Add the parent english field to each syllable mapping
        'audio_path': item['audio_path'], // Preserve audio_path in mappings too
      }).toList(),
    };
  }

  Widget _buildCharacterTracingDialog(Map<String, dynamic> itemData, String targetLanguage) {
    // Map vocabulary format to app format
    final mappedItemData = _mapVocabularyToAppFormat(itemData);
    
    // Use syllable boundaries from syllable_mapping for NPC vocabulary, fallback to word_mapping
    List<Map<String, dynamic>> wordMapping;
    
    if (mappedItemData['syllable_mapping'] != null && mappedItemData['syllable_mapping'] is List) {
      // Prioritize syllable_mapping for NPC vocabulary words (better granularity for tracing)
      wordMapping = List<Map<String, dynamic>>.from(mappedItemData['syllable_mapping']);
      print('Using syllable_mapping for tracing: ${wordMapping.length} syllables');
    } else if (mappedItemData['word_mapping'] != null && mappedItemData['word_mapping'] is List) {
      // Use the semantic word breakdown for tracing (e.g., เครื่องปรุง → เครื่อง, ปรุง)
      wordMapping = List<Map<String, dynamic>>.from(mappedItemData['word_mapping']);
      print('Using word_mapping for tracing: ${wordMapping.length} words');
    } else if (mappedItemData['target'] != null && mappedItemData['target'].toString().isNotEmpty) {
      // Fallback: create mapping with the full word
      final fullWordMapping = {
        'target': mappedItemData['target'],
        'transliteration': mappedItemData['transliteration'] ?? '',
        'translation': mappedItemData['english'] ?? '',
      };
      wordMapping = [fullWordMapping];
      print('Using fallback single word mapping for tracing');
    } else {
      // Final fallback
      wordMapping = [mappedItemData];
      print('Using final fallback mapping for tracing');
    }
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: CharacterTracingWidget(
        wordMapping: wordMapping,
        originalVocabularyItem: mappedItemData, // Pass mapped item for audio_path
        onBack: () {
          Navigator.of(context).pop(); // Close character tracing
          // Show language tools dialog with Give Item tab selected
          _showEnglishToTargetLanguageTranslationDialog(context, targetLanguage: 'th', initialTabIndex: 1);
        },
        onComplete: () => _submitTracing(itemData, targetLanguage),
        showBackButton: true,
        showWritingTips: true,
      ),
    );
  }

  Widget _buildCombinedTracingArea(String targetCharacter) {
    _targetCharacter = targetCharacter;
    final currentChar = _getCurrentCharacter();
    final transliteration = currentChar['transliteration'] ?? currentChar['romanized'] ?? '';
    final translation = currentChar['translation'] ?? currentChar['english'] ?? '';
    
    // Improved font size calculation that's more responsive to container size
    // Base the calculation on both character length and available space
    double characterFontSize = 180; // Reduced base size
    
    // Adjust based on character length with more granular control
    if (targetCharacter.length > 5) {
      characterFontSize = 80; // Much smaller for very long words
    } else if (targetCharacter.length > 3) {
      characterFontSize = 100; // Smaller for longer words  
    } else if (targetCharacter.length > 2) {
      characterFontSize = 140; // Medium for multi-character
    } else if (targetCharacter.length > 1) {
      characterFontSize = 160; // Slightly smaller for 2-character words
    }
    
    // Additional check for complex characters (with tone marks, vowels)
    if (_isComplexCharacter(targetCharacter)) {
      characterFontSize *= 0.8; // Reduce by 20% for complex characters
    }
    
    return Stack(
      children: [
        // Background with character guide using app styles
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F1F1F), // app_styles primary
                const Color(0xFF2D2D2D), // app_styles secondary
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain, // Ensure text always fits within bounds
              child: Padding(
                padding: const EdgeInsets.all(20.0), // Add padding to prevent edge clipping
                child: Text(
                  targetCharacter,
                  style: TextStyle(
                    fontSize: characterFontSize,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF4ECCA3).withOpacity(0.15), // app_styles accent with opacity
                    shadows: [
                      Shadow(
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                        color: const Color(0xFF4ECCA3).withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Transliteration and translation overlay (semi-transparent)
        if (transliteration.isNotEmpty || translation.isNotEmpty)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF4ECCA3).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (transliteration.isNotEmpty)
                    Text(
                      transliteration,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4ECCA3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (translation.isNotEmpty)
                    Text(
                      translation,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        // Digital ink drawing area with real-time preview
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _InkPainter(_ink, currentStrokePoints: _currentStrokePoints),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }

  Widget _buildTracingCanvas(String targetCharacter) {
    _targetCharacter = targetCharacter;
    
    return Stack(
      children: [
        // Background with character guide (IMPROVED VISIBILITY)
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[50]!, Colors.blue[100]!],
            ),
          ),
          child: Center(
            child: Text(
              targetCharacter,
              style: TextStyle(
                fontSize: 150,
                fontWeight: FontWeight.w200,
                color: Colors.blue[200],
                shadows: [
                  Shadow(
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.blue[100]!,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Digital ink drawing area
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            key: ValueKey('ink_canvas_${_ink.strokes.length}_${_currentStrokePoints.length}'),
            painter: _InkPainter(_ink, currentStrokePoints: _currentStrokePoints),
            size: Size.infinite,
          ),
        ),
        // Top-right corner info
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Trace: $targetCharacter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isModelDownloaded ? Icons.check_circle : Icons.downloading,
                      size: 16,
                      color: _isModelDownloaded ? Colors.green : Colors.orange,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _isModelDownloaded ? 'Ready' : 'Loading model...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordTracingArea(String targetWord, Map<String, dynamic> wordData) {
    _targetCharacter = targetWord;
    final transliteration = wordData['transliteration'] ?? wordData['romanized'] ?? '';
    final translation = wordData['translation'] ?? wordData['english'] ?? '';
    
    // Calculate font size based on word length for better readability
    double wordFontSize = 200; // Start with larger base size
    
    // Adjust based on word length
    if (targetWord.length > 8) {
      wordFontSize = 60; // Very small for extremely long words
    } else if (targetWord.length > 6) {
      wordFontSize = 80; // Small for long words
    } else if (targetWord.length > 4) {
      wordFontSize = 120; // Medium for moderate words
    } else if (targetWord.length > 2) {
      wordFontSize = 160; // Large for short words
    }
    // Single characters or very short words keep the largest size (200)
    
    return Stack(
      children: [
        // Word display background with subtle border
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1F1F1F),
                Color(0xFF2D2D2D),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF4ECCA3).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  targetWord,
                  style: TextStyle(
                    fontSize: wordFontSize,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF4ECCA3).withOpacity(0.15),
                    shadows: [
                      Shadow(
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                        color: const Color(0xFF4ECCA3).withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Transliteration and translation overlay with info icon
        if (transliteration.isNotEmpty || translation.isNotEmpty)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF4ECCA3).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (transliteration.isNotEmpty)
                          Text(
                            transliteration,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4ECCA3),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        if (translation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              translation,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Pronunciation tips info icon
                  GestureDetector(
                    onTap: () => _showCharacterPronunciationTips(wordData),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECCA3).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF4ECCA3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Drawing area overlay - Using working approach from test widget
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _InkPainter(_ink, currentStrokePoints: _currentStrokePoints),
            size: Size.infinite,
          ),
        ),

      ],
    );
  }

  void _showWritingTipsTooltip(BuildContext context) {
    final character = _getCurrentCharacter()['thai'] ?? '';
    final transliteration = _getCurrentCharacter()['transliteration'] ?? '';
    final english = _getCurrentCharacter()['english'] ?? '';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1F1F1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4ECCA3).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Character display
                Row(
                  children: [
                    Text(
                      character,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4ECCA3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transliteration,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            english,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Writing tips
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: SizedBox(
                    height: 300, // Set max height for scrollable area
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: const Color(0xFF4ECCA3),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Writing Tips',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4ECCA3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<String>(
                            future: _getCharacterSpecificTips(character),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Text(
                                  'Loading character analysis...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                );
                              }
                              return Text(
                                snapshot.data ?? 'General tip: Start with circles, write vowels after consonants, keep strokes smooth and flowing.',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'General Thai Writing Principles:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '• Write from top to bottom, left to right\n• Complete circles and curves first\n• Keep strokes smooth and flowing\n• Practice consistent character size',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECCA3),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  Future<void> _submitTracing(Map<String, dynamic> itemData, String targetLanguage) async {
    print("Starting item submission process for traced item: ${itemData['english']}");
    
    // Check if widget is still mounted before proceeding
    if (!mounted) {
      print("Widget disposed, cancelling _submitTracing");
      return;
    }
    
    try {
      // First ensure Thai model is downloaded
      if (!_isModelDownloaded) {
        await _downloadThaiModel();
      }
      
      // Process the traced character with ML Kit Digital Ink Recognition
      await _recognizeCharacter();
      
      // Now send the completed item to backend via GIVE_ITEM pipeline
      // Start both dialog closure and backend processing concurrently for minimal latency
      _sendItemToBackendConcurrent(itemData, targetLanguage);
    } catch (e) {
      print("Error during tracing submission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit item: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _sendItemToBackend(Map<String, dynamic> itemData, String targetLanguage) async {
    print("Sending completed item to backend: ${itemData['english']}");
    
    // Check if widget is still mounted before proceeding
    if (!mounted) {
      print("Widget disposed, cancelling _sendItemToBackend");
      return;
    }
    
    setState(() { _isProcessingBackend = true; });

    try {
      // Construct conversation history for the backend
      final currentFullHistory = ref.read(fullConversationHistoryProvider(widget.npcId));
      List<String> historyLinesForBackend = [];
      
      for (var entry in currentFullHistory) {
        if (entry.isNpc) {
          historyLinesForBackend.add("NPC: ${entry.text}");
        } else {
          String playerContent = entry.playerTranscriptionForHistory ?? entry.text;
          historyLinesForBackend.add("Player: $playerContent");
        }
      }

      String previousHistoryPayload = historyLinesForBackend.join('\n');
      
      // Get current charm level
      final int currentCharmLevel = ref.read(currentCharmLevelProvider(widget.npcId));
      int charmLevelForRequest = math.max(0, math.min(100, currentCharmLevel));

      // Prepare GIVE_ITEM request data
      final String itemName = itemData['english'] ?? 'Unknown Item';
      final String thaiName = itemData['thai'] ?? itemData['target'] ?? '';
      
      // Send GIVE_ITEM request to backend
      var uri = Uri.parse('http://127.0.0.1:8000/generate-npc-response/');
      var request = http.MultipartRequest('POST', uri)
        ..fields['npc_id'] = _npcData.id
        ..fields['npc_name'] = _npcData.name
        ..fields['charm_level'] = charmLevelForRequest.toString()
        ..fields['previous_conversation_history'] = previousHistoryPayload
        ..fields['action_type'] = 'GIVE_ITEM'
        ..fields['action_item'] = thaiName  // Send Thai text only
        ..fields['custom_message'] = 'User gives $itemName to ${_npcData.name}'  // Proper format for conversation history
        ..fields['quest_state_json'] = '{}' // TODO: Implement quest state tracking
        ..fields['user_id'] = PostHogService.userId ?? 'unknown_user'
        ..fields['session_id'] = PostHogService.sessionId ?? 'unknown_session';

      print('Sending GIVE_ITEM request to backend for item: $thaiName ($itemName)');
      var response = await request.send();
      
      if (response.statusCode == 200) {
        print('GIVE_ITEM request succeeded with status: ${response.statusCode}');
        
        // Read the response body (audio bytes)
        var responseBytes = await response.stream.toBytes();
        
        // Extract NPC response metadata from headers
        var npcResponseDataHeader = response.headers['x-npc-response-data'];
        if (npcResponseDataHeader == null) {
          throw Exception('Missing NPC response data in headers');
        }
        
        var npcResponseDataJson = utf8.decode(base64.decode(npcResponseDataHeader));
        var responsePayload = json.decode(npcResponseDataJson);
        
        String playerMessage = 'User gives $itemName to ${_npcData.name}'; // Use English message instead of Thai input_target
        String npcText = responsePayload['response_target'] ?? 'Thank you for the item!';
        String englishTranslation = responsePayload['response_english'] ?? '';
        
        List<POSMapping> npcPosMappings = (responsePayload['response_mapping'] as List<dynamic>?)
          ?.map((mapping) => POSMapping.fromJson(mapping))
          .toList() ?? [];
        
        List<POSMapping> playerInputMappings = (responsePayload['input_mapping'] as List<dynamic>?)
          ?.map((mapping) => POSMapping.fromJson(mapping))
          .toList() ?? [];
        
        int charmDelta = responsePayload['charm_delta'] ?? 0;
        String charmReason = responsePayload['charm_reason'] ?? '';

        // Update charm level
        if (charmDelta != 0 && mounted) {
          ref.read(currentCharmLevelProvider(widget.npcId).notifier).update((current) => 
            math.max(0, math.min(100, current + charmDelta))
          );
        }

        // Create dialogue entries
        final String playerId = DateTime.now().millisecondsSinceEpoch.toString() + '_player';
        final String npcId = DateTime.now().millisecondsSinceEpoch.toString() + '_npc';

        final playerEntry = DialogueEntry(
          customId: playerId,
          text: 'User gives $itemName to ${_npcData.name}',
          englishText: '',
          speaker: 'Player',
          audioPath: null, // No audio for item giving
          audioBytes: null,
          isNpc: false,
          posMappings: playerInputMappings,
          playerTranscriptionForHistory: playerMessage,
        );

        final npcEntry = DialogueEntry(
          customId: npcId,
          text: npcText,
          englishText: englishTranslation,
          speaker: _npcData.name,
          audioPath: null,
          audioBytes: responseBytes,
          isNpc: true,
          posMappings: npcPosMappings,
          playerTranscriptionForHistory: null,
        );

        // Add entries to conversation history
        final fullHistoryNotifier = ref.read(fullConversationHistoryProvider(widget.npcId).notifier);
        fullHistoryNotifier.update((history) => [...history, playerEntry, npcEntry]);

        print("GIVE_ITEM response successfully processed and added to conversation");
        
        // Clear stale text cache entries to ensure fresh display
        _fullyAnimatedMainNpcTexts.clear();
        
        // Set current NPC display entry for the main box and start animation
        print("DEBUG: Setting currentNpcDisplayEntry for GIVE_ITEM - ID: ${npcEntry.id}, hasAudio: ${npcEntry.audioBytes?.isNotEmpty == true}");
        ref.read(currentNpcDisplayEntryProvider.notifier).state = npcEntry;
        _startNpcTextAnimation(
          idForAnimation: npcId, // Pass the pre-generated ID
          speakerName: _npcData.name, // Pass speaker name
          fullText: npcText,
          englishText: englishTranslation,
          audioPathToPlayWhenDone: null, // No temp audio path for GIVE_ITEM
          audioBytesToPlayWhenDone: responseBytes, // Pass audio bytes
          posMappings: npcPosMappings,
          charmDelta: charmDelta, // Use actual backend charm data
          charmReason: charmReason, // Use actual backend charm reason
          justReachedMaxCharm: ref.read(currentCharmLevelProvider(widget.npcId)) >= 100,
          onAnimationComplete: (finalAnimatedEntry) {
            // Update the display provider with the final animated entry
            ref.read(currentNpcDisplayEntryProvider.notifier).state = finalAnimatedEntry;
            // Also update the text map for correct display on rebuild
            _fullyAnimatedMainNpcTexts[finalAnimatedEntry.id] = finalAnimatedEntry.text;
          }
        );
        
        // Note: Dialog closure is handled concurrently by _sendItemToBackendConcurrent

      } else {
        String responseBody = await response.stream.bytesToString();
        throw Exception('Backend returned ${response.statusCode}: $responseBody');
      }
      
    } catch (e, stackTrace) {
      print("Exception in _sendItemToBackend: $e\n$stackTrace");
      if (mounted) {
        _showErrorDialog("Failed to send item to NPC: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() { _isProcessingBackend = false; });
      }
    }
  }

  void _sendItemToBackendConcurrent(Map<String, dynamic> itemData, String targetLanguage) {
    // Close the remaining Language Tools dialog (Assessment + Character Tracing already closed via callbacks)
    if (mounted) {
      Navigator.of(context).pop(); // Close Language Tools dialog (safe - last dialog in chain)
    }
    
    // Track item giving
    PostHogService.trackNPCConversation(
      npcName: widget.npcId,
      event: 'item_given',
      additionalProperties: {
        'item_english': itemData['english'] ?? 'Unknown',
        'item_thai': itemData['thai'] ?? 'Unknown',
        'target_language': targetLanguage,
      },
    );
    
    // Start backend processing immediately (fire-and-forget)
    _sendItemToBackend(itemData, targetLanguage);
  }

  void _clearCanvas() {
    // Clear the digital ink canvas
    _ink.strokes.clear();
    _currentStroke = null;
    _currentStrokePoints.clear(); // CRITICAL: Clear real-time stroke points
    
    // Reset stroke order tracking
    _completedStrokes.clear();
    _currentStrokeCount = 0;
    _strokeSpeeds.clear();
    _strokeLengths.clear();
    _strokeOrderHints.clear();
    _strokeStartTime = null;
    
    // Clear last recognition result for this character
    _lastRecognitionResult = '';
    
    setState(() {});
  }

  void _undoLastStroke() {
    // Remove the last stroke if there are any strokes
    if (_ink.strokes.isNotEmpty) {
      _ink.strokes.removeLast();
      
      // Also remove from completed strokes tracking
      if (_completedStrokes.isNotEmpty) {
        _completedStrokes.removeLast();
      }
      
      // Decrement stroke count
      if (_currentStrokeCount > 0) {
        _currentStrokeCount--;
      }
      
      // Remove last stroke metrics if available
      if (_strokeLengths.isNotEmpty) {
        _strokeLengths.removeLast();
      }
      if (_strokeSpeeds.isNotEmpty) {
        _strokeSpeeds.removeLast();
      }
      
      // Clear current stroke points if any
      _currentStrokePoints.clear();
      
      // Clear last recognition result since the drawing has changed
      _lastRecognitionResult = '';
      
      setState(() {});
      print("Last stroke undone");
    }
  }

  // --- ML Kit Initialization and Methods ---
  
  void _initializeMLKit() {
    _modelManager = mlkit.DigitalInkRecognizerModelManager();
    _digitalInkRecognizer = mlkit.DigitalInkRecognizer(languageCode: 'th');
    // Check if model is already preloaded by the game
    _isModelDownloaded = widget.game.isMLKitModelReady;
  }

  Future<void> _downloadThaiModel() async {
    // Model should already be preloaded by the game
    _isModelDownloaded = widget.game.isMLKitModelReady;
    if (!_isModelDownloaded) {
      try {
        const String thaiModelIdentifier = 'th';
        final bool isDownloaded = await _modelManager.isModelDownloaded(thaiModelIdentifier);
        
        if (!isDownloaded) {
          final bool success = await _modelManager.downloadModel(thaiModelIdentifier);
          _isModelDownloaded = success;
          print("Thai model download result: $success");
        } else {
          _isModelDownloaded = true;
          print("Thai model already downloaded");
        }
      } catch (e) {
        print("Error downloading Thai model: $e");
        _isModelDownloaded = false;
      }
    }
  }

  // --- Touch Gesture Handlers for Drawing ---
  
  void _onPanStart(DragStartDetails details) {
    _currentStroke = mlkit.Stroke();
    _currentStrokePoints.clear();
    _strokeStartTime = DateTime.now();
    _currentStrokeCount++;
    
    final point = mlkit.StrokePoint(
      x: details.localPosition.dx,
      y: details.localPosition.dy,
      t: DateTime.now().millisecondsSinceEpoch,
    );
    
    _currentStroke!.points.add(point);
    _currentStrokePoints.add(point);
    
    // Start stroke analysis
    _analyzeStrokeStart(details.localPosition);
    setState(() {}); // Trigger immediate redraw
    
    // Force immediate frame to ensure real-time rendering
    SchedulerBinding.instance.scheduleFrame();
  }
  
  void _analyzeStrokeStart(Offset startPoint) {
    // Track stroke starting position for order validation
    final currentChar = _getCurrentCharacter();
    final character = currentChar['thai'] ?? '';
    
    // Simple stroke order hints for common Thai characters
    _strokeOrderHints = _getStrokeOrderHints(character, _currentStrokeCount);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke != null) {
      final point = mlkit.StrokePoint(
        x: details.localPosition.dx,
        y: details.localPosition.dy,
        t: DateTime.now().millisecondsSinceEpoch,
      );
      
      _currentStroke!.points.add(point);
      _currentStrokePoints.add(point);
      
      setState(() {}); // Trigger real-time redraw
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke != null) {
      // Calculate stroke metrics
      _analyzeStrokeMetrics(_currentStroke!);
      
      // Add stroke to completed strokes list
      _completedStrokes.add(_currentStroke!.points.toList());
      
      // Ensure stroke is in ink
      if (!_ink.strokes.contains(_currentStroke!)) {
        _ink.strokes.add(_currentStroke!);
      }
      
      _currentStroke = null;
      _currentStrokePoints.clear();
      
      // Analyze stroke pattern for order validation
      _validateStrokeOrder();
      
      setState(() {});
    }
  }
  
  void _analyzeStrokeMetrics(mlkit.Stroke stroke) {
    if (stroke.points.length < 2) return;
    
    // Store stroke for Thai writing pattern analysis
    _strokeLengths.add(_calculateStrokeLength(stroke));
    
    // Analyze Thai-specific writing patterns
    _analyzeThaiWritingPattern(stroke);
  }
  
  double _calculateStrokeLength(mlkit.Stroke stroke) {
    double totalDistance = 0.0;
    for (int i = 1; i < stroke.points.length; i++) {
      final p1 = stroke.points[i - 1];
      final p2 = stroke.points[i];
      totalDistance += math.sqrt(
        math.pow(p2.x - p1.x, 2) + math.pow(p2.y - p1.y, 2)
      );
    }
    return totalDistance;
  }
  
  void _analyzeThaiWritingPattern(mlkit.Stroke stroke) {
    final currentChar = _getCurrentCharacter();
    final character = currentChar['thai'] ?? '';
    
    // Check if stroke follows Thai writing principles
    if (!_followsThaiWritingOrder(stroke, character)) {
      _trackMistake('incorrect_writing_pattern');
    }
  }
  
  bool _followsThaiWritingOrder(mlkit.Stroke stroke, String character) {
    // Basic Thai writing pattern validation
    // Top-to-bottom: check if stroke generally moves downward
    // Left-to-right: check if stroke generally moves rightward
    // Circles first: check if circular elements come before linear elements
    
    if (stroke.points.length < 3) return true; // Too short to analyze
    
    final startPoint = stroke.points.first;
    final endPoint = stroke.points.last;
    final midPoint = stroke.points[stroke.points.length ~/ 2];
    
    // Check for common Thai patterns based on character
    switch (character) {
      case 'ก': case 'ด': case 'ต': case 'น': case 'บ': case 'ป':
        // These characters should generally be written top-to-bottom
        return _isTopToBottomStroke(startPoint, endPoint);
      case 'อ': case 'ว': case 'ใ': case 'ไ':
        // These characters have circular/curved elements that should be smooth
        return _isSmoothCurve(stroke);
      default:
        return true; // Default to accepting the stroke
    }
  }
  
  bool _isTopToBottomStroke(mlkit.StrokePoint start, mlkit.StrokePoint end) {
    // Stroke should generally move downward (positive Y direction)
    return end.y >= start.y - 20; // Allow some tolerance
  }
  
  bool _isSmoothCurve(mlkit.Stroke stroke) {
    // Check if the stroke has smooth curves (simplified validation)
    // Could be enhanced with more sophisticated curve analysis
    return stroke.points.length > 5; // Smooth curves have many points
  }
  
  void _validateStrokeOrder() {
    final currentChar = _getCurrentCharacter();
    final character = currentChar['thai'] ?? '';
    
    // Check stroke order based on Thai writing principles
    final expectedStrokeCount = _getExpectedStrokeCount(character);
    if (_currentStrokeCount > expectedStrokeCount) {
      _trackMistake('too_many_strokes');
    }
    
    // Check if stroke follows general Thai writing patterns
    if (!_isStrokeOrderCorrect(character, _currentStrokeCount)) {
      _trackMistake('incorrect_order');
    }
  }
  
  void _trackMistake(String mistakeType) {
    final currentChar = _getCurrentCharacter();
    final character = currentChar['thai'] ?? '';
    final mistakeKey = '${character}_$mistakeType';
    
    _characterMistakes[mistakeKey] = (_characterMistakes[mistakeKey] ?? 0) + 1;
    
    // Update stroke order hints based on mistakes
    _updateStrokeOrderHints(character, mistakeType);
  }
  
  List<String> _getStrokeOrderHints(String character, int strokeNumber) {
    // Basic Thai character stroke order hints
    final hints = <String>[];
    
    switch (character) {
      case 'ก': // 'k' sound
        if (strokeNumber == 1) hints.add('Start with the top horizontal line');
        if (strokeNumber == 2) hints.add('Draw the vertical line downward');
        break;
      case 'ข': // 'kh' sound  
        if (strokeNumber == 1) hints.add('Begin with the loop at top');
        if (strokeNumber == 2) hints.add('Add the tail extending right');
        break;
      case 'น': // 'n' sound
        if (strokeNumber == 1) hints.add('Start with the curved bowl shape');
        if (strokeNumber == 2) hints.add('Add the small hook on the right');
        break;
      case 'ม': // 'm' sound
        if (strokeNumber == 1) hints.add('Draw the left vertical line first');
        if (strokeNumber == 2) hints.add('Add the curved connection');
        if (strokeNumber == 3) hints.add('Finish with right vertical line');
        break;
      case 'หมึก': // 'ink/squid' - for compound characters
        hints.add('Write characters left to right: ห → ม → ึ → ก');
        break;
      default:
        hints.add('Follow Thai writing order: circles first, then lines');
        hints.add('Write from top to bottom, left to right');
    }
    
    return hints;
  }
  
  int _getExpectedStrokeCount(String character) {
    // Expected stroke counts for common Thai characters
    switch (character) {
      case 'ก': case 'ด': case 'ต': case 'น': case 'บ': case 'ป': case 'ผ': case 'ฝ': case 'พ': case 'ฟ': case 'ม': case 'ย': case 'ร': case 'ล': case 'ว': case 'ส': case 'ห': case 'อ':
        return 2;
      case 'ข': case 'ฃ': case 'ค': case 'ฅ': case 'ฆ': case 'ง': case 'จ': case 'ฉ': case 'ช': case 'ซ': case 'ฌ': case 'ญ': case 'ฎ': case 'ฏ': case 'ฐ': case 'ฑ': case 'ฒ': case 'ณ': case 'ถ': case 'ท': case 'ธ': case 'ภ': case 'ฬ': case 'ฮ':
        return 3;
      default:
        return 2; // Default assumption
    }
  }
  
  bool _isStrokeOrderCorrect(String character, int strokeNumber) {
    // Simplified stroke order validation
    // In a real implementation, this would be more sophisticated
    return strokeNumber <= _getExpectedStrokeCount(character);
  }
  
  void _updateStrokeOrderHints(String character, String mistakeType) {
    switch (mistakeType) {
      case 'too_many_strokes':
        _strokeOrderHints.add('🔄 This character needs fewer strokes. Try again!');
        break;
      case 'incorrect_order':
        _strokeOrderHints.add('📝 Check the stroke order - circles and curves first!');
        break;
      case 'incorrect_writing_pattern':
        _strokeOrderHints.add('✍️ Follow Thai writing direction: top-to-bottom, left-to-right');
        break;
    }
  }
  
  Future<String> _getCharacterSpecificTips(String character) async {
    // First, check if we have cached analysis from parallel processing
    if (_characterAnalysisCache.containsKey(character)) {
      final cachedData = _characterAnalysisCache[character]!;
      if (!cachedData.containsKey('error')) {
        return _buildTipsFromAnalysis(character, cachedData);
      }
    }
    
    // If not cached, try to get syllable-based analysis from backend
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/generate-writing-guide'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'word': character, 'target_language': 'th'}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Cache the result for future use (convert syllable data to character format)
        if (data.containsKey('syllables') && data['syllables'] is List) {
          final syllables = data['syllables'] as List;
          // Find the syllable containing this character
          for (var syllable in syllables) {
            if (syllable['syllable']?.contains(character) == true) {
              _characterAnalysisCache[character] = syllable;
              return _buildTipsFromSyllableAnalysis(character, syllable);
            }
          }
        }
        // Fallback: cache the whole response for single character
        _characterAnalysisCache[character] = data;
        return _buildTipsFromSyllableData(character, data);
      }
    } catch (e) {
      print("Failed to get syllable-based analysis: $e");
    }
    
    // Fallback to static tips
    return _getStaticCharacterTips(character);
  }
  
  String _buildTipsFromAnalysis(String character, Map<String, dynamic> analysis) {
    final List<String> practicalTips = [];
    
    // Extract only practical drawing guidance from PyThaiNLP analysis
    if (analysis['writing_tips'] != null) {
      final writingTips = analysis['writing_tips'] as List;
      for (var tip in writingTips) {
        String tipText = tip.toString();
        // Filter to keep only directional and order-based tips
        if (_isPracticalDrawingTip(tipText)) {
          practicalTips.add('• $tipText');
        }
      }
    }
    
    // Add basic drawing order guidance based on character components
    if (analysis['breakdown'] != null) {
      final consonants = analysis['consonants'] as List? ?? [];
      final vowels = analysis['vowels'] as List? ?? [];
      final toneMarks = analysis['tone_marks'] as List? ?? [];
      
      // Generate simple directional tips
      if (consonants.isNotEmpty && vowels.isNotEmpty) {
        practicalTips.add('• Draw main character first, then add marks');
      }
      
      if (vowels.any((v) => v['position_type'] == 'above')) {
        practicalTips.add('• Add marks above after completing base');
      }
      
      if (vowels.any((v) => v['position_type'] == 'below')) {
        practicalTips.add('• Add marks below after completing base');
      }
      
      if (vowels.any((v) => v['position_type'] == 'leading')) {
        practicalTips.add('• Start from left, move right');
      }
    }
    
    // Fallback to static directional tips
    if (practicalTips.isEmpty) {
      practicalTips.add('• ${_getDirectionalTips(character)}');
    }
    
    // Add general drawing principles
    practicalTips.add('• Keep strokes smooth and flowing');
    practicalTips.add('• Write from top to bottom, left to right');
    
    return practicalTips.isNotEmpty ? practicalTips.join('\n') : 'Practice writing this character smoothly and steadily.';
  }
  
  bool _isPracticalDrawingTip(String tip) {
    // Check if tip contains practical drawing guidance
    final practicalKeywords = ['draw', 'start', 'begin', 'first', 'then', 'direction', 'stroke', 'top', 'bottom', 'left', 'right', 'circle', 'line', 'curve'];
    final lowercaseTip = tip.toLowerCase();
    
    return practicalKeywords.any((keyword) => lowercaseTip.contains(keyword)) &&
           !lowercaseTip.contains('class') &&
           !lowercaseTip.contains('tone') &&
           !lowercaseTip.contains('phonetic');
  }
  
  String _getDirectionalTips(String character) {
    // Simple directional guidance based on character structure
    if (character.contains('ก') || character.contains('ด') || character.contains('ต')) {
      return 'Start with horizontal line, then add vertical strokes';
    } else if (character.contains('อ') || character.contains('ว')) {
      return 'Begin with circular shapes, draw curves smoothly';
    } else if (character.contains('ย') || character.contains('ร')) {
      return 'Start from top, draw main stroke downward';
    } else {
      return 'Start from top-left, move right and down';
    }
  }

  /// Build tips from syllable analysis data (new syllable-based approach)
  String _buildTipsFromSyllableAnalysis(String character, Map<String, dynamic> syllableData) {
    final List<String> practicalTips = [];
    
    // Extract tips from syllable data structure
    if (syllableData['tips'] != null) {
      final tips = syllableData['tips'] as Map<String, dynamic>;
      
      // Add step-by-step tips
      if (tips['step_by_step'] != null) {
        final stepTips = tips['step_by_step'] as List;
        for (var step in stepTips) {
          if (step['instruction'] != null) {
            practicalTips.add('• ${step['instruction']}');
          }
        }
      }
      
      // Add general tips
      if (tips['general'] != null) {
        final generalTips = tips['general'] as List;
        for (var tip in generalTips) {
          practicalTips.add('• $tip');
        }
      }
    }
    
    // Fallback to directional tips
    if (practicalTips.isEmpty) {
      practicalTips.add('• ${_getDirectionalTips(character)}');
    }
    
    return practicalTips.join('\n');
  }

  /// Build tips from complete syllable data (when character is a full syllable)
  String _buildTipsFromSyllableData(String character, Map<String, dynamic> syllableData) {
    final List<String> practicalTips = [];
    
    // Extract tips from syllables array
    if (syllableData['syllables'] != null) {
      final syllables = syllableData['syllables'] as List;
      for (var syllable in syllables) {
        if (syllable['tips'] != null) {
          final tips = syllable['tips'] as Map<String, dynamic>;
          
          // Add step-by-step tips
          if (tips['step_by_step'] != null) {
            final stepTips = tips['step_by_step'] as List;
            for (var step in stepTips) {
              if (step['instruction'] != null) {
                practicalTips.add('• ${step['instruction']}');
              }
            }
          }
        }
      }
    }
    
    // Fallback to directional tips
    if (practicalTips.isEmpty) {
      practicalTips.add('• ${_getDirectionalTips(character)}');
    }
    
    return practicalTips.join('\n');
  }

  void _analyzeAllCharactersInParallel() async {
    // Extract all unique characters from the current word mapping
    Set<String> uniqueCharacters = {};
    for (var wordData in _currentWordMapping) {
      String character = wordData['thai'] ?? '';
      if (character.isNotEmpty) {
        uniqueCharacters.add(character);
      }
    }

    // Create parallel analysis tasks for all unique characters using syllable-based approach
    List<Future<void>> analysisTasks = uniqueCharacters.map((character) async {
      try {
        final response = await http.post(
          Uri.parse('http://localhost:8000/generate-writing-guide'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'word': character, 'target_language': 'th'}),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Convert syllable data to character format for caching
          if (data.containsKey('syllables') && data['syllables'] is List) {
            final syllables = data['syllables'] as List;
            // Find the syllable containing this character
            for (var syllable in syllables) {
              if (syllable['syllable']?.contains(character) == true) {
                _characterAnalysisCache[character] = syllable;
                break;
              }
            }
          } else {
            _characterAnalysisCache[character] = data;
          }
          print('Analyzed character using syllable data: $character');
        }
      } catch (e) {
        print('Failed to analyze character $character: $e');
        // Store fallback analysis
        _characterAnalysisCache[character] = {
          'character': character,
          'error': 'Network error',
          'fallback': true
        };
      }
    }).toList();

    // Execute all analysis tasks in parallel
    try {
      await Future.wait(analysisTasks);
      print('Completed parallel analysis for ${uniqueCharacters.length} characters');
    } catch (e) {
      print('Error in parallel character analysis: $e');
    }
  }
  
  String _getWritingTipsByStructure(String character, Map<String, dynamic> analysis) {
    // Analyze character structure for writing tips
    if (character.contains('ก') || character.contains('ด') || character.contains('ต')) {
      return 'Start with horizontal lines, then add vertical strokes';
    } else if (character.contains('อ') || character.contains('ว')) {
      return 'Begin with circular shapes, keep curves smooth';
    } else if (character.contains('ย') || character.contains('ร')) {
      return 'Start from top, draw main stroke downward';
    } else {
      return 'Follow top-to-bottom, left-to-right order';
    }
  }

  bool _shouldShowCharacterNavigation() {
    // Show character navigation if:
    // 1. Multiple characters exist
    // 2. Single character word but it's complex (contains multiple components)
    // 3. Word is longer than 3 Thai characters (likely to overflow)
    
    if (_currentWordMapping.length > 1) return true;
    
    if (_currentWordMapping.length == 1) {
      final word = _currentWordMapping[0]['thai'] ?? '';
      // Show for complex single characters or long compound words
      return word.length > 2 || _isComplexCharacter(word);
    }
    
    return false;
  }
  
  bool _isComplexCharacter(String character) {
    // Check if character contains multiple Thai components (vowels, tones, etc.)
    // This is a simplified check - ideally would use PyThaiNLP analysis
    final complexMarkers = ['์', '่', '้', '๊', '๋', 'ั', 'ิ', 'ี', 'ึ', 'ื', 'ุ', 'ู', 'เ', 'แ', 'โ', 'ใ', 'ไ'];
    return complexMarkers.any((marker) => character.contains(marker));
  }
  
  List<Map<String, dynamic>> _splitWordIntelligently(Map<String, dynamic> wordData) {
    final word = wordData['thai'] ?? '';
    
    // If word is short enough for UI, return as-is
    if (word.length <= 3) {
      return [wordData];
    }
    
    // For longer words, try to split at natural boundaries
    final characters = <Map<String, dynamic>>[];
    
    // Use character-by-character splitting for now
    // TODO: Integrate with PyThaiNLP for better syllable segmentation
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      
      // Skip combining characters - they should be part of the previous character
      if (_isCombiningCharacter(char) && characters.isNotEmpty) {
        final lastChar = characters.last;
        lastChar['thai'] = (lastChar['thai'] ?? '') + char;
        continue;
      }
      
      characters.add({
        'thai': char,
        'transliteration': _extractTransliterationForChar(wordData, i),
        'english': wordData['english'], // Keep the full word meaning
        'translation': wordData['translation'],
      });
    }
    
    return characters;
  }
  
  bool _isCombiningCharacter(String char) {
    // Thai combining characters that modify the previous character
    final combiningChars = ['์', '่', '้', '๊', '๋', 'ั', 'ิ', 'ี', 'ึ', 'ื', 'ุ', 'ู'];
    return combiningChars.contains(char);
  }
  
  String _extractTransliterationForChar(Map<String, dynamic> wordData, int charIndex) {
    final transliteration = wordData['transliteration'] ?? wordData['romanized'] ?? '';
    // Simple approximation - divide transliteration by character count
    if (transliteration.isNotEmpty) {
      final word = wordData['thai'] ?? '';
      final charCount = word.length;
      final syllableLength = (transliteration.length / charCount).ceil();
      final start = charIndex * syllableLength;
      final end = (start + syllableLength < transliteration.length) 
          ? start + syllableLength 
          : transliteration.length;
      return transliteration.substring(start, end);
    }
    return '';
  }

  String _getStaticCharacterTips(String character) {
    switch (character) {
      case 'ก':
        return 'ก: Start with horizontal line, then vertical. Keep strokes connected.';
      case 'ข':
        return 'ข: Begin with the loop, then add the tail. Smooth curves are key.';
      case 'ค':
        return 'ค: Draw the vertical line first, then add the horizontal crossbar.';
      case 'ง':
        return 'ง: Start with the curved bowl, then add the small tail.';
      case 'จ':
        return 'จ: Begin with the circle, then add the vertical line downward.';
      case 'ฉ':
        return 'ฉ: Draw the base first, then add the top horizontal line.';
      case 'ช':
        return 'ช: Start with the main body, then add the small hook on top.';
      case 'ซ':
        return 'ซ: Begin with the circular part, then extend the line.';
      case 'ด':
        return 'ด: Draw the main curve first, then add the small circle on top.';
      case 'ต':
        return 'ต: Start with the base, then add the distinctive top element.';
      case 'ท':
        return 'ท: Begin with the vertical line, then add the horizontal elements.';
      case 'น':
        return 'น: Start with the curved bowl shape, then add the hook.';
      case 'บ':
        return 'บ: Draw the main body first, then add the small loop on top.';
      case 'ป':
        return 'ป: Begin with the vertical stroke, then add the horizontal line.';
      case 'ผ':
        return 'ผ: Start with the main curve, then add the small ascending stroke.';
      case 'ฝ':
        return 'ฝ: Draw the vertical line first, then add the curved top.';
      case 'พ':
        return 'พ: Begin with the base curve, then add the top horizontal line.';
      case 'ฟ':
        return 'ฟ: Start with the circular element, then add the connecting line.';
      case 'ภ':
        return 'ภ: Draw the main body first, then add the distinctive top hook.';
      case 'ม':
        return 'ม: Start left vertical line, add curve, finish with right line.';
      case 'ย':
        return 'ย: Begin with the main curve, then add the small tail.';
      case 'ร':
        return 'ร: Start with the vertical line, then add the curved top.';
      case 'ล':
        return 'ล: Draw the main curve first, then add the small circle.';
      case 'ว':
        return 'ว: Begin with the circular shape, keep it smooth and round.';
      case 'ศ':
        return 'ศ: Start with the main vertical line, then add side elements.';
      case 'ษ':
        return 'ษ: Draw the base first, then add the top curved elements.';
      case 'ส':
        return 'ส: Begin with the curved shape, then add the top line.';
      case 'ห':
        return 'ห: Start with the vertical line, then add the curved hook.';
      case 'อ':
        return 'อ: Draw the circular shape first, keep it round and even.';
      case 'ฮ':
        return 'ฮ: Begin with the main curve, then add the top horizontal line.';
      default:
        return 'General tip: Start with circles, write vowels after consonants, keep strokes smooth and flowing.';
    }
  }

  Future<void> _recognizeCharacter() async {
    if (_ink.strokes.isEmpty || !_isModelDownloaded) {
      return;
    }

    try {
      final List<mlkit.RecognitionCandidate> candidates = await _digitalInkRecognizer.recognize(_ink);
      
      if (candidates.isNotEmpty) {
        final String recognizedText = candidates.first.text;
        final double confidence = candidates.first.score ?? 0.0;
        
        print("Recognized: $recognizedText with confidence: $confidence");
        
        // Check if recognized character matches target
        if (recognizedText == _targetCharacter && confidence >= 0.6) {
          // Success! Character matches with good confidence
          _onCharacterRecognitionSuccess(recognizedText, confidence);
        } else {
          // Show feedback for incorrect or low confidence recognition
          _onCharacterRecognitionFailure(recognizedText, confidence);
        }
      } else {
        print("No characters recognized");
      }
    } catch (e) {
      print("Error during character recognition: $e");
    }
  }

  void _onCharacterRecognitionSuccess(String recognizedText, double confidence) {
    Navigator.of(context).pop(); // Close tracing dialog
    
    // Show animated success dialog with Lottie animation
    _showSuccessDialog(recognizedText, confidence);
    
    // Save to mastered vocabulary database
    _saveCharacterTracingToDatabase(recognizedText, confidence);
    
    print("Character tracing successful: $recognizedText ($confidence)");
  }

  void _showSuccessDialog(String recognizedText, double confidence) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        content: SizedBox(
          width: 300,
          height: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie confetti animation
              SizedBox(
                width: 150,
                height: 150,
                child: Lottie.asset(
                  'assets/lottie/victory_confetti.json',
                  repeat: false,
                  animate: true,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Excellent!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'You traced "$recognizedText" with ${(confidence * 100).toInt()}% accuracy!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              if (confidence >= 0.6)
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    '🎉 Character Mastered! 🎉',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCharacterTracingToDatabase(String recognizedCharacter, double confidence) async {
    try {
      final isarService = IsarService();
      
      // Use the recognized character as the phrase ID for character tracing
      final phraseId = recognizedCharacter;
      
      // Get existing record or create new one
      MasteredPhrase? existingPhrase = await isarService.getMasteredPhrase(phraseId);
      
      if (existingPhrase != null) {
        // Update existing record
        existingPhrase.lastTracingScore = confidence * 100; // Convert to 0-100 scale
        existingPhrase.timesTraced += 1;
        existingPhrase.lastTracedAt = DateTime.now();
        existingPhrase.lastConfidenceScore = confidence;
        existingPhrase.lastRecognizedCharacter = recognizedCharacter;
        
        // Check if character is mastered (60+ score)
        if (confidence >= 0.6) {
          existingPhrase.isCharacterMastered = true;
          if (!existingPhrase.masteredCharacters.contains(recognizedCharacter)) {
            existingPhrase.masteredCharacters.add(recognizedCharacter);
          }
        }
        
        await isarService.saveMasteredPhrase(existingPhrase);
      } else {
        // Create new record
        final newPhrase = MasteredPhrase()
          ..phraseEnglishId = phraseId
          ..lastTracingScore = confidence * 100
          ..timesTraced = 1
          ..lastTracedAt = DateTime.now()
          ..lastConfidenceScore = confidence
          ..lastRecognizedCharacter = recognizedCharacter
          ..isCharacterMastered = confidence >= 0.6
          ..masteredCharacters = confidence >= 0.6 ? [recognizedCharacter] : [];
        
        await isarService.saveMasteredPhrase(newPhrase);
      }
      
      print("Character tracing data saved to database: $recognizedCharacter (${(confidence * 100).toInt()}%)");
    } catch (e) {
      print("Error saving character tracing data: $e");
    }
  }

  void _onCharacterRecognitionFailure(String recognizedText, double confidence) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Try again! Expected "$_targetCharacter" but got "$recognizedText" (${(confidence * 100).toInt()}%)'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }



  Future<void> _giveItemToNPC(Map<String, dynamic> item, BuildContext dialogContext, String targetLanguage) async {
    try {
      // Close the dialog
      Navigator.of(dialogContext).pop();
      
      // Create custom message for LLM bypassing STT
      final String itemName = item['english'] ?? 'item';
      final String customMessage = 'User gives $itemName to ${_npcData.name}';
      
      // Use the existing NPC ID from the widget and providers
      final currentNPCId = widget.npcId;
      final currentNPCName = _npcData.name;
      final currentCharmLevel = ref.read(currentCharmLevelProvider(currentNPCId));
      
      // Get conversation history from provider using existing pattern
      final currentFullHistory = ref.read(fullConversationHistoryProvider(currentNPCId));
      List<String> historyLinesForBackend = [];
      for (var entry in currentFullHistory) {
        if (!entry.isNpc) {
          // Player entry
          historyLinesForBackend.add("Player: ${entry.playerTranscriptionForHistory ?? entry.text}");
        } else {
          // NPC entry  
          historyLinesForBackend.add("NPC: ${entry.text}");
        }
      }

      // Prepare the multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/generate-npc-response/'),
      );

      // Add form data - no audio file since we're using custom_message
      request.fields['npc_id'] = currentNPCId;
      request.fields['npc_name'] = currentNPCName;
      request.fields['charm_level'] = currentCharmLevel.toString();
      request.fields['target_language'] = targetLanguage;
      request.fields['custom_message'] = customMessage; // This bypasses STT
      request.fields['previous_conversation_history'] = historyLinesForBackend.join('\n');
      request.fields['user_id'] = PostHogService.userId ?? 'unknown_user';
      request.fields['session_id'] = PostHogService.sessionId ?? 'unknown_session';

      print("Sending item giving request for $itemName to $currentNPCName");

      setState(() { _isProcessingBackend = true; });

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Handle the NPC response using existing pattern
        Uint8List npcAudioBytes = response.bodyBytes;
        String? npcResponseDataJsonB64 = response.headers['x-npc-response-data'];

        if (npcResponseDataJsonB64 != null) {
          String npcResponseDataJson = utf8.decode(base64Decode(npcResponseDataJsonB64));
          Map<String, dynamic> responsePayload = jsonDecode(npcResponseDataJson);
          
          // Process NPC response using existing pattern
          String playerTranscription = _sanitizeString(responsePayload['input_target'] ?? customMessage);
          String npcText = _sanitizeString(responsePayload['response_target'] ?? '...');
          List<POSMapping> npcPosMappings = (responsePayload['response_mapping'] as List? ?? [])
              .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();
          List<POSMapping> playerInputMappings = (responsePayload['input_mapping'] as List? ?? [])
              .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();

          // Update charm level from backend
          int charmDelta = 0;
          String charmReason = '';
          if (responsePayload.containsKey('charm_delta')) {
              charmDelta = responsePayload['charm_delta'] ?? 0;
              charmReason = _sanitizeString(responsePayload['charm_reason'] as String? ?? '');
              final charmNotifier = ref.read(currentCharmLevelProvider(currentNPCId).notifier);
              final oldCharm = charmNotifier.state;
              int newCharm = (oldCharm + charmDelta).clamp(0, 100);
              charmNotifier.state = newCharm;
          }

          // Save NPC audio to temporary file
          String? tempNpcAudioPath;
          try {
            final tempDir = await getTemporaryDirectory();
            tempNpcAudioPath = '${tempDir.path}/npc_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
            await File(tempNpcAudioPath).writeAsBytes(npcAudioBytes);
          } catch (e) {
            print("Error saving NPC audio to temp file: $e");
          }

          // Create entries for conversation history
          final playerEntryForHistory = DialogueEntry(
            text: customMessage,
            englishText: '', // No English translation for item giving to prevent toggle effects
            speaker: 'Player',
            isNpc: false,
            posMappings: null, // No POS mappings for item giving to prevent word analysis toggle effects
            playerTranscriptionForHistory: customMessage,
          );
          
          final String npcEntryId = DialogueEntry._generateId();
          final npcEntryForDisplayAndHistory = DialogueEntry.npc(
            id: npcEntryId,
            text: npcText,
            englishText: _sanitizeString(responsePayload['response_english'] ?? ''),
            audioBytes: npcAudioBytes,
            npcName: currentNPCName,
            posMappings: npcPosMappings,
          );

          // Update conversation history and display
          final fullHistoryNotifier = ref.read(fullConversationHistoryProvider(currentNPCId).notifier);
          fullHistoryNotifier.update((history) => [...history, playerEntryForHistory, npcEntryForDisplayAndHistory]);
          
          final currentNpcDisplayNotifier = ref.read(currentNpcDisplayEntryProvider.notifier);
          currentNpcDisplayNotifier.state = npcEntryForDisplayAndHistory;

          // Play NPC audio
          if (tempNpcAudioPath != null) {
            await _replayPlayer.setAudioSource(just_audio.AudioSource.file(tempNpcAudioPath));
            await _replayPlayer.play();
          }
          
          print("Item giving successful for $itemName");
        } else {
          print("Error: Missing response data header");
        }
      } else {
        print("Error in item giving: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error giving item to NPC: $e");
    } finally {
      setState(() { _isProcessingBackend = false; });
    }
  }


  Future<void> _transcribeForTranslation(String audioPath) async {
    _isTranscribing.value = true;
    _translationErrorNotifier.value = null;

    final File audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      _translationErrorNotifier.value = "Error: Audio file not found.";
      _isTranscribing.value = false;
      return;
    }

    try {
      var uri = Uri.parse('http://127.0.0.1:8000/gcloud-transcribe/');
      var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('audio_file', audioFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcription = data['transcription'] as String?;
        if (transcription != null) {
          _translationEnglishController.text = transcription;
          // Clear previous results when new text is dictated
          _translationMappingsNotifier.value = [];
          _translationAudioNotifier.value = "";
        } else {
          _translationErrorNotifier.value = "Failed to get transcription.";
        }
      } else {
        _translationErrorNotifier.value = "Transcription failed (code: ${response.statusCode}).";
        print("Transcription backend error: ${response.body}");
      }
    } catch (e) {
      _translationErrorNotifier.value = "Error connecting to transcription service.";
      print("Error calling transcription backend: $e");
    } finally {
      _isTranscribing.value = false;
      // Clean up temp file
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    }
  }

  Widget _buildPracticeMicControls() {
    return ValueListenableBuilder<RecordingState>(
      valueListenable: _practiceRecordingState,
      builder: (context, state, child) {
        switch (state) {
          case RecordingState.idle:
            return Center(
              child: GestureDetector(
                onTap: () {
                  _startPracticeRecording();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 32),
                ),
              ),
            );
          case RecordingState.recording:
            return Center(
              child: GestureDetector(
                onTap: () {
                  _stopPracticeRecording();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 32),
                ),
              ),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }



  Future<void> _startPracticeRecording() async {
    // Clean up previous recording before starting a new one
    await _practiceReviewPlayer.stop();
    if (_lastPracticeRecordingPath.value != null) {
      final file = File(_lastPracticeRecordingPath.value!);
      if (await file.exists()) {
        await file.delete();
      }
      _lastPracticeRecordingPath.value = null;
    }

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _translationErrorNotifier.value = "Microphone permission is required.";
      return;
    }

    _practiceRecordingState.value = RecordingState.recording;
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/practice_input_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _practiceAudioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // Optimal for STT APIs
          numChannels: 1,     // Mono
        ), 
        path: path
      );
      _lastPracticeRecordingPath.value = path; // Store path immediately
    } catch (e) {
      print("Error starting practice recording: $e");
      _practiceRecordingState.value = RecordingState.idle;
    }
  }

  Future<void> _stopPracticeRecording() async {
    if (_practiceRecordingState.value != RecordingState.recording) return;
    try {
      await _practiceAudioRecorder.stop();
      _practiceRecordingState.value = RecordingState.reviewing;
    } catch (e) {
      print("Error stopping practice recording: $e");
      _practiceRecordingState.value = RecordingState.idle;
    }
  }


  // --- Text Animation for Main NPC Display Box ---
  void _startNpcTextAnimation({
    required String idForAnimation, // Expecting the ID to be passed
    required String speakerName,    // Expecting speaker name
    required String fullText,    
    required String englishText,
    String? audioPathToPlayWhenDone,
    Uint8List? audioBytesToPlayWhenDone, // Added to handle direct bytes
    List<POSMapping>? posMappings,
    int? charmDelta,
    String? charmReason,
    bool? justReachedMaxCharm,
    Function(DialogueEntry finalAnimatedEntry)? onAnimationComplete,
  }) {
    _activeTextStreamTimer?.cancel(); 

    final currentNpcNotifier = ref.read(currentNpcDisplayEntryProvider.notifier);
    
    // Create the entry for animation using the passed ID
    DialogueEntry entryWithCorrectIdForAnimation = DialogueEntry.npc(
        id: idForAnimation, 
        text: "", // Start with blank text for animation
        englishText: englishText,
        npcName: speakerName, 
        audioPath: audioPathToPlayWhenDone,
        audioBytes: audioBytesToPlayWhenDone,
        posMappings: posMappings
    );

    print("DEBUG: _startNpcTextAnimation overwriting currentNpcDisplayEntry - ID: ${entryWithCorrectIdForAnimation.id}, hasAudio: ${entryWithCorrectIdForAnimation.audioBytes?.isNotEmpty == true || entryWithCorrectIdForAnimation.audioPath?.isNotEmpty == true}");
    currentNpcNotifier.state = entryWithCorrectIdForAnimation;

    setState(() {
      _currentlyAnimatingEntryId = entryWithCorrectIdForAnimation.id; 
      _displayedTextForAnimation = ""; 
      _currentCharIndexForAnimation = 0;
       _scrollToBottom(_mainDialogueScrollController);
    });

    Duration charDuration = Duration(milliseconds: 50); 

    Future<Duration?> getAudioDuration() async {
        if (audioPathToPlayWhenDone != null && audioPathToPlayWhenDone!.isNotEmpty) {
            final tempPlayer = just_audio.AudioPlayer();
            try {
                return audioPathToPlayWhenDone.startsWith('assets/') 
                    ? await tempPlayer.setAsset(audioPathToPlayWhenDone)
                    : await tempPlayer.setAudioSource(just_audio.AudioSource.uri(Uri.file(audioPathToPlayWhenDone)));
            } finally { tempPlayer.dispose(); }
        } else if (entryWithCorrectIdForAnimation.audioBytes != null && entryWithCorrectIdForAnimation.audioBytes!.isNotEmpty) {
            final tempPlayer = just_audio.AudioPlayer();
            try {
                return await tempPlayer.setAudioSource(_MyCustomStreamAudioSource.fromBytes(entryWithCorrectIdForAnimation.audioBytes!));
             } finally { tempPlayer.dispose(); }
        }
        return null;
    }

    getAudioDuration().then((duration) {
        if (duration != null && duration.inMilliseconds > 0 && fullText.isNotEmpty) {
            charDuration = Duration(milliseconds: math.max(30, (duration.inMilliseconds * 0.95 / fullText.length).round()));
        }
        
        // Play audio for the entry being animated (using entryWithCorrectIdForAnimation)
        if (entryWithCorrectIdForAnimation.audioPath != null || entryWithCorrectIdForAnimation.audioBytes != null) {
            _playDialogueAudio(entryWithCorrectIdForAnimation);
        }

        _activeTextStreamTimer = Timer.periodic(charDuration, (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            if (_currentCharIndexForAnimation < fullText.length) {
                setState(() {
                _displayedTextForAnimation = fullText.substring(0, _currentCharIndexForAnimation + 1);
                _currentCharIndexForAnimation++;
                });
            } else {
                timer.cancel();
                _activeTextStreamTimer = null;
                
                // Create the final version of the entry with full text, using the same ID
                DialogueEntry finalAnimatedEntry = DialogueEntry.npc(
                    id: entryWithCorrectIdForAnimation.id, 
                    text: fullText, 
                    englishText: englishText,
                    npcName: entryWithCorrectIdForAnimation.speaker, 
                    audioPath: entryWithCorrectIdForAnimation.audioPath, 
                    audioBytes: entryWithCorrectIdForAnimation.audioBytes,
                    posMappings: entryWithCorrectIdForAnimation.posMappings
                );

                print("DEBUG: Animation complete, setting final entry - ID: ${finalAnimatedEntry.id}, hasAudio: ${finalAnimatedEntry.audioBytes?.isNotEmpty == true || finalAnimatedEntry.audioPath?.isNotEmpty == true}");
                currentNpcNotifier.state = finalAnimatedEntry; // Update provider with full text
                
                setState(() {
                    _fullyAnimatedMainNpcTexts[finalAnimatedEntry.id] = fullText; 
                    _currentlyAnimatingEntryId = ""; 
                });

                // Show charm notifications after animation completes
                if (charmDelta != null && charmDelta != 0 && charmReason != null && charmReason.isNotEmpty) {
                  Future.microtask(() {
                    _showCharmChangeNotification(context, charmDelta, charmReason).then((_) {
                      if (justReachedMaxCharm == true) {
                        _showMaxCharmNotification(context);
                      }
                    });
                  });
                } else if (justReachedMaxCharm == true) {
                  Future.microtask(() => _showMaxCharmNotification(context));
                }

                if (onAnimationComplete != null) {
                    onAnimationComplete(finalAnimatedEntry);
                }
                _scrollToBottom(_mainDialogueScrollController);
            }
        });
    });
  }
}

class _CharmChangeDialogContent extends StatefulWidget {
  final int charmDelta;
  final String charmReason;

  const _CharmChangeDialogContent({
    required this.charmDelta,
    required this.charmReason,
  });

  @override
  _CharmChangeDialogContentState createState() => _CharmChangeDialogContentState();
}

class _CharmChangeDialogContentState extends State<_CharmChangeDialogContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.charmDelta > 0 ? 800 : 500),
      vsync: this,
    );

    if (widget.charmDelta > 0) {
      // Bouncy, expanding animation for positive charm
      _animation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.6).chain(CurveTween(curve: Curves.easeOut)),
          weight: 50
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.6, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
          weight: 50
        ),
      ]).animate(_controller);
    } else {
      // Shake animation for negative charm
      _animation = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 5),
        TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -8.0), weight: 10),
        TweenSequenceItem(tween: Tween<double>(begin: -8.0, end: 8.0), weight: 20),
        TweenSequenceItem(tween: Tween<double>(begin: 8.0, end: -8.0), weight: 20),
        TweenSequenceItem(tween: Tween<double>(begin: -8.0, end: 4.0), weight: 15),
        TweenSequenceItem(tween: Tween<double>(begin: 4.0, end: -4.0), weight: 15),
        TweenSequenceItem(tween: Tween<double>(begin: -4.0, end: 0.0), weight: 10),
      ]).animate(_controller);
    }
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPositive = widget.charmDelta > 0;
    final Color deltaColor = isPositive ? Colors.green.shade600 : Colors.red.shade600;
    final String sign = isPositive ? '+' : '';

    final Widget textWidget = Text(
      '$sign${widget.charmDelta}',
      style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: deltaColor,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            if (isPositive) {
              return Transform.scale(
                scale: _animation.value,
                child: child,
              );
            } else {
              return Transform.translate(
                offset: Offset(_animation.value, 0),
                child: child,
              );
            }
          },
          child: textWidget,
        ),
        const SizedBox(height: 16),
        Text(
          widget.charmReason,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ],
    );
  }
}

// Custom painter for ML Kit Digital Ink with real-time preview
class _InkPainter extends CustomPainter {
  final mlkit.Ink ink;
  final List<mlkit.StrokePoint> currentStrokePoints;

  _InkPainter(this.ink, {this.currentStrokePoints = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF4ECCA3)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Draw all completed strokes
    for (final mlkit.Stroke stroke in ink.strokes) {
      final Path path = Path();
      bool first = true;
      
      for (final mlkit.StrokePoint point in stroke.points) {
        if (first) {
          path.moveTo(point.x, point.y);
          first = false;
        } else {
          path.lineTo(point.x, point.y);
        }
      }
      
      canvas.drawPath(path, paint);
    }

    // Draw current stroke being drawn (real-time preview)
    if (currentStrokePoints.isNotEmpty) {
      final Paint currentPaint = Paint()
        ..color = const Color(0xFF4ECCA3).withValues(alpha: 0.8)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;

      final Path currentPath = Path();
      bool first = true;
      
      for (final mlkit.StrokePoint point in currentStrokePoints) {
        if (first) {
          currentPath.moveTo(point.x, point.y);
          first = false;
        } else {
          currentPath.lineTo(point.x, point.y);
        }
      }
      
      canvas.drawPath(currentPath, currentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) {
    // Always repaint if we're currently drawing (have current stroke points)
    if (currentStrokePoints.isNotEmpty || oldDelegate.currentStrokePoints.isNotEmpty) {
      return true; // Fast path for live drawing
    }
    
    // Repaint when ink changes
    return oldDelegate.ink.strokes.length != ink.strokes.length;
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  _SpeechBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final RRect bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      const Radius.circular(10),
    );

    final Path path = Path()..addRRect(bubbleRect);

    // Triangle/tail of the bubble
    final Path tail = Path();
    tail.moveTo(size.width * 0.5 - 15, size.height - 10);
    tail.lineTo(size.width * 0.5, size.height);
    tail.lineTo(size.width * 0.5 + 15, size.height - 10);
    tail.close();

    path.addPath(tail, Offset.zero);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom AudioSource for playing from a list of bytes or a stream (Unchanged)
class _MyCustomStreamAudioSource extends just_audio.StreamAudioSource {
  final Uint8List? _fixedBytes;

  _MyCustomStreamAudioSource.fromBytes(this._fixedBytes)
    : super(tag: 'npc-audio-bytes-${DateTime.now().millisecondsSinceEpoch}');

  @override
  Future<just_audio.StreamAudioResponse> request([int? start, int? end]) async {
    if (_fixedBytes != null) {
      start ??= 0;
      end ??= _fixedBytes!.length;
      return just_audio.StreamAudioResponse(
        sourceLength: _fixedBytes!.length,
        contentLength: end - start,
        offset: start,
        stream: Stream.value(_fixedBytes!.sublist(start, end)),
        contentType: 'audio/wav',
      );
    }
    throw Exception("CustomStreamAudioSource not initialized with bytes or stream");
  }
} 

// --- End Custom AudioSource ---

class _AnimatedPressWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isDisabled;

  const _AnimatedPressWrapper({
    required this.child,
    this.onTap,
    this.isDisabled = false,
  });

  @override
  _AnimatedPressWrapperState createState() => _AnimatedPressWrapperState();
}

class _AnimatedPressWrapperState extends State<_AnimatedPressWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isDisabled) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isDisabled) {
      _controller.reverse().then((_) {
        widget.onTap?.call();
      });
    }
  }

  void _onTapCancel() {
    if (!widget.isDisabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// PRODUCTION PAINTER - OPTIMIZED VERSION BASED ON FLUTTER DOCS PATTERN
