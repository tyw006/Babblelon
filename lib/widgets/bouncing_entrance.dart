import 'package:flutter/material.dart';

/// Bouncing entrance animation widget using TweenAnimationBuilder
/// Implements elastic bounce effect for Voxie-style entrance
class BouncingEntrance extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double delay;

  const BouncingEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.elasticOut,
    this.delay = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        // Add delay if specified
        if (delay > 0) {
          final delayedValue = (value - delay).clamp(0.0, 1.0);
          return Transform.scale(
            scale: delayedValue,
            child: child,
          );
        }
        
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Staggered bouncing entrance for multiple elements
class StaggeredBouncingEntrance extends StatelessWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration staggerDelay;
  final Curve curve;
  final Axis direction;

  const StaggeredBouncingEntrance({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 1200),
    this.staggerDelay = const Duration(milliseconds: 100),
    this.curve = Curves.elasticOut,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return direction == Axis.vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildStaggeredChildren(),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildStaggeredChildren(),
          );
  }

  List<Widget> _buildStaggeredChildren() {
    return children.asMap().entries.map((entry) {
      final index = entry.key;
      final child = entry.value;
      final delay = index * staggerDelay.inMilliseconds / duration.inMilliseconds;
      
      return BouncingEntrance(
        duration: duration,
        curve: curve,
        delay: delay,
        child: child,
      );
    }).toList();
  }
}

/// Entrance animation with scale and fade effects
class ScaleFadeEntrance extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double initialScale;
  final double finalScale;

  const ScaleFadeEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutBack,
    this.initialScale = 0.0,
    this.finalScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final scale = initialScale + (finalScale - initialScale) * value;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Entrance animation with slide and bounce effects
class SlideBouncingEntrance extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Offset initialOffset;
  final Offset finalOffset;

  const SlideBouncingEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.curve = Curves.elasticOut,
    this.initialOffset = const Offset(0.0, -0.5),
    this.finalOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: initialOffset, end: finalOffset),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Combined entrance animation with multiple effects
class VoxieStyleEntrance extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final bool enableBounce;
  final bool enableFade;
  final bool enableSlide;

  const VoxieStyleEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.enableBounce = true,
    this.enableFade = true,
    this.enableSlide = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget animatedChild = child;

    if (enableSlide) {
      animatedChild = SlideBouncingEntrance(
        duration: duration,
        child: animatedChild,
      );
    }

    if (enableBounce) {
      animatedChild = BouncingEntrance(
        duration: duration,
        curve: Curves.elasticOut,
        child: animatedChild,
      );
    }

    if (enableFade) {
      animatedChild = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: (duration.inMilliseconds * 0.6).round()),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: child,
          );
        },
        child: animatedChild,
      );
    }

    return animatedChild;
  }
}