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
import '../models/npc_data.dart'; // Import the new NPC data model
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
  
  // --- Refactored NPC Management ---
  final Map<String, SpriteComponent> _npcs = {};
  final Map<String, SpeechBubbleComponent> _speechBubbles = {};
  String? _activeNpcId; // Tracks which NPC is currently interactable
  String? activeNpcIdForOverlay; // Used to pass the ID to the overlay
  // --- End Refactored NPC Management ---

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

    // --- Add all NPCs from the data map ---
    await _addNpcs();
    // --- End NPC addition ---

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
    if (!ref.read(gameStateProvider).isPaused && overlays.activeOverlays.isEmpty) {
      String? closestNpcId;
      double minDistance = 150.0; // Interaction distance

      for (var entry in _npcs.entries) {
        final npcId = entry.key;
        final npcComponent = entry.value;

        if (npcComponent.isMounted) {
          final double distance = (player.position - npcComponent.position).length;
          if (distance < minDistance) {
            minDistance = distance;
            closestNpcId = npcId;
          }
        }
      }

      // If a new NPC is the closest/active one
      if (closestNpcId != _activeNpcId) {
        // Hide the bubble for the previously active NPC
        if (_activeNpcId != null && _speechBubbles[_activeNpcId]!.isMounted) {
          _speechBubbles[_activeNpcId]!.removeFromParent();
        }

        // Show the bubble for the new active NPC, but only if they haven't given their special item
        if (closestNpcId != null) {
          final hasReceivedSpecialItem = ref.read(specialItemReceivedProvider(closestNpcId));
          if (!hasReceivedSpecialItem) {
            final bubble = _speechBubbles[closestNpcId]!;
            if (!bubble.isMounted) {
              gameWorld.add(bubble);
            }
          }
        }
        _activeNpcId = closestNpcId;
      }

      // Keep the active bubble positioned correctly
      if (_activeNpcId != null) {
        final npcComponent = _npcs[_activeNpcId]!;
        final bubble = _speechBubbles[_activeNpcId]!;
        final npcData = npcDataMap[_activeNpcId]!;
        bubble.position = npcComponent.position - Vector2(0, npcComponent.size.y) + npcData.speechBubbleOffset;
      }
    }
    // --- End NPC speech bubble sprite logic ---
  }
  
  void _startDialogue(String npcId) {
    if (_activeNpcId == npcId) {
      pauseGame(ref);
      activeNpcIdForOverlay = npcId; // Set the ID for the overlay builder
      overlays.add('dialogue');
    }
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