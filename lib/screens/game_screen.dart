import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/babblelon_game.dart';
import '../overlays/dialogue_overlay.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../providers/game_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>> gameWidgetKey = GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>>();

class GameScreen extends StatefulWidget {
  GameScreen({super.key});
  final BabblelonGame _game = BabblelonGame();

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late WidgetRef _ref;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        _ref = ref;
        return Scaffold(
          body: Stack(
            children: [
              RiverpodAwareGameWidget(
                key: gameWidgetKey,
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
                  'dialogue': (context, game) {
                    final babbleGame = game as BabblelonGame;
                    // Assuming BabblelonGame has these properties.
                    // If not, they will need to be added to BabblelonGame.
                    return DialogueOverlay(
                      game: babbleGame,
                    );
                  }
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
      },
    );
  }

  void _openMenu() {
    final isPaused = _ref.read(gameStateProvider).isPaused;
    // Only add overlay if not already present
    if (!widget._game.overlays.isActive('main_menu')) {
      if (!isPaused) {
        widget._game.pauseGame(_ref);
      }
      widget._game.overlays.add('main_menu');
    }
  }

  void _closeMenuAndResume() {
    widget._game.overlays.remove('main_menu');
    widget._game.resumeGame(_ref);
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

class MainMenu extends ConsumerWidget {
  final BabblelonGame game;
  final VoidCallback onClose;
  const MainMenu({super.key, required this.game, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final dialogueSettings = ref.watch(dialogueSettingsProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose, // Tap outside closes menu and resumes game
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

                // Music Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items
                  children: [
                    Icon(gameState.bgmIsPlaying ? Icons.music_note : Icons.music_off, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      gameState.musicEnabled ? 'Music On' : 'Music Off',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Switch(
                      value: gameState.musicEnabled,
                      onChanged: (val) => ref.read(gameStateProvider.notifier).toggleMusic(),
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Translation Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items
                  children: [
                    Icon(dialogueSettings.showTranslation ? Icons.translate : Icons.translate_outlined, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      dialogueSettings.showTranslation ? 'Translation On' : 'Translation Off',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Switch(
                      value: dialogueSettings.showTranslation,
                      onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleTranslation(),
                      activeColor: Colors.lightBlueAccent,
                      inactiveThumbColor: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transliteration Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items
                  children: [
                    Icon(dialogueSettings.showTransliteration ? Icons.spellcheck : Icons.spellcheck_outlined, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      dialogueSettings.showTransliteration ? 'Transliteration On' : 'Transliteration Off',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Switch(
                      value: dialogueSettings.showTransliteration,
                      onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleTransliteration(),
                      activeColor: Colors.orangeAccent,
                      inactiveThumbColor: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Word Highlighting (formerly POS Colors) Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items
                  children: [
                    Icon(dialogueSettings.showPos ? Icons.color_lens : Icons.color_lens_outlined, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      dialogueSettings.showPos ? 'Word Colors On' : 'Word Colors Off', // Renamed
                      style: const TextStyle(color: Colors.white),
                    ),
                    Switch(
                      value: dialogueSettings.showPos,
                      onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleShowPos(),
                      activeColor: Colors.purpleAccent,
                      inactiveThumbColor: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onClose,
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