import 'dart:math'; // For max function
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import '../babblelon_game.dart'; // Adjust if your game class file is named differently or located elsewhere

class PlayerComponent extends SpriteComponent with HasGameRef<BabblelonGame> {
  final double speed = 250.0; // Slightly increased speed
  bool isMovingRight = false;
  bool isMovingLeft = false;  // Flag for moving left
  // Set to false initially, as the sprite asset faces left.
  // The onLoad method will correctly flip it to face right at the start.
  bool isFacingRight = false;

  double backgroundWidth = 0.0; // Will be set from game.backgroundWidth

  PlayerComponent(){
    // Size and anchor will be set in onLoad
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    this.backgroundWidth = game.backgroundWidth; // Initialize backgroundWidth from the game

    final playerImage = await game.images.load('player/sprite_male_tourist.png');
    sprite = Sprite(playerImage);

    const double scaleFactor = 0.20; // Slightly smaller scale for 1080p, adjust as needed
    size = sprite!.originalSize * scaleFactor;
    anchor = Anchor.bottomCenter;

    // Start further to the right.
    // EDIT THIS VALUE to change the player's starting X position.
    double playerX = 150.0;
    double playerY = (game.backgroundHeight > 0) ? game.backgroundHeight : game.size.y;
    position = Vector2(playerX, playerY);

    // Set initial facing direction to Right
    _ensureCorrectFacing(true);
    
    // Add collision detection
    add(RectangleHitbox());
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
    final double maxX = backgroundWidth - size.x / 2;
    
    position.x = newX.clamp(minX, maxX);
  }

  void _ensureCorrectFacing(bool shouldFaceRight) {
    if (isFacingRight && !shouldFaceRight) { 
      flipHorizontally();
      isFacingRight = false;
    } else if (!isFacingRight && shouldFaceRight) { 
      flipHorizontally();
      isFacingRight = true;
    }
  }

  // void move(Vector2 delta) { // Original move method, can be adapted or removed
  //   position.add(delta);
  // }
} 