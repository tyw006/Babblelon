/// Represents the state of an NPC's quest
class QuestState {
  final List<String> categoriesNeeded;
  final Map<String, String> categoriesAccepted;
  final List<String> itemsGiven;
  final bool scenarioComplete;
  final String? currentCategoryNeeded;
  final String? nextCategoryNeeded;
  final int conversationTurns;

  const QuestState({
    required this.categoriesNeeded,
    this.categoriesAccepted = const {},
    this.itemsGiven = const [],
    this.scenarioComplete = false,
    this.currentCategoryNeeded,
    this.nextCategoryNeeded,
    this.conversationTurns = 0,
  });

  QuestState copyWith({
    List<String>? categoriesNeeded,
    Map<String, String>? categoriesAccepted,
    List<String>? itemsGiven,
    bool? scenarioComplete,
    String? currentCategoryNeeded,
    String? nextCategoryNeeded,
    int? conversationTurns,
  }) {
    return QuestState(
      categoriesNeeded: categoriesNeeded ?? this.categoriesNeeded,
      categoriesAccepted: categoriesAccepted ?? this.categoriesAccepted,
      itemsGiven: itemsGiven ?? this.itemsGiven,
      scenarioComplete: scenarioComplete ?? this.scenarioComplete,
      currentCategoryNeeded: currentCategoryNeeded ?? this.currentCategoryNeeded,
      nextCategoryNeeded: nextCategoryNeeded ?? this.nextCategoryNeeded,
      conversationTurns: conversationTurns ?? this.conversationTurns,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories_needed': categoriesNeeded,
      'categories_accepted': categoriesAccepted,
      'items_given': itemsGiven,
      'scenario_complete': scenarioComplete,
      'current_category_needed': currentCategoryNeeded,
      'next_category_needed': nextCategoryNeeded,
      'conversation_turns': conversationTurns,
    };
  }

  factory QuestState.fromJson(Map<String, dynamic> json) {
    return QuestState(
      categoriesNeeded: List<String>.from(json['categories_needed'] ?? []),
      categoriesAccepted: Map<String, String>.from(json['categories_accepted'] ?? {}),
      itemsGiven: List<String>.from(json['items_given'] ?? []),
      scenarioComplete: json['scenario_complete'] ?? false,
      currentCategoryNeeded: json['current_category_needed'],
      nextCategoryNeeded: json['next_category_needed'],
      conversationTurns: json['conversation_turns'] ?? 0,
    );
  }
}

/// Computed quest progress information
class QuestProgress {
  final String progress;
  final List<String> categoriesSatisfied;
  final List<String> categoriesRemaining;
  final String currentCategoryNeeded;
  final String nextCategoryNeeded;
  final Map<String, String> acceptedItems;
  final List<String> allItemsGiven;
  final bool complete;

  const QuestProgress({
    required this.progress,
    required this.categoriesSatisfied,
    required this.categoriesRemaining,
    required this.currentCategoryNeeded,
    required this.nextCategoryNeeded,
    required this.acceptedItems,
    required this.allItemsGiven,
    required this.complete,
  });

  Map<String, dynamic> toJson() {
    return {
      'progress': progress,
      'categories_satisfied': categoriesSatisfied,
      'categories_remaining': categoriesRemaining,
      'current_category_needed': currentCategoryNeeded,
      'next_category_needed': nextCategoryNeeded,
      'accepted_items': acceptedItems,
      'all_items_given': allItemsGiven,
      'complete': complete,
    };
  }

  factory QuestProgress.fromJson(Map<String, dynamic> json) {
    return QuestProgress(
      progress: json['progress'] ?? '0/0',
      categoriesSatisfied: List<String>.from(json['categories_satisfied'] ?? []),
      categoriesRemaining: List<String>.from(json['categories_remaining'] ?? []),
      currentCategoryNeeded: json['current_category_needed'] ?? '',
      nextCategoryNeeded: json['next_category_needed'] ?? '',
      acceptedItems: Map<String, String>.from(json['accepted_items'] ?? {}),
      allItemsGiven: List<String>.from(json['all_items_given'] ?? []),
      complete: json['complete'] ?? false,
    );
  }
}

/// Represents an NPC's complete quest configuration
class NpcQuestConfig {
  final String npcId;
  final String npcName;
  final QuestState questState;
  final Map<String, String> categoriesAccepted;
  final List<String> itemsGiven;
  final int charmLevel;
  final String conversationHistory;
  final String level;

  const NpcQuestConfig({
    required this.npcId,
    required this.npcName,
    required this.questState,
    this.categoriesAccepted = const {},
    this.itemsGiven = const [],
    this.charmLevel = 50,
    this.conversationHistory = "",
    this.level = "beginner",
  });

  NpcQuestConfig copyWith({
    String? npcId,
    String? npcName,
    QuestState? questState,
    Map<String, String>? categoriesAccepted,
    List<String>? itemsGiven,
    int? charmLevel,
    String? conversationHistory,
    String? level,
  }) {
    return NpcQuestConfig(
      npcId: npcId ?? this.npcId,
      npcName: npcName ?? this.npcName,
      questState: questState ?? this.questState,
      categoriesAccepted: categoriesAccepted ?? this.categoriesAccepted,
      itemsGiven: itemsGiven ?? this.itemsGiven,
      charmLevel: charmLevel ?? this.charmLevel,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      level: level ?? this.level,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'npc_id': npcId,
      'npc_name': npcName,
      'quest_state': questState.toJson(),
      'categories_accepted': categoriesAccepted,
      'items_given': itemsGiven,
      'charm_level': charmLevel,
      'conversation_history': conversationHistory,
      'level': level,
    };
  }

  factory NpcQuestConfig.fromJson(Map<String, dynamic> json) {
    return NpcQuestConfig(
      npcId: json['npc_id'] ?? '',
      npcName: json['npc_name'] ?? '',
      questState: QuestState.fromJson(json['quest_state'] ?? {}),
      categoriesAccepted: Map<String, String>.from(json['categories_accepted'] ?? {}),
      itemsGiven: List<String>.from(json['items_given'] ?? []),
      charmLevel: json['charm_level'] ?? 50,
      conversationHistory: json['conversation_history'] ?? '',
      level: json['level'] ?? 'beginner',
    );
  }
}

/// Quest completion information
class QuestCompletion {
  final String npcId;
  final String npcName;
  final int finalCharmLevel;
  final Map<String, String> acceptedItems;
  final DateTime completedAt;
  final int experienceGained;

  const QuestCompletion({
    required this.npcId,
    required this.npcName,
    required this.finalCharmLevel,
    required this.acceptedItems,
    required this.completedAt,
    this.experienceGained = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'npc_id': npcId,
      'npc_name': npcName,
      'final_charm_level': finalCharmLevel,
      'accepted_items': acceptedItems,
      'completed_at': completedAt.toIso8601String(),
      'experience_gained': experienceGained,
    };
  }

  factory QuestCompletion.fromJson(Map<String, dynamic> json) {
    return QuestCompletion(
      npcId: json['npc_id'] ?? '',
      npcName: json['npc_name'] ?? '',
      finalCharmLevel: json['final_charm_level'] ?? 0,
      acceptedItems: Map<String, String>.from(json['accepted_items'] ?? {}),
      completedAt: DateTime.parse(json['completed_at']),
      experienceGained: json['experience_gained'] ?? 0,
    );
  }
}

/// Category information for quest tracking
class QuestCategory {
  final String name;
  final String description;
  final String? acceptedItem;
  final bool isCompleted;
  final bool isCurrent;

  const QuestCategory({
    required this.name,
    required this.description,
    this.acceptedItem,
    this.isCompleted = false,
    this.isCurrent = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'accepted_item': acceptedItem,
      'is_completed': isCompleted,
      'is_current': isCurrent,
    };
  }

  factory QuestCategory.fromJson(Map<String, dynamic> json) {
    return QuestCategory(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      acceptedItem: json['accepted_item'],
      isCompleted: json['is_completed'] ?? false,
      isCurrent: json['is_current'] ?? false,
    );
  }
}