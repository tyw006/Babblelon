import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/victory_report_dialog.dart';
import 'package:babblelon/widgets/defeat_dialog.dart';
import 'package:babblelon/providers/battle_providers.dart';

class DebugDialogTest extends ConsumerWidget {
  const DebugDialogTest({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialog Tests'),
        backgroundColor: Colors.grey.shade800,
      ),
      backgroundColor: Colors.grey.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _showVictoryDialog(context),
              child: const Text('Test Victory Dialog (with Lottie)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showDefeatDialog(context),
              child: const Text('Test Defeat Dialog'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVictoryDialog(BuildContext context) {
    final mockMetrics = BattleMetrics(
      battleStartTime: DateTime.now().subtract(const Duration(minutes: 5, seconds: 30)),
      pronunciationScores: [85.5, 92.0, 78.5, 88.0, 95.5],
      maxStreak: 7,
      totalDamageDealt: 150.0,
      finalPlayerHealth: 85,
      playerStartingHealth: 100,
      bossMaxHealth: 200,
      wordScores: {
        'hello': 95,
        'world': 88,
        'food': 92,
        'water': 78,
        'thank you': 65,
      },
      wordsUsed: {'hello', 'world', 'food', 'water', 'thank you'},
      wordFailureCount: {
        'water': 2,
        'thank you': 1,
      },
      expGained: 250,
      goldEarned: 150,
      newlyMasteredWords: {'hello', 'world', 'food'},
    );

    showDialog(
      context: context,
      builder: (context) => VictoryReportDialog(metrics: mockMetrics),
    );
  }

  void _showDefeatDialog(BuildContext context) {
    final mockDefeatMetrics = BattleMetrics(
      battleStartTime: DateTime.now().subtract(const Duration(minutes: 3, seconds: 15)),
      pronunciationScores: [65.0, 72.5, 58.0, 69.5, 61.0],
      maxStreak: 2,
      totalDamageDealt: 150.0,
      finalPlayerHealth: 0,
      playerStartingHealth: 100,
      bossMaxHealth: 200,
      wordScores: {
        'hello': 65,
        'water': 72,
        'chicken': 58,
        'spicy': 69,
        'rice': 61,
      },
      wordsUsed: {'hello', 'water', 'chicken', 'spicy', 'rice'},
      wordFailureCount: {
        'spicy': 3,
        'chicken': 2,
        'rice': 1,
      },
      expGained: 25,
      goldEarned: 10,
      newlyMasteredWords: {},
    );

    showDialog(
      context: context,
      builder: (context) => DefeatDialog(metrics: mockDefeatMetrics),
    );
  }
} 