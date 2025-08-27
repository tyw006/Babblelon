import 'package:flutter/material.dart';

class ComplexityRating extends StatelessWidget {
  final int complexity;
  final double size;
  final bool isDialog;

  const ComplexityRating({
    super.key, 
    required this.complexity,
    this.size = 16.0,
    this.isDialog = false,
  });

  @override
  Widget build(BuildContext context) {
    // Context-aware sizing: larger dots for dialog, slightly larger for boss fight grid
    final double dotSize = isDialog ? 8.0 : 5.0;
    final double margin = isDialog ? 2.0 : 1.5;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isActive = index < complexity;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: margin),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive 
              ? Colors.orange.shade400
              : Colors.grey.shade600,
          ),
        );
      }),
    );
  }
} 