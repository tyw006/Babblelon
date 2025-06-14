import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/models/turn.dart';
import 'package:babblelon/widgets/flashcard.dart';
import 'package:babblelon/widgets/top_info_bar.dart';
import 'package:babblelon/screens/main_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:babblelon/providers/game_providers.dart';

// --- Recording State Enum ---
enum RecordingState {
  idle,
  recording,
  reviewing,
}

// --- Vocabulary Model ---
class Vocabulary {
  final String english;
  final String targetWord;
  final String transliteration;

  Vocabulary({required this.english, required this.targetWord, required this.transliteration});

  factory Vocabulary.fromJson(Map<String, dynamic> json) {
    return Vocabulary(
      english: json['english'],
      targetWord: json['thai'],
      transliteration: json['transliteration'],
    );
  }
}

// --- Providers ---
final bossVocabularyProvider = FutureProvider.family<List<Vocabulary>, String>((ref, vocabPath) async {
  final String response = await rootBundle.loadString(vocabPath);
  final data = await json.decode(response);
  final List<dynamic> vocabList = data['vocabulary'];
  return vocabList.map((json) => Vocabulary.fromJson(json)).toList();
});

final playerHealthProvider = StateProvider<int>((ref) => 100);
final bossHealthProvider = StateProvider.family<int, int>((ref, maxHealth) => maxHealth);
final turnProvider = StateProvider<Turn>((ref) => Turn.player);
final flashcardIndexProvider = StateProvider<int>((ref) => 0); // To cycle through vocabulary

// --- Boss Fight Screen ---
class BossFightScreen extends ConsumerStatefulWidget {
  final BossData bossData;

  const BossFightScreen({super.key, required this.bossData});

  @override
  ConsumerState<BossFightScreen> createState() => _BossFightScreenState();
}

class _BossFightScreenState extends ConsumerState<BossFightScreen> {
  Size? _playerSize;
  Size? _capySize;
  Size? _bossSize;

  // --- State for Practice Recording in Flashcard Dialog ---
  final AudioRecorder _practiceAudioRecorder = AudioRecorder();
  final ValueNotifier<RecordingState> _practiceRecordingState = ValueNotifier<RecordingState>(RecordingState.idle);
  final ValueNotifier<String?> _lastPracticeRecordingPath = ValueNotifier<String?>(null);
  final just_audio.AudioPlayer _practiceReviewPlayer = just_audio.AudioPlayer();

  @override
  void initState() {
    super.initState();
    _calculateSpriteSizes();
  }

  @override
  void dispose() {
    _practiceAudioRecorder.dispose();
    _practiceRecordingState.dispose();
    _lastPracticeRecordingPath.dispose();
    _practiceReviewPlayer.dispose();
    super.dispose();
  }

  Future<void> _calculateSpriteSizes() async {
    // Player - using same scale factor as PlayerComponent
    final playerImageBytes = await rootBundle.load('assets/images/player/sprite_male_tourist.png');
    final decodedPlayerImage = await decodeImageFromList(playerImageBytes.buffer.asUint8List());
    const playerScaleFactor = 0.15; // Was 0.20
    final playerOriginalSize = Size(decodedPlayerImage.width.toDouble(), decodedPlayerImage.height.toDouble());
    
    // Capybara - using same scale factor as CapybaraCompanion
    final capyImageBytes = await rootBundle.load('assets/images/player/capybara.png');
    final decodedCapyImage = await decodeImageFromList(capyImageBytes.buffer.asUint8List());
    const capyScaleFactor = 0.07; // Was 0.10
    final capyOriginalSize = Size(decodedCapyImage.width.toDouble(), decodedCapyImage.height.toDouble());

    // Boss - using appropriate scale factor for boss sprites
    final bossImageBytes = await rootBundle.load(widget.bossData.spritePath);
    final decodedBossImage = await decodeImageFromList(bossImageBytes.buffer.asUint8List());
    const bossScaleFactor = 0.17; // Was 0.25
    final bossOriginalSize = Size(decodedBossImage.width.toDouble(), decodedBossImage.height.toDouble());
    
    if (mounted) {
      setState(() {
        _playerSize = playerOriginalSize * playerScaleFactor;
        _capySize = capyOriginalSize * capyScaleFactor;
        _bossSize = bossOriginalSize * bossScaleFactor;
      });
    }
  }

  void _showFlashcardDialog(Vocabulary card) {
    // Reset practice recording state every time a new card dialog is opened.
    _resetPracticeRecording();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _InteractiveFlashcardDialog(
          card: card,
          practiceRecordingState: _practiceRecordingState,
          onPracticeRecord: _startPracticeRecording,
          onPracticeStop: _stopPracticeRecording,
          onPracticePlay: _playPracticeRecording,
          onPracticeReset: _resetPracticeRecording,
          currentTurn: ref.read(turnProvider),
          // The penalty is now handled inside the dialog after confirmation.
          onReveal: () {
            // The penalty message is now shown on the card itself.
            // No longer need to show a snackbar.
          },
        );
      },
    );
  }

  void _showMenuDialog() {
    showDialog(
      context: context,
      builder: (context) => _BossFightMenuDialog(
        onExit: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainMenuScreen()),
            (route) => false, // Remove all previous routes
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerHealth = ref.watch(playerHealthProvider);
    final bossHealth = ref.watch(bossHealthProvider(widget.bossData.maxHealth));
    final currentTurn = ref.watch(turnProvider);
    final vocabularyAsyncValue = ref.watch(bossVocabularyProvider(widget.bossData.vocabularyPath));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          // --- Game View Container (Top portion) ---
          Expanded(
            child: vocabularyAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (vocabulary) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final bottomPadding = constraints.maxHeight * 0.01;
                    final playerXPos = screenWidth * 0.2;
                    final bossXPos = screenWidth * 0.8;
                    final spriteYPos = constraints.maxHeight - bottomPadding;

                    return Stack(
                      children: [
                        // --- Background Image ---
                        Positioned.fill(
                          child: Image.asset(
                            widget.bossData.backgroundPath,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0.25, 0),
                          ),
                        ),

                        // --- Top Info Bar ---
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: TopInfoBar(
                            onMenuPressed: _showMenuDialog,
                            playerHealth: playerHealth,
                            bossHealth: bossHealth,
                            maxBossHealth: widget.bossData.maxHealth,
                            bossName: widget.bossData.name,
                            currentTurn: currentTurn,
                          ),
                        ),

                        if (_playerSize != null && _capySize != null && _bossSize != null) ...[
                          // --- Player and Companion ---
                          Positioned(
                            left: playerXPos - _playerSize!.width / 2,
                            top: spriteYPos - _playerSize!.height,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Player Sprite
                                Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(math.pi),
                                  child: Image.asset(
                                    'assets/images/player/sprite_male_tourist.png',
                                    width: _playerSize!.width,
                                    height: _playerSize!.height,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                // Capybara Sprite
                                Positioned(
                                  left: -_capySize!.width * 0.05,
                                  bottom: 0,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(math.pi),
                                    child: Image.asset(
                                      'assets/images/player/capybara.png',
                                      width: _capySize!.width,
                                      height: _capySize!.height,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- Boss ---
                          Positioned(
                            left: bossXPos - _bossSize!.width / 2,
                            top: spriteYPos - _bossSize!.height,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Boss Sprite
                                Image.asset(
                                  widget.bossData.spritePath,
                                  width: _bossSize!.width,
                                  height: _bossSize!.height,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // --- Divider to hide the seam and clean up the UI ---
          Divider(
            height: 1.5,
            thickness: 1.5,
            color: Colors.grey.shade900.withOpacity(0.95),
          ),

          // --- Flashcard UI Container (Bottom portion) ---
          vocabularyAsyncValue.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (vocabulary) {
              final cards = [
                vocabulary[ref.watch(flashcardIndexProvider) % vocabulary.length],
                vocabulary[(ref.watch(flashcardIndexProvider) + 1) % vocabulary.length],
                vocabulary[(ref.watch(flashcardIndexProvider) + 2) % vocabulary.length],
                vocabulary[(ref.watch(flashcardIndexProvider) + 3) % vocabulary.length],
              ];
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade900.withOpacity(0.95),
                      Colors.grey.shade800.withOpacity(0.98),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentTurn == Turn.player)
                          Text(
                            'Select a flash card to attack',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (currentTurn == Turn.boss)
                          Text(
                            'Brace for impact!',
                             style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 8.0),
                        GridView.builder(
                          padding: EdgeInsets.zero,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: cards.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            return GestureDetector(
                              onTap: () => _showFlashcardDialog(card),
                              child: Flashcard(word: card.english),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- New Boss Fight Menu Dialog ---
class _BossFightMenuDialog extends ConsumerWidget {
  final VoidCallback onExit;

  const _BossFightMenuDialog({required this.onExit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicEnabled = ref.watch(gameStateProvider.select((state) => state.musicEnabled));
    final soundEffectsEnabled = ref.watch(gameStateProvider.select((state) => state.soundEffectsEnabled));
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            _BossFightMenuButton(
              icon: musicEnabled ? Icons.music_note : Icons.music_off,
              label: musicEnabled ? 'Music On' : 'Music Off',
              value: musicEnabled,
              onChanged: (val) {
                final notifier = ref.read(gameStateProvider.notifier);
                notifier.setMusicEnabled(val);

                if (val) {
                  FlameAudio.bgm.play('bg/Chinatown in Summer.mp3', volume: 0.5);
                } else {
                  FlameAudio.bgm.stop();
                }
              },
            ),
            const SizedBox(height: 12),
            _BossFightMenuButton(
              icon: soundEffectsEnabled ? Icons.graphic_eq : Icons.volume_mute,
              label: soundEffectsEnabled ? 'SFX On' : 'SFX Off',
              value: soundEffectsEnabled,
              onChanged: (val) {
                final notifier = ref.read(gameStateProvider.notifier);
                notifier.setSoundEffectsEnabled(val);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
              onPressed: () => _showExitLevelConfirmation(context, onExit),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.exit_to_app, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Exit Level', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.withOpacity(0.3),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showExitLevelConfirmation(BuildContext context, VoidCallback onConfirm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          title: const Text(
            'Exit Level?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to exit the level? You will lose all progress and return to the main menu.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
              ),
              child: const Text(
                'Exit Level',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onConfirm();
    }
  }
}

// A private styled button for the menu dialog, consistent with the main menu.
class _BossFightMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _BossFightMenuButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.red,
        ),
      ],
    );
  }
}

// --- Practice Recording Logic (Adapted from Dialogue Overlay) ---
extension PracticeRecording on _BossFightScreenState {
  Future<void> _resetPracticeRecording() async {
    await _practiceReviewPlayer.stop();
    if (_lastPracticeRecordingPath.value != null) {
      final file = File(_lastPracticeRecordingPath.value!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          print("Error deleting previous practice recording: $e");
        }
      }
      _lastPracticeRecordingPath.value = null;
    }
    _practiceRecordingState.value = RecordingState.idle;
  }

  Future<void> _startPracticeRecording() async {
    await _resetPracticeRecording(); // Clear previous recording first

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denied case, maybe show a snackbar
      print("Microphone permission denied.");
      return;
    }

    _practiceRecordingState.value = RecordingState.recording;
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/practice_input_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _practiceAudioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
      _lastPracticeRecordingPath.value = path;
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

  Future<void> _playPracticeRecording() async {
    if (_lastPracticeRecordingPath.value == null) return;
    try {
      await _practiceReviewPlayer.stop();
      await _practiceReviewPlayer.setAudioSource(just_audio.AudioSource.uri(Uri.file(_lastPracticeRecordingPath.value!)));
      await _practiceReviewPlayer.play();
    } catch (e) {
      print("Error playing practice audio: $e");
    }
  }
}

// --- New Interactive Flashcard Dialog Widget ---
class _InteractiveFlashcardDialog extends StatefulWidget {
  final Vocabulary card;
  final VoidCallback onReveal;
  final ValueNotifier<RecordingState> practiceRecordingState;
  final Future<void> Function() onPracticeRecord;
  final Future<void> Function() onPracticeStop;
  final Future<void> Function() onPracticePlay;
  final Future<void> Function() onPracticeReset;
  final Turn currentTurn;
  final bool isInitiallyRevealed;

  const _InteractiveFlashcardDialog({
    required this.card,
    required this.onReveal,
    required this.practiceRecordingState,
    required this.onPracticeRecord,
    required this.onPracticeStop,
    required this.onPracticePlay,
    required this.onPracticeReset,
    required this.currentTurn,
    this.isInitiallyRevealed = false,
  });

  @override
  __InteractiveFlashcardDialogState createState() => __InteractiveFlashcardDialogState();
}

class __InteractiveFlashcardDialogState extends State<_InteractiveFlashcardDialog> with TickerProviderStateMixin {
  late bool _isFlipped;
  String? _penaltyMessage;
  late final AnimationController _micPulseController;

  @override
  void initState() {
    super.initState();
    _isFlipped = false;
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    widget.practiceRecordingState.addListener(_handleRecordingStateChange);
  }

  @override
  void dispose() {
    widget.practiceRecordingState.removeListener(_handleRecordingStateChange);
    _micPulseController.dispose();
    super.dispose();
  }
  
  void _handleRecordingStateChange() {
    if (!mounted) return; // Add guard
    if (widget.practiceRecordingState.value == RecordingState.recording) {
      _micPulseController.repeat(reverse: true);
    } else {
      _micPulseController.stop();
      _micPulseController.value = 1.0; // Reset to full size
    }
  }

  Future<void> _flipCard() async {
    // Show confirmation dialog first
    final confirmed = await _showConfirmationDialog();
    if (confirmed == true) {
      if (!_isFlipped) {
        final turn = ProviderScope.containerOf(context, listen: false).read(turnProvider);
        final actionType = turn == Turn.player ? 'attack' : 'defense';
        setState(() {
          _isFlipped = true;
          _penaltyMessage = '$actionType efficiency has been decreased!';
        });
        widget.onReveal();
      }
    }
  }

  Future<bool?> _showConfirmationDialog() {
    final turn = ProviderScope.containerOf(context, listen: false).read(turnProvider);
    final actionType = turn == Turn.player ? 'attack' : 'defense';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext confirmContext) {
        return AlertDialog(
          backgroundColor: isDarkMode 
              ? Colors.grey.shade900
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(
              color: isDarkMode 
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.5),
              width: 1,
            ),
          ),
          title: Text(
            'Reveal Answer?',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Revealing the answer will decrease your $actionType efficiency. Are you sure?',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              onPressed: () => Navigator.of(confirmContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode 
                    ? Colors.teal.shade700
                    : Colors.teal.shade600,
              ),
              child: const Text(
                'Reveal Anyway',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.of(confirmContext).pop(true),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final front = _buildCardSide(
      isDarkMode: isDarkMode,
      child: Center(
        child: Text(
          widget.card.english,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.bold, 
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );

    final back = _buildCardSide(
      isDarkMode: isDarkMode,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.card.targetWord,
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: isDarkMode ? Colors.teal.shade300 : Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.card.transliteration,
              style: TextStyle(
                fontSize: 20, 
                fontStyle: FontStyle.italic, 
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            if (_penaltyMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _penaltyMessage!,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.bold, 
                  color: isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
                ),
              ),
            ]
          ],
        ),
      ),
    );

    return AlertDialog(
      backgroundColor: isDarkMode 
          ? Colors.grey.shade900
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(
          color: isDarkMode 
              ? Colors.white.withOpacity(0.3)
              : Colors.grey.withOpacity(0.5),
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.all(16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // TODO: Pass in target language from BossData
              _isFlipped ? 'Practice your pronunciation:' : 'Speak the Thai for:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 120,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1000), // Slower animation (was 600ms)
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final rotateAnim = Tween(begin: math.pi, end: 0.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut), // Smoother curve
                  );
                  return AnimatedBuilder(
                    animation: rotateAnim,
                    child: child,
                    builder: (context, child) {
                      final isUnder = (ValueKey(_isFlipped) != child?.key);
                      var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                      tilt *= isUnder ? -1.0 : 1.0;
                      final value = isUnder ? math.min(rotateAnim.value, math.pi / 2) : rotateAnim.value;
                      return Transform(
                        transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                  );
                },
                child: _isFlipped ? back : front,
              ),
            ),
            const SizedBox(height: 24), // Always show spacing
            _buildPracticeMicControls(), // Always show mic controls
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        if (!_isFlipped)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode 
                  ? Colors.teal.shade700
                  : Colors.teal.shade600,
            ),
            onPressed: _flipCard,
            child: const Text(
              'Reveal',
              style: TextStyle(color: Colors.white),
            ),
          ),
        // Add a listener for the Send button state
        ValueListenableBuilder<RecordingState>(
          valueListenable: widget.practiceRecordingState,
          builder: (context, state, child) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: state == RecordingState.reviewing 
                    ? (isDarkMode ? Colors.green.shade700 : Colors.green.shade600)
                    : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400),
              ),
              // TODO: Implement send functionality
              onPressed: state == RecordingState.reviewing ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attack sent! (Not implemented)')),
                );
                Navigator.of(context).pop();
              } : null, // Disabled if not in review state
              child: const Text(
                'Send',
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCardSide({required Widget child, required bool isDarkMode}) {
    return Container(
      key: ValueKey(_isFlipped),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode 
            ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
  
  Widget _buildPracticeMicControls() {
    return ValueListenableBuilder<RecordingState>(
      valueListenable: widget.practiceRecordingState,
      builder: (context, state, child) {
        switch (state) {
          case RecordingState.recording:
            return _AnimatedPressWrapper(
              onTap: widget.onPracticeStop,
              child: _buildMicButton(),
            );
          case RecordingState.reviewing:
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildReviewButton(icon: Icons.replay, onTap: widget.onPracticeReset),
                const SizedBox(width: 20),
                _buildReviewButton(icon: Icons.play_arrow, onTap: widget.onPracticePlay),
              ],
            );
          case RecordingState.idle:
          default:
            return _AnimatedPressWrapper(
              onTap: widget.onPracticeRecord,
              child: _buildMicButton(),
            );
        }
      },
    );
  }

  Widget _buildMicButton() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: widget.practiceRecordingState.value == RecordingState.recording ? Colors.red.withOpacity(0.8) : Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 40),
      ),
    );
  }

   Widget _buildReviewButton({required IconData icon, required VoidCallback onTap}) {
    return _AnimatedPressWrapper(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

// --- Animated Press Wrapper (for button feedback) ---
class _AnimatedPressWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _AnimatedPressWrapper({required this.child, this.onTap});

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse().then((_) {
          widget.onTap?.call();
        });
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// --- Floating Health Bar Widget ---
class FloatingHealthBar extends StatelessWidget {
  final int currentHealth;
  final int maxHealth;
  final String name;
  final double barWidth;

  const FloatingHealthBar({
    super.key,
    required this.currentHealth,
    required this.maxHealth,
    required this.name,
    required this.barWidth,
  });

  @override
  Widget build(BuildContext context) {
    double healthPercentage = (currentHealth / maxHealth).clamp(0.0, 1.0);

    return Container(
      width: barWidth,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: healthPercentage,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: healthPercentage > 0.5 ? Colors.green.shade400 : (healthPercentage > 0.2 ? Colors.orange.shade400 : Colors.red.shade400),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- New Bouncing Turn Indicator Widget ---
/*
class BouncingTurnIndicator extends StatefulWidget {
  const BouncingTurnIndicator({super.key});

  @override
  _BouncingTurnIndicatorState createState() => _BouncingTurnIndicatorState();
}

class _BouncingTurnIndicatorState extends State<BouncingTurnIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: CustomPaint(
        painter: _TrianglePainter(),
        size: const Size(20, 10),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.shade600
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
*/ 