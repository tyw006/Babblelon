import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/babblelon_game.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: BabblelonGame(),
        loadingBuilder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, error) => Center(
          child: Text(
            'Error loading game: $error',
            style: const TextStyle(color: Colors.red, fontSize: 20),
          ),
        ),
        overlayBuilderMap: {
          'pause_menu': (context, game) => const PauseMenu(),
          'game_over': (context, game) => const GameOverMenu(),
        },
      ),
    );
  }
}

class PauseMenu extends StatelessWidget {
  const PauseMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Resume game logic will go here
              },
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverMenu extends StatelessWidget {
  const GameOverMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Restart game logic will go here
              },
              child: const Text('Play Again'),
            ),
          ],
        ),
      ),
    );
  }
} 