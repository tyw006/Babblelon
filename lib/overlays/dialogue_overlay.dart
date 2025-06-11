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
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../game/babblelon_game.dart';
import '../models/npc_data.dart'; // Using the new unified NPC data model
import '../providers/game_providers.dart'; // Ensure this import is present
import '../widgets/charm_bar.dart';
import '../widgets/dialogue_ui.dart';

// --- Sanitization Helper ---
String _sanitizeString(String text) {
  // Re-encoding and decoding with allowMalformed: true replaces invalid sequences
  // with the Unicode replacement character (U+FFFD), preventing rendering errors.
  return utf8.decode(utf8.encode(text), allowMalformed: true);
}
// --- End Sanitization Helper ---

// --- POSMapping Model ---
@immutable
class POSMapping {
  final String wordTarget;
  final String wordTranslit;
  final String wordEng;
  final String pos;

  const POSMapping({
    required this.wordTarget,
    required this.wordTranslit,
    required this.wordEng,
    required this.pos,
  });

  factory POSMapping.fromJson(Map<String, dynamic> json) {
    return POSMapping(
      wordTarget: _sanitizeString(json['word_target'] as String? ?? ''),
      wordTranslit: _sanitizeString(json['word_translit'] as String? ?? ''),
      wordEng: _sanitizeString(json['word_eng'] as String? ?? ''),
      pos: _sanitizeString(json['pos'] as String? ?? ''),
    );
  }
}
// --- End POSMapping Model ---

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
  factory DialogueEntry.player(String transcribedText, String audioPath, {List<POSMapping>? inputMappings}) {
    return DialogueEntry(
      // customId will be null, so _generateId() is used by the main constructor
      text: transcribedText, // Player's own transcribed text
      englishText: transcribedText,
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
  bool _isRecording = false;

  // --- State for Translation Dialog ---
  final TextEditingController _translationEnglishController = TextEditingController();
  final ValueNotifier<List<Map<String, String>>> _translationMappingsNotifier = ValueNotifier<List<Map<String, String>>>([]);
  final ValueNotifier<String> _translationAudioNotifier = ValueNotifier<String>("");
  final ValueNotifier<bool> _translationIsLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _translationErrorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String> _translationDialogTitleNotifier = ValueNotifier<String>('Translate to Thai'); // Default title

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

  bool _isProcessingBackend = false;

  InitialNPCGreeting? _initialGreetingData;
  late NpcData _npcData; // Store the current NPC's data

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _replayPlayer = ref.read(dialogueReplayPlayerProvider);

    // Look up the NPC data using the widget's npcId
    _npcData = npcDataMap[widget.npcId]!;

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
      await _loadInitialGreetingData();

      final history = ref.read(fullConversationHistoryProvider(widget.npcId));
      final currentNpcDisplayNotifier = ref.read(currentNpcDisplayEntryProvider.notifier);
      final fullHistoryNotifier = ref.read(fullConversationHistoryProvider(widget.npcId).notifier);

      if (_initialGreetingData == null) {
        print("Error: ${_npcData.name}'s initial greeting data could not be loaded.");
        final errorEntry = DialogueEntry.npc(text: "Error loading greeting.", englishText: "Error loading greeting.", npcName: _npcData.name);
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
          posMappings: [],
        );
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

  Future<void> _loadInitialGreetingData() async {
    final npcId = widget.npcId;
    // Load the initial dialogue data from JSON
    final jsonString = await rootBundle.loadString('assets/data/npc_initial_dialogues.json');
    final Map<String, dynamic> allGreetings = json.decode(jsonString);
    final greetingData = allGreetings[npcId];

    if (greetingData != null) {
      _initialGreetingData = InitialNPCGreeting.fromJson(greetingData);
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

  @override
  void dispose() {
    _replayPlayer.stop(); // Stop any playing audio on exit
    _audioRecorder.dispose();
    _animationController?.dispose();
    _giftIconAnimationController.dispose();
    _activeTextStreamTimer?.cancel();
    _mainDialogueScrollController.dispose();
    _historyDialogScrollController.dispose();
    
    // Dispose translation dialog state
    _translationEnglishController.dispose();
    _translationMappingsNotifier.dispose();
    _translationAudioNotifier.dispose();
    _translationIsLoadingNotifier.dispose();
    _translationErrorNotifier.dispose();
    _translationDialogTitleNotifier.dispose();

    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print("Microphone permission denied");
      // Optionally, show a dialog to the user explaining why you need the permission.
      return;
    }

    setState(() {
      _isRecording = true;
    });
    _animationController?.repeat(reverse: true);

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/c_input_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Add the path to the provider to be cleaned up later
    ref.read(tempFilePathsProvider.notifier).update((state) => [...state, path]);

    try {
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
      print("Recording started at path: $path");
    } catch (e) {
      print("Error starting recording: $e");
      setState(() {
        _isRecording = false;
      });
      _animationController?.stop();
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return; // Avoid stopping if not recording

    _animationController?.stop();
    setState(() {
      _isRecording = false;
    });

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        print("Recording stopped, file at: $path");
        _sendAudioToBackend(path);
      } else {
        print("Error: Recording path is null.");
      }
    } catch (e) {
      print("Error stopping recording: $e");
    }
  }

  Future<void> _sendAudioToBackend(String audioPath) async {
    print("Mic button action triggered. Sending audio to new endpoint.");
    setState(() { _isProcessingBackend = true; });

    final File audioFileToSend = File(audioPath);

    if (!await audioFileToSend.exists()) {
        print("Error: Recorded audio file does not exist at path: $audioPath");
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
        ..fields['previous_conversation_history'] = previousHistoryPayload;
      
      print("Sending audio and data to /generate-npc-response/...");
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        Uint8List npcAudioBytes = response.bodyBytes;
        String? npcResponseDataJsonB64 = response.headers['x-npc-response-data'];

        print("--- Frontend Received from Backend ---");
        print("NPC Audio Bytes Length: ${npcAudioBytes.lengthInBytes}");
        print("X-NPC-Response-Data (Base64): $npcResponseDataJsonB64");

        if (npcResponseDataJsonB64 == null) {
          print("Error: X-NPC-Response-Data header is missing.");
          setState(() { _isProcessingBackend = false; });
          return;
        }
        
        String npcResponseDataJson = utf8.decode(base64Decode(npcResponseDataJsonB64));
        print("Decoded X-NPC-Response-Data (JSON): $npcResponseDataJson");
        print("-------------------------------------");

        var responsePayload = json.decode(npcResponseDataJson);
        
        String playerTranscription = _sanitizeString(responsePayload['input_target'] ?? "Transcription unavailable");
        String npcText = _sanitizeString(responsePayload['response_target'] ?? '...');
        List<POSMapping> npcPosMappings = (responsePayload['response_mapping'] as List? ?? [])
            .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();
        List<POSMapping> playerInputMappings = (responsePayload['input_mapping'] as List? ?? [])
            .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();

        print("Received Player Transcription: $playerTranscription");
        print("Received NPC Text: $npcText");
        print("Received Player Input Mappings: ${playerInputMappings.length} words");

        // Update charm level from backend
        if (responsePayload.containsKey('charm_delta')) { // This comes from NPCResponse model
            int charmDelta = responsePayload['charm_delta'] ?? 0;
            final charmNotifier = ref.read(currentCharmLevelProvider(widget.npcId).notifier);
            final oldCharm = charmNotifier.state;
            int newCharm = (oldCharm + charmDelta).clamp(0, 100);

            if (newCharm == 100 && oldCharm < 100) {
              // Using context from the widget, which should be safe.
              _showMaxCharmNotification(context);
            }
            
            charmNotifier.state = newCharm;
            print("Charm level updated by delta $charmDelta to: ${ref.read(currentCharmLevelProvider(widget.npcId))}");
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

        // Create entries for full history
        final playerEntryForHistory = DialogueEntry.player(playerTranscription, audioFileToSend.path, inputMappings: playerInputMappings);
        
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

        // Set current NPC display entry for the main box and start animation
        ref.read(currentNpcDisplayEntryProvider.notifier).state = npcEntryForDisplayAndHistory;
        _startNpcTextAnimation(
          idForAnimation: npcEntryId, // Pass the pre-generated ID
          speakerName: _npcData.name, // Pass speaker name
          fullText: npcText,
          englishText: responsePayload['response_english'] ?? '',
          audioPathToPlayWhenDone: tempNpcAudioPath, // Pass audio path
          audioBytesToPlayWhenDone: npcAudioBytes,   // Pass audio bytes
          posMappings: npcPosMappings,
          onAnimationComplete: (finalAnimatedEntry) {
            // History is already updated. Just update the map for correct display on rebuild.
            _fullyAnimatedMainNpcTexts[finalAnimatedEntry.id] = finalAnimatedEntry.text;
          }
        );

      } else {
        print("Backend processing failed. Status: ${response.statusCode}, Body: ${response.body}");
        
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
      topRightAction: (currentNpcDisplayEntry?.isNpc ?? false) && !isAnimatingThisNpcEntry && (currentNpcDisplayEntry?.audioPath != null || currentNpcDisplayEntry?.audioBytes != null)
        ? Positioned(
            top: -7,
            right: -7, // Adjusted to be next to the history icon
            child: IconButton(
              icon: Icon(Icons.volume_up, color: Colors.grey.shade600, size: 27),
              onPressed: () => _playDialogueAudio(currentNpcDisplayEntry!),
            ),
          )
        : null,
      giftIconAnimationController: _giftIconAnimationController,
      onRequestItem: () => _showRequestItemDialog(context),
      onResumeGame: () {
        widget.game.overlays.remove('dialogue');
        widget.game.resumeGame(ref);
      },
      onStartRecording: () => _startRecording(),
      onStopRecording: () => _stopRecording(),
      onShowTranslation: () => _showEnglishToTargetLanguageTranslationDialog(context),
      micButton: _buildMicButton(),
      isProcessingBackend: _isProcessingBackend,
      mainDialogueScrollController: _mainDialogueScrollController,
      onShowHistory: () => _showFullConversationHistoryDialog(context),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap, double size = 28, double padding = 12}) {
    return GestureDetector(
      onTap: onTap,
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

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        // Use a Consumer to rebuild only this dialog when settings change
        return Consumer(
          builder: (context, ref, child) {
            final settings = ref.watch(dialogueSettingsProvider);
            return AlertDialog(
              title: const Text('Dialogue Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('English Translation'),
                    subtitle: const Text('Show full English translation of dialogue.'),
                    value: settings.showEnglishTranslation,
                    onChanged: (_) => ref.read(dialogueSettingsProvider.notifier).toggleShowEnglishTranslation(),
                  ),
                  SwitchListTile(
                    title: const Text('Language Breakdown'),
                    subtitle: const Text('Show transliteration and POS for each word.'),
                    value: settings.showWordByWordAnalysis,
                    onChanged: (_) => ref.read(dialogueSettingsProvider.notifier).toggleWordByWordAnalysis(),
                  ),
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
      },
    );
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

                            // If it's a special item, mark it as received to prevent future interaction pop-ups
                            if (isSpecial) {
                              ref.read(specialItemReceivedProvider(widget.npcId).notifier).state = true;
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

  // --- Debug Charm Dialog ---
  Future<void> _showDebugCharmDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Debug: Set Charm Level"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                child: Text("Set Charm to 20"),
                onPressed: () {
                  ref.read(currentCharmLevelProvider(widget.npcId).notifier).state = 20;
                  Navigator.of(dialogContext).pop();
                },
              ),
              ElevatedButton(
                child: Text("Set Charm to 75"),
                onPressed: () {
                  ref.read(currentCharmLevelProvider(widget.npcId).notifier).state = 75;
                  Navigator.of(dialogContext).pop();
                },
              ),
              ElevatedButton(
                child: Text("Set Charm to 100"),
                onPressed: () {
                  ref.read(currentCharmLevelProvider(widget.npcId).notifier).state = 100;
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
          actions: [
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
                    if (entry.posMappings != null && entry.posMappings!.isNotEmpty && showWordByWordAnalysisInHistory) {
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
  
  // --- New Dialog for English to Target Language Translation Input ---
  Future<void> _showEnglishToTargetLanguageTranslationDialog(BuildContext context, {String targetLanguage = "th"}) async {
    // Set initial title when dialog is opened.
    _translationDialogTitleNotifier.value = 'Translate to ${getLanguageName(targetLanguage)}';

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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: ValueListenableBuilder<String>(
            valueListenable: _translationDialogTitleNotifier,
            builder: (context, title, child) => Text(title),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
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
                ValueListenableBuilder<bool>(
                  valueListenable: _translationIsLoadingNotifier,
                  builder: (context, isLoading, child) {
                    if (isLoading) {
                      return Center(child: CircularProgressIndicator());
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
                            return SizedBox.shrink();
                          },
                        ),
                        // Word mappings display with column format
                        ValueListenableBuilder<List<Map<String, String>>>(
                          valueListenable: _translationMappingsNotifier,
                          builder: (context, wordMappings, child) {
                            if (wordMappings.isEmpty) return SizedBox.shrink();
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row with play button
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
                                          if (audioBase64.isEmpty) return SizedBox.shrink();
                                          return IconButton(
                                            icon: Icon(Icons.volume_up, color: Colors.teal[700]),
                                            onPressed: () => playTranslatedAudio(audioBase64),
                                          );
                                        }
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  // Word mappings in column format
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: wordMappings.map((mapping) {
                                      return Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.teal.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Target language text (top)
                                            Text(
                                              mapping['target'] ?? '',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[800],
                                              ),
                                            ),
                                            SizedBox(height: 1),
                                            // Romanized text (middle)
                                            Text(
                                              mapping['romanized'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.teal[600],
                                              ),
                                            ),
                                            SizedBox(height: 1),
                                            // English text (bottom)
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
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Translate'),
              onPressed: () async {
                final String englishText = _translationEnglishController.text;
                if (englishText.trim().isEmpty) return;

                _translationIsLoadingNotifier.value = true;
                _translationErrorNotifier.value = null; // Clear previous errors

                try {
                  final response = await http.post(
                    Uri.parse('http://127.0.0.1:8000/gcloud-translate-tts/'), // New endpoint
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'english_text': englishText,
                      'target_language': targetLanguage
                    }),
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    
                    // Update dialog title with actual language name from response
                    if (data['target_language_name'] != null) {
                      _translationDialogTitleNotifier.value = 'Translate to ${data['target_language_name']}';
                    }
                    
                    _translationAudioNotifier.value = data['audio_base64'] ?? ""; // Store the audio
                    
                    // Handle word mappings, updating the display
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
                      _translationMappingsNotifier.value = []; // Clear mappings if none are returned
                    }
                  } else {
                    String errorMessage = "Error: ${response.statusCode}";
                    try {
                       final errorData = jsonDecode(response.body);
                       errorMessage += ": ${errorData['detail'] ?? 'Unknown backend error'}";
                    } catch(_){ /* Ignore if error body is not json */ }
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
          ],
        );
      },
    );
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

                currentNpcNotifier.state = finalAnimatedEntry; // Update provider with full text
                
                setState(() {
                    _fullyAnimatedMainNpcTexts[finalAnimatedEntry.id] = fullText; 
                    _currentlyAnimatingEntryId = ""; 
                });

                if (onAnimationComplete != null) {
                    onAnimationComplete(finalAnimatedEntry);
                }
                _scrollToBottom(_mainDialogueScrollController);
            }
        });
    });
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