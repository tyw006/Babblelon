import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/models/npc_data.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';

class PortalComponent extends SpriteComponent with HasGameRef<BabblelonGame>, TapCallbacks, RiverpodComponentMixin {
  // 🔧 COMPONENT IMPLEMENTATION: This handles HOW the portal looks and behaves
  // For basic configuration (size, position, boss), modify the portal creation in babblelon_game.dart
  
  final BossData bossData;
  final double desiredHeight;
  final Vector2 offsetFromBottomRight;
  bool _hasTriggered = false; // Prevent multiple triggers

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
    // Play button sound effect on portal tap
    FlameAudio.play('soundeffects/soundeffect_button.mp3');
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
      // Player has items in both slots, show confirmation
      final popupConfig = PopupConfig(
        title: 'Enter the Portal?',
        message: 'You have items equipped in both attack and defense slots. Do you want to proceed to the boss fight?',
        confirmText: 'Yes',
        onConfirm: (context) {
          ref.read(popupConfigProvider.notifier).state = null;
          game.overlays.remove('info_popup');
          
          // Stop the game background music before transitioning
          FlameAudio.bgm.stop();
          
          // Get items from inventory and create BattleItem objects
          final inventory = ref.read(inventoryProvider);
          final attackItem = _createBattleItemFromPath(inventory['attack']!);
          final defenseItem = _createBattleItemFromPath(inventory['defense']!);
          
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => BossFightScreen(
                bossData: bossData,
                attackItem: attackItem,
                defenseItem: defenseItem,
                game: game,
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
        cancelText: 'No',
        onCancel: (context) {
          ref.read(popupConfigProvider.notifier).state = null;
          game.overlays.remove('info_popup');
        },
      );
      ref.read(popupConfigProvider.notifier).state = popupConfig;
      game.overlays.add('info_popup');
    } else {
      // Player is missing items in one or both slots
      String message;
      if (!hasAttackItem && !hasDefenseItem) {
        message = 'You need to collect items for both your attack and defense slots before entering the portal.\n\nTalk to NPCs around the town to collect items!';
      } else if (!hasAttackItem) {
        message = 'You need an attack item before entering the portal.\n\nTalk to NPCs around the town to collect an attack item!';
      } else {
        message = 'You need a defense item before entering the portal.\n\nTalk to NPCs around the town to collect a defense item!';
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