import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:flutter/material.dart';

class PortalComponent extends SpriteComponent with HasGameRef<BabblelonGame>, TapCallbacks, RiverpodComponentMixin {
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

    // Add a hitbox to ensure tap events are properly detected
    add(RectangleHitbox());
  }

  @override
  void onTapDown(TapDownEvent event) {
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BossFightScreen(bossData: bossData),
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
      String missingItems = '';
      if (!hasAttackItem && !hasDefenseItem) {
        missingItems = 'attack and defense';
      } else if (!hasAttackItem) {
        missingItems = 'attack';
      } else {
        missingItems = 'defense';
      }
      
      final popupConfig = PopupConfig(
        title: 'Equipment Required',
        message: 'You must have items equipped in both attack and defense slots before you can proceed. You are missing an item in your $missingItems slot.',
        confirmText: 'OK',
        onConfirm: (context) {
          ref.read(popupConfigProvider.notifier).state = null;
          game.overlays.remove('info_popup');
        },
      );
      ref.read(popupConfigProvider.notifier).state = popupConfig;
      game.overlays.add('info_popup');
    }
    // Mark the event as handled so it doesn't propagate to other components (like the game for player movement)
    event.handled = true;
    super.onTapDown(event);
  }
} 