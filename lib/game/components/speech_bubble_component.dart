import 'package:flame/components.dart';
import 'package:flame/events.dart';


class SpeechBubbleComponent extends SpriteComponent with TapCallbacks {
  SpeechBubbleComponent({
    required Sprite sprite,
    required Vector2 size,
    required Vector2 position,
    Anchor anchor = Anchor.bottomCenter,
    int priority = 1,
  }) : super(
    sprite: sprite,
    size: size,
    position: position,
    anchor: anchor,
    priority: priority,
  );

  @override
  void onTapDown(TapDownEvent event) {
    print('Interacted with NPC!');
  }
} 