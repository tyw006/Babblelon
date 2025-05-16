import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set camera viewfinder
    camera.viewport = FixedResolutionViewport(Vector2(360, 640));
    
    // Add background
    final background = RectangleComponent(
      size: Vector2(360, 640),
      paint: Paint()..color = const Color(0xFF3A3A3A),
    );
    add(background);
    
    // Add score text
    _scoreText = TextComponent(
      text: 'Score: $_score',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
      ),
      position: Vector2(20, 20),
    );
    add(_scoreText);
    
    // Initialize game components
    // Will be implemented in subsequent tasks
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (_isPaused || _isGameOver) return;
    
    // Game logic updates will be added here
  }
  
  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    
    // Handle player input
  }
  
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.escape)) {
        togglePause();
        return KeyEventResult.handled;
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
    
    // Reset game components
    // Will be implemented in subsequent tasks
  }
  
  void increaseScore(int points) {
    _score += points;
    _scoreText.text = 'Score: $_score';
  }
} 