import 'package:flame/components.dart';
import '../babblelon_game.dart';
import 'player_component.dart';

class CapybaraCompanion extends SpriteComponent with HasGameReference<BabblelonGame> {
  final double speed = 200.0; // Slightly slower than player
  final double followDistance = 80.0; // Distance before capybara starts following
  // Set to false initially, as the sprite asset faces left.
  // This will be synced with the player's direction.
  bool _isFacingRight = false; 
  
  late PlayerComponent player;
  double backgroundWidth = 0.0;
  Vector2 _targetPosition = Vector2.zero();

  CapybaraCompanion({required this.player});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    backgroundWidth = game.backgroundWidth;

    final capybaraImage = await game.images.load('player/capybara.png');
    sprite = Sprite(capybaraImage);

    // EDIT THIS VALUE to change the capybara's size.
    const double scaleFactor = 0.10; // Smaller than player
    size = sprite!.originalSize * scaleFactor;
    anchor = Anchor.bottomCenter;

    // Start at the left edge of the screen.
    // EDIT THIS VALUE to change the capybara's starting X position.
    final capybaraX = size.x / 2;
    
    // This ensures the capybara is on the same ground plane as the player.
    final capybaraY = ((game.backgroundHeight > 0) ? game.backgroundHeight : game.size.y);
    position = Vector2(capybaraX, capybaraY);
    _targetPosition = position.clone();

    // Set initial facing direction to right (matching sprite)
    _ensureCorrectFacing(true);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (!player.isMounted) return;

    // Always have the capybara face the same direction as the player.
    _ensureCorrectFacing(player.isFacingRight);

    // EDIT THIS VALUE to change the gap between the player and capybara.
    const double horizontalGap = 75.0;
    
    // EDIT THIS VALUE to change the capybara's Y position offset from the player.
    // Positive values move the capybara down, negative values move it up.
    const double verticalOffset = -10.0;

    // Determine the target position based on the player's direction.
    // Only follow horizontally, maintain the capybara's own Y position with optional offset.
    double targetX;
    if (player.isFacingRight) {
      targetX = player.position.x - horizontalGap;
    } else {
      targetX = player.position.x + horizontalGap;
    }
    
    // Set target position with the capybara's Y plus any offset
    _targetPosition = Vector2(targetX, player.position.y + verticalOffset);
    
    final distanceToTarget = (position - _targetPosition).length;
    
    // Only follow if the capybara is too far from its target spot.
    if (distanceToTarget > 5) { // Using a small threshold to prevent jitter
      
      // Move towards target position
      final directionToTarget = (_targetPosition - position).normalized();
      final moveDistance = speed * dt;
      
      // Move towards target
      final newPosition = position + (directionToTarget * moveDistance);
      
      // Clamp to background bounds
      final double minX = size.x / 2;
      final double maxX = backgroundWidth - size.x / 2;
      position.x = newPosition.x.clamp(minX, maxX);
      position.y = newPosition.y;
    }
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
} 