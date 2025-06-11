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
                  'main_menu': (context, game) => MainMenu(
                    game: game as BabblelonGame,
                    onClose: _closeMenuAndResume,
                  ),
                  'dialogue': (context, game) {
                    final babblelonGame = game as BabblelonGame;
                    final npcId = babblelonGame.activeNpcIdForOverlay;

                    if (npcId == null) {
                      // This is a fallback, should not happen in normal flow
                      return const Center(
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            "Error: No NPC selected for dialogue.",
                            style: TextStyle(color: Colors.red, fontSize: 24),
                          ),
                        ),
                      );
                    }
                    return DialogueOverlay(game: babblelonGame, npcId: npcId);
                  },
                  'game_over': (context, game) {
                    return GameOverMenu(
                      game: game as BabblelonGame,
                      onRestart: () => (game as BabblelonGame).reset(),
                    );
                  },
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
                      child: Consumer(
                        builder: (context, ref, child) {
                          final hasNewItem = ref.watch(gameStateProvider.select((s) => s.hasNewItem));
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.menu, color: Colors.white, size: 32),
                                onPressed: () {
                                  // When opening menu, mark new item as seen
                                  if (hasNewItem) {
                                    ref.read(gameStateProvider.notifier).clearNewItem();
                                  }
                                  _openMenu();
                                },
                              ),
                              if (hasNewItem)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 12,
                                      minHeight: 12,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
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
  final BabblelonGame game;
  final VoidCallback onRestart;
  const GameOverMenu({super.key, required this.game, required this.onRestart});

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
              onPressed: onRestart,
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

                _MenuButton(
                  icon: gameState.musicEnabled ? Icons.music_note : Icons.music_off,
                  label: gameState.musicEnabled ? 'Music On' : 'Music Off',
                  value: gameState.musicEnabled,
                  onChanged: (val) => ref.read(gameStateProvider.notifier).toggleMusic(),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  icon: dialogueSettings.showEnglishTranslation ? Icons.visibility : Icons.visibility_off,
                  label: 'English Translation',
                  value: dialogueSettings.showEnglishTranslation,
                  onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleShowEnglishTranslation(),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  icon: dialogueSettings.showWordByWordAnalysis ? Icons.segment : Icons.segment_outlined,
                  label: 'Word Analysis',
                  value: dialogueSettings.showWordByWordAnalysis,
                  onChanged: (val) => ref.read(dialogueSettingsProvider.notifier).toggleWordByWordAnalysis(),
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
    final hasNewItem = ref.watch(gameStateProvider.select((s) => s.hasNewItem));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: hasNewItem ? Colors.amber.shade700 : Colors.black, 
          width: 2
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Inventory',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InventorySlot(
                label: 'Attack',
                assetPath: inventory['attack'],
                isHighlighted: false, // This can be driven by a different provider if needed
              ),
              _InventorySlot(
                label: 'Defense',
                assetPath: inventory['defense'],
                isHighlighted: false, // This can be driven by a different provider if needed
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventorySlot extends StatelessWidget {
  final String label;
  final String? assetPath;
  final bool isHighlighted;

  const _InventorySlot({required this.label, this.assetPath, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHighlighted ? Colors.yellowAccent : Colors.white24,
              width: isHighlighted ? 3 : 1,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: Colors.yellowAccent.withOpacity(0.7),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: assetPath != null
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(assetPath!),
                )
              : const Icon(Icons.add_box_outlined, color: Colors.white38, size: 30),
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

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _MenuButton({
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