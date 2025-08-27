import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../babblelon_game.dart';

// Base class for all game components
abstract class BaseComponent extends PositionComponent with HasGameReference<BabblelonGame> {
  BaseComponent({
    super.position,
    super.size,
    super.scale,
    super.angle,
    super.anchor,
    super.priority,
  });
  
  // Add scale effect animation
  void addScaleEffect({
    double scaleTo = 1.2,
    double duration = 0.2,
  }) {
    add(
      ScaleEffect.by(
        Vector2.all(scaleTo),
        EffectController(
          duration: duration,
          reverseDuration: duration,
          infinite: false,
        ),
      ),
    );
  }
  
  // Add rotation effect animation
  void addRotationEffect({
    double angleBy = 0.1,
    double duration = 0.5,
    bool infinite = false,
  }) {
    add(
      RotateEffect.by(
        angleBy,
        EffectController(
          duration: duration,
          infinite: infinite,
        ),
      ),
    );
  }
  
  // Add opacity effect animation
  void addOpacityEffect({
    double opacityTo = 0.5,
    double duration = 0.3,
    bool infinite = false,
    bool alternate = true,
  }) {
    add(
      OpacityEffect.to(
        opacityTo,
        EffectController(
          duration: duration,
          reverseDuration: alternate ? duration : null,
          infinite: infinite,
        ),
      ),
    );
  }
  
  // Add move effect animation
  void addMoveEffect({
    required Vector2 moveBy,
    double duration = 0.5,
    bool infinite = false,
    bool alternate = true,
    Curve curve = Curves.easeInOut,
  }) {
    add(
      MoveEffect.by(
        moveBy,
        EffectController(
          duration: duration,
          reverseDuration: alternate ? duration : null,
          infinite: infinite,
          curve: curve,
        ),
      ),
    );
  }
  
  // Add color effect animation
  void addColorEffect({
    required Color colorTo,
    double duration = 0.3,
    bool infinite = false,
    bool alternate = true,
  }) {
    add(
      ColorEffect(
        colorTo,
        EffectController(
          duration: duration,
          reverseDuration: alternate ? duration : null,
          infinite: infinite,
        ),
      ),
    );
  }
  
  // Add sequence effect
  void addSequenceEffect({
    required List<Effect> effects,
    bool infinite = false,
  }) {
    add(
      SequenceEffect(
        effects,
        infinite: infinite,
      ),
    );
  }
} 