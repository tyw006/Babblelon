import 'package:flutter/material.dart';
import 'dart:ui';
import '../game/babblelon_game.dart';
import '../overlays/dialogue_overlay.dart';
import '../widgets/info_popup_overlay.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../providers/game_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'main_navigation_screen.dart';
import '../services/game_initialization_service.dart';
import '../services/posthog_service.dart';
import '../services/game_save_service.dart';
import '../models/popup_models.dart';
import '../widgets/popups/base_popup_widget.dart';
import '../models/npc_data.dart';
import '../services/static_game_loader.dart';
import '../models/local_storage_models.dart';

final GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>> gameWidgetKey = GlobalKey<RiverpodAwareGameWidgetState<BabblelonGame>>();

class GameScreen extends StatefulWidget {
  final GameSaveState? existingSave;
  
  const GameScreen({super.key, this.existingSave});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late WidgetRef _ref;
  late final AppLifecycleListener _listener;
  bool _hasRestoredInventory = false;

  @override
  void initState() {
    super.initState();
    
    debugPrint('🎮 GameScreen: initState() called');
    debugPrint('🎮 GameScreen: existingSave provided: ${widget.existingSave != null}');
    if (widget.existingSave != null) {
      debugPrint('🎮 GameScreen: save data level: ${widget.existingSave!.levelId}');
      debugPrint('🎮 GameScreen: save data timestamp: ${widget.existingSave!.timestamp}');
      debugPrint('🎮 GameScreen: save data game type: ${widget.existingSave!.gameType}');
    }
    
    _listener = AppLifecycleListener(
      onExitRequested: _onExitRequested,
    );
    
    // Track screen view
    PostHogService.trackGameEvent(
      event: 'screen_view',
      screen: 'game_screen',
      additionalProperties: {
        'game_initialized': false,
      },
    );
    
    // Start background initialization (non-blocking)
    debugPrint('🎮 GameScreen: About to initialize game assets in background');
    _initializeGameAssetsInBackground();
    
    debugPrint('🎮 GameScreen: initState() completed');
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
  
  /// Restore inventory from existing save data if available
  void _restoreInventoryFromSave() {
    debugPrint('🎒 GameScreen: _restoreInventoryFromSave called');
    if (widget.existingSave != null) {
      debugPrint('🎒 GameScreen: Processing save data for restoration');
      final saveData = widget.existingSave!;
      final saveService = GameSaveService();
      final restoredInventory = saveService.getInventory(saveData);
      
      if (restoredInventory != null && restoredInventory.isNotEmpty) {
        // Restore inventory from save data
        _ref.read(inventoryProvider.notifier).state = restoredInventory;
        debugPrint('🎒 GameScreen: Restored inventory from save: $restoredInventory');
        
        // Check for special items and update specialItemReceivedProvider accordingly
        _updateSpecialItemProvidersFromInventory(restoredInventory);
      } else {
        debugPrint('🎒 GameScreen: No inventory data found in save');
      }
    } else {
      debugPrint('🎒 GameScreen: No save data provided for restoration');
    }
  }

  void _updateSpecialItemProvidersFromInventory(Map<String, String?> inventory) {
    debugPrint('🔄 GameScreen: Checking inventory for special items to update NPC providers');
    
    // Check each item in the inventory against all NPCs' special items
    for (final item in inventory.values) {
      if (item == null) continue; // Skip null values
      
      // Find which NPC this special item belongs to
      for (final npcData in npcDataMap.values) {
        if (npcData.specialItemAsset == item) {
          // This is a special item from this NPC - mark as received
          _ref.read(specialItemReceivedProvider(npcData.id).notifier).state = true;
          debugPrint('🔄 GameScreen: Marked special item received for NPC ${npcData.id} (item: ${npcData.specialItemName})');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ GameScreen: build() called');
    return Consumer(
      builder: (context, ref, _) {
        _ref = ref;
        
        // Handle game state based on save data after build completes (when _ref is available)
        if (!_hasRestoredInventory) {
          _hasRestoredInventory = true; // Set flag immediately to prevent duplicates
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.existingSave != null) {
              debugPrint('🎒 GameScreen: Restoring inventory after build completes');
              _restoreInventoryFromSave();
            } else {
              debugPrint('🔄 GameScreen: No save data - ensuring fresh start');
              ref.resetForNewGame(); // Full reset for fresh start
            }
          });
        }
        
        // Game loading completion tutorial is now handled by main_navigation_screen.dart
        // with consolidated multi-slide tutorial - no separate tutorial needed here
        
        debugPrint('🏗️ GameScreen: About to access BabblelonGame.instance');
        final gameInstance = BabblelonGame.instance;
        debugPrint('🏗️ GameScreen: BabblelonGame.instance obtained: ${gameInstance.runtimeType}');
        
        return Scaffold(
          body: Stack(
            children: [
              RiverpodAwareGameWidget(
                key: gameWidgetKey,
                game: gameInstance,
                loadingBuilder: (context) {
                  debugPrint('🏗️ GameScreen: loadingBuilder called - showing CircularProgressIndicator');
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
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
                  'info_popup': (context, game) {
                    final config = ref.watch(popupConfigProvider);
                    if (config == null) {
                      return const SizedBox.shrink();
                    }
                    return InfoPopupOverlay(
                      title: config.title,
                      message: config.message,
                      confirmText: config.confirmText,
                      onConfirm: config.onConfirm,
                      cancelText: config.cancelText,
                      onCancel: config.onCancel,
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
    final game = BabblelonGame.instance;
    // Only add overlay if not already present
    if (!game.overlays.isActive('main_menu')) {
      if (!isPaused) {
        game.pauseGame(_ref);
      }
      game.overlays.add('main_menu');
    }
  }

  void _closeMenuAndResume() {
    final game = BabblelonGame.instance;
    game.overlays.remove('main_menu');
    game.resumeGame(_ref);
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
                  icon: gameState.soundEffectsEnabled ? Icons.graphic_eq : Icons.volume_mute,
                  label: gameState.soundEffectsEnabled ? 'SFX On' : 'SFX Off',
                  value: gameState.soundEffectsEnabled,
                  onChanged: (val) => ref.read(gameStateProvider.notifier).setSoundEffectsEnabled(val),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
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
                    backgroundColor: Colors.grey.withOpacity(0.3),
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
    final confirmed = await BasePopup.showPopup<bool>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Exit Level?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Are you sure you want to exit the level? Your progress will be saved automatically so you can continue from where you left off next time!',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    ref.playButtonSound();
                    Navigator.of(context).pop(false);
                  },
                  style: BasePopup.secondaryButtonStyle,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref.playButtonSound();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Exit Level'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Reset UI state and close any open overlays/menus
      try {
        // Clear any new item notifications and reset overlay visibility
        ref.read(gameStateProvider.notifier).clearNewItem();
        ref.read(dialogueOverlayVisibilityProvider.notifier).state = false;
        
        // Save game state before clearing inventory (for resume functionality)
        await ref.triggerInventorySave();
        
        // Clear inventory to prevent state mismatch with new game instance
        ref.clearInventory();
        
        debugPrint('🔄 GameScreen: Reset UI state on exit');
      } catch (e) {
        debugPrint('⚠️ GameScreen: Error resetting UI state: $e');
      }
      
      // Reset the entire game instance for clean state
      try {
        BabblelonGame.resetInstance();
        debugPrint('🔄 GameScreen: Reset game instance completely');
        
        // Also reset StaticGameLoader to ensure coordinated state
        final staticLoader = StaticGameLoader();
        staticLoader.reset();
        debugPrint('🔄 GameScreen: Reset StaticGameLoader state');
        
      } catch (e) {
        debugPrint('⚠️ GameScreen: Error resetting game instance: $e');
      }
      
      // Navigate away
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          (route) => false, // Remove all previous routes
        );
      }
      
      debugPrint('🎮 GameScreen: Navigation complete - game disposed itself properly');
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