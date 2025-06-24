import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'BabbleOn',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(5.0, 5.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  FlameAudio.play('soundeffects/soundeffect_button.mp3');
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => GameScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            // First half: fade to black
                            if (animation.value < 0.5) {
                              return Container(
                                color: Colors.black.withOpacity(animation.value * 2),
                                child: Opacity(
                                  opacity: 1 - (animation.value * 2),
                                  child: const SizedBox.expand(),
                                ),
                              );
                            }
                            // Second half: fade in new screen
                            else {
                              return Container(
                                color: Colors.black.withOpacity(2 - (animation.value * 2)),
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
                  
                  FlameAudio.play('soundeffects/soundeffect_button.mp3');
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => BossFightScreen(
                        bossData: tuktukBoss,
                        attackItem: testAttackItem,
                        defenseItem: testDefenseItem,
                        game: BabblelonGame(),
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            // First half: fade to black
                            if (animation.value < 0.5) {
                              return Container(
                                color: Colors.black.withOpacity(animation.value * 2),
                                child: Opacity(
                                  opacity: 1 - (animation.value * 2),
                                  child: const SizedBox.expand(),
                                ),
                              );
                            }
                            // Second half: fade in new screen
                            else {
                              return Container(
                                color: Colors.black.withOpacity(2 - (animation.value * 2)),
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
            ],
          ),
        ),
      ),
    );
  }
} 