import 'package:flutter/material.dart';
import 'dart:math' as math;

class SpaceStarfield extends StatelessWidget {
  final bool isActive;
  final double intensity;
  final int starCount;
  final Color baseColor;
  final Color twinkleColor;

  const SpaceStarfield({
    super.key,
    this.isActive = true,
    this.intensity = 0.8,
    this.starCount = 100,
    this.baseColor = Colors.white,
    this.twinkleColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StarfieldPainter(
        starCount: starCount,
        intensity: intensity,
        baseColor: baseColor,
        twinkleColor: twinkleColor,
        isActive: isActive,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class StarfieldPainter extends CustomPainter {
  final int starCount;
  final double intensity;
  final Color baseColor;
  final Color twinkleColor;
  final bool isActive;

  StarfieldPainter({
    required this.starCount,
    required this.intensity,
    required this.baseColor,
    required this.twinkleColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42); // Fixed seed for consistent stars
    
    for (int i = 0; i < starCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = random.nextDouble() * 3 * intensity + 1;
      final opacity = random.nextDouble() * 0.8 + 0.2;
      
      // Use consistent color with alpha for opacity support
      final color = i % 3 == 0 ? twinkleColor : baseColor;
      paint.color = color.withValues(alpha: (opacity * intensity).clamp(0.0, 1.0));
      
      // Draw star as a small circle
      canvas.drawCircle(Offset(x, y), starSize, paint);
      
      // Add sparkle effect for some stars with proper alpha clamping
      if (i % 5 == 0 && starSize > 2) {
        paint.color = color.withValues(alpha: (opacity * 0.5 * intensity).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), starSize * 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EnhancedSpaceStarfield extends StatefulWidget {
  final bool isActive;
  final double intensity;
  final int starCount;
  final Color baseColor;
  final Color twinkleColor;

  const EnhancedSpaceStarfield({
    super.key,
    this.isActive = true,
    this.intensity = 0.8,
    this.starCount = 100,
    this.baseColor = Colors.white,
    this.twinkleColor = Colors.blue,
  });

  @override
  State<EnhancedSpaceStarfield> createState() => _EnhancedSpaceStarfieldState();
}

class _EnhancedSpaceStarfieldState extends State<EnhancedSpaceStarfield>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _intensityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _intensityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _intensityAnimation,
      builder: (context, child) {
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background layer of stars (static)
              SpaceStarfield(
                isActive: widget.isActive,
                intensity: widget.intensity * 0.5,
                starCount: widget.starCount,
                baseColor: widget.baseColor,
                twinkleColor: widget.twinkleColor,
              ),
              // Foreground layer with animation
              Opacity(
                opacity: _intensityAnimation.value * 0.6,
                child: SpaceStarfield(
                  isActive: widget.isActive,
                  intensity: widget.intensity * _intensityAnimation.value,
                  starCount: (widget.starCount * 0.2).round(),
                  baseColor: widget.baseColor,
                  twinkleColor: widget.twinkleColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}