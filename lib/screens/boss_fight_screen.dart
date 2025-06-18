import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/models/turn.dart';
import 'package:babblelon/models/game_models.dart';
import 'package:babblelon/widgets/flashcard.dart';
import 'package:babblelon/widgets/top_info_bar.dart';
import 'package:babblelon/screens/main_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'package:flutter/services.dart' show rootBundle;

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/models/assessment_model.dart';
import 'package:babblelon/services/api_service.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:provider/provider.dart' as provider;

// --- Item Data Structure ---
class BattleItem {
  final String name;
  final String assetPath;
  final bool isSpecial;
  
  const BattleItem({required this.name, required this.assetPath, this.isSpecial = false});
}

// --- Recording State Enum ---
enum RecordingState {
  idle,
  recording,
  reviewing,
  assessing, // New state for when we're calling the backend
  results,   // New state for showing assessment results
}

// --- Animation State Enum ---
enum AnimationState {
  idle,
  attacking,
  defending,
  bossAttacking,
  bossProjectileAttacking, // New state for boss projectile attack
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
final usedVocabularyIndicesProvider = StateProvider<Set<int>>((ref) => <int>{}); // Track used vocabulary indices
final animationStateProvider = StateProvider<AnimationState>((ref) => AnimationState.idle);
final activeFlashcardsProvider = StateProvider<List<Vocabulary>>((ref) => []);
final tappedCardProvider = StateProvider<Vocabulary?>((ref) => null);
final revealedCardsProvider = StateProvider<Set<String>>((ref) => {});

// --- Boss Fight Screen ---
class BossFightScreen extends ConsumerStatefulWidget {
  final BossData bossData;
  final BattleItem attackItem;
  final BattleItem defenseItem;
  final BabblelonGame game;

  const BossFightScreen({
    super.key, 
    required this.bossData,
    required this.attackItem,
    required this.defenseItem,
    required this.game,
  });

  @override
  ConsumerState<BossFightScreen> createState() => _BossFightScreenState();
}

class _BossFightScreenState extends ConsumerState<BossFightScreen> with TickerProviderStateMixin {
  Size? _playerSize;
  Size? _capySize;
  Size? _bossSize;
  double? _playerActionStartX; // Shared start position for player actions
  final Random _random = Random();
  bool _isInitialTurnSet = false; // Ensures initial turn is set only once
  bool _gameInitialized = false; // Ensures game setup happens only once
  late final ApiService _apiService;
  bool _isRecording = false;
  bool _isLoading = false;
  PronunciationAssessmentResponse? _lastAssessment;
  
  // --- State for Practice Assessment in Flashcard Dialog ---
  final ValueNotifier<PronunciationAssessmentResponse?> _practiceAssessmentResult = ValueNotifier<PronunciationAssessmentResponse?>(null);

  // --- Animation Controllers ---
  late AnimationController _projectileController;
  late AnimationController _shieldController;
  late AnimationController _bossProjectileController; // New controller for boss attack sprite
  late AnimationController _playerDamageController; // New controller for player damage animation
  late AnimationController _bossDamageController; // New controller for boss damage animation
  
  // --- Animations ---
  late Animation<Offset> _projectileAnimation;
  late Animation<Offset> _bossProjectileAnimation; // New animation for boss attack sprite
  late Animation<double> _shieldScaleAnimation;
  late Animation<double> _shieldOpacityAnimation;
  late Animation<double> _playerShakeAnimation; // New animation for player damage
  late Animation<double> _bossDamageShakeAnimation; // New animation for boss damage

  // --- State for Practice Recording in Flashcard Dialog ---
  final AudioRecorder _practiceAudioRecorder = AudioRecorder();
  final ValueNotifier<RecordingState> _practiceRecordingState = ValueNotifier<RecordingState>(RecordingState.idle);
  final ValueNotifier<String?> _lastPracticeRecordingPath = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _calculateSpriteSizes();
    _initializeAnimations();
    _apiService = ApiService();
  }

  void _setInitialTurn() {
    final isPlayerTurn = _random.nextBool();
    final initialTurn = isPlayerTurn ? Turn.player : Turn.boss;
    
    // Update the turn provider
    if (mounted) {
      ref.read(turnProvider.notifier).state = initialTurn;
      // Force a rebuild to ensure all widgets get the new state
      setState(() {});
    }

    // Show a snackbar to announce the first turn
    final message = isPlayerTurn 
        ? 'You get the first move! Attack!' 
        : 'The monster strikes first! Defend!';
    final color = isPlayerTurn ? Colors.redAccent : Colors.blueAccent;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.7,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    // If the boss gets the first turn, start its attack sequence.
    if (!isPlayerTurn) {
      // Use a short delay to ensure the screen is fully visible.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startBossTurn(showSnackbar: false);
        }
      });
    }
  }

  void _initializeAnimations() {
    // Projectile animation (attack)
    _projectileController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Shield animation (defense)
    _shieldController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Boss projectile animation (when player defends)
    _bossProjectileController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Slowed down from 800ms to 1400ms
      vsync: this,
    );

    // Player damage animation
    _playerDamageController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Boss damage animation
    _bossDamageController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shieldScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _shieldController,
      curve: Curves.elasticOut,
    ));

    _shieldOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _shieldController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _playerShakeAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _playerDamageController,
      curve: Curves.elasticInOut,
    ));

    _bossDamageShakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _bossDamageController,
      curve: Curves.elasticInOut,
    ));
  }

  @override
  void dispose() {
    _projectileController.dispose();
    _shieldController.dispose();
    _bossProjectileController.dispose(); // Dispose new controller
    _playerDamageController.dispose(); // Dispose player damage controller
    _bossDamageController.dispose(); // Dispose boss damage controller
    _practiceAudioRecorder.dispose();
    _practiceRecordingState.dispose();
    _lastPracticeRecordingPath.dispose();
    _practiceAssessmentResult.dispose();
    
    // Reset game state when screen is disposed
    _isInitialTurnSet = false;
    _gameInitialized = false;
    _apiService.dispose();
    
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
      
      // Initialize projectile animations after sizes are calculated
      _initializeProjectileAnimations();
    }
  }

  void _initializeProjectileAnimations() {
    if (_playerSize != null && _bossSize != null) {
      final screenWidth = MediaQuery.of(context).size.width;
      final playerXPos = screenWidth * 0.2;
      final bossXPos = screenWidth * 0.8;
      
      // Define the shared starting X position for both attack and defense animations.
      _playerActionStartX = (screenWidth * 0.2) + (_playerSize!.width / 2) - 40;

      // PLAYER ATTACK ANIMATION
      // End at the left side of the boss sprite (collision point)
      final attackEndX = bossXPos - (_bossSize!.width / 2);
      
      _projectileAnimation = Tween<Offset>(
        begin: Offset(_playerActionStartX!, 0), // Use the shared start X
        end: Offset(attackEndX, -30), // End at boss collision point with slight arc
      ).animate(CurvedAnimation(
        parent: _projectileController,
        curve: Curves.easeOutQuart,
      ));
      
      // BOSS ATTACK ANIMATION (for defense turns)
      // Start from the center of the boss sprite
      final bossAttackStartX = bossXPos;
      // End much closer to the player (almost touching)
      final bossAttackEndX = playerXPos - (_playerSize!.width * 0.1);
      
      _bossProjectileAnimation = Tween<Offset>(
        begin: Offset(bossAttackStartX, 0), // Start from boss
        end: Offset(bossAttackEndX, 0), // End at player (straight line)
      ).animate(CurvedAnimation(
        parent: _bossProjectileController,
        curve: Curves.easeInQuart,
      ));
    }
  }

  // Helper method to get 4 random unused vocabulary indices
  List<int> _getRandomVocabularyIndices(List<Vocabulary> vocabulary) {
    final usedIndices = ref.read(usedVocabularyIndicesProvider);
    final availableIndices = <int>[];
    
    // Find all unused indices
    for (int i = 0; i < vocabulary.length; i++) {
      if (!usedIndices.contains(i)) {
        availableIndices.add(i);
      }
    }
    
    // If we've used all vocabulary, reset the used set
    if (availableIndices.length < 4) {
      availableIndices.clear();
      for (int i = 0; i < vocabulary.length; i++) {
        availableIndices.add(i);
      }
    }
    
    // Shuffle and take 4 random indices
    availableIndices.shuffle(_random);
    final selectedIndices = availableIndices.take(4).toList();
    
    // Schedule the provider update to happen after the build phase
    Future.microtask(() {
      if (mounted) {
        // Reset used indices if we had to use all vocabulary
        if (availableIndices.length >= vocabulary.length) {
          ref.read(usedVocabularyIndicesProvider.notifier).state = Set<int>.from(selectedIndices);
        } else {
          // Mark these indices as used
          final newUsedIndices = Set<int>.from(usedIndices);
          newUsedIndices.addAll(selectedIndices);
          ref.read(usedVocabularyIndicesProvider.notifier).state = newUsedIndices;
        }
      }
    });
    
    return selectedIndices;
  }

  Future<void> _performAttack({double attackMultiplier = 20.0}) async {
    ref.read(animationStateProvider.notifier).state = AnimationState.attacking;
    
    // Small delay to let popup close completely before starting animation
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Start projectile animation
    await _projectileController.forward();
    
    // Deal damage to boss using the attack multiplier
    final bossHealth = ref.read(bossHealthProvider(widget.bossData.maxHealth).notifier);
    final damage = attackMultiplier.round();
    bossHealth.state = (bossHealth.state - damage).clamp(0, widget.bossData.maxHealth);
    
    // Show boss damage effect
    await _performBossDamageAnimation();
    
    // Reset projectile and hide it
    _projectileController.reset();
    ref.read(animationStateProvider.notifier).state = AnimationState.idle;
    
    // Start boss turn after a short delay (show snackbar every time now)
    await Future.delayed(const Duration(milliseconds: 100));
    _startBossTurn(showSnackbar: true);
  }

  Future<void> _performDefense({double defenseMultiplier = 1.0}) async {
    // Small delay to let popup close completely
    await Future.delayed(const Duration(milliseconds: 100));
    
    ref.read(animationStateProvider.notifier).state = AnimationState.bossProjectileAttacking;
    
    // Start boss attack, but don't wait for it to finish yet.
    final bossAttackFuture = _bossProjectileController.forward();
    
    // Wait for the boss projectile to get close before showing the shield.
    // Adjust this delay to time the block.
    await Future.delayed(const Duration(milliseconds: 5));
    
    // Activate shield animation to block the attack. It will render based on its controller.
    _shieldController.forward();
    
    // Wait for the boss attack animation to fully complete.
    await bossAttackFuture;
    
    // Player takes damage modified by defense multiplier (lower multiplier = better defense)
    final playerHealth = ref.read(playerHealthProvider.notifier);
    const baseDamage = 20.0; // Boss base damage
    final actualDamage = (baseDamage * defenseMultiplier).round();
    playerHealth.state = (playerHealth.state - actualDamage).clamp(0, 100);
    
    // Show damage effect on player.
    await _performPlayerDamageAnimation();
    
    // Reset animations and state.
    await Future.delayed(const Duration(milliseconds: 300));
    _shieldController.reset();
    _bossProjectileController.reset();
    ref.read(animationStateProvider.notifier).state = AnimationState.idle;
    
    // Switch back to player turn.
    ref.read(turnProvider.notifier).state = Turn.player;
    
    // Announce player's turn to attack.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Your turn to attack!',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.7,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    // Note: New random cards will be generated automatically on next render.
  }

  Future<void> _performPlayerDamageAnimation() async {
    // Make player shake to indicate damage (same as boss damage effect)
    _playerDamageController.repeat(reverse: true);
    
    // Stop after a few shakes
    await Future.delayed(const Duration(milliseconds: 600)); // Slightly longer for more visible effect
    _playerDamageController.stop();
    _playerDamageController.reset();
  }

  Future<void> _performBossDamageAnimation() async {
    // Make boss shake to indicate damage
    _bossDamageController.repeat(reverse: true);
    
    // Stop after a few shakes
    await Future.delayed(const Duration(milliseconds: 600));
    _bossDamageController.stop();
    _bossDamageController.reset();
  }

  Future<void> _startBossTurn({bool showSnackbar = true}) async {
    if (!mounted) return; // Guard against disposed widget

    ref.read(turnProvider.notifier).state = Turn.boss;
    ref.read(animationStateProvider.notifier).state = AnimationState.bossAttacking;
    
    // Show boss attack message only if requested (for initial turn or specific cases)
    if (showSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'The monster attacks! Defend yourself!',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.7,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    // Wait for boss attack duration
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return; // Guard after await
    ref.read(animationStateProvider.notifier).state = AnimationState.idle;
    
    // Note: New random cards will be generated automatically on next render
  }

  void _showFlashcardDialog(Vocabulary card) {
    // Reset practice recording state every time a new card dialog is opened.
    _resetPracticeRecording();
    // Reset assessment result
    _practiceAssessmentResult.value = null;
    showDialog(
      context: context,
      barrierDismissible: true, // Allow tapping outside to close
      builder: (BuildContext dialogContext) {
        return __InteractiveFlashcardDialog(
          card: card,
          bossData: widget.bossData,
          practiceRecordingState: _practiceRecordingState,
          onPracticeRecord: _startPracticeRecording,
          onPracticeStop: _stopPracticeRecording,
          onPracticeReset: _resetPracticeRecording,
          lastPracticeRecordingPathNotifier: _lastPracticeRecordingPath,
          practiceAssessmentResultNotifier: _practiceAssessmentResult,
          currentTurn: ref.read(turnProvider),
          onSend: _handleSendAction, // Triggers assessment
          onConfirm: _handleConfirmedAction, // Triggers actual game action after assessment
          onReveal: () {
            // When a card is revealed, add it to our state provider
            // so we can apply the penalty later.
            final currentRevealed = ref.read(revealedCardsProvider);
            if (!currentRevealed.contains(card.english)) {
              ref.read(revealedCardsProvider.notifier).state = {
                ...currentRevealed,
                card.english,
              };
            }
          },
          isInitiallyRevealed: ref.watch(revealedCardsProvider).contains(card.english),
        );
      },
    ).then((_) {
      // Reset recording and assessment when dialog closes
      _resetPracticeRecording();
      _practiceAssessmentResult.value = null;
    });
  }

  // Handle send action from flashcard dialog (now triggers assessment)
  Future<void> _handleSendAction() async {
    final currentTurn = ref.read(turnProvider);
    final usedCard = ref.read(tappedCardProvider);
    
    if (usedCard == null || _lastPracticeRecordingPath.value == null) {
      print("No card selected or no recording available");
      return;
    }

    // Set state to assessing
    _practiceRecordingState.value = RecordingState.assessing;
    
    try {
      // Read the audio file
      final audioFile = File(_lastPracticeRecordingPath.value!);
      final audioBytes = await audioFile.readAsBytes();
      
      // Determine turn type and item type
      final turnType = currentTurn == Turn.player ? 'attack' : 'defense';
      final itemType = currentTurn == Turn.player 
          ? (widget.attackItem.isSpecial ? 'special' : 'regular')
          : (widget.defenseItem.isSpecial ? 'special' : 'regular');
      
      // Call the pronunciation service
      final revealedCards = ref.read(revealedCardsProvider);
      final wasRevealed = revealedCards.contains(usedCard.english);

      final assessmentResult = await _apiService.assessPronunciation(
        audioBytes: audioBytes,
        referenceText: usedCard.targetWord,
        transliteration: usedCard.transliteration,
        complexity: "medium", // TODO: Get from vocabulary data if available
        itemType: itemType,
        turnType: turnType,
        wasRevealed: wasRevealed, // Pass the revealed status
      );
      
      // Store the result and switch to results state
      _practiceAssessmentResult.value = assessmentResult;
      _practiceRecordingState.value = RecordingState.results;
      
    } catch (e) {
      print("Error during pronunciation assessment: $e");
      // Reset to reviewing state so user can try again
      _practiceRecordingState.value = RecordingState.reviewing;
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assessment failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // New method to handle confirmed action after assessment
  Future<void> _handleConfirmedAction() async {
    final currentTurn = ref.read(turnProvider);
    final assessmentResult = _practiceAssessmentResult.value;
    
    if (assessmentResult == null) return;
    
    // Apply the assessment results to game mechanics
    if (currentTurn == Turn.player) {
      // Player's attack turn - use attack multiplier
      await _performAttack(attackMultiplier: assessmentResult.attackMultiplier);
    } else {
      // Player's defense turn - use defense multiplier
      await _performDefense(defenseMultiplier: assessmentResult.defenseMultiplier);
    }
    
    // After the turn action is complete, replace the used flashcard.
    final usedCard = ref.read(tappedCardProvider);
    if (usedCard != null) {
      final vocabulary = await ref.read(bossVocabularyProvider(widget.bossData.vocabularyPath).future);
      _replaceFlashcard(usedCard, vocabulary);
    }
  }

  void _replaceFlashcard(Vocabulary cardToReplace, List<Vocabulary> fullVocabulary) {
    final newIndex = _getNewSingleVocabularyIndex(fullVocabulary);
    final newCard = fullVocabulary[newIndex];
    
    final currentCards = ref.read(activeFlashcardsProvider);
    final indexToReplace = currentCards.indexOf(cardToReplace);

    if (indexToReplace != -1) {
      final newCards = List<Vocabulary>.from(currentCards);
      newCards[indexToReplace] = newCard;
      ref.read(activeFlashcardsProvider.notifier).state = newCards;
    }
  }

  int _getNewSingleVocabularyIndex(List<Vocabulary> vocabulary) {
    final usedIndices = ref.read(usedVocabularyIndicesProvider);
    final availableIndices = <int>[];
    
    for (int i = 0; i < vocabulary.length; i++) {
      if (!usedIndices.contains(i)) {
        availableIndices.add(i);
      }
    }

    if (availableIndices.isEmpty) {
      // All words used, reset and get a new one
      ref.read(usedVocabularyIndicesProvider.notifier).state = {};
      for (int i = 0; i < vocabulary.length; i++) {
        availableIndices.add(i);
      }
    }

    availableIndices.shuffle(_random);
    final newIndex = availableIndices.first;

    // Schedule update
    Future.microtask(() {
      if (mounted) {
        final newUsedIndices = Set<int>.from(usedIndices)..add(newIndex);
        ref.read(usedVocabularyIndicesProvider.notifier).state = newUsedIndices;
      }
    });

    return newIndex;
  }

  void _showMenuDialog() {
    showDialog(
      context: context,
      builder: (context) => _BossFightMenuDialog(
        onExit: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainMenuScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // First half: fade to black
                    if (animation.value < 0.5) {
                      return Container(
                        color: Colors.black.withOpacity(animation.value * 2),
                        child: Opacity(
                          opacity: 1 - (animation.value * 2),
                          child: const SizedBox.expand(),
                        ),
                      );
                    }
                    // Second half: fade in new screen
                    else {
                      return Container(
                        color: Colors.black.withOpacity(2 - (animation.value * 2)),
                        child: Opacity(
                          opacity: (animation.value - 0.5) * 2,
                          child: child,
                        ),
                      );
                    }
                  },
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 1000),
            ),
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
    final animationState = ref.watch(animationStateProvider);
    final vocabularyAsyncValue = ref.watch(bossVocabularyProvider(widget.bossData.vocabularyPath));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // --- Game View Container (Top portion) ---
              Expanded(
                child: vocabularyAsyncValue.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (vocabulary) {
                    // Set the initial turn once the main data is loaded.
                    if (!_isInitialTurnSet && !_gameInitialized) {
                      _isInitialTurnSet = true;
                      _gameInitialized = true;
                      // Defer the call to after the build is complete to avoid errors.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _setInitialTurn();
                        }
                      });
                    }

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
                              // --- Player and Companion with damage animation ---
                              Positioned(
                                left: playerXPos - _playerSize!.width / 2,
                                top: spriteYPos - _playerSize!.height,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    // Player Sprite with individual damage effects
                                    AnimatedBuilder(
                                      animation: _playerShakeAnimation,
                                      builder: (context, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                            _playerShakeAnimation.value * (Random().nextBool() ? 1 : -1),
                                            0,
                                          ),
                                          child: Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.rotationY(math.pi),
                                            child: Image.asset(
                                              'assets/images/player/sprite_male_tourist.png',
                                              width: _playerSize!.width,
                                              height: _playerSize!.height,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Capybara Sprite (not affected by damage animation)
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

                              // --- Boss with attack and damage animations ---
                              Positioned(
                                left: bossXPos - _bossSize!.width / 2,
                                top: spriteYPos - _bossSize!.height,
                                child: AnimatedBuilder(
                                  animation: _bossDamageShakeAnimation,
                                  builder: (context, child) {
                                    // Calculate shake offset for damage animation
                                    final damageShakeOffset = _bossDamageController.isAnimating
                                        ? _bossDamageShakeAnimation.value * (Random().nextBool() ? 1 : -1)
                                        : 0.0;
                                    
                                    return Transform.translate(
                                      offset: Offset(damageShakeOffset, 0),
                                      child: Image.asset(
                                        widget.bossData.spritePath,
                                        width: _bossSize!.width,
                                        height: _bossSize!.height,
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  },
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
                  // Initialize the active flashcards if they are empty.
                  if (ref.read(activeFlashcardsProvider).isEmpty) {
                    Future.microtask(() {
                      final randomIndices = _getRandomVocabularyIndices(vocabulary);
                      final initialCards = randomIndices.map((index) => vocabulary[index]).toList();
                      ref.read(activeFlashcardsProvider.notifier).state = initialCards;
                    });
                  }
                  
                  final cards = ref.watch(activeFlashcardsProvider);
                  // Return a loading indicator while cards are being initialized.
                  if (cards.isEmpty) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ));
                  }

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
                            // Use the same text as the turn indicator
                            _buildTurnIndicatorText(currentTurn),
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
                                  onTap: () {
                                    ref.read(tappedCardProvider.notifier).state = card;
                                    _showFlashcardDialog(card);
                                  },
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

          // --- Animation Overlays ---
          // Player attack projectile animation overlay
          if (animationState == AnimationState.attacking)
            AnimatedBuilder(
              animation: _projectileAnimation,
              builder: (context, child) {
                // Calculate rotation based on projectile progress (spinning effect)
                final rotationAngle = _projectileController.value * 4 * math.pi;
                
                return Positioned(
                  left: _projectileAnimation.value.dx,
                  top: MediaQuery.of(context).size.height * 0.6 + _projectileAnimation.value.dy,
                  child: Transform.rotate(
                    angle: rotationAngle, // Rotate the attack sprite as it flies
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: widget.attackItem.isSpecial ? [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.7),
                            blurRadius: 20,
                            spreadRadius: 8,
                          ),
                        ] : [],
                      ),
                      child: Image.asset(
                        widget.attackItem.assetPath,
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Shield animation overlay (render first so boss projectile appears on top)
          if (_shieldController.isAnimating || _shieldController.isCompleted)
            Positioned(
              left: _playerActionStartX, // Use the shared start X
              top: MediaQuery.of(context).size.height * 0.57,
              child: AnimatedBuilder(
                animation: _shieldController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _shieldScaleAnimation.value,
                    child: Transform.rotate(
                      angle: (-math.pi / 2)+ 10, // Statically rotate 90 degrees counter-clockwise
                      child: Opacity(
                        opacity: _shieldOpacityAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: widget.defenseItem.isSpecial ? [
                              BoxShadow(
                                color: Colors.yellow.withOpacity(0.7),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ] : [],
                          ),
                          child: Image.asset(
                            widget.defenseItem.assetPath,
                            width: 80,
                            height: 80,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Boss attack projectile animation overlay (render on top so it passes through shield)
          if (animationState == AnimationState.bossProjectileAttacking)
            AnimatedBuilder(
              animation: _bossProjectileAnimation,
              builder: (context, child) {
                return Positioned(
                  left: _bossProjectileAnimation.value.dx,
                  top: MediaQuery.of(context).size.height * 0.6 + _bossProjectileAnimation.value.dy,
                  child: Image.asset(
                    'assets/images/bosses/tuktuk/sprite_attack.png',
                    width: 50,
                    height: 50,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTurnIndicatorText(Turn currentTurn) {
    final String itemName;
    final String itemPath;
    final String actionText;
    final Color textColor;

    if (currentTurn == Turn.player) {
      itemName = widget.attackItem.name;
      itemPath = widget.attackItem.assetPath;
      actionText = 'attack';
      textColor = Colors.white70;
    } else {
      itemName = widget.defenseItem.name;
      itemPath = widget.defenseItem.assetPath;
      actionText = 'defend';
      textColor = Colors.red.shade300;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Select word below to $actionText with $itemName:',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Image.asset(itemPath, width: 24, height: 24),
      ],
    );
  }

  Future<void> _handleRecordButtonPressed() async {
    if (_isRecording) {
      setState(() {
        _isLoading = true;
        _isRecording = false;
      });

      // TODO: Replace with actual data from your game state
      final assessmentResult = await _apiService.stopRecordingAndGetAssessment(
        referenceText: "ไอ้เหี้ยไอ้สัตว์", // Example
        transliteration: "ai hia ai sat", // Example
        complexity: "medium",
        itemType: "special",
        turnType: "attack", // Example: determine this from game state
      );
      
      if (mounted) {
        setState(() {
          _lastAssessment = assessmentResult;
          _isLoading = false;
          // TODO: Add logic to update player/boss health based on assessmentResult
        });
        
        // Show a dialog with the results
        if (_lastAssessment != null) {
          _showAssessmentDialog(_lastAssessment!);
        }
      }

    } else {
      await _apiService.startRecording();
      if(mounted) {
        setState(() {
          _isRecording = true;
        });
      }
    }
  }
  
  void _showAssessmentDialog(PronunciationAssessmentResponse result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assessment: ${result.rating}'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Overall Score: ${result.pronunciationScore.toStringAsFixed(1)}'),
              Text('Attack Multiplier: ${result.attackMultiplier.toStringAsFixed(2)}x'),
              Text('Defense Multiplier: ${result.defenseMultiplier.toStringAsFixed(2)}x'),
              SizedBox(height: 10),
              Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text(result.wordFeedback),
              SizedBox(height: 10),
              Text('Calculation:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Base Attack: ${result.calculationBreakdown.baseAttack}'),
              Text('Pronunciation Bonus: ${result.calculationBreakdown.pronunciationMultiplier}x'),
              Text('Complexity Bonus: ${result.calculationBreakdown.complexityMultiplier}x'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
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
    // Only stop if we are actually recording to prevent errors.
    if (await _practiceAudioRecorder.isRecording()) {
      await _practiceAudioRecorder.stop();
    }
    
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
      print("Starting recording. Saving to: $path");
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
      final path = await _practiceAudioRecorder.stop();
      print('Stopped recording. File at: $path');
      _practiceRecordingState.value = RecordingState.reviewing;
    } catch (e) {
      print("Error stopping practice recording: $e");
      _practiceRecordingState.value = RecordingState.idle;
    }
  }
}

// --- New Interactive Flashcard Dialog Widget ---
class __InteractiveFlashcardDialog extends ConsumerStatefulWidget {
  final Vocabulary card;
  final BossData bossData;
  final VoidCallback onReveal;
  final ValueNotifier<RecordingState> practiceRecordingState;
  final Future<void> Function() onPracticeRecord;
  final Future<void> Function() onPracticeStop;
  final Future<void> Function() onPracticeReset;
  final ValueNotifier<String?> lastPracticeRecordingPathNotifier;
  final ValueNotifier<PronunciationAssessmentResponse?> practiceAssessmentResultNotifier;
  final Future<void> Function() onSend;
  final Future<void> Function() onConfirm;
  final Turn currentTurn;
  final bool isInitiallyRevealed;

  const __InteractiveFlashcardDialog({
    required this.card,
    required this.bossData,
    required this.onReveal,
    required this.practiceRecordingState,
    required this.onPracticeRecord,
    required this.onPracticeStop,
    required this.onPracticeReset,
    required this.lastPracticeRecordingPathNotifier,
    required this.practiceAssessmentResultNotifier,
    required this.onSend,
    required this.onConfirm,
    required this.currentTurn,
    this.isInitiallyRevealed = false,
  });

  @override
  __InteractiveFlashcardDialogState createState() => __InteractiveFlashcardDialogState();
}

class __InteractiveFlashcardDialogState extends ConsumerState<__InteractiveFlashcardDialog> with TickerProviderStateMixin {
  String? _penaltyMessage;
  late bool _hasBeenRevealed; // Changed from final to late bool
  late final AnimationController _micPulseController;
  late final AnimationController _playButtonController;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _hasBeenRevealed = widget.isInitiallyRevealed; // Initialize based on parent state

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    
    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    widget.practiceRecordingState.addListener(_handleRecordingStateChange);
  }

  @override
  void dispose() {
    widget.practiceRecordingState.removeListener(_handleRecordingStateChange);
    _micPulseController.dispose();
    _playButtonController.dispose();
    _flipController.dispose();
    // Player is now managed within the play function, no need to dispose here.
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
    if (!_hasBeenRevealed) {
      final turn = ref.read(turnProvider);
      final actionType = turn == Turn.player ? 'attack' : 'defense';
      _hasBeenRevealed = true; // Mark as revealed once
      
      setState(() {
        _penaltyMessage = '$actionType efficiency decreased by 20%!';
      });
      widget.onReveal(); // Notify parent screen
    }
    
    if (_flipController.status == AnimationStatus.completed) {
      _flipController.reverse();
    } else if (_flipController.status == AnimationStatus.dismissed) {
      _flipController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCardFlipped = _flipController.value >= 0.5;
    
    // If the card is already revealed from a previous action, flip it instantly
    // without animation when the dialog opens.
    if (widget.isInitiallyRevealed && !_flipController.isAnimating) {
      _flipController.value = 1.0;
    }

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
              isCardFlipped ? 'Practice your pronunciation:' : 'Speak the Thai for:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onDoubleTap: _flipCard,
              child: SizedBox(
                width: 250,
                height: 120,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final isCurrentlyFlipped = _flipController.value >= 0.5;
                    
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Perspective effect
                        ..rotateY(_flipAnimation.value),
                      child: isCurrentlyFlipped
                          ? Transform( // Rotate the back content to face forward
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: back,
                            )
                          : front,
                    );
                  },
                ),
              ),
            ),
            // Penalty notification - show if it has been revealed in this session OR was revealed previously
            if (_penaltyMessage != null || widget.isInitiallyRevealed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.red.shade900.withOpacity(0.7) : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.red.shade600 : Colors.red.shade400,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning,
                      color: isDarkMode ? Colors.red.shade200 : Colors.red.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        // Define actionType here since it's out of the original scope
                        _penaltyMessage ?? '${widget.currentTurn == Turn.player ? 'attack' : 'defense'} efficiency decreased by 20%!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold, 
                          color: isDarkMode ? Colors.red.shade200 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!_hasBeenRevealed) ...[
              // Show hint box only if card hasn't been revealed yet
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.blue.shade900.withOpacity(0.7) : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.blue.shade600 : Colors.blue.shade400,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info,
                      color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Double-tap card to reveal answer\n(decreases ${widget.currentTurn == Turn.player ? 'attack' : 'defense'} efficiency)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold, 
                          color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24), // Always show spacing
            _buildPracticeMicControls(), // Always show mic controls
          ],
        ),
      ),
      actions: [
        // Center the action button
        Center(
          child: ValueListenableBuilder<RecordingState>(
            valueListenable: widget.practiceRecordingState,
            builder: (context, state, child) {
              final currentTurn = widget.currentTurn;
              
              switch (state) {
                case RecordingState.reviewing:
                  final actionText = currentTurn == Turn.player ? 'Attack' : 'Defend';
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.orange.shade700 : Colors.orange.shade600,
                      minimumSize: const Size(120, 45),
                    ),
                    onPressed: () async {
                      // Don't close dialog, just trigger assessment
                      await widget.onSend();
                    },
                    child: Text(
                      actionText,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                  
                case RecordingState.assessing:
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                      minimumSize: const Size(120, 45),
                    ),
                    onPressed: null, // Disabled during assessment
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Assessing...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                  
                case RecordingState.results:
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show assessment results
                      ValueListenableBuilder<PronunciationAssessmentResponse?>(
                        valueListenable: widget.practiceAssessmentResultNotifier,
                        builder: (context, assessment, child) {
                          if (assessment == null) return const SizedBox.shrink();
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Assessment: ${assessment.rating}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Score: ${assessment.pronunciationScore.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currentTurn == Turn.player 
                                      ? 'Attack Power: ${assessment.attackMultiplier.toStringAsFixed(1)}'
                                      : 'Damage Reduction: ${(100 * (1 - assessment.defenseMultiplier)).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: currentTurn == Turn.player ? Colors.red.shade600 : Colors.blue.shade600,
                                  ),
                                ),
                                if (assessment.wordFeedback.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    assessment.wordFeedback,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      // Confirm button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.green.shade700 : Colors.green.shade600,
                          minimumSize: const Size(120, 45),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close dialog
                          await widget.onConfirm(); // Execute game action
                        },
                        child: const Text(
                          'Confirm',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                  
                default:
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                      minimumSize: const Size(120, 45),
                    ),
                    onPressed: null, // Disabled
                    child: Text(
                      currentTurn == Turn.player ? 'Attack' : 'Defend',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCardSide({required Widget child, required bool isDarkMode}) {
    return Container(
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
                _buildReviewButton(icon: Icons.play_arrow, onAsyncTap: _playPracticeRecording),
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

   Widget _buildReviewButton({required IconData icon, VoidCallback? onTap, Future<void> Function()? onAsyncTap}) {
    final isPlayButton = icon == Icons.play_arrow;
    
    final buttonContent = AnimatedBuilder(
      animation: _playButtonController,
      builder: (context, child) {
        final baseButton = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        );

        if (isPlayButton) {
          return CustomPaint(
            painter: _RedLinePainter(_playButtonController.value),
            child: baseButton,
          );
        }
        return baseButton;
      },
    );

    return _AnimatedPressWrapper(
      onTap: onTap,
      onAsyncTap: onAsyncTap,
      child: buttonContent,
    );
  }

  Future<void> _playPracticeRecording() async {
    if (widget.lastPracticeRecordingPathNotifier.value == null) {
      print("No recording path found to play.");
      return;
    }
    // Create a new, temporary player instance for each playback.
    // This is safer and avoids state-related bugs from the `just_audio` plugin.
    final player = just_audio.AudioPlayer();
    try {
      final duration = await player.setAudioSource(just_audio.AudioSource.uri(Uri.file(widget.lastPracticeRecordingPathNotifier.value!)));
      
      if (duration != null) {
        _playButtonController.duration = duration;
        _playButtonController.forward().whenComplete(() {
          _playButtonController.reset();
        });
        
        await player.play();

        // Listen to the player state. When it completes, dispose of the player
        // to free up resources.
        final subscription = player.processingStateStream.listen((state) {
          if (state == just_audio.ProcessingState.completed) {
            player.stop().then((_) => player.dispose()).catchError((e) {
              print("Error disposing audio player: $e");
            });
          }
        });

        // Also dispose after a reasonable timeout to prevent memory leaks
        Future.delayed(duration + const Duration(seconds: 2), () {
          subscription.cancel();
          player.stop().then((_) => player.dispose()).catchError((e) {
            print("Error disposing audio player on timeout: $e");
          });
        });
      } else {
        // If loading fails, dispose immediately.
        await player.dispose();
      }
      
    } catch (e) {
      print("Error playing practice audio: $e");
      // Ensure disposal on error.
      try {
        await player.dispose();
      } catch (disposeError) {
        print("Error disposing audio player after error: $disposeError");
      }
    }
  }
}

// --- Animated Press Wrapper (for button feedback) ---
class _AnimatedPressWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Future<void> Function()? onAsyncTap;

  const _AnimatedPressWrapper({required this.child, this.onTap, this.onAsyncTap});

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
      onTapUp: (_) async {
        await _controller.reverse();
        if (widget.onTap != null) {
          widget.onTap!();
        }
        if (widget.onAsyncTap != null) {
          await widget.onAsyncTap!();
        }
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

// --- Red Line Painter for Play Button Animation ---
class _RedLinePainter extends CustomPainter {
  final double progress;
  
  _RedLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;
    
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) + 8; // Slightly larger than the button
    
    // Draw a red line that grows around the circle
    final sweepAngle = 2 * math.pi * progress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _RedLinePainter && oldDelegate.progress != progress;
  }
}