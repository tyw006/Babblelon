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
        [
          PlayerProfileSchema, 
          MasteredPhraseSchema, 
          CustomVocabularyEntrySchema,
          CurrentSessionSchema,
          NpcInteractionStateSchema
        ],
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

  Future<void> saveCustomVocabulary(CustomVocabularyEntry word) async {
    await isar.writeTxn(() async {
      await isar.customVocabularyEntrys.put(word);
    });
  }

  Future<CustomVocabularyEntry?> getCustomVocabulary(String wordThai) async {
    return await isar.customVocabularyEntrys.where().wordThaiEqualTo(wordThai).findFirst();
  }

  Future<List<CustomVocabularyEntry>> getAllCustomVocabulary() async {
    return await isar.customVocabularyEntrys.where().findAll();
  }

  // Current Session methods (only active session)
  Future<void> saveCurrentSession(CurrentSession session) async {
    await isar.writeTxn(() async {
      await isar.currentSessions.put(session);
    });
  }

  Future<CurrentSession?> getCurrentSession() async {
    // Only one active session at a time
    return await isar.currentSessions.where().findFirst();
  }

  Future<void> clearCurrentSession() async {
    await isar.writeTxn(() async {
      await isar.currentSessions.clear();
    });
  }

  // NPC Interaction State methods
  Future<void> saveNpcInteractionState(NpcInteractionState state) async {
    await isar.writeTxn(() async {
      await isar.npcInteractionStates.put(state);
    });
  }

  Future<NpcInteractionState?> getNpcInteractionState(String npcId) async {
    return await isar.npcInteractionStates.where().npcIdEqualTo(npcId).findFirst();
  }

  Future<List<NpcInteractionState>> getAllNpcInteractionStates() async {
    return await isar.npcInteractionStates.where().findAll();
  }
} 