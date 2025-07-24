import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/quest_models.dart';
import 'dart:convert';

part 'quest_providers.g.dart';

/// Manages quest state for a specific NPC
@riverpod
class NpcQuestState extends _$NpcQuestState {
  @override
  NpcQuestConfig build(String npcId) {
    // Initialize with default quest state - will be updated from backend
    return NpcQuestConfig(
      npcId: npcId,
      npcName: _getNpcName(npcId),
      questState: const QuestState(
        categoriesNeeded: [],
        scenarioComplete: false,
      ),
    );
  }

  /// Update quest state from backend response
  void updateFromBackend(Map<String, dynamic> questStateJson) {
    try {
      final currentState = state;
      final updatedQuestState = QuestState.fromJson(questStateJson);
      
      state = currentState.copyWith(
        questState: updatedQuestState,
      );
    } catch (e) {
      print('Error updating quest state from backend: $e');
    }
  }

  /// Update quest state with new item giving results
  void updateWithItemGiving(String item, bool accepted, String? category) {
    final currentState = state;
    final updatedItemsGiven = [...currentState.itemsGiven, item];
    
    Map<String, String> updatedCategoriesAccepted = {...currentState.categoriesAccepted};
    if (accepted && category != null) {
      updatedCategoriesAccepted[category] = item;
    }

    // Check if quest is complete
    final questComplete = updatedCategoriesAccepted.length == currentState.questState.categoriesNeeded.length;

    state = currentState.copyWith(
      itemsGiven: updatedItemsGiven,
      categoriesAccepted: updatedCategoriesAccepted,
      questState: currentState.questState.copyWith(
        scenarioComplete: questComplete,
      ),
    );
  }

  /// Update charm level
  void updateCharmLevel(int newCharmLevel) {
    state = state.copyWith(charmLevel: newCharmLevel);
  }

  /// Update conversation history
  void updateConversationHistory(String newHistory) {
    state = state.copyWith(conversationHistory: newHistory);
  }

  /// Reset quest state for new conversation
  void reset() {
    state = NpcQuestConfig(
      npcId: state.npcId,
      npcName: state.npcName,
      questState: const QuestState(
        categoriesNeeded: [],
        scenarioComplete: false,
      ),
    );
  }

  /// Get NPC name from ID
  String _getNpcName(String npcId) {
    switch (npcId.toLowerCase()) {
      case 'amara':
        return 'Amara';
      case 'somchai':
        return 'Somchai';
      default:
        return npcId;
    }
  }
}

/// Provider for item giving mode state
@riverpod
class ItemGivingMode extends _$ItemGivingMode {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void enable() => state = true;
  void disable() => state = false;
}

/// Computed provider for quest progress
@riverpod
QuestProgress questProgress(QuestProgressRef ref, String npcId) {
  final questConfig = ref.watch(npcQuestStateProvider(npcId));
  
  final categoriesNeeded = questConfig.questState.categoriesNeeded;
  final categoriesAccepted = questConfig.categoriesAccepted;
  final itemsGiven = questConfig.itemsGiven;
  
  final categoriesSatisfied = categoriesAccepted.keys.toList();
  final categoriesRemaining = categoriesNeeded.where((c) => !categoriesAccepted.containsKey(c)).toList();
  
  // Calculate current and next category needed
  final currentCategoryNeeded = categoriesRemaining.isNotEmpty ? categoriesRemaining.first : "None (quest complete)";
  final nextCategoryNeeded = categoriesRemaining.length > 1 ? categoriesRemaining[1] : 
                             categoriesRemaining.length == 1 ? "None (final category)" : 
                             "None (quest complete)";
  
  return QuestProgress(
    progress: "${categoriesSatisfied.length}/${categoriesNeeded.length}",
    categoriesSatisfied: categoriesSatisfied,
    categoriesRemaining: categoriesRemaining,
    currentCategoryNeeded: currentCategoryNeeded,
    nextCategoryNeeded: nextCategoryNeeded,
    acceptedItems: categoriesAccepted,
    allItemsGiven: itemsGiven,
    complete: questConfig.questState.scenarioComplete,
  );
}

/// Provider for quest categories with visual state
@riverpod
List<QuestCategory> questCategories(QuestCategoriesRef ref, String npcId) {
  final questConfig = ref.watch(npcQuestStateProvider(npcId));
  final progress = ref.watch(questProgressProvider(npcId));
  
  return questConfig.questState.categoriesNeeded.map((categoryName) {
    final isCompleted = questConfig.categoriesAccepted.containsKey(categoryName);
    final isCurrent = categoryName == progress.currentCategoryNeeded;
    final acceptedItem = questConfig.categoriesAccepted[categoryName];
    
    return QuestCategory(
      name: categoryName,
      description: _getCategoryDescription(categoryName),
      acceptedItem: acceptedItem,
      isCompleted: isCompleted,
      isCurrent: isCurrent,
    );
  }).toList();
}

/// Provides quest state as JSON for backend API
@riverpod
String questStateJson(QuestStateJsonRef ref, String npcId) {
  final questConfig = ref.watch(npcQuestStateProvider(npcId));
  
  final questStateMap = {
    'name': questConfig.npcName,
    'quest_state': questConfig.questState.toJson(),
    'items_given': questConfig.itemsGiven,
    'categories_accepted': questConfig.categoriesAccepted,
  };
  
  return jsonEncode(questStateMap);
}

/// Helper function to get category descriptions
String _getCategoryDescription(String categoryName) {
  switch (categoryName) {
    // Amara (recipe creation) categories
    case 'Proteins':
      return 'Main protein ingredient (meat, fish, tofu)';
    case 'Aromatics':
      return 'Fragrant ingredients (garlic, ginger, herbs)';
    case 'Sauces/Flavors':
      return 'Sauces and seasonings for taste';
    case 'Textures/Garnishes':
      return 'Ingredients for texture and appearance';
    case 'Vegetables':
      return 'Fresh vegetables and greens';
    
    // Somchai (customer service) categories
    case 'Tableware/Utensils':
      return 'Bowls, spoons, and eating utensils';
    case 'Drinks':
      return 'Beverages for the customer';
    case 'Condiments':
      return 'Sauces and condiments for seasoning';
    case 'Customer Actions/Requests':
      return 'Special requests or instructions';
    case 'Service Items':
      return 'Additional service items like menus';
    
    default:
      return 'Quest category item';
  }
}