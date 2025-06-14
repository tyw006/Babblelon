import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:flutter/material.dart';

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
                'Babble-On',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GameScreen()),
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
                    vocabularyPath: 'assets/data/boss_vocabulary.json',
                    backgroundPath: 'assets/images/background/bossfight_tuktuk_bg.png',
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BossFightScreen(bossData: tuktukBoss),
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