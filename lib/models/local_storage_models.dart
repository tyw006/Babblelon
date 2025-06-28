import 'package:isar/isar.dart';

part 'local_storage_models.g.dart';

@collection
class PlayerProfile {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String userId;
  
  String? username;
  String? avatarUrl;
  int playerLevel = 1;
  int experiencePoints = 0;
  int gold = 0;
}

@collection
class MasteredPhrase {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String phraseEnglishId;
  
  double? lastScore;
  int timesPracticed = 1;
  DateTime? lastPracticedAt;
  bool isMastered = false;
} 