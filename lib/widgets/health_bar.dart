import 'package:flutter/material.dart';

class HealthBar extends StatelessWidget {
  final int currentHealth;
  final int maxHealth;
  final bool isPlayer;
  final String name;

  const HealthBar({
    super.key,
    required this.currentHealth,
    required this.maxHealth,
    this.isPlayer = true,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final healthPercentage = (currentHealth / maxHealth).clamp(0.0, 1.0);
    final barColor = isPlayer ? Colors.green : Colors.red;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          height: 20,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: healthPercentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  '$currentHealth / $maxHealth',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 