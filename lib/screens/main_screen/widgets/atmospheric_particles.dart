import 'package:flutter/material.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'dart:math' as math;

class AtmosphericParticles extends StatelessWidget {
  final double earthRadius;
  final bool isActive;
  final double intensity;

  const AtmosphericParticles({
    super.key,
    required this.earthRadius,
    this.isActive = true,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();
    
    final particleSize = earthRadius * 2.5;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer atmospheric layer - cosmic dust
        SizedBox(
          width: particleSize,
          height: particleSize,
          child: CircularParticle(
            width: particleSize,
            height: particleSize,
            numberOfParticles: (15 * intensity).toDouble(),
            speedOfParticles: 0.2 * intensity,
            particleColor: Colors.cyan.withValues(alpha: 0.2),
            awayRadius: 180,
            isRandSize: true,
            isRandomColor: true,
            randColorList: [
              Colors.white.withValues(alpha: 0.3),
              Colors.cyan.shade100.withValues(alpha: 0.2),
              Colors.blue.shade100.withValues(alpha: 0.15),
              Colors.purple.shade100.withValues(alpha: 0.1),
            ],
            connectDots: false,
            enableHover: false,
          ),
        ),
        
        // Middle atmospheric layer - stardust
        SizedBox(
          width: particleSize * 0.8,
          height: particleSize * 0.8,
          child: CircularParticle(
            width: particleSize * 0.8,
            height: particleSize * 0.8,
            numberOfParticles: (25 * intensity).toDouble(),
            speedOfParticles: 0.4 * intensity,
            particleColor: Colors.white.withValues(alpha: 0.4),
            awayRadius: 120,
            isRandSize: true,
            isRandomColor: true,
            randColorList: [
              Colors.white.withValues(alpha: 0.5),
              Colors.blue.withValues(alpha: 0.3),
              Colors.cyan.withValues(alpha: 0.25),
            ],
            connectDots: false,
            enableHover: true,
          ),
        ),
        
        // Inner atmospheric layer - close particles
        SizedBox(
          width: particleSize * 0.6,
          height: particleSize * 0.6,
          child: CircularParticle(
            width: particleSize * 0.6,
            height: particleSize * 0.6,
            numberOfParticles: (35 * intensity).toDouble(),
            speedOfParticles: 0.6 * intensity,
            particleColor: Colors.white.withValues(alpha: 0.6),
            awayRadius: 80,
            isRandSize: true,
            isRandomColor: true,
            randColorList: [
              Colors.white.withValues(alpha: 0.7),
              Colors.lightBlue.withValues(alpha: 0.4),
              Colors.cyan.withValues(alpha: 0.3),
            ],
            connectDots: false,
            enableHover: true,
          ),
        ),
      ],
    );
  }
}

class EnhancedTwinklingStars extends StatefulWidget {
  final int starCount;
  final double minSize;
  final double maxSize;
  final Duration duration;
  final int layers;

  const EnhancedTwinklingStars({
    super.key,
    this.starCount = 50,
    this.minSize = 1.0,
    this.maxSize = 3.0,
    this.duration = const Duration(seconds: 8),
    this.layers = 3,
  });

  @override
  State<EnhancedTwinklingStars> createState() => _EnhancedTwinklingStarsState();
}

class _EnhancedTwinklingStarsState extends State<EnhancedTwinklingStars>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<List<StarData>> _starLayers;

  @override
  void initState() {
    super.initState();
    _controllers = [];
    _starLayers = [];
    
    // Create multiple layers for parallax effect
    for (int layer = 0; layer < widget.layers; layer++) {
      final controller = AnimationController(
        duration: Duration(
          milliseconds: (widget.duration.inMilliseconds * (1.0 + layer * 0.3)).round(),
        ),
        vsync: this,
      )..repeat();
      
      _controllers.add(controller);
      
      // Generate stars for this layer
      final stars = <StarData>[];
      final layerStarCount = (widget.starCount / widget.layers).round();
      
      for (int i = 0; i < layerStarCount; i++) {
        stars.add(StarData(
          x: (i * 137.5) % 1, // Golden angle distribution
          y: (i * 0.618) % 1,
          size: widget.minSize + 
                (widget.maxSize - widget.minSize) * 
                ((i * 0.382) % 1),
          opacity: 0.3 + (0.7 * ((i * 0.191) % 1)),
          layer: layer,
        ));
      }
      
      _starLayers.add(stars);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.layers, (layerIndex) {
        return AnimatedBuilder(
          animation: _controllers[layerIndex],
          builder: (context, child) {
            return CustomPaint(
              painter: StarLayerPainter(
                stars: _starLayers[layerIndex],
                animationValue: _controllers[layerIndex].value,
                layerDepth: layerIndex / widget.layers,
              ),
              size: Size.infinite,
            );
          },
        );
      }),
    );
  }
}

class StarData {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final int layer;

  StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.layer,
  });
}

class StarLayerPainter extends CustomPainter {
  final List<StarData> stars;
  final double animationValue;
  final double layerDepth;

  StarLayerPainter({
    required this.stars,
    required this.animationValue,
    required this.layerDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final star in stars) {
      // Create parallax offset based on layer depth
      final parallaxOffset = layerDepth * 50 * animationValue;
      
      final x = (star.x * size.width + parallaxOffset) % size.width;
      final y = star.y * size.height;
      
      // Twinkling effect
      final twinkle = (1.0 +
        0.5 *
        (1.0 + math.sin(animationValue * 6.28 + star.x * 10)) *
        (1.0 + math.cos(animationValue * 4.71 + star.y * 10))
      ) / 2.0;
      
      final alpha = (star.opacity * twinkle * (1.0 - layerDepth * 0.3)).clamp(0.0, 1.0);
      
      paint.color = Colors.white.withValues(alpha: alpha);
      
      // Draw star as small circle
      canvas.drawCircle(
        Offset(x, y),
        star.size * twinkle,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarLayerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(covariant StarLayerPainter oldDelegate) => false;
}