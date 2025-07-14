import 'dart:math';
import 'package:flutter/material.dart';

class TwinklingStars extends StatefulWidget {
  final int starCount;
  final double minSize;
  final double maxSize;
  final Duration duration;

  const TwinklingStars({
    super.key,
    this.starCount = 50,
    this.minSize = 1.0,
    this.maxSize = 2.5,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<TwinklingStars> createState() => _TwinklingStarsState();
}

class _TwinklingStarsState extends State<TwinklingStars> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    
    _generateStars();
  }

  void _generateStars() {
    _stars = List.generate(widget.starCount, (index) {
      return Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: widget.minSize + _random.nextDouble() * (widget.maxSize - widget.minSize),
        phase: _random.nextDouble() * 2 * pi,
        speed: 0.5 + _random.nextDouble() * 0.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: StarPainter(_stars, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;

  StarPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final star in stars) {
      final opacity = (sin(animationValue * 2 * pi * star.speed + star.phase) + 1) / 2;
      paint.color = Colors.white.withOpacity(opacity * 0.8);
      
      final position = Offset(
        star.x * size.width,
        star.y * size.height,
      );
      
      canvas.drawCircle(position, star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 