import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../game/babblelon_game.dart';
import '../overlays/dialogue_overlay.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../providers/game_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

final GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>> gameWidgetKey = GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>>();

class GameScreen extends StatefulWidget {
  GameScreen({super.key});
  final BabblelonGame _game = BabblelonGame();

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late WidgetRef _ref;
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: _onExitRequested,
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _onExitRequested() async {
    final tempFiles = _ref.read(tempFilePathsProvider);
    for (final path in tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          print('Deleted temporary file: $path');
        }
      } catch (e) {
        print('Error deleting temporary file $path: $e');
      }
    }
    // Clear the provider list after deleting the files
    _ref.read(tempFilePathsProvider.notifier).state = [];
    return AppExitResponse.exit;
  }

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

class InventoryWidget extends ConsumerWidget {
  const InventoryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final attackItem = inventory['attack'];
    final defenseItem = inventory['defense'];

    // Using an Opacity widget to hide/show the inventory based on whether it's empty.
    return Opacity(
      opacity: (attackItem == null && defenseItem == null) ? 0.0 : 1.0,
      child: Container(
        width: 80, // Adjusted size to better fit the UI
        height: 160, // Adjusted size
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/ui/inventory.png'),
            fit: BoxFit.contain,
          ),
        ),
        child: Column(
          children: [
            Expanded( // Attack Slot
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12), // Padding inside the slot
                margin: const EdgeInsets.only(top: 20), // Margin to align with the box
                child: attackItem != null 
                  ? Image.asset(attackItem) 
                  : const SizedBox.shrink(),
              ),
            ),
            Expanded( // Defense Slot
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12), // Padding inside the slot
                margin: const EdgeInsets.only(bottom: 20), // Margin to align with the box
                child: defenseItem != null 
                  ? Image.asset(defenseItem) 
                  : const SizedBox.shrink(),
              ),
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
                // --- Inventory Section ---
                const _InventoryCard(),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                // --- End Inventory Section ---

                const Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Music Toggle
                _MenuRow(
                  icon: gameState.musicEnabled ? Icons.music_note : Icons.music_off,
                  label: gameState.musicEnabled ? 'Music On' : 'Music Off',
                  value: gameState.musicEnabled,
                  onChanged: (val) => ref.read(gameStateProvider.notifier).toggleMusic(),
                ),
                const SizedBox(height: 16),

                // Translation Toggle
                _MenuRow(
                  icon: dialogueSettings.showTranslation ? Icons.translate : Icons.translate_outlined,
                  label: dialogueSettings.showTranslation ? 'Translation On' : 'Translation Off',
                  value: dialogueSettings.showTranslation,
                  onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleTranslation(),
                ),
                const SizedBox(height: 16),

                // Transliteration Toggle
                _MenuRow(
                  icon: dialogueSettings.showTransliteration ? Icons.spellcheck : Icons.spellcheck_outlined,
                  label: dialogueSettings.showTransliteration ? 'Transliteration On' : 'Transliteration Off',
                  value: dialogueSettings.showTransliteration,
                  onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleTransliteration(),
                ),
                const SizedBox(height: 16),

                // Word Highlighting (formerly POS Colors) Toggle
                _MenuRow(
                  icon: dialogueSettings.showPos ? Icons.color_lens : Icons.color_lens_outlined,
                  label: dialogueSettings.showPos ? 'Word Colors On' : 'Word Colors Off',
                  value: dialogueSettings.showPos,
                  onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleShowPos(),
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

class _InventoryCard extends ConsumerWidget {
  const _InventoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final attackItem = inventory['attack'];
    final defenseItem = inventory['defense'];

    // If both slots are empty, don't show the inventory section at all.
    if (attackItem == null && defenseItem == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Inventory',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InventorySlot(title: 'Attack', itemAsset: attackItem),
              _InventorySlot(title: 'Defense', itemAsset: defenseItem),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventorySlot extends StatelessWidget {
  final String title;
  final String? itemAsset;

  const _InventorySlot({required this.title, this.itemAsset});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: itemAsset != null
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(itemAsset!, fit: BoxFit.contain),
                )
              : const Center(
                  child: Text(
                  'Empty',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                )),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.red,
        ),
      ],
    );
  }
} 