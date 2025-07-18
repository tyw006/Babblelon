import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../game/babblelon_game.dart';
import '../overlays/dialogue_overlay.dart';
import '../widgets/info_popup_overlay.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../providers/game_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'main_menu_screen.dart';
import 'package:flame_audio/flame_audio.dart';
import '../services/game_initialization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>> gameWidgetKey = GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>>();

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late WidgetRef _ref;
  late final AppLifecycleListener _listener;
  BabblelonGame? _game;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: _onExitRequested,
    );
    _initializeGame();
    // Start background initialization (non-blocking)
    _initializeGameAssetsInBackground();
  }

  Future<void> _initializeGame() async {
    final prefs = await SharedPreferences.getInstance();
    final character = prefs.getString('selected_character') ?? 'male';
    setState(() {
      _game = BabblelonGame(character: character);
    });
  }

  /// Initialize game assets in the background without blocking the game
  void _initializeGameAssetsInBackground() {
    final initService = GameInitializationService();
    initService.initializeGame().then((success) {
      print('🎮 Background initialization completed: $success');
    }).catchError((error) {
      print('⚠️ Background initialization failed, but game can continue: $error');
    });
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
              if (_game == null)
                const Center(child: CircularProgressIndicator()),
              if (_game != null)
                RiverpodAwareGameWidget(
                  key: gameWidgetKey,
                  game: _game!,
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
                    'main_menu': (context, game) => SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return MainMenu(
                            game: game as BabblelonGame,
                            onClose: _closeMenuAndResume,
                          );
                        },
                      ),
                    ),
                    'game_over': (context, game) {
                      return SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GameOverMenu(
                              game: game as BabblelonGame,
                              onRestart: () => (game as BabblelonGame).reset(),
                            );
                          },
                        ),
                      );
                    },
                    'info_popup': (context, game) {
                      final config = ref.watch(popupConfigProvider);
                      if (config == null) {
                        return const SizedBox.shrink();
                      }
                      return SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return InfoPopupOverlay(
                              title: config.title,
                              message: config.message,
                              confirmText: config.confirmText,
                              onConfirm: config.onConfirm,
                              cancelText: config.cancelText,
                              onCancel: config.onCancel,
                            );
                          },
                        ),
                      );
                    },
                  },
                ),
              // DialogueOverlay outside GameWidget for full-screen access
              Consumer(
                builder: (context, ref, child) {
                  final isDialogueOpen = ref.watch(dialogueOverlayVisibilityProvider);
                  final activeNpcId = ref.watch(activeNpcIdProvider);
                  
                  if (isDialogueOpen && activeNpcId != null && _game != null) {
                    return Positioned.fill(
                      child: DialogueOverlay(game: _game!, npcId: activeNpcId),
                    );
                  }
                  return const SizedBox.shrink();
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
    if (_game == null) return;
    final isPaused = _ref.read(gameStateProvider).isPaused;
    // Only add overlay if not already present
    if (!_game!.overlays.isActive('main_menu')) {
      if (!isPaused) {
        _game!.pauseGame(_ref);
      }
      _game!.overlays.add('main_menu');
    }
  }

  void _closeMenuAndResume() {
    if (_game == null) return;
    _game!.overlays.remove('main_menu');
    _game!.resumeGame(_ref);
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
          color: Colors.black.withValues(alpha: 0.7),
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
              color: Colors.black.withValues(alpha: 0.85),
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
                  icon: gameState.soundEffectsEnabled ? Icons.graphic_eq : Icons.volume_mute,
                  label: gameState.soundEffectsEnabled ? 'SFX On' : 'SFX Off',
                  value: gameState.soundEffectsEnabled,
                  onChanged: (val) => ref.read(gameStateProvider.notifier).setSoundEffectsEnabled(val),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                  ),
                  onPressed: () {
                    ref.playButtonSound();
                    _showExitLevelConfirmation(context, ref);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.exit_to_app, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Exit Level', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.3),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                  ),
                  onPressed: () {
                    ref.playButtonSound();
                    onClose();
                  },
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _showExitLevelConfirmation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          title: const Text(
            'Exit Level?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to exit the level? You will lose all progress and return to the main menu.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () {
                ref.playButtonSound();
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
              ),
              child: const Text(
                'Exit Level',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                ref.playButtonSound();
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainMenuScreen()),
        (route) => false, // Remove all previous routes
      );
    }
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
        color: Colors.grey.shade800.withValues(alpha: 0.9),
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
                      color: Colors.yellowAccent.withValues(alpha: 0.7),
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

class _MenuButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Switch(
          value: value,
        onChanged: (val) {
          ref.playButtonSound();
          onChanged(val);
        },
        activeColor: Colors.blueAccent,
      ),
      onTap: () {
        ref.playButtonSound();
        onChanged(!value);
      },
    );
  }
} 