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
          NpcInteractionStateSchema,
          GameSaveStateSchema
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
  
  // Clear all data from the local database
  Future<void> clearAllData() async {
    await isar.writeTxn(() async {
      await isar.playerProfiles.clear();
      await isar.masteredPhrases.clear();
      await isar.customVocabularyEntrys.clear();
      await isar.currentSessions.clear();
      await isar.npcInteractionStates.clear();
      await isar.gameSaveStates.clear();
    });
  }

  // Game Save State methods (single-slot per level)
  Future<void> saveGameState(GameSaveState saveState) async {
    // Set expiry for automatic cleanup
    saveState.setExpiry();
    
    await isar.writeTxn(() async {
      // This will automatically replace any existing save for this levelId
      // due to the @Index(unique: true, replace: true) annotation
      await isar.gameSaveStates.put(saveState);
    });
  }

  Future<GameSaveState?> getGameSave(String levelId) async {
    final save = await isar.gameSaveStates.where().levelIdEqualTo(levelId).findFirst();
    
    // Check if save is expired and clean it up
    if (save != null && save.isExpired) {
      await clearGameSave(levelId);
      return null;
    }
    
    return save;
  }

  Future<void> clearGameSave(String levelId) async {
    await isar.writeTxn(() async {
      await isar.gameSaveStates.where().levelIdEqualTo(levelId).deleteAll();
    });
  }

  Future<List<GameSaveState>> getAllGameSaves() async {
    final saves = await isar.gameSaveStates.where().findAll();
    
    // Filter out expired saves and clean them up
    final validSaves = <GameSaveState>[];
    final expiredIds = <String>[];
    
    for (final save in saves) {
      if (save.isExpired) {
        expiredIds.add(save.levelId);
      } else {
        validSaves.add(save);
      }
    }
    
    // Clean up expired saves
    if (expiredIds.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final levelId in expiredIds) {
          await isar.gameSaveStates.where().levelIdEqualTo(levelId).deleteAll();
        }
      });
    }
    
    return validSaves;
  }

  Future<void> clearAllGameSaves() async {
    await isar.writeTxn(() async {
      await isar.gameSaveStates.clear();
    });
  }
} 