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
import 'package:babblelon/widgets/complexity_rating.dart';
import 'package:babblelon/widgets/score_progress_bar.dart';
import 'package:babblelon/widgets/modern_calculation_display.dart';
import 'package:babblelon/widgets/floating_damage_overlay.dart';
import 'package:google_fonts/google_fonts.dart';

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
final cardsRevealedBeforeAssessmentProvider = StateProvider<Set<String>>((ref) => {});

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
  final GlobalKey<FloatingDamageOverlayState> damageOverlayKey = GlobalKey<FloatingDamageOverlayState>();
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
  AudioRecorder _practiceAudioRecorder = AudioRecorder();
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

    for (int i = 0; i < vocabulary.length; i++) {
      if (!usedIndices.contains(i)) {
        availableIndices.add(i);
      }
    }

    // If we've used all vocabulary, reset the used set
    if (availableIndices.length < 4) {
      usedIndices.clear(); // Reset for next cycle
      availableIndices.clear();
      for (int i = 0; i < vocabulary.length; i++) {
        availableIndices.add(i);
      }
    }

    // Separate indices by complexity
    final lowComplexityIndices = <int>[];
    final mediumComplexityIndices = <int>[];
    final highComplexityIndices = <int>[];

    for (final index in availableIndices) {
      final complexity = vocabulary[index].complexity;
      if (complexity <= 2) {
        lowComplexityIndices.add(index);
      } else if (complexity == 3) {
        mediumComplexityIndices.add(index);
      } else {
        highComplexityIndices.add(index);
      }
    }

    // Shuffle each list
    lowComplexityIndices.shuffle(_random);
    mediumComplexityIndices.shuffle(_random);
    highComplexityIndices.shuffle(_random);

    final selectedIndices = <int>[];

    // Aim for 2 low, 1 medium, 1 high
    selectedIndices.addAll(lowComplexityIndices.take(2));
    selectedIndices.addAll(mediumComplexityIndices.take(1));
    selectedIndices.addAll(highComplexityIndices.take(1));
    
    // Fill remaining spots if any category was short
    int i = 0;
    final allShuffled = (lowComplexityIndices + mediumComplexityIndices + highComplexityIndices)..shuffle(_random);
    
    while (selectedIndices.length < 4 && i < allShuffled.length) {
      if (!selectedIndices.contains(allShuffled[i])) {
        selectedIndices.add(allShuffled[i]);
      }
      i++;
    }

    // Schedule the provider update to happen after the build phase
    Future.microtask(() {
      if (mounted) {
        // Mark these indices as used
        final newUsedIndices = Set<int>.from(usedIndices);
        newUsedIndices.addAll(selectedIndices);
        ref.read(usedVocabularyIndicesProvider.notifier).state = newUsedIndices;
      }
    });

    return selectedIndices.take(4).toList(); // Ensure we only return 4
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
    const baseDamage = 15.0; // Boss base damage (per rubric)
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
    // Reset states for the dialog
    _practiceRecordingState.value = RecordingState.idle;
    _lastPracticeRecordingPath.value = null;
    _practiceAssessmentResult.value = null;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _InteractiveFlashcardDialog(
          card: card,
          bossData: widget.bossData,
          practiceRecordingStateNotifier: _practiceRecordingState,
          onPracticeRecord: _startPracticeRecording,
          onPracticeStop: _stopPracticeRecording,
          onPracticeReset: _resetPracticeRecording,
          lastPracticeRecordingPathNotifier: _lastPracticeRecordingPath,
          practiceAssessmentResultNotifier: _practiceAssessmentResult,
          onSend: _handleSendAction,
          onConfirm: _handleConfirmedAction,
          onReveal: () {
            final card = ref.read(tappedCardProvider);
            if (card != null) {
              // Track overall revealed cards
              ref.read(revealedCardsProvider.notifier).update((state) => {...state, card.english});
              // Track cards revealed before this assessment
              ref.read(cardsRevealedBeforeAssessmentProvider.notifier).update((state) => {...state, card.english});
            }
          },
          getRatingColor: _getRatingColor,
          getRatingText: _getRatingText,
          buildScoreRowWithTooltip: _buildScoreRowWithTooltip,
        );
      },
    ).then((_) {
      // Clean up when the dialog is closed
      _resetPracticeRecording();
      _practiceAssessmentResult.value = null;
    });
  }

  Future<void> _handleSendAction() async {
    final currentTurn = ref.read(turnProvider);
    final usedCard = ref.read(tappedCardProvider);
    
    if (usedCard == null || _lastPracticeRecordingPath.value == null) {
      return;
    }

    _practiceRecordingState.value = RecordingState.assessing;
    // FlameAudio.play('sfx/assessing_1.wav', volume: ref.read(gameStateProvider).soundEffectsEnabled ? 1.0 : 0.0);
    
    try {
      final audioFile = File(_lastPracticeRecordingPath.value!);
      final audioBytes = await audioFile.readAsBytes();
      
      final turnType = currentTurn == Turn.player ? 'attack' : 'defense';
      final itemType = currentTurn == Turn.player 
          ? (widget.attackItem.isSpecial ? 'special' : 'regular')
          : (widget.defenseItem.isSpecial ? 'special' : 'regular');
      
      final revealedBeforeAssessment = ref.read(cardsRevealedBeforeAssessmentProvider);
      final wasRevealedBeforeAssessment = revealedBeforeAssessment.contains(usedCard.english);

      final assessmentResult = await _apiService.assessPronunciation(
        audioBytes: audioBytes,
        referenceText: usedCard.thai,
        transliteration: usedCard.transliteration,
        wordMapping: usedCard.wordMapping.map((e) => e.toJson()).toList(),
        complexity: usedCard.complexity,
        itemType: itemType,
        turnType: turnType,
        wasRevealed: wasRevealedBeforeAssessment,
      );
      
      // Clear the cards revealed before assessment tracker
      ref.read(cardsRevealedBeforeAssessmentProvider.notifier).state = {};
      
      _practiceAssessmentResult.value = assessmentResult;
      _practiceRecordingState.value = RecordingState.results;
      // FlameAudio.play('sfx/results_1.wav', volume: ref.read(gameStateProvider).soundEffectsEnabled ? 1.0 : 0.0);
      
    } catch (e) {
      print("Error during pronunciation assessment: $e");
      _practiceRecordingState.value = RecordingState.reviewing;
      
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

  Future<void> _handleConfirmedAction() async {
    final currentTurn = ref.read(turnProvider);
    final assessmentResult = _practiceAssessmentResult.value;
    
    if (assessmentResult == null) return;

    // if (assessmentResult.pronunciationScore >= 80) {
    //   FlameAudio.play('sfx/success_1.wav', volume: ref.read(gameStateProvider).soundEffectsEnabled ? 1.0 : 0.0);
    // } else if (assessmentResult.pronunciationScore < 60) {
    //   FlameAudio.play('sfx/failure_1.wav', volume: ref.read(gameStateProvider).soundEffectsEnabled ? 1.0 : 0.0);
    // }
    
    if (currentTurn == Turn.player) {
      await _performAttack(attackMultiplier: assessmentResult.attackMultiplier);
    } else {
      await _performDefense(defenseMultiplier: assessmentResult.defenseMultiplier);
    }
    
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
      ref.read(usedVocabularyIndicesProvider.notifier).state = {};
      for (int i = 0; i < vocabulary.length; i++) {
        availableIndices.add(i);
      }
    }

    availableIndices.shuffle(_random);
    final newIndex = availableIndices.first;

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
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainMenuScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    if (animation.value < 0.5) {
                      return Container(
                        color: Colors.black.withOpacity(animation.value * 2),
                        child: Opacity(
                          opacity: 1 - (animation.value * 2),
                          child: const SizedBox.expand(),
                        ),
                      );
                    } else {
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
            (route) => false,
          );
        },
      ),
    );
  }

  Future<void> _startPracticeRecording() async {
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      print("Recording permission not granted.");
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/practice_recording.wav';
      
      await _practiceAudioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
      
      _practiceRecordingState.value = RecordingState.recording;
      _lastPracticeRecordingPath.value = null;
    } catch (e) {
      print("Error starting practice recording: $e");
    }
  }

  Future<void> _stopPracticeRecording() async {
    try {
      final path = await _practiceAudioRecorder.stop();
      if (path != null) {
        _lastPracticeRecordingPath.value = path;
        _practiceRecordingState.value = RecordingState.reviewing;
      }
    } catch (e) {
      print("Error stopping practice recording: $e");
      _practiceRecordingState.value = RecordingState.idle;
    }
  }

  void _resetPracticeRecording() {
    _practiceAudioRecorder.dispose();
    _practiceAudioRecorder = AudioRecorder(); // Re-initialize the recorder
    _practiceRecordingState.value = RecordingState.idle;
    _lastPracticeRecordingPath.value = null;
  }

  Future<bool> _checkPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  @override
  Widget build(BuildContext context) {
    final playerHealth = ref.watch(playerHealthProvider);
    final bossHealth = ref.watch(bossHealthProvider(widget.bossData.maxHealth));
    final currentTurn = ref.watch(turnProvider);
    final animationState = ref.watch(animationStateProvider);
    final vocabularyAsyncValue = ref.watch(bossVocabularyProvider(widget.bossData.vocabularyPath));
    final screenWidth = MediaQuery.of(context).size.width;

    return FloatingDamageOverlay(
      key: damageOverlayKey,
      child: Scaffold(
        body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: vocabularyAsyncValue.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (vocabulary) {
                    if (!_isInitialTurnSet && !_gameInitialized) {
                      _isInitialTurnSet = true;
                      _gameInitialized = true;
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
                            Positioned.fill(
                              child: Image.asset(
                                widget.bossData.backgroundPath,
                                fit: BoxFit.cover,
                                alignment: const Alignment(0.25, 0),
                              ),
                            ),
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
                              Positioned(
                                left: playerXPos - _playerSize!.width / 2,
                                top: spriteYPos - _playerSize!.height,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
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
                              Positioned(
                                left: bossXPos - _bossSize!.width / 2,
                                top: spriteYPos - _bossSize!.height,
                                child: AnimatedBuilder(
                                  animation: _bossDamageShakeAnimation,
                                  builder: (context, child) {
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
              Divider(
                height: 1.5,
                thickness: 1.5,
                color: Colors.grey.shade900.withOpacity(0.95),
              ),
              vocabularyAsyncValue.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                )),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (vocabulary) {
                  if (ref.read(activeFlashcardsProvider).isEmpty) {
                    Future.microtask(() {
                      final randomIndices = _getRandomVocabularyIndices(vocabulary);
                      final initialCards = randomIndices.map((index) => vocabulary[index]).toList();
                      ref.read(activeFlashcardsProvider.notifier).state = initialCards;
                    });
                  }
                  
                  final cards = ref.watch(activeFlashcardsProvider);
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
                                return Flashcard(
                                  key: ValueKey(card.english),
                                  vocabulary: card,
                                  isRevealed: false,
                                  isFlippable: false,
                                  onTap: () {
                                    ref.read(tappedCardProvider.notifier).state = card;
                                    _showFlashcardDialog(card);
                                  },
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
          if (animationState == AnimationState.attacking)
            AnimatedBuilder(
              animation: _projectileAnimation,
              builder: (context, child) {
                final rotationAngle = _projectileController.value * 4 * math.pi;
                
                return Positioned(
                  left: _projectileAnimation.value.dx,
                  top: MediaQuery.of(context).size.height * 0.6 + _projectileAnimation.value.dy,
                  child: Transform.rotate(
                    angle: rotationAngle,
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
          if (_shieldController.isAnimating || _shieldController.isCompleted)
            Positioned(
              left: _playerActionStartX,
              top: MediaQuery.of(context).size.height * 0.57,
              child: AnimatedBuilder(
                animation: _shieldController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _shieldScaleAnimation.value,
                    child: Transform.rotate(
                      angle: (-math.pi / 2)+ 10,
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
    ),
    );
  }

  Widget _buildTurnIndicatorText(Turn currentTurn) {
    final String actionText = currentTurn == Turn.player ? 'attack' : 'defend';

    return Text(
      'Select a word below to $actionText:',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getRatingText(String rating) {
    switch (rating.toLowerCase()) {
      case 'excellent':
        return 'Excellent!';
      case 'good':
        return 'Good';
      case 'okay':
        return 'Okay';
      case 'poor':
      default:
        return 'Needs Improvement';
    }
  }

  Color _getRatingColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'excellent':
        return Colors.yellow.shade600; // Gold for the shiny effect
      case 'good':
        return Colors.green.shade400;
      case 'okay':
        return Colors.orange.shade400;
      case 'poor':
      default:
        return Colors.red.shade400;
    }
  }

  Widget _buildScoreRowWithTooltip({
    required String label,
    required double score,
    required String tooltip,
    required BuildContext context,
    bool isHeader = false,
  }) {
    final tooltipKey = GlobalKey<TooltipState>();

    if (isHeader) {
      return Column(
        children: [
          GestureDetector(
            onTap: () {
              tooltipKey.currentState?.ensureTooltipVisible();
            },
            child: Tooltip(
              key: tooltipKey,
              message: tooltip,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(score * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11, // Reduced from 12
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: () {
          tooltipKey.currentState?.ensureTooltipVisible();
        },
        child: Tooltip(
          key: tooltipKey,
          message: tooltip,
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
          child: ScoreProgressBar(
            label: label,
            value: score,
            score: score * 100,
            showTooltipIcon: true,
          ),
        ),
      );
    }
  }
}

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
              icon: soundEffectsEnabled ? Icons.volume_up : Icons.volume_off,
              label: soundEffectsEnabled ? 'Sound FX On' : 'Sound FX Off',
              value: soundEffectsEnabled,
              onChanged: (val) {
                ref.read(gameStateProvider.notifier).setSoundEffectsEnabled(val);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              onPressed: onExit,
              child: const Text('Exit to Main Menu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BossFightMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BossFightMenuButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blueAccent,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

// --- Interactive Flashcard Dialog and its components ---

class _InteractiveFlashcardDialog extends ConsumerStatefulWidget {
  final Vocabulary card;
  final BossData bossData;
  final ValueNotifier<RecordingState> practiceRecordingStateNotifier;
  final VoidCallback onPracticeRecord;
  final VoidCallback onPracticeStop;
  final VoidCallback onPracticeReset;
  final ValueNotifier<String?> lastPracticeRecordingPathNotifier;
  final ValueNotifier<PronunciationAssessmentResponse?> practiceAssessmentResultNotifier;
  final VoidCallback onSend;
  final VoidCallback onConfirm;
  final VoidCallback onReveal;
  final Color Function(String) getRatingColor;
  final String Function(String) getRatingText;
  final Widget Function({
    required String label,
    required double score,
    required String tooltip,
    required BuildContext context,
    bool isHeader,
  }) buildScoreRowWithTooltip;

  const _InteractiveFlashcardDialog({
    required this.card,
    required this.bossData,
    required this.practiceRecordingStateNotifier,
    required this.onPracticeRecord,
    required this.onPracticeStop,
    required this.onPracticeReset,
    required this.lastPracticeRecordingPathNotifier,
    required this.practiceAssessmentResultNotifier,
    required this.onSend,
    required this.onConfirm,
    required this.onReveal,
    required this.getRatingColor,
    required this.getRatingText,
    required this.buildScoreRowWithTooltip,
  });

  @override
  ConsumerState<_InteractiveFlashcardDialog> createState() =>
      _InteractiveFlashcardDialogState();
}

class _InteractiveFlashcardDialogState
    extends ConsumerState<_InteractiveFlashcardDialog> with TickerProviderStateMixin {
  bool _isRevealed = false;
  late final just_audio.AudioPlayer _audioPlayer;
  late AnimationController _progressController; // For playback progress

  @override
  void initState() {
    super.initState();
    _isRevealed = ref.read(revealedCardsProvider).contains(widget.card.english);
    _audioPlayer = just_audio.AudioPlayer();
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Duration will be updated dynamically
    )..addListener(() {
        setState(() {}); // Redraw on progress change
      });

    // Listen for the results state to auto-flip the card
    widget.practiceRecordingStateNotifier.addListener(_onRecordingStateChange);
  }

  @override
  void dispose() {
    widget.practiceRecordingStateNotifier.removeListener(_onRecordingStateChange);
    _audioPlayer.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  void _onRecordingStateChange() {
    if (widget.practiceRecordingStateNotifier.value == RecordingState.results && !_isRevealed) {
      if (mounted) {
        setState(() {
          _isRevealed = true;
        });
      }
    }
  }

  Future<void> _playRecording() async {
    final path = widget.lastPracticeRecordingPathNotifier.value;
    if (path != null) {
      try {
        final duration = await _audioPlayer.setFilePath(path);
        if (duration != null) {
          _progressController.duration = duration;
          _progressController.forward(from: 0.0);
        }
        _audioPlayer.play();
      } catch (e) {
        print("Error playing recording: $e");
        // Optionally show a snackbar
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: _buildPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrollable content area
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _getDynamicWarningText(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isRevealed ? Colors.orange.shade300 : Colors.white70,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 220, // Increased height for the dialog flashcard
                        child: Flashcard(
                          vocabulary: widget.card,
                          isRevealed: _isRevealed,
                          isFlippable: true, // Allow flipping in the dialog
                          onReveal: () {
                            if (!_isRevealed) {
                              setState(() => _isRevealed = true);
                              widget.onReveal();
                            }
                          },
                          revealedChild: _RevealedCardDetails(card: widget.card, bossData: widget.bossData),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<RecordingState>(
                        valueListenable: widget.practiceRecordingStateNotifier,
                        builder: (context, state, child) {
                          return _buildContentForState(state);
                        }
                      ),
                    ],
                  ),
                ),
              ),
              // Fixed confirm button area (only shown in results state)
              ValueListenableBuilder<RecordingState>(
                valueListenable: widget.practiceRecordingStateNotifier,
                builder: (context, state, child) {
                  if (state == RecordingState.results) {
                    return ValueListenableBuilder<PronunciationAssessmentResponse?>(
                      valueListenable: widget.practiceAssessmentResultNotifier,
                      builder: (context, result, child) {
                        if (result == null) return const SizedBox.shrink();
                        
                        final currentTurn = ref.watch(turnProvider);
                        final isAttackTurn = currentTurn == Turn.player;
                        final buttonColor = isAttackTurn ? Colors.red.shade400 : Colors.blue.shade400;
                        final buttonLabel = isAttackTurn ? "Confirm Attack" : "Confirm Defense";

                        return Container(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onConfirm();
                            },
                            child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDynamicWarningText() {
    final card = widget.card;
    final revealedBeforeAssessment = ref.read(cardsRevealedBeforeAssessmentProvider);
    final wasRevealedBeforeAssessment = revealedBeforeAssessment.contains(card.english);
    
    // Don't show any message after assessment has processed
    if (widget.practiceRecordingStateNotifier.value == RecordingState.results) {
      return "";
    }
    
    if (wasRevealedBeforeAssessment) {
      final turnType = ref.read(turnProvider) == Turn.player ? 'Attack' : 'Defense';
      return "Card revealed! $turnType power is reduced by 20%.";
    } else {
      return "Double-tap the card to reveal the translation.";
    }
  }

  Widget _buildContentForState(RecordingState state) {
    switch (state) {
      case RecordingState.idle:
        return _buildIdleUI();
      case RecordingState.recording:
        return _buildRecordingUI();
      case RecordingState.reviewing:
        return _buildReviewingUI();
      case RecordingState.assessing:
        return _buildAssessingUI();
      case RecordingState.results:
        return _buildResultsUI();
    }
  }

  Widget _buildPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: child,
    );
  }
  
  Widget _buildIdleUI() {
    return Column(
      children: [
        const Text("Ready to record?", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        _RecordButton(
          isRecording: false,
          onTap: widget.onPracticeRecord,
        ),
      ],
    );
  }

  Widget _buildRecordingUI() {
    return Column(
      children: [
        const Text("Recording...", style: TextStyle(color: Colors.redAccent)),
         const SizedBox(height: 16),
        _RecordButton(
          isRecording: true,
          onTap: widget.onPracticeStop,
        ),
      ],
    );
  }

  Widget _buildReviewingUI() {
    return Column(
      children: [
         const Text("Review your recording", style: TextStyle(color: Colors.white70)),
         const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.replay, color: Colors.white, size: 30),
              onPressed: widget.onPracticeReset,
              tooltip: 'Record Again',
            ),
            _PlaybackButton(
              progress: _progressController.value,
              onTap: _playRecording,
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.greenAccent, size: 30),
              onPressed: widget.onSend,
              tooltip: 'Send for Assessment',
            ),
          ],
        )
      ],
    );
  }

  Widget _buildAssessingUI() {
    return const Column(
      children: [
        SizedBox(
            width: 30, height: 30, child: CircularProgressIndicator()),
        SizedBox(height: 16),
        Text("Assessing...", style: TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildResultsUI() {
    return ValueListenableBuilder<PronunciationAssessmentResponse?>(
      valueListenable: widget.practiceAssessmentResultNotifier,
      builder: (context, result, child) {
        if (result == null) {
          return const Text("Error: No assessment result.", style: TextStyle(color: Colors.red));
        }

        final isAttackTurn = ref.read(turnProvider) == Turn.player;
        final String label;
        final double value;
        final String unit;
        final bool isPercentage;

        if (isAttackTurn) {
          label = 'Attack Damage';
          value = result.attackMultiplier;
          unit = '';
          isPercentage = false;
        } else {
          label = 'Damage Reduction';
          value = (1 - result.defenseMultiplier) * 100;
          unit = '%';
          isPercentage = true;
        }

        return Column(
          children: [
            // Expandable Attack/Defense Calculation Section
            _ExpandableSection(
              title: isAttackTurn ? 'Attack Bonus Details' : 'Defense Reduction Bonus Details',
              isExpanded: false, // Collapsed by default
              headerContent: Column(
                children: [
                  Text(
                    isAttackTurn ? 'Attack Bonus' : 'Defense Bonus',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(isAttackTurn ? ((value - 40) / 40 * 100) : value).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                ],
              ),
                                expandedContent: ModernCalculationDisplay(
                    explanation: result.calculationBreakdown.explanation,
                    isDefenseCalculation: ref.watch(turnProvider) == Turn.boss,
                  ),
            ),
            const SizedBox(height: 16),
            
            // Pronunciation Score Section
            Column(
              children: [
                const Text(
                  "Pronunciation Score",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                _AnimatedNumberDisplay(
                  number: result.pronunciationScore,
                  unit: '',
                  isPercentage: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.getRatingText(result.rating),
                style: TextStyle(
                  color: widget.getRatingColor(result.rating),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 3,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Expandable Detailed Scores Section
            _ExpandableSection(
              title: "Detailed Analysis",
              isExpanded: false, // Collapsed by default
              headerContent: const SizedBox.shrink(),
              expandedContent: _DetailedScoresWidget(
                result: result,
                card: widget.card,
                buildScoreRowWithTooltip: widget.buildScoreRowWithTooltip,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final bool isExpanded;
  final Widget headerContent;
  final Widget expandedContent;

  const _ExpandableSection({
    required this.title,
    required this.isExpanded,
    required this.headerContent,
    required this.expandedContent,
  });

  @override
  _ExpandableSectionState createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _isExpanded = false;
  final GlobalKey _sectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  void _scrollToSection() {
    final context = _sectionKey.currentContext;
    if (context != null) {
      // Delay to ensure the expansion animation has started
      Future.delayed(const Duration(milliseconds: 150), () {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 1.0, // Scroll to bottom of the widget
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: _sectionKey,
      children: [
        // Always show the header content
        widget.headerContent,
        const SizedBox(height: 8),
        // Expandable button
        GestureDetector(
          onTap: () {
            setState(() => _isExpanded = !_isExpanded);
            if (_isExpanded) {
              _scrollToSection();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade800.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade600.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.cyanAccent,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _isExpanded ? 'Hide Details' : 'Show Details',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        // Expandable content
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isExpanded 
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: widget.expandedContent,
              )
            : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _DetailedScoresWidget extends StatelessWidget {
  final PronunciationAssessmentResponse result;
  final Vocabulary card;
  final Widget Function({
    required String label,
    required double score,
    required String tooltip,
    required BuildContext context,
    bool isHeader,
  }) buildScoreRowWithTooltip;

  const _DetailedScoresWidget({
    required this.result,
    required this.card,
    required this.buildScoreRowWithTooltip,
  });

  @override
  Widget build(BuildContext context) {
    // Create a map for easy lookup of feedback by Thai word
    final feedbackMap = {for (var fb in result.detailedFeedback) fb.word: fb};

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildScoreRowWithTooltip(
            label: "Accuracy",
            score: result.accuracyScore,
            tooltip: "How closely your pronunciation matches a native speaker's.",
            context: context,
            isHeader: false,
          ),
          const SizedBox(height: 4),
          buildScoreRowWithTooltip(
            label: "Fluency",
            score: result.fluencyScore,
            tooltip: "Measures the naturalness of speech through silent breaks. Note: Less relevant for 1-3 word phrases.",
            context: context,
          ),
          const SizedBox(height: 4),
          buildScoreRowWithTooltip(
            label: "Completeness",
            score: result.completenessScore,
            tooltip: "The percentage of words you pronounced correctly from the text.",
            context: context,
          ),
          const SizedBox(height: 12),
          // Word-by-word analysis
          Text('Word-by-Word Accuracy',
            style: GoogleFonts.lato(
              color: Colors.cyan.shade200,
              fontWeight: FontWeight.bold,
              fontSize: 16
            ),
          ),
          const SizedBox(height: 8),
          if (card.wordMapping.isNotEmpty)
            ...card.wordMapping.map((mapping) {
              final feedback = feedbackMap[mapping.thai];
              return _WordAnalysisRow(
                mapping: mapping,
                score: feedback?.accuracyScore,
              );
            }),
        ],
      ),
    );
  }
}

class _WordAnalysisRow extends StatelessWidget {
  final WordMapping mapping;
  final double? score;

  const _WordAnalysisRow({required this.mapping, this.score});

  @override
  Widget build(BuildContext context) {
    final effectiveScore = score ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Word information
          SizedBox(
            width: 110, // Fixed width for alignment
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mapping.thai,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                if (mapping.transliteration.isNotEmpty)
                  Text(mapping.transliteration,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 10)),
                if (mapping.translation.isNotEmpty)
                  Text('"${mapping.translation}"',
                      style: TextStyle(
                          color: Colors.cyan.shade200.withOpacity(0.8),
                          fontSize: 10,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Progress bar
          Expanded(
            child: ScoreProgressBar(
              label: '', // Remove "Accuracy" label to give more space to bar
              value: effectiveScore / 100.0,
              score: effectiveScore,
              height: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedScoreBar extends StatefulWidget {
  final double score;
  final Color color;

  const _AnimatedScoreBar({required this.score, required this.color});

  @override
  _AnimatedScoreBarState createState() => _AnimatedScoreBarState();
}

class _AnimatedScoreBarState extends State<_AnimatedScoreBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation =
        Tween<double>(begin: 0, end: widget.score).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }
  
  @override
  void didUpdateWidget(covariant _AnimatedScoreBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: 0, end: widget.score).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
    }
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
        return Container(
          height: 10,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            widthFactor: _animation.value / 100,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RevealedCardDetails extends StatelessWidget {
  final Vocabulary card;
  final BossData bossData;

  const _RevealedCardDetails({required this.card, required this.bossData});

  @override
  Widget build(BuildContext context) {
    // Debug output for complexity
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Complexity section
          Row(
            children: [
              const Text(
                'Complexity:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(width: 8),
              ComplexityRating(complexity: card.complexity, size: 16),
            ],
          ),
          const Divider(color: Colors.white24, height: 20, thickness: 0.5),

          // Thai text and transliteration
          Text(card.thai,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('(${card.transliteration})',
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.white70)),
          const SizedBox(height: 16),

          // Details section (formerly Example)
          if (card.details != null && card.details!.isNotEmpty) ...[
            const Text('Details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              card.details!,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 16),
          ],

          // Slang section
          if (card.slang != null && card.slang!.isNotEmpty) ...[
            Text('Slang / Common Use',
                style: GoogleFonts.lato(
                    color: Colors.cyan.shade200,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              card.slang!,
              style: GoogleFonts.lato(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const _RecordButton({required this.isRecording, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isRecording ? Colors.redAccent.withOpacity(0.8) : Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: Icon(
            isRecording ? Icons.stop_rounded : Icons.mic_none,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}

// Custom widget for the playback button with progress animation
class _PlaybackButton extends StatelessWidget {
  final double progress;
  final VoidCallback onTap;

  const _PlaybackButton({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
              backgroundColor: Colors.white.withOpacity(0.3),
            ),
          ),
          const Icon(Icons.play_circle_fill, color: Colors.cyan, size: 40),
        ],
      ),
    );
  }
}

class _AnimatedNumberDisplay extends StatelessWidget {
  final double number;
  final String unit;
  final bool isPercentage;

  const _AnimatedNumberDisplay({
    required this.number,
    required this.unit,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: number),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Text(
          '${isPercentage ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}$unit',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 28,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
            ],
          ),
        );
      },
    );
  }
}