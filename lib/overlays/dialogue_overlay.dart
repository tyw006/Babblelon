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
import '../providers/game_providers.dart'; // Ensure this import is present

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
      wordTarget: json['word_target'] as String,
      wordTranslit: json['word_translit'] as String,
      wordEng: json['word_eng'] as String,
      pos: json['pos'] as String,
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
      responseTarget: json['response_target'] as String,
      responseAudioPath: json['response_audio_path'] as String,
      responseEnglish: json['response_english'] as String? ?? '', 
      responseTranslit: json['response_translit'] as String? ?? '',
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
    String? audioPath, 
    Uint8List? audioBytes, 
    required String npcName, 
    List<POSMapping>? posMappings
  }) {
    return DialogueEntry(
      customId: id, // Pass it to the main constructor
      text: text,
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

// Provider to track if the greeting has been played for a specific NPC
final greetingPlayedProvider = StateProvider.family<bool, String>((ref, npcId) => false);

// Provider for the FULL conversation history (Player and NPC turns)
final fullConversationHistoryProvider = StateProvider<List<DialogueEntry>>((ref) => []);

// Provider for the CURRENT NPC entry being displayed/animated in the main dialogue box
final currentNpcDisplayEntryProvider = StateProvider<DialogueEntry?>((ref) => null);

// Provider for the current charm level
final currentCharmLevelProvider = StateProvider<int>((ref) => 50);

// Provider for the audio player used for replaying dialogue lines
final dialogueReplayPlayerProvider = Provider<just_audio.AudioPlayer>((ref) => just_audio.AudioPlayer());

// Convert to ConsumerStatefulWidget to access ref
class DialogueOverlay extends ConsumerStatefulWidget {
  final BabblelonGame game;
  final String currentNpcId = "amara"; // Example NPC ID, this should be dynamic
  final String currentNpcName = "Amara"; // Example NPC Name

  const DialogueOverlay({super.key, required this.game});

  @override
  ConsumerState<DialogueOverlay> createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends ConsumerState<DialogueOverlay> with TickerProviderStateMixin {
  final ScrollController _mainDialogueScrollController = ScrollController();
  final ScrollController _historyDialogScrollController = ScrollController(); // For history dialog
  late just_audio.AudioPlayer _greetingPlayer;
  bool _isRecording = false;

  // --- Audio Recording State ---
  late final AudioRecorder _audioRecorder;
  // --- End Audio Recording State ---

  // --- Animation State ---
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  // --- End Animation State ---

  Timer? _activeTextStreamTimer;
  String _currentlyAnimatingEntryId = "";
  String _displayedTextForAnimation = "";
  int _currentCharIndexForAnimation = 0;
  final Map<String, String> _fullyAnimatedMainNpcTexts = {}; 

  bool _isProcessingBackend = false;

  InitialNPCGreeting? _amaraInitialGreetingData; // To store parsed JSON data

  @override
  void initState() {
    super.initState();
    _greetingPlayer = just_audio.AudioPlayer();
    _audioRecorder = AudioRecorder();

    // --- Animation Initialization ---
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
    // --- End Animation Initialization ---

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialGreetingData();

      final hasPlayedGreeting = ref.read(greetingPlayedProvider(widget.currentNpcId));
      final currentNpcDisplayNotifier = ref.read(currentNpcDisplayEntryProvider.notifier);
      final fullHistoryNotifier = ref.read(fullConversationHistoryProvider.notifier);

      if (_amaraInitialGreetingData == null) {
        print("Error: Amara's initial greeting data could not be loaded.");
        final errorEntry = DialogueEntry.npc(text: "Error loading greeting.", npcName: widget.currentNpcName);
        currentNpcDisplayNotifier.state = errorEntry;
        fullHistoryNotifier.state = [errorEntry]; // Also add to history
        return;
      }

      if (!hasPlayedGreeting) {
        final placeholderForAnimation = DialogueEntry.npc(
          text: "",
          npcName: widget.currentNpcName,
          posMappings: _amaraInitialGreetingData!.responseMapping,
        );
        currentNpcDisplayNotifier.state = placeholderForAnimation;
        // Add to full history as well, it will be updated by animation completion
        fullHistoryNotifier.state = [placeholderForAnimation];
        
        _startNpcTextAnimation(
          idForAnimation: placeholderForAnimation.id,
          speakerName: widget.currentNpcName,
          fullText: _amaraInitialGreetingData!.responseTarget, 
          audioPathToPlayWhenDone: _amaraInitialGreetingData!.responseAudioPath,
          posMappings: _amaraInitialGreetingData!.responseMapping,
          onAnimationComplete: (finalAnimatedEntry) {
            fullHistoryNotifier.update((history) {
              final index = history.indexWhere((h) => h.id == finalAnimatedEntry.id);
              if (index != -1) {
                history[index] = finalAnimatedEntry;
                return List.from(history);
              }
              return history;
            });
          }
        );
        ref.read(greetingPlayedProvider(widget.currentNpcId).notifier).state = true;
      } else {
          // If greeting was played, try to restore the last state or show greeting
          final history = ref.read(fullConversationHistoryProvider);
          if (history.isNotEmpty && history.last.isNpc) {
              currentNpcDisplayNotifier.state = history.last;
              _fullyAnimatedMainNpcTexts[history.last.id] = history.last.text;
          } else if (history.isEmpty) { // Or if history is empty, replay initial greeting
              final initialGreetingEntry = DialogueEntry.npc(
                  text: _amaraInitialGreetingData!.responseTarget,
                  npcName: widget.currentNpcName,
                  audioPath: _amaraInitialGreetingData!.responseAudioPath,
                  posMappings: _amaraInitialGreetingData!.responseMapping
                );
              currentNpcDisplayNotifier.state = initialGreetingEntry;
              fullHistoryNotifier.state = [initialGreetingEntry];
              _fullyAnimatedMainNpcTexts[initialGreetingEntry.id] = initialGreetingEntry.text;
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
    try {
      final String response = await rootBundle.loadString('assets/data/npc_initial_dialogues.json');
      final data = json.decode(response) as Map<String, dynamic>;
      if (data[widget.currentNpcId] != null) {
        _amaraInitialGreetingData = InitialNPCGreeting.fromJson(data[widget.currentNpcId] as Map<String, dynamic>);
        print("Initial greeting data loaded for ${widget.currentNpcId}");
      } else {
        print("No initial greeting data found for NPC ID: ${widget.currentNpcId}");
      }
    } catch (e) {
      print("Error loading initial greeting data: $e");
      _amaraInitialGreetingData = null;
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
    _greetingPlayer.dispose();
    _audioRecorder.dispose();
    _animationController?.dispose();
    _activeTextStreamTimer?.cancel();
    _mainDialogueScrollController.dispose();
    _historyDialogScrollController.dispose();
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
      final currentFullHistory = ref.read(fullConversationHistoryProvider);
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

      final charmLevelForRequest = ref.read(currentCharmLevelProvider); // Read from provider

      var uri = Uri.parse('http://127.0.0.1:8000/generate-npc-response/');
    var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('audio_file', audioFileToSend.path))
        ..fields['npc_id'] = widget.currentNpcId
        ..fields['npc_name'] = widget.currentNpcName
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
        
        String playerTranscription = responsePayload['player_transcription'] ?? "Transcription unavailable";
        String npcText = responsePayload['response_target'];
        List<POSMapping> npcPosMappings = (responsePayload['response_mapping'] as List? ?? [])
            .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();
        List<POSMapping> playerInputMappings = (responsePayload['input_mapping'] as List? ?? [])
            .map((m) => POSMapping.fromJson(m as Map<String, dynamic>)).toList();

        print("Received Player Transcription: $playerTranscription");
        print("Received NPC Text: $npcText");
        print("Received Player Input Mappings: ${playerInputMappings.length} words");

        // Update charm level from backend
        if (responsePayload.containsKey('new_charm_level')) {
             // Note: NPCResponse model itself doesn't have new_charm_level, it's part of the LLM's raw output that llm_service maps to charm_delta.
             // The main.py currently sends the *original* NPCResponse model dump.
             // For now, we rely on charm_delta from NPCResponse.
        }
        if (responsePayload.containsKey('charm_delta')) { // This comes from NPCResponse model
            int charmDelta = responsePayload['charm_delta'] ?? 0;
             ref.read(currentCharmLevelProvider.notifier).update((state) => (state + charmDelta).clamp(0, 100));
             print("Charm level updated by delta $charmDelta to: ${ref.read(currentCharmLevelProvider)}");
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

        final npcEntryForDisplayAndHistory = DialogueEntry.npc(
          id: npcEntryId, // Use the pre-generated ID
          text: "", // Start with blank for animation
          npcName: widget.currentNpcName,
          audioPath: tempNpcAudioPath, // This is the path to the NPC's audio file
          audioBytes: npcAudioBytes, // This is the actual audio data for NPC
          posMappings: npcPosMappings, 
        );

        // Update full conversation history
        final fullHistoryNotifier = ref.read(fullConversationHistoryProvider.notifier);
        fullHistoryNotifier.update((history) => [...history, playerEntryForHistory, npcEntryForDisplayAndHistory]);
         WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(_historyDialogScrollController));

        // Set current NPC display entry for the main box and start animation
        ref.read(currentNpcDisplayEntryProvider.notifier).state = npcEntryForDisplayAndHistory;
        _startNpcTextAnimation(
          idForAnimation: npcEntryId, // Pass the pre-generated ID
          speakerName: widget.currentNpcName, // Pass speaker name
          fullText: npcText,
          audioPathToPlayWhenDone: tempNpcAudioPath, // Pass audio path
          audioBytesToPlayWhenDone: npcAudioBytes,   // Pass audio bytes
          posMappings: npcPosMappings,
          onAnimationComplete: (finalAnimatedEntry) {
             // Update the entry in full history with the final animated text
            fullHistoryNotifier.update((history) {
                final index = history.indexWhere((h) => h.id == finalAnimatedEntry.id);
                if (index != -1) {
                    history[index] = finalAnimatedEntry; // finalAnimatedEntry now has the full text
                    return List.from(history);
                }
                return history;
            });
            _fullyAnimatedMainNpcTexts[finalAnimatedEntry.id] = finalAnimatedEntry.text;
          }
        );

      } else {
        print("Backend processing failed. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e, stackTrace) {
      print("Exception in _sendAudioToBackend: $e\\n$stackTrace");
    } finally {
      setState(() { _isProcessingBackend = false; });
      // The recorded file is no longer deleted here.
      // It will be cleaned up on game exit.
    }
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
    final double outerHorizontalPadding = screenWidth * 0.01;

    final double textboxHeight = 150.0; // Fixed height for main dialogue box
    final double textboxWidth = math.max(screenWidth * 0.95, 368.0);

    final dialogueSettings = ref.watch(dialogueSettingsProvider); // Watch the central provider
    final currentNpcDisplayEntry = ref.watch(currentNpcDisplayEntryProvider);
    final bool showTranslations = dialogueSettings.showTranslation;
    final bool showTransliterations = dialogueSettings.showTransliteration;
    final bool showPOSColors = dialogueSettings.showPos;
    final int displayedCharmLevel = ref.watch(currentCharmLevelProvider); // Watch charm level for UI

    // Define isAnimatingThisNpcEntry carefully, ensuring currentNpcDisplayEntry is not null before accessing 'id'
    final bool isAnimatingThisNpcEntry = (currentNpcDisplayEntry != null && currentNpcDisplayEntry.id == _currentlyAnimatingEntryId);

    Widget npcContentWidget;
    if (currentNpcDisplayEntry == null) {
        npcContentWidget = SizedBox.shrink(); // Or a placeholder
    } else {
        String textToDisplayForNpc = isAnimatingThisNpcEntry ? _displayedTextForAnimation : (_fullyAnimatedMainNpcTexts[currentNpcDisplayEntry.id] ?? currentNpcDisplayEntry.text);

        if (isAnimatingThisNpcEntry) {
            npcContentWidget = Text(
                textToDisplayForNpc,
                textAlign: TextAlign.left,
                style: TextStyle(color: Colors.black, fontSize: 16),
            );
        } else if (currentNpcDisplayEntry.isNpc && currentNpcDisplayEntry.posMappings != null && currentNpcDisplayEntry.posMappings!.isNotEmpty) {
            // Word-column display for live NPC responses
            List<InlineSpan> wordSpans = currentNpcDisplayEntry.posMappings!.map((mapping) {
                List<Widget> wordParts = [
                    Text(mapping.wordTarget, style: TextStyle(color: showPOSColors ? (posColorMapping[mapping.pos] ?? Colors.black) : Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
                ];
                if (showTransliterations && mapping.wordTranslit.isNotEmpty) {
                    wordParts.add(SizedBox(height: 1));
                    wordParts.add(Text(mapping.wordTranslit, style: TextStyle(fontSize: 10, color: showPOSColors ? (posColorMapping[mapping.pos] ?? Colors.black54) : Colors.black54)));
                }
                if (showTranslations && mapping.wordEng.isNotEmpty) {
                    wordParts.add(SizedBox(height: 1));
                    wordParts.add(Text(mapping.wordEng, style: TextStyle(fontSize: 10, color: showPOSColors ? (posColorMapping[mapping.pos] ?? Colors.blueGrey.shade600) : Colors.blueGrey.shade600, fontStyle: FontStyle.italic)));
                }
                return WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3.0, bottom: 2.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: wordParts),
                  ),
                );
            }).toList();
            npcContentWidget = RichText(textAlign: TextAlign.left, text: TextSpan(children: wordSpans));
        } else {
            // NPC text without special formatting (e.g., if no POS mappings)
            npcContentWidget = Text(textToDisplayForNpc, style: TextStyle(fontSize: 14, color: Colors.black87));
        }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset('assets/images/background/convo_yaowarat_bg.png', fit: BoxFit.cover),
          ),
          SafeArea(
            bottom: false,
            top: true,
            child: Stack(
              children: <Widget>[
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.002),
                    child: Image.asset('assets/images/npcs/sprite_dimsum_vendor_bar.png', width: screenWidth * 0.7, fit: BoxFit.contain),
                  ),
                ),
                Align(
                  alignment: Alignment(0.0, 0.0),
                  child: Image.asset('assets/images/npcs/sprite_dimsum_vendor_female_portrait.png', height: screenHeight * 0.70, fit: BoxFit.contain),
                ),
                Positioned( // Charm Score Display
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(128),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Charm: $displayedCharmLevel',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: outerHorizontalPadding,
                      right: outerHorizontalPadding,
                      bottom: MediaQuery.of(context).padding.bottom + 0.0,
                    ),
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container( // Main Dialogue Box
                            width: textboxWidth,
                            height: textboxHeight,
                            clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                image: AssetImage('assets/images/ui/textbox_hdpi.9.png'),
                                  fit: BoxFit.fill,
                                  centerSlice: Rect.fromLTWH(22, 22, 324, 229),
                                ),
                              ),
                            child: Stack(
                                children: [
                                      Padding(
                                  padding: const EdgeInsets.only(top: 30.0, left: 30.0, right: 25.0, bottom: 25.0),
                                  child: Scrollbar(
                                                thumbVisibility: true,
                                    controller: _mainDialogueScrollController,
                                                child: SingleChildScrollView(
                                      controller: _mainDialogueScrollController,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (currentNpcDisplayEntry != null) // Combined speaker and content logic
                                            Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 4.0), 
                                                            child: Column( 
                                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                                              children: [
                                                  
                                                  Row( // Row for content and play button
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(child: npcContentWidget), // Dialogue content
                                                      // Play button only if not animating and content is present and has audio
                                                      if (currentNpcDisplayEntry.id != _currentlyAnimatingEntryId && 
                                                          (_fullyAnimatedMainNpcTexts.containsKey(currentNpcDisplayEntry.id) || currentNpcDisplayEntry.text.isNotEmpty) &&
                                                          (currentNpcDisplayEntry.audioPath != null || currentNpcDisplayEntry.audioBytes != null))
                                                        IconButton(
                                                          icon: Icon(Icons.volume_up, color: Colors.black54),
                                                          iconSize: 20,
                                                          padding: EdgeInsets.only(left: 8, top: 0, bottom: 0, right: 0),
                                                          constraints: BoxConstraints(),
                                                          onPressed: () => _playDialogueAudio(currentNpcDisplayEntry),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                      if (_isProcessingBackend)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Text("...", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                        ),
                                    ],
                                  ),
                                    ),
                                  ),
                                ),
                                Positioned( // Full Convo Button
                                  top: 0, 
                                  right: 30,
                                  child: SizedBox(
                                    width: 35, // Adjust size as needed
                                    height: 35,
                                    child: IconButton(
                                      icon: Image.asset('assets/images/ui/button_full_convo.png'), // New button
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                      onPressed: () => _showFullConversationHistoryDialog(context),
                                    ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row( // Bottom Action Buttons
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: SizedBox(width: 70, height: 70, child: Image.asset('assets/images/ui/button_back.png', fit: BoxFit.contain)),
                                onPressed: () {
                                  widget.game.overlays.remove('dialogue');
                                  widget.game.resumeGame(ref);
                                },
                              ),
                              GestureDetector(
                                onLongPressStart: (_) {
                                  if (!_isProcessingBackend) _startRecording();
                                },
                                onLongPressEnd: (_) {
                                  if (!_isProcessingBackend) _stopRecording();
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_isRecording)
                                      ScaleTransition(
                                        scale: _scaleAnimation!,
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.blue.withAlpha(128),
                                          ),
                                        ),
                                      ),
                                    SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: Image.asset('assets/images/ui/button_mic.png', fit: BoxFit.contain)
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: SizedBox(width: 80, height: 80, child: Image.asset('assets/images/ui/button_translate.png', fit: BoxFit.contain)),
                                onPressed: () => _showEnglishToThaiTranslationDialog(context), // Changed to new dialog
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
                          ),
                        ],
                      ),
    );
  }

  // --- Full Conversation History Dialog ---
  Future<void> _showFullConversationHistoryDialog(BuildContext context) async {
    final historyEntries = ref.watch(fullConversationHistoryProvider); // Watch for live updates
    final dialogueSettings = ref.watch(dialogueSettingsProvider);
    final bool showTranslationsInHistory = dialogueSettings.showTranslation;
    final bool showTransliterationsInHistory = dialogueSettings.showTransliteration;
    final bool showPOSColorsInHistory = dialogueSettings.showPos;

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
                  Widget entryContentWidget;

                  if (entry.isNpc) {
                      if (entry.posMappings != null && entry.posMappings!.isNotEmpty) {
                      // NPC live response with word columns
                      List<InlineSpan> wordSpans = entry.posMappings!.map((mapping) {
                        List<Widget> wordParts = [
                          Text(mapping.wordTarget, style: TextStyle(color: showPOSColorsInHistory ? (posColorMapping[mapping.pos] ?? Colors.black87) : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)),
                        ];
                        if (showTransliterationsInHistory && mapping.wordTranslit.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordTranslit, style: TextStyle(fontSize: 10, color: showPOSColorsInHistory ? (posColorMapping[mapping.pos] ?? Colors.black54) : Colors.black54)));
                        }
                        if (showTranslationsInHistory && mapping.wordEng.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordEng, style: TextStyle(fontSize: 10, color: showPOSColorsInHistory ? (posColorMapping[mapping.pos] ?? Colors.blueGrey.shade600) : Colors.blueGrey.shade600, fontStyle: FontStyle.italic)));
                        }
                        return WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3.0, bottom: 2.0),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: wordParts),
                          ),
                        );
                      }).toList();
                      entryContentWidget = RichText(textAlign: TextAlign.left, text: TextSpan(children: wordSpans));
                    } else {
                      // NPC text without special formatting (e.g., if no POS mappings)
                      entryContentWidget = Text(entry.text, style: TextStyle(fontSize: 14, color: Colors.black87));
                    }
                  } else {
                    // Player's transcribed text - check if we have POS mappings for enhanced display
                    if (entry.posMappings != null && entry.posMappings!.isNotEmpty) {
                      // Player input with word columns (same as NPC but with different base color)
                      List<InlineSpan> wordSpans = entry.posMappings!.map((mapping) {
                        List<Widget> wordParts = [
                          Text(mapping.wordTarget, style: TextStyle(color: showPOSColorsInHistory ? (posColorMapping[mapping.pos] ?? Colors.deepPurple.shade700) : Colors.deepPurple.shade700, fontSize: 14, fontWeight: FontWeight.w500)),
                        ];
                        if (showTransliterationsInHistory && mapping.wordTranslit.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordTranslit, style: TextStyle(fontSize: 10, color: showPOSColorsInHistory ? (posColorMapping[mapping.pos] ?? Colors.deepPurple.shade400) : Colors.deepPurple.shade400)));
                        }
                        if (showTranslationsInHistory && mapping.wordEng.isNotEmpty) {
                          wordParts.add(SizedBox(height: 1));
                          wordParts.add(Text(mapping.wordEng, style: TextStyle(fontSize: 10, color: showPOSColorsInHistory ? (posColorMapping[mapping.pos] ?? Colors.deepPurple.shade300) : Colors.deepPurple.shade300, fontStyle: FontStyle.italic)));
                        }
                        return WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3.0, bottom: 2.0),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: wordParts),
                          ),
                        );
                      }).toList();
                      entryContentWidget = RichText(textAlign: TextAlign.left, text: TextSpan(children: wordSpans));
                    } else {
                      // Player's transcribed text without POS mappings (fallback)
                      entryContentWidget = Text(entry.playerTranscriptionForHistory ?? entry.text, style: TextStyle(fontSize: 14, color: Colors.deepPurple.shade700));
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
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row( // Row for content and play button
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: entryContentWidget), // Dialogue content
                            // Play button only if entry has audio
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
  
  // --- New Dialog for English to Thai Translation Input ---
  Future<void> _showEnglishToThaiTranslationDialog(BuildContext context) async {
    final TextEditingController englishTextController = TextEditingController();
    final ValueNotifier<String> translatedThaiTextNotifier = ValueNotifier<String>("");
    final ValueNotifier<String> translatedRomanizationNotifier = ValueNotifier<String>("");
    final ValueNotifier<String> audioBase64Notifier = ValueNotifier<String>(""); // To store audio data
    final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
    final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

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
        errorNotifier.value = "Error playing audio.";
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Translate to Thai'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Enter English text to translate:'),
                SizedBox(height: 8),
                TextField(
                  controller: englishTextController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type here...',
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: isLoadingNotifier,
                  builder: (context, isLoading, child) {
                    if (isLoading) {
                      return Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: errorNotifier,
                          builder: (context, error, child) {
                            if (error != null) {
                              return Text(error, style: TextStyle(color: Colors.red));
                            }
                            return SizedBox.shrink();
                          },
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: translatedThaiTextNotifier,
                          builder: (context, thaiText, child) {
                            if (thaiText.isEmpty) return SizedBox.shrink();
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row( // Row for text and play button
                                children: [
                                  Expanded(
                                    child: Text(thaiText, style: TextStyle(fontSize: 16, color: Colors.teal[800]))
                                  ),
                                  ValueListenableBuilder<String>(
                                    valueListenable: audioBase64Notifier,
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
                            );
                          },
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: translatedRomanizationNotifier,
                          builder: (context, romanizedText, child) {
                            if (romanizedText.isEmpty) return SizedBox.shrink();
                            return Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(romanizedText, style: TextStyle(fontSize: 14, color: Colors.blueGrey[700])),
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
                final String englishText = englishTextController.text;
                if (englishText.trim().isEmpty) return;

                isLoadingNotifier.value = true;
                translatedThaiTextNotifier.value = "";
                translatedRomanizationNotifier.value = "";
                errorNotifier.value = null;
                audioBase64Notifier.value = ""; // Clear previous audio

                try {
                  final response = await http.post(
                    Uri.parse('http://127.0.0.1:8000/gcloud-translate-tts/'), // New endpoint
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'english_text': englishText}),
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    translatedThaiTextNotifier.value = data['thai_text'] ?? "";
                    translatedRomanizationNotifier.value = data['romanized_text'] ?? "";
                    audioBase64Notifier.value = data['audio_base64'] ?? ""; // Store the audio
                  } else {
                    String errorMessage = "Error: ${response.statusCode}";
                    try {
                       final errorData = jsonDecode(response.body);
                       errorMessage += ": ${errorData['detail'] ?? 'Unknown backend error'}";
                    } catch(_){ /* Ignore if error body is not json */ }
                    errorNotifier.value = errorMessage;
                    print("Backend translation error: ${response.body}");
                  }
                } catch (e) {
                  errorNotifier.value = "Error: Could not connect to translation service.";
                  print("Network or other error calling translation backend: $e");
                }

                isLoadingNotifier.value = false;
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
                return audioPathToPlayWhenDone!.startsWith('assets/') 
                    ? await tempPlayer.setAsset(audioPathToPlayWhenDone!)
                    : await tempPlayer.setAudioSource(just_audio.AudioSource.uri(Uri.file(audioPathToPlayWhenDone!)));
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
                    npcName: entryWithCorrectIdForAnimation.speaker, 
                    audioPath: entryWithCorrectIdForAnimation.audioPath, 
                    audioBytes: entryWithCorrectIdForAnimation.audioBytes,
                    posMappings: entryWithCorrectIdForAnimation.posMappings
                );

                currentNpcNotifier.state = finalAnimatedEntry; // Update provider with final text
                
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

// Custom AudioSource for playing from a list of bytes or a stream (Unchanged)
class _MyCustomStreamAudioSource extends just_audio.StreamAudioSource {
  final Uint8List? _fixedBytes;

  _MyCustomStreamAudioSource.fromBytes(this._fixedBytes) 
    : super(tag: 'npc-audio-bytes-${DateTime.now().millisecondsSinceEpoch}');

  @override
  Future<just_audio.StreamAudioResponse> request([int? start, int? end]) async {
    if (_fixedBytes != null) {
      start ??= 0;
      end ??= _fixedBytes.length;
      return just_audio.StreamAudioResponse(
        sourceLength: _fixedBytes.length,
        contentLength: end - start,
        offset: start,
        stream: Stream.value(_fixedBytes.sublist(start, end)),
        contentType: 'audio/wav',
      );
    }
    throw Exception("CustomStreamAudioSource not initialized with bytes or stream");
  }
} 