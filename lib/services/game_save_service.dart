import 'dart:convert';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

/// Service for managing game save states with single-slot per level storage
class GameSaveService {
  static final GameSaveService _instance = GameSaveService._internal();
  factory GameSaveService() => _instance;
  GameSaveService._internal();

  final IsarService _isarService = IsarService();

  /// Save current game state - automatically overwrites existing save for this level
  Future<void> saveGameState({
    required String levelId,
    required String gameType,
    Vector2? playerPosition,
    Map<String, String?>? inventory,
    List<String>? conversationHistory,
    List<String>? cachedAudioPaths,
    Map<String, dynamic>? npcStates,
    // Boss fight specific
    String? bossId,
    String? currentTurn,
    int? playerHealth,
    int? bossHealth,
    List<int>? usedFlashcards,
    List<int>? activeFlashcards, // New: indices of cards currently on screen
    Set<String>? revealedCards, // New: IDs of cards that have been revealed/tapped
    Map<String, dynamic>? battleMetrics,
    // Progress metadata
    double progressPercentage = 0.0,
    int npcsVisited = 0,
    int itemsCollected = 0,
  }) async {
    try {
      final saveState = GameSaveState()
        ..levelId = levelId
        ..gameType = gameType
        ..timestamp = DateTime.now()
        ..progressPercentage = progressPercentage
        ..npcsVisited = npcsVisited
        ..itemsCollected = itemsCollected;

      // Serialize BabblelonGame state
      if (gameType == 'babblelon_game') {
        if (playerPosition != null) {
          saveState.playerPositionJson = jsonEncode({
            'x': playerPosition.x,
            'y': playerPosition.y,
          });
        }
        
        if (inventory != null) {
          saveState.inventoryJson = jsonEncode(inventory);
        }
        
        if (conversationHistory != null) {
          // Keep only last 10 messages to save space
          final limitedHistory = conversationHistory.length > 10
              ? conversationHistory.sublist(conversationHistory.length - 10)
              : conversationHistory;
          saveState.conversationHistoryJson = jsonEncode(limitedHistory);
        }
        
        if (cachedAudioPaths != null) {
          saveState.cachedAudioPaths = cachedAudioPaths;
        }
        
        if (npcStates != null) {
          saveState.npcStatesJson = jsonEncode(npcStates);
        }
      }

      // Serialize Boss Fight state
      if (gameType == 'boss_fight') {
        saveState.bossId = bossId;
        saveState.currentTurn = currentTurn;
        saveState.playerHealth = playerHealth;
        saveState.bossHealth = bossHealth;
        
        // Save inventory for boss fights too
        if (inventory != null) {
          saveState.inventoryJson = jsonEncode(inventory);
        }
        
        if (usedFlashcards != null) {
          saveState.usedFlashcardsJson = jsonEncode(usedFlashcards);
        }
        
        if (activeFlashcards != null) {
          saveState.activeFlashcardsJson = jsonEncode(activeFlashcards);
        }
        
        if (revealedCards != null) {
          saveState.revealedCardsJson = jsonEncode(revealedCards.toList());
        }
        
        if (battleMetrics != null) {
          saveState.battleMetricsJson = jsonEncode(battleMetrics);
        }
      }

      await _isarService.saveGameState(saveState);
      debugPrint('💾 GameSaveService: Saved $gameType state for level $levelId');
      
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to save game state: $e');
      rethrow;
    }
  }

  /// Load game save for a specific level
  Future<GameSaveState?> loadGameState(String levelId) async {
    try {
      final saveState = await _isarService.getGameSave(levelId);
      
      if (saveState != null) {
        debugPrint('📂 GameSaveService: Loaded save for level $levelId (${saveState.gameType})');
      } else {
        debugPrint('📂 GameSaveService: No save found for level $levelId');
      }
      
      return saveState;
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to load game state: $e');
      return null;
    }
  }

  /// Get parsed player position from save state
  Vector2? getPlayerPosition(GameSaveState saveState) {
    if (saveState.playerPositionJson == null) return null;
    
    try {
      final data = jsonDecode(saveState.playerPositionJson!) as Map<String, dynamic>;
      return Vector2(
        (data['x'] as num).toDouble(),
        (data['y'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse player position: $e');
      return null;
    }
  }

  /// Get parsed inventory from save state
  Map<String, String?>? getInventory(GameSaveState saveState) {
    if (saveState.inventoryJson == null) return null;
    
    try {
      final data = jsonDecode(saveState.inventoryJson!) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, value as String?));
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse inventory: $e');
      return null;
    }
  }

  /// Get parsed conversation history from save state
  List<String>? getConversationHistory(GameSaveState saveState) {
    if (saveState.conversationHistoryJson == null) return null;
    
    try {
      final data = jsonDecode(saveState.conversationHistoryJson!) as List<dynamic>;
      return data.cast<String>();
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse conversation history: $e');
      return null;
    }
  }

  /// Get parsed NPC states from save state
  Map<String, dynamic>? getNpcStates(GameSaveState saveState) {
    if (saveState.npcStatesJson == null) return null;
    
    try {
      return jsonDecode(saveState.npcStatesJson!) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse NPC states: $e');
      return null;
    }
  }

  /// Get parsed used flashcards from save state
  List<int>? getUsedFlashcards(GameSaveState saveState) {
    if (saveState.usedFlashcardsJson == null) return null;
    
    try {
      final data = jsonDecode(saveState.usedFlashcardsJson!) as List<dynamic>;
      return data.cast<int>();
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse used flashcards: $e');
      return null;
    }
  }

  /// Get parsed active flashcards (currently on screen) from save state
  List<int>? getActiveFlashcards(GameSaveState saveState) {
    if (saveState.activeFlashcardsJson == null) return null;
    
    try {
      final data = jsonDecode(saveState.activeFlashcardsJson!) as List<dynamic>;
      return data.cast<int>();
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse active flashcards: $e');
      return null;
    }
  }

  /// Get parsed revealed cards from save state
  Set<String>? getRevealedCards(GameSaveState saveState) {
    if (saveState.revealedCardsJson == null) return null;
    
    try {
      final data = jsonDecode(saveState.revealedCardsJson!) as List<dynamic>;
      return data.cast<String>().toSet();
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse revealed cards: $e');
      return null;
    }
  }

  /// Get parsed battle metrics from save state
  Map<String, dynamic>? getBattleMetrics(GameSaveState saveState) {
    if (saveState.battleMetricsJson == null) return null;
    
    try {
      return jsonDecode(saveState.battleMetricsJson!) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to parse battle metrics: $e');
      return null;
    }
  }

  /// Delete save for a specific level
  Future<void> deleteSave(String levelId) async {
    try {
      await _isarService.clearGameSave(levelId);
      debugPrint('🗑️ GameSaveService: Deleted save for level $levelId');
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to delete save: $e');
    }
  }

  /// Get all available saves with their metadata
  Future<List<GameSaveState>> getAllSaves() async {
    try {
      final saves = await _isarService.getAllGameSaves();
      debugPrint('📂 GameSaveService: Found ${saves.length} saves');
      return saves;
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to get all saves: $e');
      return [];
    }
  }

  /// Clear all saves (useful for testing or reset)
  Future<void> clearAllSaves() async {
    try {
      await _isarService.clearAllGameSaves();
      debugPrint('🗑️ GameSaveService: Cleared all saves');
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to clear all saves: $e');
    }
  }

  /// Check if a level has a save available
  Future<bool> hasSave(String levelId) async {
    final save = await loadGameState(levelId);
    return save != null;
  }

  /// Get save metadata for UI display
  Future<Map<String, dynamic>?> getSaveMetadata(String levelId) async {
    final save = await loadGameState(levelId);
    
    if (save == null) return null;
    
    return {
      'timestamp': save.timestamp,
      'gameType': save.gameType,
      'progressPercentage': save.progressPercentage,
      'npcsVisited': save.npcsVisited,
      'itemsCollected': save.itemsCollected,
      'levelId': save.levelId,
      'timeSinceLastSave': DateTime.now().difference(save.timestamp),
    };
  }

  /// Delete all saves related to a level (both exploration and boss saves)
  Future<void> deleteAllLevelSaves(String levelId) async {
    try {
      // Delete exploration save
      await deleteSave(levelId);
      
      // Delete boss save (boss level ID format: boss_[boss_name])
      // We need to find any boss saves that might be related to this level
      final allSaves = await getAllSaves();
      for (final save in allSaves) {
        if (save.levelId.startsWith('boss_') && save.gameType == 'boss_fight') {
          await deleteSave(save.levelId);
        }
      }
      
      debugPrint('🗑️ GameSaveService: Deleted all saves for level $levelId');
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to delete all level saves: $e');
    }
  }

  /// Reset boss fight HP in save state (for when boss defeats player)
  Future<void> resetBossFightHP(String bossLevelId, int maxPlayerHP, int maxBossHP) async {
    try {
      final existingSave = await loadGameState(bossLevelId);
      if (existingSave != null && existingSave.gameType == 'boss_fight') {
        // Update the save with reset HP values
        await saveGameState(
          levelId: bossLevelId,
          gameType: 'boss_fight',
          bossId: existingSave.bossId,
          currentTurn: 'player', // Reset to player turn
          playerHealth: maxPlayerHP, // Reset to full HP
          bossHealth: maxBossHP, // Reset to full HP
          usedFlashcards: [], // Clear used flashcards for fresh retry
          battleMetrics: getBattleMetrics(existingSave), // Keep battle metrics
          progressPercentage: existingSave.progressPercentage, // Keep progress
          npcsVisited: existingSave.npcsVisited,
          itemsCollected: existingSave.itemsCollected,
        );
        
        debugPrint('🔄 GameSaveService: Reset HP for boss fight $bossLevelId');
      }
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to reset boss fight HP: $e');
    }
  }

  /// Enhanced reset method for boss fight defeat retry with options
  Future<void> resetBossFightForRetry(
    String bossLevelId,
    int maxPlayerHP,
    int maxBossHP, {
    bool randomizeTurn = true,
    bool clearFlashcards = true,
  }) async {
    try {
      final existingSave = await loadGameState(bossLevelId);
      if (existingSave != null && existingSave.gameType == 'boss_fight') {
        // Determine turn - randomize or default to player
        String turn = 'player';
        if (randomizeTurn) {
          final isPlayerTurn = DateTime.now().millisecondsSinceEpoch % 2 == 0;
          turn = isPlayerTurn ? 'player' : 'boss';
          debugPrint('🎲 GameSaveService: Randomized turn to: $turn');
        }
        
        // Update the save with reset values
        await saveGameState(
          levelId: bossLevelId,
          gameType: 'boss_fight',
          bossId: existingSave.bossId,
          currentTurn: turn,
          playerHealth: maxPlayerHP, // Reset to full HP
          bossHealth: maxBossHP, // Reset to full HP
          usedFlashcards: clearFlashcards ? [] : getUsedFlashcards(existingSave),
          activeFlashcards: [], // Clear active flashcards for fresh battle
          revealedCards: <String>{}, // Clear revealed cards
          battleMetrics: getBattleMetrics(existingSave), // Keep battle metrics
          progressPercentage: existingSave.progressPercentage, // Keep progress
          npcsVisited: existingSave.npcsVisited,
          itemsCollected: existingSave.itemsCollected,
        );
        
        debugPrint('🔄 GameSaveService: Reset boss fight for retry (randomizeTurn: $randomizeTurn, clearFlashcards: $clearFlashcards)');
      }
    } catch (e) {
      debugPrint('❌ GameSaveService: Failed to reset boss fight for retry: $e');
    }
  }
}