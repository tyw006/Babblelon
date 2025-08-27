import 'package:flutter/material.dart';
import 'package:babblelon/screens/main_screen/widgets/animated_gradient_background.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: AnimatedGradientBackground(
        colors: [
          Color(0xFF0A0E27), // Very deep space blue
          Color(0xFF1E3A5F), // Rich midnight blue
          Color(0xFF2E5090), // Vibrant space blue
          Color(0xFF5B4E8C), // Deep purple
          Color(0xFF3A6B8C), // Ocean teal
          Color(0xFF1B4F72), // Deep teal blue
        ],
        animationDuration: Duration(seconds: 20),
      ),
    );
  }
}