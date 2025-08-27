/// Battle item data structure for boss fight combat system
class BattleItem {
  final String name;
  final String assetPath;
  final bool isSpecial;
  
  const BattleItem({required this.name, required this.assetPath, this.isSpecial = false});
}