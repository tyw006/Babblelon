import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/screens/loading_screen.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/widgets/victory_report_dialog.dart';
import 'package:babblelon/widgets/defeat_dialog.dart';
import 'package:babblelon/widgets/character_tracing_test_widget.dart';
import 'package:babblelon/providers/battle_providers.dart';
import 'package:babblelon/widgets/warm_babbleon_title.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/yaowarat_bg1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const WarmBabbleOnTitle(),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  ref.playButtonSound();
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const GameScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            // First half: fade to black
                            if (animation.value < 0.5) {
                              return Container(
                                color: Colors.black.withValues(alpha: animation.value * 2),
                                child: Opacity(
                                  opacity: 1 - (animation.value * 2),
                                  child: const SizedBox.expand(),
                                ),
                              );
                            }
                            // Second half: fade in new screen
                            else {
                              return Container(
                                color: Colors.black.withValues(alpha: 2 - (animation.value * 2)),
                                child: Opacity(
                                  opacity: (animation.value - 0.5) * 2,
                                  child: child,
                                ),
                              );
                            }
                          },
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 1200),
                    ),
                  );
                },
                child: const Text('Start Game'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Define the test boss data here
                  const tuktukBoss = BossData(
                    name: "Tuk-Tuk Monster",
                    spritePath: 'assets/images/bosses/tuktuk/sprite_tuktukmonster.png',
                    maxHealth: 500,
                    vocabularyPath: 'assets/data/beginner_food_vocabulary.json',
                    backgroundPath: 'assets/images/background/bossfight_tuktuk_bg.png',
                  );

                  // Create test items for the boss fight
                  const testAttackItem = BattleItem(
                    name: 'Test Attack Item',
                    assetPath: 'assets/images/items/steambun_regular.png',
                  );
                  const testDefenseItem = BattleItem(
                    name: 'Test Defense Item', 
                    assetPath: 'assets/images/items/porkbelly_regular.png',
                  );
                  
                  ref.playButtonSound();
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => BossFightScreen(
                        bossData: tuktukBoss,
                        attackItem: testAttackItem,
                        defenseItem: testDefenseItem,
                        game: BabblelonGame(character: 'male'), // Add character parameter for test
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            // First half: fade to black
                            if (animation.value < 0.5) {
                              return Container(
                                color: Colors.black.withValues(alpha: animation.value * 2),
                                child: Opacity(
                                  opacity: 1 - (animation.value * 2),
                                  child: const SizedBox.expand(),
                                ),
                              );
                            }
                            // Second half: fade in new screen
                            else {
                              return Container(
                                color: Colors.black.withValues(alpha: 2 - (animation.value * 2)),
                                child: Opacity(
                                  opacity: (animation.value - 0.5) * 2,
                                  child: child,
                                ),
                              );
                            }
                          },
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 1200),
                    ),
                  );
                },
                child: const Text('Go to Boss Fight (Test)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _showVictoryDialog(context),
                child: const Text('Test Victory Dialog'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _showDefeatDialog(context),
                child: const Text('Test Defeat Dialog'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  ref.playButtonSound();
                  showDialog(
                    context: context,
                    builder: (context) => const CharacterTracingTestWidget(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECCA3),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Test Character Tracing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVictoryDialog(BuildContext context) {
    final mockMetrics = BattleMetrics(
      battleStartTime: DateTime.now().subtract(const Duration(minutes: 5, seconds: 30)),
      pronunciationScores: [95.0, 88.5, 92.0, 78.0, 65.5],
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
      totalDamageDealt: 75.0,
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