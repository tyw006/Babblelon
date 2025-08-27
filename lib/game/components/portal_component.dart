import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart' as tutorial_db;
import 'package:babblelon/models/popup_models.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/models/npc_data.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:babblelon/services/tutorial_service.dart';
import 'package:babblelon/services/game_save_service.dart';
import 'package:babblelon/services/boss_asset_preloader.dart';
import 'package:babblelon/models/battle_item.dart';

class PortalComponent extends SpriteComponent with HasGameReference<BabblelonGame>, TapCallbacks, RiverpodComponentMixin {
  // 🔧 COMPONENT IMPLEMENTATION: This handles HOW the portal looks and behaves
  // For basic configuration (size, position, boss), modify the portal creation in babblelon_game.dart
  
  final BossData bossData;
  final double desiredHeight;
  final Vector2 offsetFromBottomRight;

  PortalComponent({
    super.position,
    required this.bossData,
    this.desiredHeight = 180.0, // Default height, can be customized
    Vector2? offsetFromBottomRight, // Make it nullable with default in constructor body
  }) : offsetFromBottomRight = offsetFromBottomRight ?? Vector2(40, 0.02);

  @override
  Future<void> onLoad() async {
    // Load the portal image and create sprite
    final portalImage = await game.images.load('bosses/tuktuk/portal.png');
    sprite = Sprite(portalImage);
    
    // Calculate size maintaining aspect ratio
    final double aspectRatio = sprite!.srcSize.x / sprite!.srcSize.y;
    size = Vector2(desiredHeight * aspectRatio, desiredHeight);
    
    // Set portal to appear behind the player (priority -1 puts it same as NPCs, player defaults to 0)
    priority = -1;
    
    // Set anchor and calculate position relative to background
    anchor = Anchor.bottomRight;
    
    // If no specific position was provided, calculate from background dimensions
    if (position == Vector2.zero()) {
      final backgroundWidth = game.backgroundWidth;
      final backgroundHeight = game.backgroundHeight;
      position = Vector2(
        backgroundWidth - offsetFromBottomRight.x,
        backgroundHeight * (1 - offsetFromBottomRight.y),
      );
    }

    // Portal now has no glow animation
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Play button sound effect on portal tap with proper toggle check using extension method
    ref.playSound('soundeffects/soundeffect_button.mp3');
    // Fallback: also allow tap to trigger portal
    _triggerPortalDialog();
    super.onTapDown(event);
  }

  void _triggerPortalDialog() {
    // Check if both attack and defense slots have items equipped
    final inventory = ref.read(inventoryProvider);
    final hasAttackItem = inventory['attack'] != null;
    final hasDefenseItem = inventory['defense'] != null;
    final hasBothItems = hasAttackItem && hasDefenseItem;

    if (hasBothItems) {
      // Tutorial will be shown when boss fight screen loads instead
      
      // Player has items in both slots, show confirmation
      // Start preloading boss assets while user reads the dialog
      final preloader = BossAssetPreloader();
      final context = game.buildContext;
      if (context != null) {
        preloader.preloadBossAssets(
          context: context,
          ref: ref,
          bossData: bossData,
        );
      }
      
      final popupConfig = PopupConfig(
        title: 'Enter the Portal?',
        message: 'You have items equipped in both attack and defense slots. Do you want to proceed to the boss fight?',
        confirmText: 'Yes',
        onConfirm: (context) async {
          // Capture both navigator and a stable context before async operations
          final navigator = Navigator.of(context);
          final gameContext = game.buildContext;
          
          if (gameContext == null) {
            debugPrint('⚠️ PortalComponent: No game context available');
            return;
          }
          
          ref.read(popupConfigProvider.notifier).state = null;
          game.overlays.remove('info_popup');
          
          // Stop the game background music before transitioning
          FlameAudio.bgm.stop();
          
          // Delete exploration save since we're transitioning to boss fight
          final saveService = GameSaveService();
          await saveService.deleteSave('yaowarat_level'); // Delete exploration save
          
          // Get items from inventory and create BattleItem objects
          final inventory = ref.read(inventoryProvider);
          final attackItem = _createBattleItemFromPath(inventory['attack']!);
          final defenseItem = _createBattleItemFromPath(inventory['defense']!);
          
          debugPrint('🔥 PortalComponent: About to navigate to boss fight with captured navigator');
          
          // Use captured navigator reference with try-catch for safety
          try {
            navigator.push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => BossFightScreen(
                bossData: bossData,
                attackItem: attackItem,
                defenseItem: defenseItem,
                game: game,
                existingSave: null, // Fresh boss fight start from portal
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final progress = animation.value;
                    
                    // Phase 1 (0.0 -> 0.375): Fade to black
                    if (progress < 0.375) {
                      final fadeProgress = progress / 0.375; // 0.0 -> 1.0
                      return Container(
                        color: Colors.black.withValues(alpha: fadeProgress),
                        child: fadeProgress < 1.0 ? Container() : const Center(
                          child: CircularProgressIndicator(color: Colors.deepPurple),
                        ),
                      );
                    }
                    // Phase 2 (0.375 -> 0.625): Hold black (asset loading time)
                    else if (progress < 0.625) {
                      return Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.deepPurple),
                        ),
                      );
                    }
                    // Phase 3 (0.625 -> 1.0): Fade in boss fight screen
                    else {
                      final fadeInProgress = (progress - 0.625) / 0.375; // 0.0 -> 1.0
                      return Container(
                        color: Colors.black.withValues(alpha: 1.0 - fadeInProgress),
                        child: Opacity(
                          opacity: fadeInProgress,
                          child: child,
                        ),
                      );
                    }
                  },
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
          debugPrint('✅ PortalComponent: Boss fight navigation initiated successfully');
          } catch (e) {
            debugPrint('❌ PortalComponent: Navigation to boss fight failed: $e');
            // Optionally show an error dialog or handle the error gracefully
          }
        },
        cancelText: 'No',
        onCancel: (context) {
          ref.read(popupConfigProvider.notifier).state = null;
          game.overlays.remove('info_popup');
        },
      );
      ref.read(popupConfigProvider.notifier).state = popupConfig;
      game.overlays.add('info_popup');
    } else {
      // Show boss prerequisites tutorial if this is first time approaching without items
      if (!ref.read(tutorial_db.tutorialCompletionProvider.notifier).isTutorialCompleted('boss_prerequisites_warning')) {
        final context = game.buildContext;
        if (context != null) {
          final tutorialManager = TutorialManager(
            context: context,
            ref: ref,
          );
          
          // Show boss prerequisites tutorial (includes all necessary information)
          tutorialManager.startTutorial(TutorialTrigger.firstBossApproach);
        }
      } else {
        // For returning users who've seen the tutorial, show brief reminder
        String message;
        if (!hasAttackItem && !hasDefenseItem) {
          message = 'Collect attack and defense items from NPCs before entering!';
        } else if (!hasAttackItem) {
          message = 'You need an attack item from NPCs!';
        } else {
          message = 'You need a defense item from NPCs!';
        }
        
        final popupConfig = PopupConfig(
          title: 'Equipment Required',
          message: message,
          confirmText: 'OK',
          onConfirm: (context) {
            ref.read(popupConfigProvider.notifier).state = null;
            game.overlays.remove('info_popup');
          },
        );
        ref.read(popupConfigProvider.notifier).state = popupConfig;
        game.overlays.add('info_popup');
      }
    }
  }
  
  // Helper function to create BattleItem from asset path
  BattleItem _createBattleItemFromPath(String assetPath) {
    // Extract item name from asset path by checking against known items
    for (var npcData in npcDataMap.values) {
      if (npcData.regularItemAsset == assetPath) {
        return BattleItem(name: npcData.regularItemName, assetPath: assetPath, isSpecial: false);
      }
      if (npcData.specialItemAsset == assetPath) {
        return BattleItem(name: npcData.specialItemName, assetPath: assetPath, isSpecial: true);
      }
    }
    
    // Fallback: extract name from path
    final fileName = assetPath.split('/').last.split('.').first;
    final itemName = fileName.replaceAll('_', ' ').split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
    
    return BattleItem(name: itemName, assetPath: assetPath);
  }
} 