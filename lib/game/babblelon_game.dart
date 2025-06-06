import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flame/camera.dart'; // Ensuring this is uncommented and present
import 'package:flame/experimental.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/player_component.dart';
import 'components/speech_bubble_component.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../providers/game_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BabblelonGame extends FlameGame with
    RiverpodGameMixin,
    TapDetector,
    KeyboardEvents,
    HasCollisionDetection {
  
  // UI Components
  
  // World and Camera
  late final World gameWorld;
  late final CameraComponent cameraComponent;

  // Game Components (will be added to the world)
  late PlayerComponent player; 
  late SpriteComponent background; 
  double backgroundWidth = 0.0;
  double backgroundHeight = 0.0;
  Vector2 gameResolution = Vector2.zero();
  
  // NPC interaction state
  String? currentInteractingNpcId;
  String? currentInteractingNpcName;
  
  // Remove the TextComponent speech bubble
  SpeechBubbleComponent? _npcSpeechBubbleSprite;
  late SpriteComponent npc;
  bool _npcSpeechBubbleShown = false;
  bool _canInteractWithNpc = false;

  void toggleMenu(BuildContext context, WidgetRef ref) {
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
    
    player = PlayerComponent();
    player.backgroundWidth = backgroundWidth; // Pass background width to player
    gameWorld.add(player); // Add player to the world

    // --- Add stationary NPC (noodle vendor) ---
    final npcImage = await images.load('npcs/sprite_dimsum_vendor_female.png');
    final npcSprite = Sprite(npcImage);
    // Use same scale factor as PlayerComponent
    const double npcScaleFactor = 0.25;
    final npcSize = npcSprite.originalSize * npcScaleFactor;
    // Place NPC at a visible position (adjust as needed)
    final npcPosition = Vector2(900, backgroundHeight * 0.93);
    npc = SpriteComponent(
      sprite: npcSprite,
      size: npcSize,
      position: npcPosition,
      anchor: Anchor.bottomCenter,
      priority: -1, // Above background, same as player
    );
    // This is the stationary noodle vendor NPC
    gameWorld.add(npc);
    // --- End NPC addition ---

    // --- Add speech bubble sprite (hidden by default) ---
    final bubbleImage = await images.load('ui/speech_bubble_interact.png');
    final bubbleSprite = Sprite(bubbleImage);
    final bubbleWidth = npcSize.x;
    final bubbleHeight = bubbleSprite.srcSize.y * (bubbleWidth / bubbleSprite.srcSize.x);
    _npcSpeechBubbleSprite = SpeechBubbleComponent(
      sprite: bubbleSprite,
      size: Vector2(bubbleWidth, bubbleHeight),
      anchor: Anchor.bottomLeft,
      position: npcPosition - Vector2(0, npcSize.y),
      priority: 1,
      onTap: () { // Show dialogue overlay when tapped
        if (_canInteractWithNpc) {
          pauseGame(ref);
          currentInteractingNpcId = "amara"; // Set NPC ID
          currentInteractingNpcName = "Amara"; // Set NPC Name
          overlays.add('dialogue');
        }
      },
    );
    // Do not add to world yet
    // --- End speech bubble sprite addition ---

    final worldBounds = Rectangle.fromLTWH(
      0, 
      0, 
      bgWidth, 
      bgHeight,
    );
    cameraComponent.setBounds(worldBounds); // Set bounds on the CameraComponent

    // Start camera at the left edge
    cameraComponent.viewfinder.position = Vector2(0, 0);

    // Initialize and play background music
    FlameAudio.bgm.initialize();
    // FlameAudio.bgm.play('bg/Chinatown in Summer.mp3', volume: 0.5);
    // Check music enabled state before playing
    final initialMusicEnabled = ref.read(gameStateProvider).musicEnabled;
    if (initialMusicEnabled) {
      FlameAudio.bgm.play('bg/Chinatown in Summer.mp3', volume: 0.5);
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Camera deadzone logic (horizontal only)
    if (player.isMounted) {
      const double deadzoneWidth = 20.0; // Deadzone width in pixels
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
      // Otherwise, camera stays put (player is inside deadzone)
    }

    // --- NPC speech bubble sprite logic ---
    if (_npcSpeechBubbleSprite != null && npc.isMounted && player.isMounted) {
      final double distance = (player.position - npc.position).length;
      if (distance < 150) {
        if (!_npcSpeechBubbleShown) {
          gameWorld.add(_npcSpeechBubbleSprite!);
          _npcSpeechBubbleShown = true;
        }
        // Keep bubble above NPC, bottom left at top center of NPC
        _npcSpeechBubbleSprite!.position = npc.position - Vector2(110, npc.size.y - 40);
        _canInteractWithNpc = true;
      } else {
        if (_npcSpeechBubbleShown) {
          _npcSpeechBubbleSprite!.removeFromParent();
          _npcSpeechBubbleShown = false;
        }
        _canInteractWithNpc = false;
      }
    }
    // --- End NPC speech bubble sprite logic ---
  }
  
  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    // Only allow movement if not paused
    final isPaused = ref.read(gameStateProvider).isPaused;
    if (isPaused) return;
    final tapX = info.eventPosition.global.x;
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
  void onTapUp(TapUpInfo info) {
    super.onTapUp(info);
    // Stop movement when touch is released
    player.isMovingLeft = false;
    player.isMovingRight = false;
  }

  @override
  void onTapCancel() {
    super.onTapCancel();
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

  void pauseMusic(WidgetRef ref) {
    FlameAudio.bgm.stop();
    ref.read(gameStateProvider.notifier).setBgmPlaying(false);
  }

  void resumeMusic(WidgetRef ref) {
    FlameAudio.bgm.play('bg/Chinatown in Summer.mp3', volume: 0.5);
    ref.read(gameStateProvider.notifier).setBgmPlaying(true);
  }
} 