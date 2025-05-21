import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/babblelon_game.dart';

class GameScreen extends StatefulWidget {
  GameScreen({super.key});
  final BabblelonGame _game = BabblelonGame();

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  void _openMenu() {
    // Only add overlay if not already present
    if (!widget._game.overlays.isActive('main_menu')) {
      if (!widget._game.isPaused) {
        widget._game.pauseGame();
      }
      widget._game.overlays.add('main_menu');
    }
  }

  void _closeMenuAndResume() {
    widget._game.overlays.remove('main_menu');
    widget._game.resumeGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(
            game: widget._game,
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
              'game_over': (context, game) => const GameOverMenu(),
              'main_menu': (context, game) => MainMenu(
                game: game as BabblelonGame,
                onClose: _closeMenuAndResume,
              ),
            },
          ),
          // Hamburger menu icon (always visible)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 32),
                    onPressed: _openMenu,
                  ),
                ),
              ),
            ),
          ),
        ],
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

class MainMenu extends StatefulWidget {
  final BabblelonGame game;
  final VoidCallback onClose;
  const MainMenu({super.key, required this.game, required this.onClose});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  void _toggleMusic(bool val) {
    setState(() {
      widget.game.musicEnabled = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose, // Tap outside closes menu and resumes game
      child: Center(
        child: GestureDetector(
          onTap: () {}, // Prevent tap from propagating to background
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.game.bgmIsPlaying ? Icons.music_note : Icons.music_off, color: Colors.white),
                    const SizedBox(width: 8),
                    Switch(
                      value: widget.game.musicEnabled,
                      onChanged: _toggleMusic,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.game.musicEnabled ? 'Music On' : 'Music Off',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 