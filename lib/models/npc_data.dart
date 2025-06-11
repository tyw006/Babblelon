import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

@immutable
class NpcData {
  final String id;
  final String name;
  final String spritePath;
  final String dialoguePortraitPath;
  final String dialogueBackgroundPath;
  final String regularItemName;
  final String regularItemAsset;
  final String regularItemType;
  final String specialItemName;
  final String specialItemAsset;
  final String specialItemType;
  final Vector2 speechBubbleOffset;

  const NpcData({
    required this.id,
    required this.name,
    required this.spritePath,
    required this.dialoguePortraitPath,
    required this.dialogueBackgroundPath,
    required this.regularItemName,
    required this.regularItemAsset,
    required this.regularItemType,
    required this.specialItemName,
    required this.specialItemAsset,
    required this.specialItemType,
    required this.speechBubbleOffset,
  });
}

final Map<String, NpcData> npcDataMap = {
  'amara': NpcData(
    id: 'amara',
    name: 'Amara',
    spritePath: 'npcs/sprite_dimsum_vendor_female.png',
    dialoguePortraitPath: 'assets/images/npcs/sprite_dimsum_vendor_female_portrait.png',
    dialogueBackgroundPath: 'assets/images/background/convo_yaowarat_bg.png',
    regularItemName: 'Steamed Bun',
    regularItemAsset: 'assets/images/items/steambun_regular.png',
    regularItemType: 'attack',
    specialItemName: 'Golden Steamed Bun',
    specialItemAsset: 'assets/images/items/steambun_special.png',
    specialItemType: 'attack',
    speechBubbleOffset: Vector2(30, 30),
  ),
  'somchai': NpcData(
    id: 'somchai',
    name: 'Somchai',
    spritePath: 'npcs/sprite_kwaychap_vendor.png',
    dialoguePortraitPath: 'assets/images/npcs/sprite_kwaychap_vendor_portrait.png',
    dialogueBackgroundPath: 'assets/images/background/convo_yaowarat_bg1.png',
    regularItemName: 'Pork Belly',
    regularItemAsset: 'assets/images/items/porkbelly_regular.png',
    regularItemType: 'defense',
    specialItemName: 'Golden Pork Belly',
    specialItemAsset: 'assets/images/items/porkbelly_special.png',
    specialItemType: 'defense',
    speechBubbleOffset: Vector2(5, 15),
  ),
}; 