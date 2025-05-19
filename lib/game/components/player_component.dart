import 'dart:math'; // For max function
import 'package:flame/components.dart';
import '../babblelon_game.dart'; // Adjust if your game class file is named differently or located elsewhere

class PlayerComponent extends SpriteComponent with HasGameRef<BabblelonGame> {
  final double speed = 250.0; // Slightly increased speed
  bool isMovingRight = false;
  bool isMovingLeft = false;  // Flag for moving left
  bool _isFacingRight = false; // Sprite now defaults to facing LEFT

  double backgroundWidth = 0.0; // <-- Add this field

  PlayerComponent(){
    // Size and anchor will be set in onLoad
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final playerImage = await game.images.load('player/sprite_male_tourist.png');
    sprite = Sprite(playerImage);

    const double scaleFactor = 0.20; // Slightly smaller scale for 1080p, adjust as needed
    size = sprite!.originalSize * scaleFactor;
    anchor = Anchor.bottomCenter;

    // Start so the left edge is at world X=0
    double playerX = size.x / 2;
    double playerY = (game.backgroundHeight > 0) ? game.backgroundHeight : game.size.y;
    position = Vector2(playerX, playerY);

    // Initially face left if that's the default sprite direction.
    // If sprite faces right by default, set _isFacingRight = true and call _ensureCorrectFacing(false) if needed.
    // Assuming sprite sheet is drawn facing left or we ensure it faces left initially.
    if (_isFacingRight) { // If default assumption was sprite faces right, flip to left
        flipHorizontally();
        _isFacingRight = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    double newX = position.x;
    if (isMovingRight) {
      newX += speed * dt; 
      _ensureCorrectFacing(true);
    } else if (isMovingLeft) {
      newX -= speed * dt; 
      _ensureCorrectFacing(false);
    }

    // Clamp: left bound size.x/2, right bound backgroundWidth - size.x/2
    final double minX = size.x / 2;
    final double maxX = (backgroundWidth > 0.0 ? backgroundWidth : game.size.x) - size.x / 2;
    
    position.x = newX.clamp(minX, maxX);
  }

  void _ensureCorrectFacing(bool shouldFaceRight) {
    if (_isFacingRight && !shouldFaceRight) { 
      flipHorizontally();
      _isFacingRight = false;
    } else if (!_isFacingRight && shouldFaceRight) { 
      flipHorizontally();
      _isFacingRight = true;
    }
  }

  // void move(Vector2 delta) { // Original move method, can be adapted or removed
  //   position.add(delta);
  // }
} 