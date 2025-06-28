import 'package:flutter/material.dart';

class ComplexityRating extends StatelessWidget {
  final int complexity;
  final double size;

  const ComplexityRating({
    super.key, 
    required this.complexity,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          Icons.local_fire_department,
          size: size,
          color: index < complexity
              ? Colors.red.shade400
              : Colors.grey.shade700,
        );
      }),
    );
  }
} 