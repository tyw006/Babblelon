import 'dart:async'; // Added for Timer
import 'dart:math' as math; // Added for math.min
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // Added for File
import 'package:http/http.dart' as http; // Added for http
import 'dart:convert'; // Added for json encoding/decoding
import 'package:flutter/services.dart'; // Added for DefaultAssetBundle

import '../game/babblelon_game.dart';

// --- Dialogue Entry Model ---
@immutable
class DialogueEntry {
  final String id; // Unique ID for the entry
  final String text;
  final String speaker;
  final String? audioPath; // For player's recorded audio
  final Uint8List? audioBytes; // For NPC's TTS audio
  final bool isNpc;

  const DialogueEntry({
    required this.id,
    required this.text,
    required this.speaker,
    this.audioPath, // Now common for both player and NPC if applicable
    this.audioBytes,
    required this.isNpc,
  });

  // Helper to create a unique ID
  static String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  // Factory constructors for convenience
  factory DialogueEntry.player(String text, String audioPath) {
    return DialogueEntry(
      id: _generateId(),
      text: text,
      speaker: 'Player',
      audioPath: audioPath,
      isNpc: false,
    );
  }

  factory DialogueEntry.npc(String text, {String? audioPath, Uint8List? audioBytes, required String npcName}) {
    return DialogueEntry(
      id: _generateId(),
      text: text,
      speaker: npcName, // Use dynamic NPC name
      audioPath: audioPath, // Added audioPath here
      audioBytes: audioBytes,
      isNpc: true,
    );
  }
}
// --- End Dialogue Entry Model ---

// Provider to track if the greeting has been played for a specific NPC
final greetingPlayedProvider = StateProvider.family<bool, String>((ref, npcId) => false);

// Provider to manage the current dialogue lines as List<DialogueEntry>
final dialogueEntriesProvider = StateProvider<List<DialogueEntry>>((ref) => []);

// Provider for the audio player used for replaying dialogue lines
final dialogueReplayPlayerProvider = Provider<just_audio.AudioPlayer>((ref) => just_audio.AudioPlayer());

// Provider for the recorder
final soundRecorderProvider = Provider<FlutterSoundRecorder>((ref) {
  final recorder = FlutterSoundRecorder();
  return recorder;
});

// Convert to ConsumerStatefulWidget to access ref
class DialogueOverlay extends ConsumerStatefulWidget {
  final BabblelonGame game;
  final String currentNpcId = "amara"; // Example NPC ID, this should be dynamic
  final String currentNpcName = "Amara"; // Example NPC Name

  const DialogueOverlay({Key? key, required this.game}) : super(key: key);

  @override
  ConsumerState<DialogueOverlay> createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends ConsumerState<DialogueOverlay> {
  bool _isExpanded = false; // State for textbox expansion
  final ScrollController _scrollController = ScrollController(); // For auto-scrolling
  late just_audio.AudioPlayer _greetingPlayer;
  late FlutterSoundRecorder _recorder;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _textStreamTimer;
  int _currentCharIndex = 0;
  String _currentGreetingText = "";
  String _fullGreetingTextToStream = "";

  // Stream controller for NPC TTS audio bytes
  StreamController<List<int>>? _npcAudioStreamController;
  just_audio.AudioPlayer? _npcLivePlayer; // Player for live NPC TTS

  // --- Text Animation State ---
  Timer? _activeTextStreamTimer; // Single timer for current animation
  
  String _currentlyAnimatingEntryId = ""; // ID of the DialogueEntry being animated
  String _fullTextForAnimation = "";    // Full text to be animated for the current entry
  String _displayedTextForAnimation = ""; // Current partially displayed text for the animation
  int _currentCharIndexForAnimation = 0;

  final Map<String, String> _fullyAnimatedTexts = {}; // Store final text of animated entries to prevent re-animation

  // --- End Text Animation State ---

  // --- Charm Level State ---
  int _currentCharmLevel = 50; // Initial charm level
  // --- End Charm Level State ---

  // --- Processing State for Backend ---
  bool _isProcessingBackend = false; // Renamed from _isProcessingNpcResponse
  // --- End Processing State ---

  static const String _initialGreetingAmaraTextOnly = "สวัสดีค่ะ! ยินดีต้อนรับสู่แผงติ่มซำค่ะ!";

  // Function to get the speaker from the line
  String _getSpeaker(DialogueEntry entry) {
    return entry.speaker;
  }

  // Function to get the actual dialogue text without the speaker prefix
  String _getDialogueText(DialogueEntry entry) {
    return entry.text;
  }

  @override
  void initState() {
    super.initState();
    _greetingPlayer = just_audio.AudioPlayer();
    // _recorder = FlutterSoundRecorder(); // Recorder removed

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hasPlayedGreeting = ref.read(greetingPlayedProvider(widget.currentNpcId));
      final dialogueNotifier = ref.read(dialogueEntriesProvider.notifier);

      if (!hasPlayedGreeting) {
        // This is the conceptual entry with full data
        final DialogueEntry initialGreetingData = DialogueEntry.npc(
          _initialGreetingAmaraTextOnly, 
          npcName: widget.currentNpcName,
          audioPath: 'assets/audio/npc/amara_greeting.wav' 
        );
        
        // This is the actual entry added to the list, which will be animated.
        // It starts blank and its text field is populated by the animation.
        // It gets its own unique ID from the DialogueEntry constructor.
        final DialogueEntry placeholderForAnimation = DialogueEntry.npc(
            "", // Blank text initially
            npcName: widget.currentNpcName
            // audioPath will be set by animation completion
        );
        dialogueNotifier.state = [placeholderForAnimation];
        
        // Start animation for the placeholder entry, using data from initialGreetingData
        _startTextAnimation(
          entry: placeholderForAnimation, // Animate the placeholder
          fullText: initialGreetingData.text, 
          audioPathToPlayWhenDone: initialGreetingData.audioPath
        );
        ref.read(greetingPlayedProvider(widget.currentNpcId).notifier).state = true;
      } else {
        // If greeting already played, ensure current dialogue list is correct
        // This might involve loading from a saved state in a more complex app
        if (dialogueNotifier.state.isEmpty || 
            (dialogueNotifier.state.last.speaker != widget.currentNpcName || 
             dialogueNotifier.state.last.text != _initialGreetingAmaraTextOnly)) {
              // Show the full initial greeting if re-entering and it's not the last message
              // Or, if dialogue is empty, add it.
              // This assumes we want to always have at least the greeting.
              // A proper game state would manage this better.
               DialogueEntry finalGreetingEntry = DialogueEntry.npc(
                  _initialGreetingAmaraTextOnly, 
                  npcName: widget.currentNpcName,
                  audioPath: 'assets/audio/npc/amara_greeting.wav');
              dialogueNotifier.state = [finalGreetingEntry];
              _fullyAnimatedTexts[finalGreetingEntry.id] = _initialGreetingAmaraTextOnly;

        }
      }
      // _requestMicPermission(); // Mic permission removed for now
    });

    // Scroll to bottom when new lines are added or widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToBottom();
      }
    });
  }

  // Future<void> _requestMicPermission() async {
  //   var status = await Permission.microphone.request();
  //   if (status != PermissionStatus.granted) {
  //     // Handle permission denial
  //     print("Microphone permission denied");
  //     // Optionally, show a dialog to the user
  //   }
  // }

  void _playInitialGreetingAndStreamText(DialogueEntry initialEntry) async {
    try {
      final greetingAudioPath = 'assets/audio/npc/amara_greeting.wav';
      final duration = await _greetingPlayer.setAsset(greetingAudioPath);
      // Audio will be played once character streaming starts or slightly after.

      _currentCharIndex = 0;
      _currentGreetingText = "${initialEntry.speaker}: "; 
      // Prepend speaker to the text that will be displayed char-by-char
      String textToStreamWithSpeaker = "${initialEntry.speaker}: ${_fullGreetingTextToStream}";
      
      final audioDurationMs = (duration ?? Duration(seconds: _fullGreetingTextToStream.length * 0.1.toInt())) // Estimate 0.1s per char if duration is null
          .inMilliseconds;
      
      // Start playing audio slightly after text streaming begins, or adjust as preferred
      // For this example, let's play it right away and sync text finish with audio finish.
      _greetingPlayer.play();

      // Calculate character display time based on audio duration and total characters (including speaker tag)
      final estimatedCharDisplayTime = (audioDurationMs * 0.95) / (textToStreamWithSpeaker.isEmpty ? 1 : textToStreamWithSpeaker.length);
      final charDuration = Duration(milliseconds: math.max(50, estimatedCharDisplayTime.round())); // Ensure a minimum speed e.g. 50ms

      _textStreamTimer?.cancel();
      _textStreamTimer = Timer.periodic(charDuration, (timer) {
        if (_currentCharIndex < textToStreamWithSpeaker.length) {
          setState(() {
            // Append one character at a time
            _currentGreetingText = textToStreamWithSpeaker.substring(0, _currentCharIndex + 1);
            
            // Update the provider with the currently visible text (stripping speaker for the entry's text field)
            String currentDisplayableText = _currentGreetingText;
            if (currentDisplayableText.startsWith("${initialEntry.speaker}: ")) {
                currentDisplayableText = currentDisplayableText.substring(initialEntry.speaker.length + 2);
            }

            ref.read(dialogueEntriesProvider.notifier).state = [
              DialogueEntry.npc(currentDisplayableText, 
                                audioPath: null, // Audio path will be set at the end for replay
                                npcName: initialEntry.speaker) 
            ];
            _scrollToBottom();
          });
          _currentCharIndex++;
        } else {
          timer.cancel();
          // Ensure the final full text is set, and associate the audio path for future replays.
          ref.read(dialogueEntriesProvider.notifier).state = [
            DialogueEntry.npc(initialEntry.text, audioPath: greetingAudioPath, npcName: initialEntry.speaker)
          ];
          _scrollToBottom();
        }
      });
    } catch (e) {
      print("Error playing initial greeting: $e");
      ref.read(dialogueEntriesProvider.notifier).state = [initialEntry];
      _scrollToBottom();
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Delay slightly to allow UI to build before scrolling
      Future.delayed(Duration(milliseconds: 50), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _greetingPlayer.dispose();
    // _recorder.closeRecorder(); // Recorder removed
    _textStreamTimer?.cancel();
    _scrollController.dispose();
    // _npcAudioStreamController?.close(); // Removed
    // _npcLivePlayer?.dispose(); // Removed
    _activeTextStreamTimer?.cancel(); // Changed from _textStreamTimer
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Microphone recording functionality removed for now.
    // This function can be reinstated later.
    print("Mic button pressed. Original recording logic removed for testing with fixed audio.");
    setState(() { _isRecording = true; }); // Keep for UI icon change if desired

    // Directly proceed to send test audio
    final String testAudioPath = 'assets/audio/test/test_input1.wav';
    // We need a File object for _sendAudioToBackend.
    // For assets, we can't directly create a File object in the same way as a temp file.
    // The backend expects a file upload. For this temporary workaround,
    // we'll need to simulate this. A proper solution would be for the backend
    // to also accept a path or identifier that it can resolve to a pre-stored test file.
    // OR, we copy the asset to a temporary file first.

    // Set processing state true at the very beginning of the user action
    setState(() {
      _isProcessingBackend = true;
    });

    try {
      final byteData = await DefaultAssetBundle.of(context).load(testAudioPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_test_input.wav');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      
      print("Test audio prepared. Sending to backend. Placeholder UI message removed.");
      
      // Create a player entry to get a unique ID for this turn. 
      // This entry might be added to the list later when transcription is received.
      final playerActionEntry = DialogueEntry.player("...", tempFile.path); // Text is temporary

      // _sendAudioToBackend(tempFile, playerActionEntry.id); // Old call
      _sendAudioForTranscription(tempFile, playerActionEntry);
      
      // Simulate recording stop for UI consistency if icon changes
      // No need to call _stopRecordingAndProcess as its logic is now partly here.
      setState(() { _isRecording = false; });

    } catch (e) {
      print("Error preparing or sending test asset: $e");
      setState(() { _isRecording = false; });
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    // Original recording functionality removed.
    // This function is not called directly if _startRecording sends the test audio.
    // If you re-enable recording, this will need to be restored.
    print("Original _stopRecordingAndProcess called, but recording is disabled for testing.");
    setState(() { _isRecording = false; });
  }

  Future<void> _sendAudioForTranscription(File audioFile, DialogueEntry playerEntryPlaceholder) async {
    var uri = Uri.parse('http://127.0.0.1:8000/transcribe-audio/');
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('audio_file', audioFile.path));

    final dialogueNotifier = ref.read(dialogueEntriesProvider.notifier);

    // DO NOT add player placeholder to UI here anymore for "(Transcribing...)"
    // final placeholderWithActualId = DialogueEntry.player(
    // "(Transcribing...)", 
    // playerEntryPlaceholder.audioPath!, 
    // );
    // dialogueNotifier.state = [...dialogueNotifier.state, placeholderWithActualId];
    // _scrollToBottom();

    print("Sending audio for transcription...");

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        String playerTranscription = jsonResponse['transcription'];
        print("Transcription received: $playerTranscription");

        // --- Start NPC response generation in the background --- 
        // setState(() { // This was for _isProcessingNpcResponse, now covered by _isProcessingBackend
        // _isProcessingNpcResponse = true; 
        // });
        _getNpcResponseAndAudio(playerTranscription, playerEntryPlaceholder.id); // Use placeholder ID
        // --- End NPC response generation ---

        // Update the player's entry with the transcription and start animation
        _startTextAnimation(
          entry: playerEntryPlaceholder, 
          fullText: playerTranscription,
          audioPathToPlayWhenDone: playerEntryPlaceholder.audioPath, 
          onAnimationComplete: () {
            // NPC response is already being fetched. 
            // This callback might be used for other UI updates if needed after player text finishes,
            // or it can be removed if _getNpcResponseAndAudio handles all subsequent steps.
            print("Player text animation completed. NPC response fetch is in progress.");
          }
        );
      } else {
        print("Transcription failed. Status: ${response.statusCode}, Body: ${response.body}");
        // Update UI to show transcription failure for the player's line - REMOVED
        // dialogueNotifier.update((state) => state.map((entry) { ... }).toList());
        // _scrollToBottom();
        setState(() { // Ensure processing indicator is turned off on STT error
          _isProcessingBackend = false;
        });
      }
    } catch (e, stackTrace) {
      print("Exception in _sendAudioForTranscription: $e\n$stackTrace");
      // dialogueNotifier.update((state) => state.map((entry) { ... }).toList()); // Error message removed
      // _scrollToBottom();
      setState(() { // Ensure processing indicator is turned off on exception
        _isProcessingBackend = false;
      });
    }
  }

  Future<void> _getNpcResponseAndAudio(String playerTranscription, String playerEntryIdForHistory) async {
    // _isProcessingBackend should already be true if this function is called.
    // if (!_isProcessingBackend) { // This check might be redundant now
    //   setState(() {
    // _isProcessingBackend = true;
    //   });
    // }

    var uri = Uri.parse('http://127.0.0.1:8000/generate-npc-response/');
    final dialogueNotifier = ref.read(dialogueEntriesProvider.notifier);

    // Compile conversation history up to, but not including, the player's current turn that was just transcribed.
    // The playerTranscription is the latest utterance.
    final currentEntriesForHistory = ref.read(dialogueEntriesProvider);
    String conversationHistory = currentEntriesForHistory
        .where((entry) => entry.id != playerEntryIdForHistory) // Exclude the player's line that just finished animating
        .map((entry) => "${entry.speaker}: ${_fullyAnimatedTexts[entry.id] ?? entry.text}")
        .join("\\n");
    
    // If the player's line (playerEntryIdForHistory) IS in fullyAnimatedTexts, include it.
    // This ensures if the flow is STT -> display -> LLM, the history is complete up to that point.
    if (_fullyAnimatedTexts.containsKey(playerEntryIdForHistory)) {
        final playerEntry = currentEntriesForHistory.firstWhere((e) => e.id == playerEntryIdForHistory);
        conversationHistory += (conversationHistory.isNotEmpty ? "\n" : "") + "${playerEntry.speaker}: ${_fullyAnimatedTexts[playerEntryIdForHistory]}";
    }

    print("Requesting NPC response. History:\n$conversationHistory");
    print("Player's latest (transcribed): $playerTranscription. Charm: $_currentCharmLevel");

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'player_transcription': playerTranscription,
          'conversation_history': conversationHistory,
          'current_charm': _currentCharmLevel,
          'npc_id': widget.currentNpcId // Assuming currentNpcId is available
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        // String type = jsonResponse['type']; // type is full_npc_response

        var npcResponsePayload = jsonResponse['npc_response_data'];
        String npcText = npcResponsePayload['response_thai'];
        String npcAudioBase64 = jsonResponse['npc_audio_base64'];
        Uint8List npcAudioBytes = base64.decode(npcAudioBase64);
        print("NPC Audio Bytes (first 100): ${npcAudioBytes.sublist(0, math.min(100, npcAudioBytes.length))}");
        
        // --- Save NPC audio to a temporary file ---
        String? tempAudioPath;
        try {
          final tempDir = await getTemporaryDirectory();
          tempAudioPath = '${tempDir.path}/npc_audio_${DateTime.now().millisecondsSinceEpoch}.wav'; // Save as .wav
          final audioFile = File(tempAudioPath);
          await audioFile.writeAsBytes(npcAudioBytes);
          print("NPC audio saved to temporary file: $tempAudioPath");
        } catch (e) {
          print("Error saving NPC audio to temporary file: $e");
          tempAudioPath = null; // Ensure path is null if saving failed
        }
        // --- End save NPC audio ---

        if (npcResponsePayload.containsKey('new_charm_level')) {
          setState(() {
            _currentCharmLevel = npcResponsePayload['new_charm_level'];
            print("Charm level updated by backend to: $_currentCharmLevel");
          });
        }
        if (npcResponsePayload.containsKey('charm_delta')) {
             print("Charm delta from this interaction: ${npcResponsePayload['charm_delta']}");
        }

        // --- Print NPC response to terminal ---
        print("NPC Full Response (from backend for terminal):");
        print("  Thai: ${npcResponsePayload['response_thai']}");
        print("  English: ${npcResponsePayload['response_eng']}");
        print("  RTGS: ${npcResponsePayload['response_rtgs']}");
        print("  Expression: ${npcResponsePayload['expression']}");
        print("  Tone: ${npcResponsePayload['response_tone']}");
        // --- End Print --- 

        // Create NPC entry and animate it
        final npcEntryForAnimation = DialogueEntry.npc(
          "", // Text will be animated
          npcName: widget.currentNpcName, 
          audioPath: tempAudioPath // Use the path to the saved temporary file
        );
        dialogueNotifier.state = [...dialogueNotifier.state, npcEntryForAnimation];
        _scrollToBottom();
        
        _startTextAnimation(
          entry: npcEntryForAnimation,
          fullText: npcText,
          audioPathToPlayWhenDone: tempAudioPath
        );
        print("NPC response and audio received, animation started.");

      } else {
        print("Failed to get NPC response. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e, stackTrace) {
      print("Exception in _getNpcResponseAndAudio: $e\n$stackTrace");
    }
    // Ensure processing indicator is turned off regardless of success/failure of this specific step
    // as long as the flow that initiated it is considered complete.
    setState(() {
      _isProcessingBackend = false;
    });
  }
  
  Future<void> _playDialogueAudio(DialogueEntry entry) async {
    final player = ref.read(dialogueReplayPlayerProvider);
    await player.stop(); // Stop any current playback

    // --- Debug Player State ---
    player.playerStateStream.listen((state) {
      print('[DialogueReplayPlayer ID: ${player.hashCode}] State: ${state.processingState}, Playing: ${state.playing}');
      if (state.processingState == just_audio.ProcessingState.completed) {
        print('[DialogueReplayPlayer ID: ${player.hashCode}] Playback completed.');
      }
    });
    // --- End Debug Player State ---

    try {
      if (entry.audioPath != null && entry.audioPath!.isNotEmpty) {
        if (entry.audioPath!.startsWith('assets/')) {
          // Handle as an asset
          await player.setAudioSource(just_audio.AudioSource.asset(entry.audioPath!));
          print("Playing from asset: ${entry.audioPath}");
        } else {
          // Handle as a local file path
          if (Uri.tryParse(entry.audioPath!)?.isAbsolute == true && Uri.tryParse(entry.audioPath!)!.scheme == 'file') {
            await player.setAudioSource(just_audio.AudioSource.uri(Uri.parse(entry.audioPath!)));
          } else {
            await player.setAudioSource(just_audio.AudioSource.uri(Uri.file(entry.audioPath!)));
          }
          print("Playing from file path: ${entry.audioPath}");
        }
      } else if (entry.audioBytes != null && entry.audioBytes!.isNotEmpty) {
        final source = _MyCustomStreamAudioSource.fromBytes(entry.audioBytes!);
        await player.setAudioSource(source); // This is a just_audio.StreamAudioSource
        print("Playing from bytes, length: ${entry.audioBytes!.length}");
      } else {
        print("No audio data to play for this entry.");
        return;
      }
      await player.play(); // Added await here
    } catch (e) {
      print("Error playing dialogue audio: $e");
      // UI message removed:
      // final dialogueNotifier = ref.read(dialogueEntriesProvider.notifier);
      // final errorFeedback = DialogueEntry.npc("Sorry, I couldn't play that audio.", npcName: "System");
      // dialogueNotifier.state = [...dialogueNotifier.state, errorFeedback];
      // _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double outerHorizontalPadding = screenWidth * 0.01;

    final double minTextboxHeight = 150.0;
    final double minTextboxWidth = 368.0;
    final double expandedTextboxHeight = math.min(screenHeight * 0.9, 500.0);

    // Target height for the AnimatedContainer, respecting min/max logic
    final double targetAnimatedHeight = _isExpanded
        ? math.max(expandedTextboxHeight, minTextboxHeight)
        : minTextboxHeight;

    // Max height for ConstrainedBox should accommodate the fully expanded state
    final double maxConstrainedHeight = math.max(expandedTextboxHeight, minTextboxHeight);

    final EdgeInsets dialogueListPadding = _isExpanded
      ? const EdgeInsets.only(left: 30.0, top: 10.0, right: 25.0, bottom: 25.0)
      : const EdgeInsets.only(left: 30.0, top: 5.0, right: 25.0, bottom: 25.0);

    final currentDialogueEntries = ref.watch(dialogueEntriesProvider);

    return Material(
      color: Colors.transparent, // Ensure transparency if debugging colors are removed
      child: Stack( // Move Stack to be the direct child of Material for full-screen background
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/convo_yaowarat_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea( // Apply SafeArea only to content that needs to avoid notches/insets
            bottom: false, // Already here, good
            top: true, // Ensure top safe area is respected for UI elements placed near top if any
            child: Stack( // This stack is for the foreground elements
              children: <Widget>[
                // NPC bar image - no changes here unless it needs to respect SafeArea differently
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.002),
                    child: Image.asset(
                      'assets/images/npcs/sprite_dimsum_vendor_bar.png',
                      width: screenWidth * 0.7, // User adjusted this
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(0.0, 0.0),
                  child: Image.asset(
                    'assets/images/npcs/sprite_dimsum_vendor_female_portrait.png',
                    height: screenHeight * 0.70,
                    fit: BoxFit.contain,
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
                      bottom: MediaQuery.of(context).padding.bottom + 0.0, // Adjusted to move UI further down
                    ),
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: minTextboxWidth,
                              minHeight: minTextboxHeight, // Enforce minimum height
                              maxHeight: maxConstrainedHeight, // Allow space for full expansion
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut, // Added for smoother animation
                              width: math.max(screenWidth * 0.95, minTextboxWidth),
                              height: targetAnimatedHeight, // This height drives the animation
                              clipBehavior: Clip.hardEdge, // Added to ensure text clipping
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/images/ui/textbox_hdpi.9.png'), // Changed to 9-patch
                                  fit: BoxFit.fill,
                                  centerSlice: Rect.fromLTWH(22, 22, 324, 229),
                                ),
                              ),
                              child: Stack( // Use Stack to position expand/contract buttons
                                children: [
                                  Column(
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.only(top: 30.0, left: 30.0, right: 30.0),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: dialogueListPadding,
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              return Scrollbar(
                                                thumbVisibility: true,
                                                controller: _scrollController,
                                                child: SingleChildScrollView(
                                                  controller: _scrollController,
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      minHeight: constraints.maxHeight,
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                                      children: currentDialogueEntries.map((entry) {
                                                        final speaker = _getSpeaker(entry);
                                                        // Determine the text to display: animated or final
                                                        String textToDisplay;
                                                        if (entry.id == _currentlyAnimatingEntryId) {
                                                          textToDisplay = _displayedTextForAnimation;
                                                        } else {
                                                          textToDisplay = _fullyAnimatedTexts[entry.id] ?? entry.text;
                                                        }
                                                        
                                                        return InkWell( 
                                                          onTap: () {
                                                            // Only allow replay if not currently animating this entry
                                                            if (entry.id != _currentlyAnimatingEntryId && (_fullyAnimatedTexts.containsKey(entry.id) || entry.text.isNotEmpty)) {
                                                              if (entry.audioPath != null || entry.audioBytes != null) {
                                                                _playDialogueAudio(entry);
                                                              }
                                                            }
                                                          },
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 4.0), 
                                                            child: Column( 
                                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                                              children: [
                                                                if (speaker.isNotEmpty) // Always show speaker if available
                                                                  Text(
                                                                    speaker,
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      color: entry.isNpc ? Colors.teal : Colors.blueGrey, // Differentiate color
                                                                      fontSize: 14,
                                                                    ),
                                                                  ),
                                                                if (speaker.isNotEmpty) SizedBox(height: 2), // Add space if speaker is shown
                                                                Text( 
                                                                  textToDisplay, // This is just the dialogue part
                                                                  textAlign: TextAlign.left,
                                                                  style: TextStyle(
                                                                    color: Colors.black,
                                                                    fontSize: 16,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      // Add the processing indicator here
                                      if (_isProcessingBackend)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Text("...", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                        ),
                                    ],
                                  ),
                                  Positioned(
                                    top: 0, // Adjust to be slightly above the textbox border
                                    right: 30, // Adjust horizontal position as needed
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min, // To make buttons touch
                                      children: [
                                        SizedBox(
                                          width: 25,
                                          height: 25,
                                          child: IconButton(
                                            icon: Image.asset('assets/images/ui/button_arrow.png', width: 30, height: 30),
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                _isExpanded = true;
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: 25,
                                          height: 25,
                                          child: IconButton(
                                            icon: Transform(
                                              alignment: Alignment.center,
                                              transform: Matrix4.rotationX(math.pi), // Flip vertically
                                              child: Image.asset('assets/images/ui/button_arrow.png', width: 30, height: 30),
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                _isExpanded = false;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: Image.asset(
                                    'assets/images/ui/button_back.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                onPressed: () {
                                  print("Back button pressed. Overlay removal should be handled by game logic.");
                                   widget.game.overlays.remove('dialogue'); // Ensure correct key - assuming 'dialogue'
                                   widget.game.resumeGame(ref); // Pass ref here
                                },
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: Image.asset(
                                    'assets/images/ui/button_mic.png', // Always use the default mic button
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                onPressed: () {
                                  // if (_isRecording) { // Original logic
                                  //   _stopRecordingAndProcess();
                                  // } else {
                                  //   _startRecording();
                                  // }
                                  // New logic: always call _startRecording which now sends test audio
                                  _startRecording(); 
                                },
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: Image.asset(
                                    'assets/images/ui/button_translate.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                onPressed: () => _showTranslationDialog(context),
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

  Future<void> _showTranslationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Translate to Thai'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Enter text to translate:'),
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Type here...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Translate'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // General text animation function
  void _startTextAnimation({
    required DialogueEntry entry, 
    required String fullText,    
    String? audioPathToPlayWhenDone, // Made this explicitly nullable String
    Function? onAnimationComplete,
  }) {
    _activeTextStreamTimer?.cancel(); 

    setState(() {
      _currentlyAnimatingEntryId = entry.id;
      _fullTextForAnimation = fullText;
      // _displayedTextForAnimation now only holds the dialogue text part, not speaker
      _displayedTextForAnimation = ""; 
      _currentCharIndexForAnimation = 0;

      ref.read(dialogueEntriesProvider.notifier).update((state) {
        final index = state.indexWhere((e) => e.id == entry.id);
        if (index != -1) {
           final existingEntry = state[index];
           state[index] = DialogueEntry(
            id: existingEntry.id,
            text: "", // Text will be built by animation
            speaker: existingEntry.speaker,
            isNpc: existingEntry.isNpc,
            audioPath: audioPathToPlayWhenDone ?? existingEntry.audioPath, // Associate audio early
            audioBytes: existingEntry.audioBytes, // Preserve if it was player's recorded bytes initially
          );
          return List.from(state);
        } 
        // If not found (e.g. new NPC entry for animation chain), add it.
        // This happens when player text finishes, and we add a new blank NPC entry to animate.
        else if (entry.id.isNotEmpty) { // Ensure entry has an ID to add
            state.add(DialogueEntry(
                id: entry.id, 
                text: "", 
                speaker: entry.speaker, 
                isNpc: entry.isNpc, 
                audioPath: audioPathToPlayWhenDone,
                audioBytes: entry.audioBytes // Preserve if it was player's recorded bytes initially
            ));
            return List.from(state);
        }
        return state;
      });
       _scrollToBottom();
    });

    Duration charDuration = Duration(milliseconds: 50); 
    bool audioPlayed = false;

    // Attempt to get audio duration for syncing
    Future<Duration?> getAudioDuration() async {
        if (audioPathToPlayWhenDone != null) {
            final tempPlayer = just_audio.AudioPlayer();
            try {
                // Check if it's an asset or a file path
                if (audioPathToPlayWhenDone!.startsWith('assets/')) {
                  return await tempPlayer.setAsset(audioPathToPlayWhenDone!);
                } else {
                  // Assume it's a local file path (like our temp NPC audio)
                  return await tempPlayer.setAudioSource(just_audio.AudioSource.uri(Uri.file(audioPathToPlayWhenDone!)));
                }
            } catch (e) { print("Error getting duration for path $audioPathToPlayWhenDone: $e"); return null; }
            finally { tempPlayer.dispose(); }
        } else if (entry.audioBytes != null && entry.audioBytes!.isNotEmpty) { // Fallback to bytes if path isn't there but bytes are (e.g. player)
            final tempPlayer = just_audio.AudioPlayer();
            try {
                return await tempPlayer.setAudioSource(_MyCustomStreamAudioSource.fromBytes(entry.audioBytes!));
            } catch (e) { print("Error getting duration for bytes: $e"); return null; }
            finally { tempPlayer.dispose(); }
        }
        return null;
    }

    getAudioDuration().then((duration) {
        if (duration != null && duration.inMilliseconds > 0) {
            final audioDurationMs = duration.inMilliseconds;
            if (fullText.isNotEmpty) {
                final charTimeMs = (audioDurationMs * 0.95) / fullText.length; // sync text to 95% of audio
                charDuration = Duration(milliseconds: math.max(30, charTimeMs.round())); // Min 30ms
            }
            print("Audio duration: ${audioDurationMs}ms, Char duration: ${charDuration.inMilliseconds}ms for entry ${entry.id}");
        } else {
            print("Could not get audio duration or audio is null/empty for entry ${entry.id}. Using default char speed.");
        }

        // Start playing audio as the first character appears
        if (audioPathToPlayWhenDone != null /*|| audioBytesToPlayWhenDone != null*/) {
             _playDialogueAudio(DialogueEntry(
                id: entry.id, 
                text: fullText, 
                speaker: entry.speaker, 
                isNpc: entry.isNpc, 
                audioPath: audioPathToPlayWhenDone, 
                audioBytes: entry.audioBytes // Pass original bytes if they exist (for player)
            ));
            audioPlayed = true;
        }

        // Setup animation timer after potentially getting audio duration
        _activeTextStreamTimer?.cancel(); // Ensure no old timer runs
        _activeTextStreamTimer = Timer.periodic(charDuration, (timer) {
            if (_currentCharIndexForAnimation < fullText.length) {
                setState(() {
                _displayedTextForAnimation = fullText.substring(0, _currentCharIndexForAnimation + 1);
                _currentCharIndexForAnimation++;
                });
            } else {
                timer.cancel();
                _activeTextStreamTimer = null;
                setState(() {
                _displayedTextForAnimation = fullText;
                _fullyAnimatedTexts[entry.id] = fullText; 
                _currentlyAnimatingEntryId = ""; 
                });
                
                ref.read(dialogueEntriesProvider.notifier).update((state) {
                final index = state.indexWhere((e) => e.id == entry.id);
                if (index != -1) {
                    final existing = state[index];
                    state[index] = DialogueEntry(
                    id: existing.id, 
                    text: fullText, 
                    speaker: existing.speaker, 
                    isNpc: existing.isNpc,
                    audioPath: audioPathToPlayWhenDone ?? existing.audioPath, 
                    audioBytes: existing.audioBytes // Preserve original bytes
                    );
                }
                return List.from(state);
                });

                if (onAnimationComplete != null) {
                onAnimationComplete();
                }
                _scrollToBottom();
            }
        });
    });
  }
}

// Custom AudioSource for playing from a list of bytes or a stream
class _MyCustomStreamAudioSource extends just_audio.StreamAudioSource {
  final Uint8List? _fixedBytes;
  final Stream<List<int>>? _streamBytes;

  // Constructor for a fixed list of bytes (e.g., complete NPC audio for replay)
  _MyCustomStreamAudioSource.fromBytes(this._fixedBytes) 
    : _streamBytes = null, 
      super(tag: 'npc-audio-bytes-${DateTime.now().millisecondsSinceEpoch}') {
        print("[_MyCustomStreamAudioSource.fromBytes] Created with ${_fixedBytes?.length ?? 0} bytes.");
      }

  // Constructor for a stream of bytes (e.g., live TTS from backend)
  _MyCustomStreamAudioSource.fromStream(this._streamBytes) 
    : _fixedBytes = null,
      super(tag: 'npc-audio-stream-${DateTime.now().millisecondsSinceEpoch}');


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
        contentType: 'audio/wav', // Expect WAV as backend now sends complete WAV files
      );
    } else if (_streamBytes != null) {
      // For a true stream, contentLength and sourceLength might be unknown initially
      // or you might need to buffer or make assumptions.
      // just_audio expects to know the length for some operations.
      // This setup is more for when the stream provides chunks of a known total or can be fully consumed.
      return just_audio.StreamAudioResponse(
        sourceLength: null, 
        contentLength: null, 
        offset: start ?? 0,
        stream: _streamBytes!, 
        contentType: 'audio/wav', // Expect WAV
      );
    }
    throw Exception("CustomStreamAudioSource not initialized with bytes or stream");
  }
} 