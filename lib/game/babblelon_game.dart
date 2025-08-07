import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flame/camera.dart'; // Ensuring this is uncommented and present
import 'package:flame/experimental.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/player_component.dart';
import 'components/capybara_companion.dart';
import 'components/speech_bubble_component.dart';
import 'components/portal_component.dart'; // Import the new portal component
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../models/boss_data.dart';
import '../models/npc_data.dart'; // Import the new NPC data model
import '../providers/game_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tutorial_service.dart';

class BabblelonGame extends FlameGame with
    RiverpodGameMixin,
    TapCallbacks,
    KeyboardEvents,
    HasCollisionDetection,
    WidgetsBindingObserver {
  
  // UI Components
  
  // World and Camera
  late final World gameWorld;
  late final CameraComponent cameraComponent;

  // Game Components (will be added to the world)
  late PlayerComponent player; 
  late CapybaraCompanion capybara;
  late SpriteComponent background; 
  double backgroundWidth = 0.0;
  double backgroundHeight = 0.0;
  Vector2 gameResolution = Vector2.zero();
  
  // Portal proximity tracking
  PortalComponent? _portal;

  // --- Refactored NPC Management ---
  final Map<String, SpriteComponent> _npcs = {};
  final Map<String, SpeechBubbleComponent> _speechBubbles = {};
  String? _activeNpcId; // Tracks which NPC is currently interactable
  String? activeNpcIdForOverlay; // Used to pass the ID to the overlay
  // --- End Refactored NPC Management ---

  just_audio.AudioPlayer? _portalSoundPlayer;
  
  // ML Kit for character tracing
  mlkit.DigitalInkRecognizerModelManager? _modelManager;
  bool _mlKitModelReady = false;

  void toggleMenu(BuildContext context, WidgetRef ref) {
    final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
    if (soundEffectsEnabled) {
      FlameAudio.play('soundeffects/soundeffect_button.mp3');
    }
    final isPaused = ref.read(gameStateProvider).isPaused;
    if (overlays.isActive('main_menu')) {
      overlays.remove('main_menu');
      if (!overlays.isActive('dialogue') && isPaused) {
        resumeGame(ref);
      }
    } else {
      if (!isPaused) {
        pauseGame(ref);
      }
      overlays.add('main_menu');
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad(); // Call super.onLoad first
    
    // Initialize app lifecycle manager
    ref.read(appLifecycleManagerProvider);
    
    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Set gameResolution for iPhone Plus portrait
    gameResolution = Vector2(414, 896); 
    // camera.viewport = FixedResolutionViewport(resolution: gameResolution); // Remove this line
    
    // Initialize World and CameraComponent
    gameWorld = World();
    cameraComponent = CameraComponent(world: gameWorld);
    cameraComponent.viewport = FixedResolutionViewport(resolution: gameResolution); // Set viewport on custom camera
    cameraComponent.viewfinder.anchor = Anchor.topLeft;
    addAll([cameraComponent, gameWorld]);

    final backgroundImageAsset = await images.load('background/yaowarat_bg2.png');
    final backgroundSprite = Sprite(backgroundImageAsset);
    
    final double imgAspectRatio = backgroundSprite.srcSize.x / backgroundSprite.srcSize.y;
    final double bgHeight = gameResolution.y; // Fill the screen vertically
    final double bgWidth = bgHeight * imgAspectRatio; // Maintain aspect ratio
    backgroundWidth = bgWidth;
    backgroundHeight = bgHeight;

    background = SpriteComponent(
      sprite: backgroundSprite,
      size: Vector2(bgWidth, bgHeight),
      anchor: Anchor.bottomLeft, 
      position: Vector2(0, gameResolution.y), 
    );
    gameWorld.add(background..priority = -2); // Add background to the world
    
    // Get selected character from SharedPreferences or default to 'male'
    final prefs = await SharedPreferences.getInstance();
    final selectedCharacter = prefs.getString('selected_character') ?? 'male';
    
    player = PlayerComponent(character: selectedCharacter);
    player.backgroundWidth = backgroundWidth; // Pass background width to player
    gameWorld.add(player); // Add player to the world

    // Add capybara companion after player is created
    capybara = CapybaraCompanion(player: player);
    capybara.backgroundWidth = backgroundWidth;
    gameWorld.add(capybara);

    // --- Add all NPCs from the data map ---
    await _addNpcs();
    // --- End NPC addition ---

    // Define the boss for this level
    const tuktukBoss = BossData(
      name: "Tuk-Tuk Monster",
      spritePath: 'assets/images/bosses/tuktuk/sprite_tuktukmonster.png',
      maxHealth: 500,
      vocabularyPath: 'assets/data/beginner_food_vocabulary.json',
      backgroundPath: 'assets/images/background/bossfight_tuktuk_bg.png',
      languageName: 'Thai',
      languageFlag: '🇹🇭',
    );

    // --- Portal Setup ---
    // 🎯 CONFIGURE PORTAL HERE: Set which boss, size, and position
    // The PortalComponent handles the visual implementation details.
    _portal = PortalComponent(
      bossData: tuktukBoss,                    // Which boss this portal leads to
      desiredHeight: 300.0,                   // How tall the portal should be (width auto-calculated to maintain aspect ratio)
      offsetFromBottomRight: Vector2(40, 0.02), // Distance from screen edge: (X: pixels from right, Y: % from bottom)
    );
    gameWorld.add(_portal!);

    final worldBounds = Rectangle.fromLTWH(
      0, 
      0, 
      bgWidth, 
      bgHeight,
    );
    cameraComponent.setBounds(worldBounds); // Set bounds on the CameraComponent

    // Start camera at the left edge
    cameraComponent.viewfinder.position = Vector2(0, 0);

    // Initialize background music
    FlameAudio.bgm.initialize();
    
    // Switch to game screen and start appropriate music
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Give settings more time to load from SharedPreferences
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (isMounted) {
        // Use the new screen-based music system
        ref.read(gameStateProvider.notifier).switchScreen(ScreenType.game);
        debugPrint('🎵 BabblelonGame: Switched to game screen and started appropriate music');
      }
    });

    // --- Pre-load portal sound ---
    _portalSoundPlayer = just_audio.AudioPlayer();
    await _portalSoundPlayer?.setAsset('assets/audio/bg/soundeffect_portal_v2.mp3');
    await _portalSoundPlayer?.setLoopMode(just_audio.LoopMode.one);
    // --- End pre-load ---
    
    // Music state changes will be handled by the GameStateProvider directly
    
    // --- Pre-load ML Kit Thai model for character tracing ---
    try {
      await _preloadMLKitThaiModel();
    } catch (e) {
      print("Failed to preload ML Kit Thai model: $e");
    }
    // --- End ML Kit preload ---
    
    // Mark game loading as completed
    ref.read(gameLoadingCompletedProvider.notifier).state = true;
    
    // Show game loading tutorial if this is the first time entering a game
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
      if (!tutorialProgressNotifier.isStepCompleted('game_loading_intro')) {
        final context = buildContext;
        if (context != null) {
          final tutorialManager = TutorialManager(
            context: context,
            ref: ref,
          );
          
          // Show the game loading/navigation tutorial
          await tutorialManager.startTutorial(TutorialTrigger.firstGameEntry);
        }
      }
    });
  }
  
  Future<void> _addNpcs() async {
    final bubbleImage = await images.load('ui/speech_bubble_interact.png');
    final bubbleSprite = Sprite(bubbleImage);
    const double npcScaleFactor = 0.25;

    // Manually define positions for now
    // You can adjust the X and Y coordinates here to move the NPCs.
    // X is the horizontal position, Y is the vertical position.
    // Smaller X moves the NPC to the left.
    final npcPositions = {
      'amara': Vector2(500, backgroundHeight * 0.93), // Was 900
      'somchai': Vector2(1000, backgroundHeight * 0.93), // Was 1400
    };

    for (var entry in npcDataMap.entries) {
      final npcData = entry.value;
      final npcId = entry.key;

      final npcImage = await images.load(npcData.spritePath);
      final npcSprite = Sprite(npcImage);
      final npcSize = npcSprite.originalSize * npcScaleFactor;
      final npcPosition = npcPositions[npcId] ?? Vector2.zero(); // Fallback position

      final npcComponent = SpriteComponent(
        sprite: npcSprite,
        size: npcSize,
        position: npcPosition,
        anchor: Anchor.bottomCenter,
        priority: -1,
      );

      _npcs[npcId] = npcComponent;
      gameWorld.add(npcComponent);

      final bubbleWidth = npcSize.x;
      final bubbleHeight = bubbleSprite.srcSize.y * (bubbleWidth / bubbleSprite.srcSize.x);
      final speechBubble = SpeechBubbleComponent(
        sprite: bubbleSprite,
        size: Vector2(bubbleWidth, bubbleHeight),
        anchor: Anchor.bottomCenter,
        position: npcPosition - Vector2(0, npcSize.y) + npcData.speechBubbleOffset,
        priority: 1,
        onTap: () => _startDialogue(npcId),
      );

      _speechBubbles[npcId] = speechBubble;
    }
  }
  
  // Performance optimization: Cache previous positions to avoid unnecessary calculations
  Vector2? _lastPlayerPosition;
  double _lastPortalDistance = double.infinity;
  double _updateAccumulator = 0.0;
  static const double _updateInterval = 1.0 / 30.0; // Reduce to 30fps for proximity checks

  @override
  void update(double dt) {
    super.update(dt);

    // Performance optimization: Only update camera when player actually moves
    if (player.isMounted && (_lastPlayerPosition == null || _lastPlayerPosition != player.position)) {
      _updateCameraPosition();
      _lastPlayerPosition = player.position.clone();
    }

    // Performance optimization: Throttle proximity checks to 30fps instead of 60fps
    _updateAccumulator += dt;
    if (_updateAccumulator >= _updateInterval) {
      _updateNpcProximity();
      _updatePortalProximity();
      _updateAccumulator = 0.0;
    }
  }

  void _updateCameraPosition() {
    const double deadzoneWidth = 20.0;
    double cameraLeft = cameraComponent.viewfinder.position.x;
    double cameraRight = cameraLeft + gameResolution.x;
    double playerCenter = player.position.x;

    double deadzoneLeft = cameraLeft + (gameResolution.x - deadzoneWidth) / 2;
    double deadzoneRight = cameraRight - (gameResolution.x - deadzoneWidth) / 2;

    if (playerCenter < deadzoneLeft) {
      double newCameraX = (playerCenter - (gameResolution.x - deadzoneWidth) / 2)
        .clamp(0.0, backgroundWidth - gameResolution.x);
      cameraComponent.viewfinder.position = Vector2(newCameraX, cameraComponent.viewfinder.position.y);
    } else if (playerCenter > deadzoneRight) {
      double newCameraX = (playerCenter + (gameResolution.x - deadzoneWidth) / 2 - gameResolution.x)
        .clamp(0.0, backgroundWidth - gameResolution.x);
      cameraComponent.viewfinder.position = Vector2(newCameraX, cameraComponent.viewfinder.position.y);
    }
  }

  void _updateNpcProximity() {
    if (ref.read(gameStateProvider).isPaused || overlays.activeOverlays.isNotEmpty) {
      return;
    }

    String? closestNpcId;
    double minDistance = 150.0;

    // Performance optimization: Early exit if no NPCs are mounted
    final mountedNpcs = _npcs.entries.where((entry) => entry.value.isMounted);
    if (mountedNpcs.isEmpty) return;

    for (var entry in mountedNpcs) {
      final npcId = entry.key;
      final npcComponent = entry.value;

      // Performance optimization: Use squared distance to avoid sqrt operation
      final distanceSquared = (player.position - npcComponent.position).length2;
      final minDistanceSquared = minDistance * minDistance;
      
      if (distanceSquared < minDistanceSquared) {
        final distance = math.sqrt(distanceSquared); // Only calculate sqrt when needed
        if (distance < minDistance) {
          minDistance = distance;
          closestNpcId = npcId;
        }
      }
    }

    // Only update UI if the closest NPC actually changed
    if (closestNpcId != _activeNpcId) {
      _updateActiveSpeechBubble(closestNpcId);
      _activeNpcId = closestNpcId;
    }

    // Update bubble position only if there's an active NPC
    if (_activeNpcId != null) {
      _updateSpeechBubblePosition(_activeNpcId!);
    }
  }

  void _updateActiveSpeechBubble(String? newActiveNpcId) {
    // Hide previous bubble
    if (_activeNpcId != null && _speechBubbles[_activeNpcId]!.isMounted) {
      _speechBubbles[_activeNpcId]!.removeFromParent();
    }

    // Show new bubble
    if (newActiveNpcId != null) {
      // Show first NPC interaction tutorial if this is the first time approaching any NPC
      // Only show if game has finished loading to prevent blocking asset loading
      final gameLoadingCompleted = ref.read(gameLoadingCompletedProvider);
      if (gameLoadingCompleted) {
        final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
        if (!tutorialProgressNotifier.isStepCompleted('first_npc_interaction')) {
          final context = buildContext;
          if (context != null) {
            final tutorialManager = TutorialManager(
              context: context,
              ref: ref,
            );
            
            // Show first NPC approach tutorial
            tutorialManager.startTutorial(TutorialTrigger.firstNpcApproach);
          }
        }
      }
      
      final hasReceivedSpecialItem = ref.read(specialItemReceivedProvider(newActiveNpcId));
      if (!hasReceivedSpecialItem) {
        final bubble = _speechBubbles[newActiveNpcId]!;
        if (!bubble.isMounted) {
          gameWorld.add(bubble);
        }
      }
    }
  }

  void _updateSpeechBubblePosition(String npcId) {
    final npcComponent = _npcs[npcId]!;
    final bubble = _speechBubbles[npcId]!;
    final npcData = npcDataMap[npcId]!;
    bubble.position = npcComponent.position - Vector2(0, npcComponent.size.y) + npcData.speechBubbleOffset;
  }

  void _updatePortalProximity() {
    if (_portal == null || !player.isMounted || !_portal!.isMounted) return;

    final isPaused = ref.read(gameStateProvider).isPaused;
    final isOverlayActive = overlays.activeOverlays.isNotEmpty;
    
    if (isPaused || isOverlayActive) {
      if (_portalSoundPlayer?.playing == true) {
        _portalSoundPlayer?.pause();
      }
      return;
    }

    final distance = player.position.distanceTo(_portal!.position);
    const maxDistance = 600.0;
    const tutorialDistance = 400.0; // Trigger tutorial when closer than this
    
    // Show boss approach tutorial when player gets near portal for the first time
    // Only show if game has finished loading to prevent blocking asset loading
    bool shouldTriggerTutorial = false;
    if (distance < tutorialDistance && _lastPortalDistance >= tutorialDistance) {
      final gameLoadingCompleted = ref.read(gameLoadingCompletedProvider);
      if (gameLoadingCompleted) {
        final tutorialProgressNotifier = ref.read(tutorialProgressProvider.notifier);
        // Show portal approach tutorial if never shown
        if (!tutorialProgressNotifier.isStepCompleted('portal_approach')) {
          shouldTriggerTutorial = true;
        }
      }
    }
    
    // Trigger tutorial AFTER updating distance but before audio logic
    if (shouldTriggerTutorial) {
      final context = buildContext;
      if (context != null) {
        final tutorialManager = TutorialManager(
          context: context,
          ref: ref,
        );
        tutorialManager.startTutorial(TutorialTrigger.bossPortal);
        debugPrint('🎓 BabblelonGame: Triggered boss portal tutorial');
      }
    }

    // Performance optimization: Only update audio if distance changed significantly
    // Use the previous distance value for comparison, not the already-updated one
    final previousDistance = _lastPortalDistance;
    if ((distance - previousDistance).abs() > 10.0) {
      if (distance < maxDistance) {
        if (_portalSoundPlayer?.playing == false) {
          _portalSoundPlayer?.play();
        }
        final volume = (1.0 - (distance / maxDistance)).clamp(0.0, 1.0);
        _portalSoundPlayer?.setVolume(volume);
      } else {
        if (_portalSoundPlayer?.playing == true) {
          _portalSoundPlayer?.pause();
        }
      }
    }
    
    // Update the last distance at the very end for next frame comparison
    _lastPortalDistance = distance;
  }
  
  void _startDialogue(String npcId) {
    if (_activeNpcId == npcId) {
      pauseGame(ref);
      activeNpcIdForOverlay = npcId; // Set the ID for the overlay builder
      overlays.add('dialogue');
    }
  }
  
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (event.handled) {
      return;
    }
    // Only allow movement if not paused
    final isPaused = ref.read(gameStateProvider).isPaused;
    if (isPaused) return;
    final tapX = event.canvasPosition.x;
    final screenMid = gameResolution.x / 2;
    if (tapX > screenMid) {
      player.isMovingRight = true;
      player.isMovingLeft = false;
    } else {
      player.isMovingLeft = true;
      player.isMovingRight = false;
    }
  }
  
  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (event.handled) {
      return;
    }
    // Stop movement when touch is released
    player.isMovingLeft = false;
    player.isMovingRight = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    if (event.handled) {
      return;
    }
    // Stop movement if touch is cancelled
    player.isMovingLeft = false;
    player.isMovingRight = false;
  }
  
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isPaused = ref.read(gameStateProvider).isPaused;
    if (isPaused) return KeyEventResult.handled;

    final isLeftKeyPressed = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
                             keysPressed.contains(LogicalKeyboardKey.keyA);
    final isRightKeyPressed = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
                              keysPressed.contains(LogicalKeyboardKey.keyD);

    if (isLeftKeyPressed) {
      player.isMovingLeft = true;
      player.isMovingRight = false;
    } else if (isRightKeyPressed) {
      player.isMovingRight = true;
      player.isMovingLeft = false;
    } else {
      player.isMovingLeft = false;
      player.isMovingRight = false;
    }
    return KeyEventResult.handled;
  }
  
  void gameOver() {
    overlays.add('game_over');
    FlameAudio.bgm.stop();
  }
  
  void reset() {
    overlays.remove('game_over');
  }

  void pauseGame(WidgetRef ref) {
    if (ref.read(gameStateProvider).isPaused) return;
    ref.read(gameStateProvider.notifier).pauseGame();
    // Store BGM playing state before pausing
    if (FlameAudio.bgm.isPlaying) {
        ref.read(gameStateProvider.notifier).setBgmPlaying(true);
        FlameAudio.bgm.pause();
    } else {
        ref.read(gameStateProvider.notifier).setBgmPlaying(false);
    }
  }

  void resumeGame(WidgetRef ref) {
    if (!ref.read(gameStateProvider).isPaused) return;
    if (overlays.isActive('dialogue')) return;

    ref.read(gameStateProvider.notifier).resumeGame();
    // Resume BGM only if it was playing and music is enabled
    final gameState = ref.read(gameStateProvider);
    if (gameState.musicEnabled && gameState.bgmIsPlaying) {
        FlameAudio.bgm.resume();
    }
  }

  // Unified method to handle music state changes from GameStateProvider
  void handleMusicStateChange(bool musicEnabled, bool shouldBePlaying) {
    if (musicEnabled && shouldBePlaying) {
      // Start or resume music
      if (!FlameAudio.bgm.isPlaying) {
        FlameAudio.bgm.play('bg/background_yaowarat.wav', volume: 0.5);
      }
    } else {
      // Stop or pause music
      if (FlameAudio.bgm.isPlaying) {
        FlameAudio.bgm.pause();
      }
    }
  }

  Future<void> _preloadMLKitThaiModel() async {
    try {
      _modelManager = mlkit.DigitalInkRecognizerModelManager();
      const String thaiModelIdentifier = 'th';
      final bool isDownloaded = await _modelManager!.isModelDownloaded(thaiModelIdentifier);
      
      if (!isDownloaded) {
        print("Downloading Thai ML Kit model for character tracing...");
        final bool success = await _modelManager!.downloadModel(thaiModelIdentifier);
        _mlKitModelReady = success;
        print("Thai model download result: $success");
      } else {
        _mlKitModelReady = true;
        print("Thai ML Kit model already available");
      }
    } catch (e) {
      print("Error initializing ML Kit Thai model: $e");
      _mlKitModelReady = false;
    }
  }
  
  bool get isMLKitModelReady => _mlKitModelReady;

  void hideSpeechBubbleFor(String npcId) {
    if (_speechBubbles.containsKey(npcId)) {
      final bubble = _speechBubbles[npcId]!;
      if (bubble.isMounted) {
        bubble.removeFromParent();
      }
    }
    // If this was the active NPC, clear it so the bubble doesn't reappear
    // until the player moves to a different NPC.
    if (_activeNpcId == npcId) {
      _activeNpcId = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appLifecycleManager = ref.read(appLifecycleManagerProvider.notifier);
    
    switch (state) {
      case AppLifecycleState.resumed:
        appLifecycleManager.appResumed();
        break;
      case AppLifecycleState.paused:
        appLifecycleManager.appPaused();
        break;
      case AppLifecycleState.detached:
        appLifecycleManager.appClosed();
        break;
      case AppLifecycleState.inactive:
        appLifecycleManager.appInactive();
        break;
      case AppLifecycleState.hidden:
        appLifecycleManager.appHidden();
        break;
    }
  }

  @override
  void onRemove() {
    WidgetsBinding.instance.removeObserver(this);
    FlameAudio.bgm.stop();
    _portalSoundPlayer?.dispose();
    _portalSoundPlayer = null;
    super.onRemove();
  }
} 