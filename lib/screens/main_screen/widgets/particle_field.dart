import 'package:flutter/material.dart';
import 'package:particles_flutter/particles_flutter.dart';

class ParticleField extends StatelessWidget {
  final double width;
  final double height;
  final int numberOfParticles;
  final double particleSpeed;
  final bool isRandomColor;

  const ParticleField({
    super.key,
    required this.width,
    required this.height,
    this.numberOfParticles = 75,
    this.particleSpeed = 0.5,
    this.isRandomColor = false,
  });

  @override
  Widget build(BuildContext context) {
    return CircularParticle(
      width: width,
      height: height,
      numberOfParticles: numberOfParticles.toDouble(),
      speedOfParticles: particleSpeed,
      particleColor: Colors.white.withValues(alpha: 0.6),
      awayRadius: 150,
      isRandSize: true,
      isRandomColor: isRandomColor,
      randColorList: [
        Colors.white.withValues(alpha: 0.8),
        Colors.blue.shade100.withValues(alpha: 0.6),
        Colors.purple.shade100.withValues(alpha: 0.5),
        Colors.cyan.shade100.withValues(alpha: 0.4),
      ],
      connectDots: false,
      enableHover: true,
    );
  }
}