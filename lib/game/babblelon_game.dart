import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flame/camera.dart'; // Ensuring this is uncommented and present
import 'package:flame/experimental.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/player_component.dart';

class BabblelonGame extends FlameGame with 
    TapDetector, 
    KeyboardEvents, 
    HasCollisionDetection {
  
  // Game state variables
  bool _isGameOver = false;
  bool _isPaused = false;
  int _score = 0;
  
  // UI Components
  late TextComponent _scoreText;
  
  // World and Camera
  late final World gameWorld;
  late final CameraComponent cameraComponent;

  // Game Components (will be added to the world)
  late PlayerComponent player; 
  late SpriteComponent background; 
  double backgroundWidth = 0.0;
  double backgroundHeight = 0.0;
  Vector2 gameResolution = Vector2.zero();
  
  @override
  Future<void> onLoad() async {
    await super.onLoad(); // Call super.onLoad first
    
    // Set gameResolution for iPhone Plus portrait
    gameResolution = Vector2(414, 896); 
    // The FlameGame's camera is the one with the viewport
    camera.viewport = FixedResolutionViewport(resolution: gameResolution); // Correct usage with named parameter
    
    // Initialize World and CameraComponent
    gameWorld = World();
    cameraComponent = CameraComponent(world: gameWorld);
    // Ensure the camera component's viewfinder starts at the top-left of what it's viewing.
    cameraComponent.viewfinder.anchor = Anchor.topLeft;

    // Add the CameraComponent and the World to the game
    // The order can matter for some setups, often CameraComponent first.
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
    gameWorld.add(background..priority = -1); // Add background to the world
    
    _scoreText = TextComponent(
      text: 'Score: $_score',
      position: Vector2(40, 40), 
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48, 
          fontFamily: 'Arial',
        ),
      ),
    );
    // UI elements like score are usually added to the camera's viewport directly
    // or to the FlameGame if they should be fixed on screen, not in the world.
    // For simplicity, let's add it to the FlameGame's fixed children for now.
    add(_scoreText); 
    
    player = PlayerComponent();
    player.backgroundWidth = backgroundWidth; // Pass background width to player
    gameWorld.add(player); // Add player to the world

    // Use built-in camera follow for smooth horizontal tracking
    cameraComponent.follow(player, horizontalOnly: true);

    final worldBounds = Rectangle.fromLTWH(
      0, 
      0, 
      bgWidth, 
      bgHeight,
    );
    cameraComponent.setBounds(worldBounds); // Set bounds on the CameraComponent
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (_isPaused || _isGameOver) return;

    // Camera follow logic for Anchor.bottomLeft
    if (player.isMounted) {
      // Center the camera on the player's center, but clamp to world bounds
      double targetX = player.position.x + player.size.x / 2 - gameResolution.x / 2;
      targetX = targetX.clamp(0.0, backgroundWidth - gameResolution.x);
      cameraComponent.viewfinder.position.x = targetX;
    }
  }
  
  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    
    if (_isPaused) {
      resumeGame();
    } else if (_isGameOver) {
      // Potentially restart game or navigate to main menu
    } else {
      // Regular game tap logic
    }
  }
  
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isKeyDown = event is KeyDownEvent;
    final isKeyUp = event is KeyUpEvent;

    if (keysPressed.contains(LogicalKeyboardKey.keyP) && isKeyDown) {
      if (_isPaused) {
        resumeGame();
      } else {
        pauseGame();
      }
      return KeyEventResult.handled;
    }

    if (player.isMounted) { 
      if (isKeyDown) {
        if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
          player.isMovingRight = true;
          return KeyEventResult.handled;
        } else if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
          player.isMovingLeft = true;
          return KeyEventResult.handled;
        }
      } else if (isKeyUp) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          player.isMovingRight = false;
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          player.isMovingLeft = false;
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }
  
  void togglePause() {
    _isPaused = !_isPaused;
    if (_isPaused) {
      overlays.add('pause_menu');
    } else {
      overlays.remove('pause_menu');
    }
  }
  
  void gameOver() {
    _isGameOver = true;
    overlays.add('game_over');
  }
  
  void reset() {
    _isGameOver = false;
    _score = 0;
    _scoreText.text = 'Score: $_score';
    overlays.remove('game_over');
    
  }
  
  void increaseScore(int points) {
    _score += points;
    _scoreText.text = 'Score: $_score';
  }

  void pauseGame() {
    pauseEngine();
    _isPaused = true;
    overlays.add('pause_menu');
  }

  void resumeGame() {
    resumeEngine();
    _isPaused = false;
    overlays.remove('pause_menu');
  }
} 