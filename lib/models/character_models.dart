/// Character models for player avatars in the game
class GameCharacter {
  final String id;
  final String name;
  final String displayName;
  final String spriteSheetPath;
  final String thumbnailPath;
  final String culturalBackground;
  final String description;
  final Map<String, dynamic> defaultCustomization;
  final List<String> availableOutfits;
  final bool isPremium;
  
  const GameCharacter({
    required this.id,
    required this.name,
    required this.displayName,
    required this.spriteSheetPath,
    required this.thumbnailPath,
    required this.culturalBackground,
    required this.description,
    required this.defaultCustomization,
    this.availableOutfits = const [],
    this.isPremium = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'spriteSheetPath': spriteSheetPath,
      'thumbnailPath': thumbnailPath,
      'culturalBackground': culturalBackground,
      'description': description,
      'defaultCustomization': defaultCustomization,
      'availableOutfits': availableOutfits,
      'isPremium': isPremium,
    };
  }
  
  factory GameCharacter.fromJson(Map<String, dynamic> json) {
    return GameCharacter(
      id: json['id'],
      name: json['name'],
      displayName: json['displayName'],
      spriteSheetPath: json['spriteSheetPath'],
      thumbnailPath: json['thumbnailPath'],
      culturalBackground: json['culturalBackground'],
      description: json['description'],
      defaultCustomization: Map<String, dynamic>.from(json['defaultCustomization'] ?? {}),
      availableOutfits: List<String>.from(json['availableOutfits'] ?? []),
      isPremium: json['isPremium'] ?? false,
    );
  }
}

/// Character customization options
class CharacterCustomization {
  final String skinTone;
  final String outfitColor;
  final String hairStyle;
  final Map<String, dynamic> accessories;
  
  const CharacterCustomization({
    required this.skinTone,
    required this.outfitColor,
    required this.hairStyle,
    this.accessories = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'skinTone': skinTone,
      'outfitColor': outfitColor,
      'hairStyle': hairStyle,
      'accessories': accessories,
    };
  }
  
  factory CharacterCustomization.fromJson(Map<String, dynamic> json) {
    return CharacterCustomization(
      skinTone: json['skinTone'] ?? 'default',
      outfitColor: json['outfitColor'] ?? 'blue',
      hairStyle: json['hairStyle'] ?? 'default',
      accessories: Map<String, dynamic>.from(json['accessories'] ?? {}),
    );
  }
}

/// Predefined character options - Simplified to 2 base characters
class CharacterDatabase {
  static const List<GameCharacter> availableCharacters = [
    GameCharacter(
      id: 'male_tourist',
      name: 'Male Tourist',
      displayName: 'Male Tourist',
      spriteSheetPath: 'assets/images/player/sprite_male_tourist.png',
      thumbnailPath: 'assets/images/player/sprite_male_tourist.png',
      culturalBackground: 'International',
      description: 'Ready for adventure!',
      defaultCustomization: {},
      availableOutfits: [],
    ),
    GameCharacter(
      id: 'female_tourist',
      name: 'Female Tourist',
      displayName: 'Female Tourist',
      spriteSheetPath: 'assets/images/player/sprite_female_tourist.png',
      thumbnailPath: 'assets/images/player/sprite_female_tourist.png',
      culturalBackground: 'International',
      description: 'Excited to explore!',
      defaultCustomization: {},
      availableOutfits: [],
    ),
  ];
  
  static GameCharacter? getCharacterById(String id) {
    try {
      return availableCharacters.firstWhere((char) => char.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static GameCharacter getDefaultCharacter() {
    return availableCharacters.first;
  }
}