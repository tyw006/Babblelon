import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/models/turn.dart';
import 'package:babblelon/models/supabase_models.dart';
import 'package:babblelon/widgets/flashcard.dart';
import 'package:babblelon/widgets/top_info_bar.dart';
import 'package:babblelon/screens/main_menu_screen.dart';
import 'package:babblelon/screens/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart' as tutorial_db;
import 'package:babblelon/models/assessment_model.dart';
import 'package:babblelon/services/api_service.dart';
import 'package:babblelon/widgets/audio_recognition_error_dialog.dart';
import 'package:babblelon/services/posthog_service.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:babblelon/widgets/complexity_rating.dart';
import 'package:babblelon/widgets/score_progress_bar.dart';
import 'package:babblelon/widgets/modern_calculation_display.dart';
import 'package:babblelon/widgets/floating_damage_overlay.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:babblelon/providers/battle_providers.dart';
import 'package:babblelon/widgets/victory_report_dialog.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/models/local_storage_models.dart' as isar_models;
import 'package:babblelon/widgets/shared/app_styles.dart';
import 'package:babblelon/widgets/defeat_dialog.dart';
import 'package:babblelon/services/tutorial_service.dart';

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
  damageCalculation, // New state for damage calculation phase
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
  late final EchoAudioService _echoAudioService;
  final GlobalKey<FloatingDamageOverlayState> damageOverlayKey = GlobalKey<FloatingDamageOverlayState>();
  bool _isRecording = false;
  bool _isLoading = false;
  bool _showProjectile = false;
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
  bool _isRecorderInitialized = false;
  
  // --- Audio Players for Sound Effects ---
  just_audio.AudioPlayer? _pronunciationSoundPlayer;
  just_audio.AudioPlayer? _bonusSoundPlayer;

  // --- Audio Helper Method ---
  void _playSoundEffect(String path, {double volume = 1.0}) {
    final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
    if (soundEffectsEnabled) {
      FlameAudio.play(path, volume: volume);
    }
  }

  @override
  void initState() {
    super.initState();
    _calculateSpriteSizes();
    _initializeAnimations();
    _apiService = ApiService();
    _echoAudioService = EchoAudioService();
    _initializeRecorder();

    // Show boss fight tutorial if this is the first time in boss battle
    // Wait for tutorial progress to load from database
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small delay to ensure tutorial database service has loaded
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      final tutorialProgressNotifier = ref.read(tutorial_db.tutorialProgressProvider.notifier);
      final isCompleted = tutorialProgressNotifier.isStepCompleted('boss_fight_intro');
      
      debugPrint('🎓 BossFightScreen: Tutorial check - boss_fight_intro completed: $isCompleted');
      
      if (!isCompleted) {
        debugPrint('🎓 BossFightScreen: Starting boss fight tutorial');
        final tutorialManager = TutorialManager(
          context: context,
          ref: ref,
        );
        
        // Show comprehensive boss fight tutorial (multi-slide)
        tutorialManager.startTutorial(TutorialTrigger.bossFight);
        
        // Show detailed battle mechanics tutorial if this is the first time
        if (!tutorialProgressNotifier.isStepCompleted('battle_mechanics_deep_dive')) {
          await tutorialManager.startTutorial(TutorialTrigger.firstBossBattle);
        }
      } else {
        debugPrint('🎓 BossFightScreen: Boss fight tutorial already completed, skipping');
      }
    });
    
    // Track boss fight start
    PostHogService.trackBossFight(
      event: 'start',
      bossName: widget.bossData.name,
      playerHealth: ref.read(playerHealthProvider),
      bossHealth: widget.bossData.maxHealth,
      additionalProperties: {
        'boss_difficulty': 'normal', // Default difficulty since BossData doesn't have difficulty property
      },
    );
    
    // Initialize and start boss fight background music using screen-based system
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameStateProvider.notifier).switchScreen(ScreenType.bossFight);

      // Start tracking battle metrics
      ref.read(battleTrackingProvider.notifier).startBattle(
            playerStartingHealth: ref.read(playerHealthProvider),
            bossMaxHealth: widget.bossData.maxHealth,
          );
          
      // Pre-load sound effects that will be used in dialogs to avoid lag
      _preloadSoundEffects();
    });
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
    _pronunciationSoundPlayer?.dispose();
    _bonusSoundPlayer?.dispose();
    
    // Stop boss fight music and restore main game music
    FlameAudio.bgm.stop();
    
    // Reset game state when screen is disposed
    _isInitialTurnSet = false;
    _gameInitialized = false;
    _apiService.dispose();
    _echoAudioService.dispose();
    
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
    // Track pronunciation attack
    PostHogService.trackBossFight(
      event: 'pronunciation_attack',
      bossName: widget.bossData.name,
      playerHealth: ref.read(playerHealthProvider),
      bossHealth: ref.read(bossHealthProvider(widget.bossData.maxHealth)),
      additionalProperties: {
        'attack_multiplier': attackMultiplier,
        'turn': 'player',
      },
    );

    // Play attack start sound effect
    _playSoundEffect('soundeffects/soundeffect_dimsum.mp3');
    
    // Small delay to let popup close completely before starting animation
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Calculate damage before animation
    final damage = attackMultiplier.round();
    final isCritical = damage >= 75; // Updated: 50% bonus threshold (50 base * 1.5 = 75)
    final screenWidth = MediaQuery.of(context).size.width;
    // Consistent positioning for all boss damage indicators - further left to fit on screen
    final bossPosition = Offset(screenWidth * 0.60, MediaQuery.of(context).size.height * 0.35);
    
          // Set animation state to show projectile
      ref.read(animationStateProvider.notifier).state = AnimationState.attacking;
      
      // Start projectile animation 
      final projectileFuture = _projectileController.forward();
      
      // Wait for projectile to reach target (70% of animation duration for contact)
      await Future.delayed(Duration(milliseconds: (_projectileController.duration!.inMilliseconds * 0.7).round()));
      
      // Stop the attacking animation state to hide projectile immediately upon contact
      ref.read(animationStateProvider.notifier).state = AnimationState.idle;
      
      // Apply damage to boss after projectile hits
      final bossHealth = ref.read(bossHealthProvider(widget.bossData.maxHealth).notifier);
      bossHealth.state = (bossHealth.state - damage).clamp(0, widget.bossData.maxHealth);
      
      // --- VICTORY CHECK ---
      if (bossHealth.state <= 0) {
        _showVictoryPopup();
        return; // Stop further execution in this method
      }
      
      // Show boss damage effect, sound, and damage indicator together
      _performBossDamageAnimation();
      
      // Play attack strike sound effect when damage animation starts
      _playSoundEffect('soundeffects/soundeffect_dimsum_strike.mp3');
      
      // Show damage indicator when damage animation starts
      damageOverlayKey.currentState?.showDamageIndicator(
        damage: damage.toDouble(),
        position: bossPosition,
        isHealing: false,
        isDefense: false,
        isCritical: isCritical,
        isGreatDefense: false,
        attackBonus: damage > 20 ? (damage - 20).toDouble() : 0.0,
        defenseBonus: 0.0,
        isMonster: true,
      );
      
      // Wait for damage animation to complete
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Reset projectile controller and ensure it's hidden
    _projectileController.reset();
    ref.read(animationStateProvider.notifier).state = AnimationState.idle;
    
    // Start boss turn after a short delay (show snackbar every time now)
    await Future.delayed(const Duration(milliseconds: 100));
    _startBossTurn(showSnackbar: true);
  }

  Future<void> _performDefense({double defenseMultiplier = 1.0}) async {
    // Track pronunciation defense
    PostHogService.trackBossFight(
      event: 'pronunciation_defense',
      bossName: widget.bossData.name,
      playerHealth: ref.read(playerHealthProvider),
      bossHealth: ref.read(bossHealthProvider(widget.bossData.maxHealth)),
      additionalProperties: {
        'defense_multiplier': defenseMultiplier,
        'turn': 'boss',
        'is_great_defense': defenseMultiplier <= 0.7,
      },
    );

    // Small delay to let popup close completely
    await Future.delayed(const Duration(milliseconds: 100));
    
    ref.read(animationStateProvider.notifier).state = AnimationState.bossProjectileAttacking;
    
    // Start boss attack, but don't wait for it to finish yet.
    final bossAttackFuture = _bossProjectileController.forward();
    
    // Play tuktuk fenrir sound with echo effect during monster sprite attack animation
    final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
    if (soundEffectsEnabled) {
      _echoAudioService.playWithEcho(
        assetPath: 'soundeffects/soundeffect_tuktuk_fenrir.wav',
        echoCount: 4,
        echoDelay: const Duration(milliseconds: 200),
        volumeDecay: 0.7,
        initialVolume: 0.8,
      );
    }
    
    // Wait for the boss projectile to get closer before showing the shield.
    // Timing this to match when the monster attack sprite collides with defense
    await Future.delayed(const Duration(milliseconds: 5)); // Reset to original timing for shield sync
    
    // Activate shield animation to block the attack. It will render based on its controller.
    _shieldController.forward();
    
    // Play defense sound effect when shield activates
    _playSoundEffect('soundeffects/soundeffect_crispyporkbelly.mp3');
    
    // Calculate damage and position info before animation completes
    const baseDamage = 15.0; // Boss base damage (per rubric)
    final actualDamage = (baseDamage * defenseMultiplier).round();
    final isGreatDefense = defenseMultiplier <= 0.7; // Great defense threshold (30% damage reduction)
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final playerXPos = screenWidth * 0.2;
    
    // Position the indicator at the top of the player sprite (matching monster positioning approach)
    final playerDamagePosition = Offset(playerXPos - 75, screenHeight * 0.35);
    
    // Wait for the full animation to complete before applying damage effects
    await bossAttackFuture;
    
    // Play laser sound effect exactly when damage is applied
    _playSoundEffect('soundeffects/soundeffect_tuktuk_laser.mp3');
    
    // Apply damage to player
    final playerHealth = ref.read(playerHealthProvider.notifier);
    playerHealth.state = (playerHealth.state - actualDamage).clamp(0, 100);

    // --- DEFEAT CHECK ---
    if (playerHealth.state <= 0) {
      _showDefeatPopup();
      return; // Stop further execution
    }

    // Trigger player damage animation, sound, and damage indicator together
    _performPlayerDamageAnimation();
    
    // Play boss attack hit sound effect when damage animation starts
    // FlameAudio.play('soundeffects/soundeffect_tuktuk_strike.mp3');

    // Show damage indicator when damage animation starts
    damageOverlayKey.currentState?.showDamageIndicator(
      damage: actualDamage.toDouble(),
      position: playerDamagePosition,
      isHealing: false,
      isDefense: true,
      isCritical: false,
      isGreatDefense: isGreatDefense,
      attackBonus: 0.0,
      defenseBonus: 0.0,
      isMonster: false,
    );

    // Wait for the full animation to complete before proceeding
    await bossAttackFuture;
    
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
    
    // Wait for boss attack duration (sped up by 50% from 1500ms to 750ms)
    await Future.delayed(const Duration(milliseconds: 750));
    
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
          onStopAllSounds: () {
            _echoAudioService.stopAllEchoPlayers();
          },
        );
      },
    ).then((_) {
      // Clean up when the dialog is closed
      _resetPracticeRecording();
      _practiceAssessmentResult.value = null;
      
      // Resume background music when flashcard dialog closes if music is enabled
      final musicEnabled = ref.read(gameStateProvider).musicEnabled;
      if (musicEnabled) {
        FlameAudio.bgm.resume();
      }
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
        azurePronMapping: usedCard.wordMapping.map((e) => e.toJson()).toList(),
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
      
      if (e is AudioNotRecognizedException) {
        // Handle audio recognition failure with custom dialog
        _practiceRecordingState.value = RecordingState.idle;
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AudioRecognitionErrorDialog(
              message: e.userMessage,
              onTryAgain: () {
                Navigator.of(context).pop();
                // Reset to recording state to allow retry
                _practiceRecordingState.value = RecordingState.idle;
              },
            ),
          );
        }
      } else {
        // Handle other errors with snackbar (keep existing behavior)
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
  }

  Future<void> _handleConfirmedAction() async {
    final currentTurn = ref.read(turnProvider);
    final assessmentResult = _practiceAssessmentResult.value;
    
    if (assessmentResult == null) return;

    // Log the turn data
    final turnData = {
      'action': currentTurn == Turn.player ? 'attack' : 'defense',
      'word': ref.read(tappedCardProvider)?.thai ?? 'Unknown',
      'pronunciationScore': assessmentResult.pronunciationScore * 100,
      'complexity': ref.read(tappedCardProvider)?.complexity ?? 0,
      'damageDealt': currentTurn == Turn.player ? assessmentResult.attackMultiplier.round().toDouble() : 0.0,
      'damageReceived': currentTurn == Turn.boss ? (15.0 * assessmentResult.defenseMultiplier) : 0.0,
      'pronunciationErrors': assessmentResult.detailedFeedback.map((e) => e.errorType).where((e) => e != 'None').toList(),
    };
    ref.read(battleTrackingProvider.notifier).addTurn(
      action: turnData['action'] as String,
      word: turnData['word'] as String,
      pronunciationScore: turnData['pronunciationScore'] as double,
      complexity: turnData['complexity'] as int,
      damageDealt: turnData['damageDealt'] as double,
      damageReceived: turnData['damageReceived'] as double,
      pronunciationErrors: turnData['pronunciationErrors'] as List<String>,
    );

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
    // Pause music when menu opens
    FlameAudio.bgm.pause();
    
    showDialog(
      context: context,
      builder: (context) => _BossFightMenuDialog(
        onExit: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
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
        onClose: () {
          Navigator.of(context).pop();
          // Resume music when menu closes if music is enabled
          final musicEnabled = ref.read(gameStateProvider).musicEnabled;
          if (musicEnabled) {
            FlameAudio.bgm.resume();
          }
        },
      ),
    );
  }

  Future<void> _initializeRecorder() async {
    if (_isRecorderInitialized) return;
    
    try {
      final hasPermission = await _checkPermission();
      if (!hasPermission) {
        print("Recording permission not granted.");
        return;
      }
      _isRecorderInitialized = true;
    } catch (e) {
      print("Error initializing recorder: $e");
    }
  }

  Future<void> _preloadSoundEffects() async {
    try {
      // Pre-load sound effects that will be used in flashcard dialogs
      // This avoids lag when these sounds play for the first time
      final tempPlayer = just_audio.AudioPlayer();
      await tempPlayer.setAsset('assets/audio/soundeffects/soundeffect_increasingnumber.mp3');
      await tempPlayer.dispose(); // Dispose after pre-loading
    } catch (e) {
      print("Error pre-loading sound effects: $e");
    }
  }

  Future<void> _startPracticeRecording() async {
    if (!_isRecorderInitialized) {
      await _initializeRecorder();
      if (!_isRecorderInitialized) return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/practice_recording.wav';
      
      final musicEnabled = ref.read(gameStateProvider).musicEnabled;
      if (musicEnabled) {
        FlameAudio.bgm.pause();
      }
      
      await _practiceAudioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // Optimal for STT APIs
          numChannels: 1,     // Mono
        ), 
        path: path
      );
      
      _practiceRecordingState.value = RecordingState.recording;
      _lastPracticeRecordingPath.value = null;
    } catch (e) {
      print("Error starting practice recording: $e");
    }
  }

  Future<void> _stopPracticeRecording() async {
    try {
      final path = await _practiceAudioRecorder.stop();

      final musicEnabled = ref.read(gameStateProvider).musicEnabled;
      if (musicEnabled) {
        FlameAudio.bgm.resume();
      }

      if (path != null) {
        _lastPracticeRecordingPath.value = path;
        _practiceRecordingState.value = RecordingState.reviewing;
      }
    } catch (e) {
      print("Error stopping practice recording: $e");
      _practiceRecordingState.value = RecordingState.idle;
    }
  }

  Future<void> _resetPracticeRecording() async {
    // Do not dispose and recreate the recorder to prevent initialization lag.
    // Instead, just ensure it's stopped and reset the state.
    if (await _practiceAudioRecorder.isRecording()) {
      await _practiceAudioRecorder.stop();
      final musicEnabled = ref.read(gameStateProvider).musicEnabled;
      if (musicEnabled) {
        FlameAudio.bgm.resume();
      }
    }
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
                                final revealedCards = ref.watch(revealedCardsProvider);
                                final isRevealed = revealedCards.contains(card.english);
                                return Flashcard(
                                  key: ValueKey(card.english),
                                  vocabulary: card,
                                  isRevealed: isRevealed,
                                  isFlippable: false, // Prevent revealing from grid
                                  showAudioButton: false,
                                  onTap: () {
                                    ref.playButtonSound();
                                    ref.read(tappedCardProvider.notifier).state = card;
                                    _showFlashcardDialog(card);
                                  },
                                  onReveal: () {
                                    ref.read(revealedCardsProvider.notifier).update((state) {
                                      final newState = Set<String>.from(state);
                                      newState.add(card.english);
                                      return newState;
                                    });
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

  Future<void> _showVictoryPopup() async {
    // Finalize metrics
    final playerHealth = ref.read(playerHealthProvider);
    ref.read(battleTrackingProvider.notifier).endBattle(finalPlayerHealth: playerHealth);
    final metrics = ref.read(battleTrackingProvider);

    // Track boss fight victory
    PostHogService.trackBossFight(
      event: 'victory',
      bossName: widget.bossData.name,
      playerHealth: playerHealth,
      bossHealth: 0,
      additionalProperties: {
        'final_player_health': playerHealth,
        'turns_taken': metrics?.turns.length ?? 0,
        'attack_count': metrics?.turns.where((turn) => turn.action == 'attack').length ?? 0,
        'defense_count': metrics?.turns.where((turn) => turn.action == 'defend').length ?? 0,
        'boss_difficulty': 'normal', // Default difficulty since BossData doesn't have difficulty property
      },
    );

    if (metrics == null) return; // Should not happen

    // --- Save Progress with Isar ---
    final isarService = IsarService();
    // This is a placeholder for a real user ID from your auth system
    const userId = 'default_user'; 
    
    // Get or create player profile
    isar_models.PlayerProfile? profile = await isarService.getPlayerProfile(userId);
    profile ??= isar_models.PlayerProfile()..userId = userId;

    // Update profile
    profile.experiencePoints += metrics.expGained;
    profile.gold += metrics.goldEarned;
    // TODO: Implement level up logic based on experiencePoints

    await isarService.savePlayerProfile(profile);

    // Update mastered phrases
    for (final turn in metrics.turns) {
      isar_models.MasteredPhrase? phrase = await isarService.getMasteredPhrase(turn.word);
      phrase ??= isar_models.MasteredPhrase()
        ..phraseEnglishId = turn.word
        ..isMastered = false;
      
      phrase.lastScore = turn.pronunciationScore;
      phrase.timesPracticed += 1;
      phrase.lastPracticedAt = DateTime.now();
      if (turn.pronunciationScore >= 60) { // Mastery threshold
        phrase.isMastered = true;
      }
      await isarService.saveMasteredPhrase(phrase);
    }
    // --- End Save Progress ---

    // Stop music and play victory sound
    FlameAudio.bgm.stop();
    _playSoundEffect('soundeffects/soundeffect_victory.mp3'); // Victory sound

    // Show the dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return VictoryReportDialog(metrics: metrics);
      },
    );

    // After dialog is closed, navigate back to main menu
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _showDefeatPopup() async {
    // Finalize metrics
    final playerHealth = ref.read(playerHealthProvider);
    ref.read(battleTrackingProvider.notifier).endBattle(finalPlayerHealth: playerHealth);
    final metrics = ref.read(battleTrackingProvider);

    // Track boss fight defeat
    PostHogService.trackBossFight(
      event: 'defeat',
      bossName: widget.bossData.name,
      playerHealth: 0,
      bossHealth: ref.read(bossHealthProvider(widget.bossData.maxHealth)),
      additionalProperties: {
        'final_boss_health': ref.read(bossHealthProvider(widget.bossData.maxHealth)),
        'turns_taken': metrics?.turns.length ?? 0,
        'attack_count': metrics?.turns.where((turn) => turn.action == 'attack').length ?? 0,
        'defense_count': metrics?.turns.where((turn) => turn.action == 'defend').length ?? 0,
        'boss_difficulty': 'normal', // Default difficulty since BossData doesn't have difficulty property
      },
    );

    if (metrics == null) return;

    // Stop music and play defeat sound
    FlameAudio.bgm.stop();
    _playSoundEffect('soundeffects/soundeffect_defeat.mp3'); // Defeat sound

    // Show the dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return DefeatDialog(metrics: metrics);
      },
    );

    // After dialog is closed, navigate back to main menu
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (Route<dynamic> route) => false,
    );
  }
}

class _BossFightMenuDialog extends ConsumerWidget {
  final VoidCallback onExit;
  final VoidCallback? onClose;

  const _BossFightMenuDialog({required this.onExit, this.onClose});

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
                backgroundColor: Colors.redAccent.withOpacity(0.8),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
              onPressed: () {
                ref.playButtonSound();
                onExit();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.exit_to_app, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Exit to Main Menu', style: TextStyle(color: Colors.white)),
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
              onPressed: () {
                ref.playButtonSound();
                if (onClose != null) onClose!();
              },
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BossFightMenuButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final soundEffectsEnabled = ref.watch(gameStateProvider.select((state) => state.soundEffectsEnabled));
    
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Switch(
        value: value,
        onChanged: (val) {
          ref.playButtonSound();
          onChanged(val);
        },
        activeColor: Colors.blueAccent,
      ),
      onTap: () {
        ref.playButtonSound();
        onChanged(!value);
      },
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
  final VoidCallback onStopAllSounds;

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
    required this.onStopAllSounds,
  });

  @override
  ConsumerState<_InteractiveFlashcardDialog> createState() =>
      _InteractiveFlashcardDialogState();
}

class _InteractiveFlashcardDialogState
    extends ConsumerState<_InteractiveFlashcardDialog> with TickerProviderStateMixin {
  bool _isRevealed = false;
  late final just_audio.AudioPlayer _audioPlayer;
  late final just_audio.AudioPlayer _soundEffectsPlayer; // Single reusable player for sound effects
  late AnimationController _progressController; // For playback progress

  double _animatedPronunciationScore = 0;
  double _animatedBonusPercentage = 0;
  Timer? _soundEffectTimer; // Timer to control sound duration

  @override
  void initState() {
    super.initState();
    _isRevealed = ref.read(revealedCardsProvider).contains(widget.card.english);
    _audioPlayer = just_audio.AudioPlayer();
    _soundEffectsPlayer = just_audio.AudioPlayer(); // Initialize once
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Duration will be updated dynamically
    )..addListener(() {
        setState(() {}); // Redraw on progress change
      });

    // Pre-load the sound effect to avoid lag on first play
    _preloadSoundEffect();

    // Listen for the results state to auto-flip the card
    widget.practiceRecordingStateNotifier.addListener(_onRecordingStateChange);
  }

  @override
  void dispose() {
    widget.practiceRecordingStateNotifier.removeListener(_onRecordingStateChange);
    _audioPlayer.dispose();
    _soundEffectsPlayer.dispose(); // Dispose the reusable player
    _soundEffectTimer?.cancel(); // Cancel any active timer
    _progressController.dispose();
    super.dispose();
  }
  

  
  Future<void> _preloadSoundEffect() async {
    try {
      // Pre-load the increasing number sound effect to avoid lag on first play
      await _soundEffectsPlayer.setAsset('assets/audio/soundeffects/soundeffect_increasingnumber.mp3');
    } catch (e) {
      print("Error pre-loading sound effect: $e");
    }
  }
  
  void _onRecordingStateChange() {
    if (widget.practiceRecordingStateNotifier.value == RecordingState.results) {
      // Trigger the card flip if it hasn't been revealed yet
      if (mounted && !_isRevealed) {
        setState(() {
          _isRevealed = true;
        });
      }
      // Animate the scores after a short delay
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted && widget.practiceAssessmentResultNotifier.value != null) {
          final score = widget.practiceAssessmentResultNotifier.value!.pronunciationScore;
          final duration = score == 0 ? const Duration(milliseconds: 300) : const Duration(milliseconds: 1500);

          // Play counting animation sound effect with a specific duration
          final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
          if (soundEffectsEnabled) {
            try {
              await _soundEffectsPlayer.setAsset('assets/audio/soundeffects/soundeffect_increasingnumber.mp3');
              _soundEffectsPlayer.play();
              
              // Stop the audio after the specified duration
              _soundEffectTimer?.cancel(); // Cancel any existing timer
              _soundEffectTimer = Timer(duration, () {
                _soundEffectsPlayer.stop();
              });
            } catch (e) {
              print("Error playing pronunciation sound: $e");
            }
          }
          
          setState(() {
            _animatedPronunciationScore = widget.practiceAssessmentResultNotifier.value!.pronunciationScore;
          });
        }
      });
    } else if (widget.practiceRecordingStateNotifier.value == RecordingState.damageCalculation) {
      // Animate the bonus percentage
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted && widget.practiceAssessmentResultNotifier.value != null) {
          final result = widget.practiceAssessmentResultNotifier.value!;
          final isAttackTurn = ref.read(turnProvider) == Turn.player;
          
          final bonusPercentage = isAttackTurn 
            ? ((result.calculationBreakdown.finalAttackBonus ?? 1.0) - 1.0) * 100
            : (1 - result.defenseMultiplier) * 100;

          final duration = bonusPercentage == 0 ? const Duration(milliseconds: 300) : const Duration(milliseconds: 1800);

          // Play counting animation sound effect with a specific duration
          final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
          if (soundEffectsEnabled) {
            try {
              await _soundEffectsPlayer.setAsset('assets/audio/soundeffects/soundeffect_increasingnumber.mp3');
              _soundEffectsPlayer.play();
              
              // Stop the audio after the specified duration
              _soundEffectTimer?.cancel(); // Cancel any existing timer
              _soundEffectTimer = Timer(duration, () {
                _soundEffectsPlayer.stop();
              });
            } catch (e) {
              print("Error playing pronunciation sound: $e");
            }
          }
          
          setState(() {
            if (isAttackTurn) {
              final breakdown = result.calculationBreakdown;
              final attackMultiplier = breakdown.finalAttackBonus ?? 1.0;
              _animatedBonusPercentage = (attackMultiplier - 1.0) * 100;
            } else {
              _animatedBonusPercentage = (1 - result.defenseMultiplier) * 100;
            }
          });
        }
      });
    } else {
      // Reset scores when leaving results/damage states
      if (mounted) {
        setState(() {
          _animatedPronunciationScore = 0;
          _animatedBonusPercentage = 0;
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
                      ValueListenableBuilder<RecordingState>(
                        valueListenable: widget.practiceRecordingStateNotifier,
                        builder: (context, state, child) {
                          // Only show flashcard for non-damage calculation states
                          if (state != RecordingState.damageCalculation) {
                            return Column(
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
                                    showAudioButton: true, // <-- Ensure audio icon appears in dialog
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
                                _buildContentForState(state),
                              ],
                            );
                          } else {
                            return _buildContentForState(state);
                          }
                        }
                      ),
                    ],
                  ),
                ),
              ),
              // Fixed continue button area (only shown in results state)
              ValueListenableBuilder<RecordingState>(
                valueListenable: widget.practiceRecordingStateNotifier,
                builder: (context, state, child) {
                  if (state == RecordingState.results) {
                    return Container(
                      padding: const EdgeInsets.only(top: 16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                        ),
                        onPressed: () {
                          // Play sound effect on continue
                          ref.playButtonSound();
                          
                          // Stop any playing sound effects when Continue is pressed
                          _soundEffectTimer?.cancel();
                          _soundEffectsPlayer.stop();
                          widget.onStopAllSounds();
                          
                          widget.practiceRecordingStateNotifier.value = RecordingState.damageCalculation;
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Continue",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward),
                          ],
                        ),
                      ),
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
      case RecordingState.damageCalculation:
        return _buildDamageCalculationUI();
    }
  }

  Widget _buildPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: AppStyles.cardDecoration,
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
              icon: const Icon(Icons.replay, color: AppStyles.textColor, size: 30),
              onPressed: widget.onPracticeReset,
              tooltip: 'Record Again',
            ),
            _PlaybackButton(
              progress: _progressController.value,
              onTap: _playRecording,
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppStyles.accentColor, size: 30),
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
        Text("Assessing...", style: TextStyle(color: AppStyles.subtitleTextColor)),
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

        return Column(
          children: [
            // Phase 1: Pronunciation Assessment Results
            const Text(
              "Pronunciation Assessment",
              style: TextStyle(
                color: AppStyles.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            // Enhanced Pronunciation Score with "out of 100"
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedFlipCounter(
                      value: _animatedPronunciationScore,
                      duration: const Duration(milliseconds: 1500),
                      textStyle: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                        shadows: [
                          Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(2, 2)),
                          Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 0)),
                          Shadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 0)),
                        ],
                      ),
                      fractionDigits: 0,
                    ),
                    _FancyAnimatedTextDisplay(
                      text: " / 100",
                      color: Colors.cyanAccent,
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
              ],
            ),
            const SizedBox(height: 24),
            
            // Detailed Pronunciation Analysis (always visible)
            _DetailedPronunciationScores(
              result: result,
              card: widget.card,
              buildScoreRowWithTooltip: widget.buildScoreRowWithTooltip,
            ),
            const SizedBox(height: 24),
            
            // Azure API Insights
                                  _AzurePronunciationTips(result: result, vocabulary: widget.card),
          ],
        );
      },
    );
  }

  Widget _buildDamageCalculationUI() {
    return ValueListenableBuilder<PronunciationAssessmentResponse?>(
      valueListenable: widget.practiceAssessmentResultNotifier,
      builder: (context, result, child) {
        if (result == null) {
          return const Text("Error: No assessment result.", style: TextStyle(color: Colors.red));
        }

        final isAttackTurn = ref.read(turnProvider) == Turn.player;
        final IconData actionIcon;
        final Color actionColor;
        final String actionText;

        if (isAttackTurn) {
          actionIcon = Icons.flash_on;
          actionColor = Colors.redAccent;
          actionText = "Attack!";
        } else {
          actionIcon = Icons.shield;
          actionColor = Colors.blueAccent;
          actionText = "Defend!";
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isAttackTurn ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Back Button
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      widget.practiceRecordingStateNotifier.value = RecordingState.results;
                    },
                    icon: const Icon(Icons.arrow_back, color: AppStyles.subtitleTextColor),
                    tooltip: 'Back to Assessment',
                  ),
                  const Spacer(),
                ],
              ),
              
              // Attack/Defense Icon
              Icon(
                actionIcon,
                size: 60,
                color: actionColor,
              ),
              const SizedBox(height: 16),
              
              // Bonus Percentage with Enhanced Animation
              Text(
                isAttackTurn ? "Attack Bonus" : "Defense Bonus",
                style: const TextStyle(
                  color: AppStyles.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedFlipCounter(
                    value: _animatedBonusPercentage,
                    duration: const Duration(milliseconds: 1800),
                    textStyle: TextStyle(
                      color: actionColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                      shadows: [
                        Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(2, 2)),
                        Shadow(color: actionColor.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 0)),
                        Shadow(color: actionColor.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 0)),
                      ],
                    ),
                    fractionDigits: 0,
                  ),
                  const Text(
                    "%",
                    style: TextStyle(
                      color: AppStyles.subtitleTextColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Calculation Breakdown (always visible)
              ModernCalculationDisplay(
                explanation: result.calculationBreakdown.explanation,
                isDefenseCalculation: ref.watch(turnProvider) == Turn.boss,
              ),
              const SizedBox(height: 32),
              
              // Final Action Button
              ElevatedButton(
                onPressed: () {
                  ref.playButtonSound();
                  _soundEffectTimer?.cancel();
                  _soundEffectsPlayer.stop();
                  widget.onStopAllSounds();
                  Navigator.of(context).pop();
                  widget.onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: AppStyles.textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actionIcon, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          // Word analysis
          Text('Word Accuracy',
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
                        color: AppStyles.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                if (mapping.transliteration.isNotEmpty)
                  Text(mapping.transliteration,
                      style: TextStyle(
                          color: AppStyles.subtitleTextColor, fontSize: 10)),
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

class _BackendWordAnalysisRow extends StatelessWidget {
  final WordFeedback feedback;

  const _BackendWordAnalysisRow({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Word information from backend
          SizedBox(
            width: 110, // Fixed width for alignment
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feedback.word,
                    style: const TextStyle(
                        color: AppStyles.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                if (feedback.transliteration.isNotEmpty)
                  Text(feedback.transliteration,
                      style: TextStyle(
                          color: AppStyles.subtitleTextColor, fontSize: 10)),
                if (feedback.errorType != 'None')
                  Text(feedback.errorType,
                      style: TextStyle(
                          color: Colors.orange.shade300,
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
              value: feedback.accuracyScore / 100.0,
              score: feedback.accuracyScore,
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

          // Thai text and transliteration - responsive sizing with audio button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  card.thai,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.left,
                ),
              ),
              if (card.audioPath != null && card.audioPath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white),
                    onPressed: () async {
                      try {
                        // Create a new audio player for this specific use
                        final audioPlayer = just_audio.AudioPlayer();
                        await audioPlayer.setAsset(card.audioPath!);
                        audioPlayer.play();
                        // Dispose the player after playing
                        audioPlayer.playerStateStream.listen((state) {
                          if (state.processingState ==
                              just_audio.ProcessingState.completed) {
                            audioPlayer.dispose();
                          }
                        });
                      } catch (e) {
                        print("Error playing audio: $e");
                      }
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Word breakdown section - compact layout with responsive text sizing
          if (card.wordMapping.isNotEmpty) ...[
            const Text('Word Breakdown:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate total text length to determine font size
                  int totalTextLength = card.wordMapping.fold(0, (sum, mapping) => 
                      sum + mapping.thai.length + mapping.transliteration.length + mapping.translation.length);
                  
                  // Adjust font size based on content density
                  double baseFontSize = totalTextLength > 100 ? 13.0 : 
                                       totalTextLength > 60 ? 14.0 : 15.0;
                  double transliterationSize = baseFontSize - 1;
                  double translationSize = baseFontSize - 1;
                  
                  return Column(
                    children: card.wordMapping.map((mapping) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          // Thai word
                          Text(
                            mapping.thai,
                            style: TextStyle(fontSize: baseFontSize, fontWeight: FontWeight.bold, color: Colors.cyan),
                          ),
                          const SizedBox(width: 4),
                          // Transliteration in parentheses
                          Text(
                            '(${mapping.transliteration})',
                            style: TextStyle(fontSize: transliterationSize, fontStyle: FontStyle.italic, color: Colors.white70),
                          ),
                          const SizedBox(width: 6),
                          // Arrow and translation
                          Expanded(
                            child: Text(
                              '→ ${mapping.translation}',
                              style: TextStyle(fontSize: translationSize, color: Colors.white60),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

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
            color: AppStyles.textColor,
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

class _FancyAnimatedNumberDisplay extends StatelessWidget {
  final double number;
  final Color color;

  const _FancyAnimatedNumberDisplay({
    required this.number,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedFlipCounter(
      value: number,
      duration: const Duration(milliseconds: 1500),
      textStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 36,
        shadows: [
          Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(2, 2)),
          Shadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 0)),
          Shadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 0)),
        ],
      ),
      fractionDigits: 0,
    );
  }
}

class _FancyAnimatedPercentageDisplay extends StatelessWidget {
  final double percentage;
  final Color color;

  const _FancyAnimatedPercentageDisplay({
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedFlipCounter(
      value: percentage,
      duration: const Duration(milliseconds: 1500),
      textStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 40,
        shadows: [
          Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(2, 2)),
          Shadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 0)),
          Shadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 0)),
        ],
      ),
      fractionDigits: 0,
    );
  }
}

class _FancyAnimatedTextDisplay extends StatefulWidget {
  final String text;
  final Color color;

  const _FancyAnimatedTextDisplay({
    required this.text,
    required this.color,
  });

  @override
  _FancyAnimatedTextDisplayState createState() => _FancyAnimatedTextDisplayState();
}

class _FancyAnimatedTextDisplayState extends State<_FancyAnimatedTextDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.color,
              fontSize: 36,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(2, 2)),
                Shadow(color: widget.color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 0)),
                Shadow(color: widget.color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 0)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailedPronunciationScores extends StatelessWidget {
  final PronunciationAssessmentResponse result;
  final Vocabulary card;
  final Widget Function({
    required BuildContext context,
    bool isHeader,
    required String label,
    required double score,
    required String tooltip,
  }) buildScoreRowWithTooltip;

  const _DetailedPronunciationScores({
    required this.result,
    required this.card,
    required this.buildScoreRowWithTooltip,
  });

  @override
  Widget build(BuildContext context) {
    // Create a map for easy lookup of feedback by Thai word
    final feedbackMap = {for (var fb in result.detailedFeedback) fb.word: fb};

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Breakdown',
            style: TextStyle(
              color: AppStyles.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          buildScoreRowWithTooltip(
            context: context,
            label: 'Accuracy',
            score: result.accuracyScore / 100.0,
            tooltip: 'How correctly you pronounced the word',
          ),
          buildScoreRowWithTooltip(
            context: context,
            label: 'Fluency',
            score: result.fluencyScore / 100.0,
            tooltip: 'How smooth and natural your pronunciation sounds',
          ),
          buildScoreRowWithTooltip(
            context: context,
            label: 'Completeness',
            score: result.completenessScore / 100.0,
            tooltip: 'How much of the word you pronounced',
          ),
          const SizedBox(height: 16),
          // Word analysis - use backend detailed feedback directly
          if (result.detailedFeedback.isNotEmpty) ...[
            Text('Word Accuracy',
              style: GoogleFonts.lato(
                color: Colors.cyan.shade200,
                fontWeight: FontWeight.bold,
                fontSize: 16
              ),
            ),
            const SizedBox(height: 8),
            ...result.detailedFeedback.map((feedback) {
              return _BackendWordAnalysisRow(
                feedback: feedback,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _AzurePronunciationTips extends StatelessWidget {
  final PronunciationAssessmentResponse result;
  final Vocabulary vocabulary;

  const _AzurePronunciationTips({
    required this.result,
    required this.vocabulary,
  });

  @override
  Widget build(BuildContext context) {
    final tipSections = _generateTipSections(result);
    
    if (tipSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.2),
            Colors.purple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Pronunciation Tips',
                style: TextStyle(
                  color: AppStyles.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tipSections.expand((section) => [
            Text(
              section['title']!,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...section['tips']!.map((tip) => Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.amber)),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: AppStyles.textColor.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
          ]),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateTipSections(PronunciationAssessmentResponse result) {
    List<Map<String, dynamic>> sections = [];

    // Section 1: Word-Specific Issues
    final wordIssues = <String>[];
    final characterGuidance = <String>[];
    final generalAdvice = <String>[];

    // Analyze each word for specific issues
    final problematicWords = result.detailedFeedback
        .where((feedback) => feedback.accuracyScore < 80 || feedback.errorType != 'None')
        .toList();

    for (final feedback in problematicWords.take(3)) { // Limit to 3 worst words
      final transliteration = feedback.transliteration.isNotEmpty 
          ? feedback.transliteration 
          : vocabulary.wordMapping
              .where((mapping) => mapping.thai == feedback.word)
              .map((mapping) => mapping.transliteration)
              .firstOrNull ?? vocabulary.transliteration;
      
      switch (feedback.errorType) {
        case 'Omission':
          wordIssues.add('You missed "${feedback.word}" ($transliteration) - make sure to pronounce every word');
          break;
        case 'Insertion':
          wordIssues.add('Extra sounds added near "${feedback.word}" ($transliteration) - stick to the written text');
          break;
        case 'Mispronunciation':
          if (feedback.accuracyScore < 40) {
            wordIssues.add('"${feedback.word}" ($transliteration) needs significant work - practice slowly and repeatedly');
          } else if (feedback.accuracyScore < 60) {
            wordIssues.add('"${feedback.word}" ($transliteration) needs improvement - focus on clear articulation');
          } else {
            wordIssues.add('"${feedback.word}" ($transliteration) is close - just needs fine-tuning');
          }
          break;
        default:
          if (feedback.accuracyScore < 80) {
            wordIssues.add('Practice "${feedback.word}" ($transliteration) more (${feedback.accuracyScore.toInt()}% accuracy)');
          }
          break;
      }

      // Add character-specific guidance for this word
      final wordCharacterTips = _getWordSpecificCharacterGuidance(feedback.word, transliteration, feedback.errorType);
      characterGuidance.addAll(wordCharacterTips);
    }

    // Section 2: Overall Performance Advice
    if (result.pronunciationScore < 60) {
      generalAdvice.add('Start by practicing each syllable separately');
      generalAdvice.add('Use a mirror to watch your mouth position');
      generalAdvice.add('Listen to Thai audio repeatedly for reference');
    } else if (result.pronunciationScore < 75) {
      generalAdvice.add('Focus on distinguishing similar consonants');
      generalAdvice.add('Pay attention to tone pronunciation');
      generalAdvice.add('Don\'t drop final consonants');
    } else if (result.pronunciationScore < 85) {
      generalAdvice.add('Work on vowel length (short vs long)');
      generalAdvice.add('Practice tone precision');
      generalAdvice.add('Focus on natural rhythm');
    } else if (result.pronunciationScore < 95) {
      generalAdvice.add('Fine-tune subtle tone variations');
      generalAdvice.add('Work on natural speech flow');
      generalAdvice.add('Practice for consistency');
    } else {
      generalAdvice.add('Excellent pronunciation! You sound nearly native');
      generalAdvice.add('Keep practicing to maintain this level');
      generalAdvice.add('Try challenging yourself with longer phrases');
    }

    // Organize tips by category into sections
    if (wordIssues.isNotEmpty) {
      sections.add({
        'title': 'Word Issues',
        'tips': wordIssues,
      });
    }

    if (characterGuidance.isNotEmpty) {
      sections.add({
        'title': 'Character Pronunciation',
        'tips': characterGuidance.take(4).toList(),
      });
    }

    if (generalAdvice.isNotEmpty) {
      sections.add({
        'title': 'General Advice',
        'tips': generalAdvice.take(3).toList(),
      });
    }

    return sections;
  }

  List<String> _getWordSpecificCharacterGuidance(String thaiWord, String transliteration, String errorType) {
    List<String> guidance = [];
    
    // Analyze each character in the Thai word
    for (int i = 0; i < thaiWord.length; i++) {
      final char = thaiWord[i];
      final tip = _getCharacterTip(char);
      if (tip.isNotEmpty) {
        guidance.add('In "$thaiWord" ($transliteration): $tip');
      }
    }
    
    // Add transliteration-based guidance for common sound patterns
    if (transliteration.contains('th')) {
      guidance.add('For "th" sounds in "$thaiWord" ($transliteration): Keep tongue tip touching upper teeth, breathe out gently');
    }
    if (transliteration.contains('ph')) {
      guidance.add('For "ph" sounds in "$thaiWord" ($transliteration): Like "p" + puff of air, not "f" sound');
    }
    if (transliteration.contains('ng')) {
      guidance.add('For "ng" sounds in "$thaiWord" ($transliteration): Like end of "sing", but can start syllables in Thai');
    }
    if (transliteration.contains('r')) {
      guidance.add('For "r" sounds in "$thaiWord" ($transliteration): Roll your tongue tip lightly');
    }
    
    return guidance.take(2).toList(); // Limit to 2 most relevant tips per word
  }

  String _getCharacterTip(String char) {
    // Comprehensive character-specific guidance based on web research
    final tips = {
      // Aspirated vs Unaspirated pairs
      'ก': 'Make a "g" sound without puffing air',
      'ค': 'Like "k" + puff of air',
      'ป': 'Like "b" without voice, no air puff',
      'พ': 'Like "p" + strong puff of air',
      'ต': 'Like "d" but unvoiced, tongue tip to teeth',
      'ท': 'Like "t" + puff of air, tongue tip to teeth',
      'บ': 'Like "b" but unvoiced',
      'ภ': 'Like "ph" with strong aspiration',
      
      // Difficult consonants
      'ร': 'Roll tongue tip lightly, like Spanish "rr" but shorter',
      'ล': 'Lateral "l" - tongue sides down, tip touches roof',
      'ง': 'Like "ng" in "sing" - can start Thai syllables',
      'ญ': 'Soft "ny" sound, tongue touches soft palate',
      'ว': 'Like "w" but lips closer together',
      'ย': 'Like "y" in "yes"',
      
      // Retroflex consonants
      'ฏ': 'Tongue tip curled back to touch roof of mouth',
      'ฐ': 'Like ฏ but with aspiration',
      'ฎ': 'Retroflex "d" - tongue tip curled back',
      'ฑ': 'Like ฎ but with aspiration',
      
      // Sibilants
      'ส': 'Regular "s" sound',
      'ศ': 'Like "s" but tongue higher',
      'ษ': 'Retroflex "s" - tongue tip curled back',
      
      // Tone marks
      '่': 'Low tone - like disappointed "oh"',
      '้': 'Falling tone - start high, drop down',
      '๊': 'High tone - like surprised "eh?"',
      '๋': 'Rising tone - like questioning "hmm?"',
      
      // Vowels with unique sounds
      'ึ': 'Like "eu" in French "peu" - rounded lips, high tongue',
      'ื': 'Like "ue" - similar to ึ but longer',
      'ำ': 'Like "am" - quick "a" + "m"',
      'เ': 'Like "ay" in "say"',
      'แ': 'Like "ae" in "cat" but longer',
      'โ': 'Like "oh" but pure, no glide',
      'ใ': 'Like "ai" in "Thai"',
      'ไ': 'Like "ai" in "Thai"',
      
      // Final consonants (often silent or changed)
      'ด': 'At word end: stop abruptly, no release',
      'ส': 'At word end: becomes "t" sound',
      'จ': 'At word end: becomes "t" sound',
      'ซ': 'At word end: becomes "t" sound',
    };
    
    return tips[char] ?? '';
  }

  void _addCharacterSpecificGuidance(List<String> tips, String thaiWord, String transliteration, String context) {
    // Character-specific pronunciation guidance based on research
    final characterTips = <String>[];

    // Analyze each character in the Thai word for specific pronunciation guidance
    final chars = thaiWord.split('');
    
    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      final guidance = _getCharacterPronunciationGuidance(char, context);
      if (guidance.isNotEmpty) {
        characterTips.add(guidance);
      }
    }

    // Add clustered consonant guidance
    if (thaiWord.contains(RegExp(r'[กขค][รลว]|[ปผพ][รลว]|[ตท][ร]'))) {
      characterTips.add('Consonant clusters: Both consonants contribute to the sound - don\'t drop either one');
    }

    // Add tone guidance based on word structure
    if (context == 'mispronunciation' && transliteration.isNotEmpty) {
      final toneGuidance = _getToneGuidance(thaiWord, transliteration);
      if (toneGuidance.isNotEmpty) {
        characterTips.add(toneGuidance);
      }
    }

    // Add up to 2 character-specific tips
    for (final tip in characterTips.take(2)) {
      tips.add(tip);
    }
  }

  String _getCharacterPronunciationGuidance(String char, String context) {
    // Comprehensive character guidance based on web research
    switch (char) {
      // Difficult consonants for English speakers
      case 'ร':
        return 'ร: Roll your tongue against the gum ridge behind your teeth - like Spanish "rr"';
      case 'ล':
        return 'ล: Touch tongue tip to gum ridge - different from ร (rolled R)';
      case 'จ':
        return 'จ: Unaspirated "ch" - like "j" in "John" but softer';
      case 'ช':
        return 'ช: Aspirated "ch" - with a puff of air, like "ch" in "church"';
      case 'ฉ':
        return 'ฉ: Softer aspirated "ch" - gentler than ช';
      case 'ง':
        return 'ง: "ng" sound - like "sing" but can start words in Thai';
      case 'ผ':
        return 'ผ: Soft aspirated "p" - gentler puff of air than พ';
      case 'พ':
        return 'พ: Strong aspirated "p" - like "p" in "pot" with air burst';
      case 'ป':
        return 'ป: Unaspirated "p" - like "p" in "spot" (no air puff)';
      case 'ท':
        return 'ท: Aspirated "t" - tongue against gum ridge with air';
      case 'ต':
        return 'ต: Unaspirated "t" - like "t" in "stop" (no air puff)';
      case 'ค':
        return 'ค: Aspirated "k" - like "k" in "kite" with air burst';
      case 'ก':
        return 'ก: Unaspirated "k" - like "g" in "go" but harder';
      
      // Tone marks
      case '่':
        return 'Low tone (่): Start slightly below normal pitch';
      case '้':
        return 'Falling tone (้): Start high, fall to low pitch';
      case '๊':
        return 'High tone (๊): Higher than normal pitch throughout';
      case '๋':
        return 'Rising tone (๋): Start low, rise above normal pitch';
        
      // Difficult vowels
      case 'ึ':
        return 'ึ: Unrounded central vowel - no English equivalent, practice with native audio';
      case 'ื':
        return 'ื: Long version of ึ - hold the unusual sound longer';
      case 'ำ':
        return 'ำ: Combined "am" sound - like "come" but with Thai "a"';
        
      // Final consonants (often dropped by learners)
      case 'บ':
      case 'ป':
      case 'พ':
      case 'ภ':
      case 'ฟ':
      case 'ผ':
        if (context == 'omission') {
          return 'Final consonant: Don\'t drop the final sound - unreleased but audible';
        }
        break;
        
      case 'ด':
      case 'ต':
      case 'ท':
      case 'ธ':
      case 'ฏ':
      case 'ฐ':
      case 'ฑ':
      case 'ฒ':
        if (context == 'omission') {
          return 'Final consonant: Stop airflow completely but don\'t release - like stopping mid-sound';
        }
        break;
        
      case 'ก':
      case 'ข':
      case 'ค':
      case 'ฆ':
        if (context == 'omission') {
          return 'Final consonant: Cut off airflow sharply - like a glottal stop';
        }
        break;
    }
    
    return '';
  }

  String _getToneGuidance(String thaiWord, String transliteration) {
    // Detect tone from transliteration marks
    if (transliteration.contains('่')) {
      return 'Low tone: Speak in a lower, flat pitch - like being bored';
    } else if (transliteration.contains('้')) {
      return 'Falling tone: Start high and drop - like "Oh no!"';
    } else if (transliteration.contains('๊')) {
      return 'High tone: Higher pitch throughout - like asking a question';
    } else if (transliteration.contains('๋')) {
      return 'Rising tone: Start low and rise - like "Really?"';
    } else {
      return 'Mid tone: Normal speaking pitch - neutral and relaxed';
    }
  }
}