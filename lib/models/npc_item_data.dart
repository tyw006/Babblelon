import 'package:flutter/foundation.dart';

@immutable
class NpcItemData {
  final String npcId;
  final String npcName;
  final String regularItem;
  final String regularItemAsset;
  final String specialItem;
  final String specialItemAsset;

  const NpcItemData({
    required this.npcId,
    required this.npcName,
    required this.regularItem,
    required this.regularItemAsset,
    required this.specialItem,
    required this.specialItemAsset,
  });
}

final Map<String, NpcItemData> npcItemDataMap = {
  'amara': const NpcItemData(
    npcId: 'amara',
    npcName: 'Amara',
    regularItem: 'Steamed Bun',
    regularItemAsset: 'assets/images/items/steambun_regular.png',
    specialItem: 'Golden Steamed Bun',
    specialItemAsset: 'assets/images/items/steambun_special.png',
  ),
  'somchai': const NpcItemData(
    npcId: 'somchai',
    npcName: 'Somchai',
    regularItem: 'a stack of bowls',
    regularItemAsset: 'assets/images/items/porkbelly_regular.png',
    specialItem: 'a magical golden bowl',
    specialItemAsset: 'assets/images/items/porkbelly_special.png',
  ),
}; 