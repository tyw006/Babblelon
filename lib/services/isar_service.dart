import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:babblelon/models/local_storage_models.dart';

class IsarService {
  late Isar isar;

  static final IsarService _instance = IsarService._internal();

  factory IsarService() {
    return _instance;
  }

  IsarService._internal();

  static Future<void> init() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      _instance.isar = await Isar.open(
        [PlayerProfileSchema, MasteredPhraseSchema],
        directory: dir.path,
        inspector: true,
      );
    } else {
      _instance.isar = Isar.getInstance()!;
    }
  }

  Future<void> savePlayerProfile(PlayerProfile profile) async {
    await isar.writeTxn(() async {
      await isar.playerProfiles.put(profile);
    });
  }

  Future<PlayerProfile?> getPlayerProfile(String userId) async {
    return await isar.playerProfiles.where().userIdEqualTo(userId).findFirst();
  }

  Future<void> saveMasteredPhrase(MasteredPhrase phrase) async {
    await isar.writeTxn(() async {
      await isar.masteredPhrases.put(phrase);
    });
  }

  Future<MasteredPhrase?> getMasteredPhrase(String phraseEnglishId) async {
    return await isar.masteredPhrases.where().phraseEnglishIdEqualTo(phraseEnglishId).findFirst();
  }

  Future<List<MasteredPhrase>> getAllMasteredPhrases() async {
    return await isar.masteredPhrases.where().findAll();
  }
} 