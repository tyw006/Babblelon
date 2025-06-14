import 'package:babblelon/models/turn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/animated_health_bar.dart';
import 'package:babblelon/widgets/turn_indicator.dart';

class TopInfoBar extends ConsumerWidget {
  final VoidCallback onMenuPressed;
  final int playerHealth;
  final int bossHealth;
  final int maxBossHealth;
  final String bossName;
  final Turn currentTurn;

  const TopInfoBar({
    super.key,
    required this.onMenuPressed,
    required this.playerHealth,
    required this.bossHealth,
    required this.maxBossHealth,
    required this.bossName,
    required this.currentTurn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4.0, 8.0, 16.0, 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.grey.shade900.withOpacity(0.90),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Menu Button
            IconButton(
              onPressed: onMenuPressed,
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 28,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Player Health
            Expanded(
              child: AnimatedHealthBar(
                currentHealth: playerHealth,
                maxHealth: 100, // Fixed: was 3, now 100
                label: "Player",
                primaryColor: Colors.green.shade400,
                backgroundColor: Colors.grey.shade700,
                width: double.infinity,
                height: 18,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Turn Indicator
            TurnIndicator(currentTurn: currentTurn),
            
            const SizedBox(width: 16),
            
            // Boss Health
            Expanded(
              child: AnimatedHealthBar(
                currentHealth: bossHealth,
                maxHealth: maxBossHealth,
                label: bossName,
                primaryColor: Colors.red.shade400,
                backgroundColor: Colors.grey.shade700,
                width: double.infinity,
                height: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 