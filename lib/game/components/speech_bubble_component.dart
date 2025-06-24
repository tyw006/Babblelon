import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';

class SpeechBubbleComponent extends SpriteComponent with TapCallbacks {
  SpeechBubbleComponent({
    required Sprite sprite,
    required Vector2 size,
    required Vector2 position,
    Anchor anchor = Anchor.bottomCenter,
    int priority = 1,
    this.onTap,
  }) : super(
    sprite: sprite,
    size: size,
    position: position,
    anchor: anchor,
    priority: priority,
  );

  final VoidCallback? onTap;

  @override
  void onTapDown(TapDownEvent event) {
    // Play both button and speech bubble sound effects for instant feedback
    FlameAudio.play('soundeffects/soundeffect_button.mp3');
    event.handled = true;
    super.onTapDown(event);
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Trigger dialogue callback only on tap release
    if (onTap != null) {
      onTap!();
    }
    event.handled = true;
    super.onTapUp(event);
  }
} 