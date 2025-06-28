import 'package:flutter/foundation.dart';

@immutable
class BossData {
  final String name;
  final String spritePath;
  final int maxHealth;
  final String vocabularyPath;
  final String backgroundPath;
  final String languageName;
  final String languageFlag;

  const BossData({
    required this.name,
    required this.spritePath,
    required this.maxHealth,
    required this.vocabularyPath,
    required this.backgroundPath,
    this.languageName = 'Thai', // Default to Thai for now
    this.languageFlag = '🇹🇭', // Default to Thai flag
  });
} 