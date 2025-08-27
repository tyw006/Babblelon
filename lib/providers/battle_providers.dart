import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../services/sync_service.dart';

// Battle tracking data class
class BattleMetrics {
  final DateTime battleStartTime;
  final List<TurnData> turns;
  final List<double> pronunciationScores;
  final int currentStreak;
  final int maxStreak;
  final double totalDamageDealt;
  final Set<String> wordsUsed;
  final Map<String, int> wordFailureCount;
  final Map<String, List<String>> wordErrors;
  final int playerStartingHealth;
  final int bossMaxHealth;

  // Fields added for victory report
  final int finalPlayerHealth;
  final int expGained;
  final int goldEarned;
  final Set<String> newlyMasteredWords;
  final Map<String, double> wordScores; // Track score for each word

  const BattleMetrics({
    required this.battleStartTime,
    this.turns = const [],
    this.pronunciationScores = const [],
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.totalDamageDealt = 0,
    this.wordsUsed = const {},
    this.wordFailureCount = const {},
    this.wordErrors = const {},
    required this.playerStartingHealth,
    required this.bossMaxHealth,
    this.finalPlayerHealth = 0,
    this.expGained = 0,
    this.goldEarned = 0,
    this.newlyMasteredWords = const {},
    this.wordScores = const {},
  });

  Duration get battleDuration => DateTime.now().difference(battleStartTime);
  
  double get averagePronunciationScore {
    if (pronunciationScores.isEmpty) return 0.0;
    return pronunciationScores.reduce((a, b) => a + b) / pronunciationScores.length;
  }
  
  int get actualTurns => turns.length;
  
  double get damagePerTurn {
    if (actualTurns == 0) return 0.0;
    return totalDamageDealt / actualTurns;
  }
  
  // Dynamic ideal turns calculation based on boss health and good player performance
  int get idealTurns {
    // Define "Good Player" performance standards
    const double baseAttackRegular = 50.0; // Regular item base attack
    const double goodPronunciationBonus = 0.3; // "Good" pronunciation bonus
    const double mediumComplexityBonus = 0.3; // Complexity 3 bonus
    
    // Calculate good performance damage
    const goodPerformanceDamage = baseAttackRegular * (1.0 + goodPronunciationBonus + mediumComplexityBonus);
    
    // Calculate ideal turns and round up to next integer
    return (bossMaxHealth / goodPerformanceDamage).ceil();
  }
  
  // Calculate overall grade (S, A, B, C)
  String get overallGrade {
    // Final Score = (AvgPronunciationScore/100 * 0.5) + (IdealTurns/ActualTurns * 0.3) + (RemainingHP/TotalHP * 0.2)
    final avgPronScore = averagePronunciationScore / 100.0;
    final turnEfficiency = idealTurns / actualTurns.clamp(1, double.infinity);
    final hpRetention = finalPlayerHealth / playerStartingHealth.clamp(1, double.infinity); // Use final player health from battle metrics
    
    final finalScore = (avgPronScore * 0.5) + (turnEfficiency * 0.3) + (hpRetention * 0.2);
    
    if (finalScore >= 0.95) return 'S';
    if (finalScore >= 0.85) return 'A';
    if (finalScore >= 0.70) return 'B';
    return 'C';
  }
  
  // Getters for Victory Report
  int get totalTurns => turns.length;
  int get longestStreak => maxStreak;

  double get vocabularyMastery {
    if (wordScores.isEmpty) return 0.0;
    final masteredCount = wordScores.values.where((score) => score >= 60).length;
    return masteredCount / wordScores.length;
  }

  Map<String, int> get mostFailedWords {
    // Return the top 3 most failed words, sorted by failure count
    final sortedEntries = wordFailureCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries.take(3));
  }
  
  BattleMetrics copyWith({
    DateTime? battleStartTime,
    List<TurnData>? turns,
    List<double>? pronunciationScores,
    int? currentStreak,
    int? maxStreak,
    double? totalDamageDealt,
    Set<String>? wordsUsed,
    Map<String, int>? wordFailureCount,
    Map<String, List<String>>? wordErrors,
    int? playerStartingHealth,
    int? bossMaxHealth,
    int? finalPlayerHealth,
    int? expGained,
    int? goldEarned,
    Set<String>? newlyMasteredWords,
    Map<String, double>? wordScores,
  }) {
    return BattleMetrics(
      battleStartTime: battleStartTime ?? this.battleStartTime,
      turns: turns ?? this.turns,
      pronunciationScores: pronunciationScores ?? this.pronunciationScores,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      totalDamageDealt: totalDamageDealt ?? this.totalDamageDealt,
      wordsUsed: wordsUsed ?? this.wordsUsed,
      wordFailureCount: wordFailureCount ?? this.wordFailureCount,
      wordErrors: wordErrors ?? this.wordErrors,
      playerStartingHealth: playerStartingHealth ?? this.playerStartingHealth,
      bossMaxHealth: bossMaxHealth ?? this.bossMaxHealth,
      finalPlayerHealth: finalPlayerHealth ?? this.finalPlayerHealth,
      expGained: expGained ?? this.expGained,
      goldEarned: goldEarned ?? this.goldEarned,
      newlyMasteredWords: newlyMasteredWords ?? this.newlyMasteredWords,
      wordScores: wordScores ?? this.wordScores,
    );
  }
}

// Turn data for tracking individual actions
class TurnData {
  final String action; // 'attack' or 'defend'
  final String word;
  final double pronunciationScore;
  final int complexity;
  final double damageDealt;
  final double damageReceived;
  final List<String> pronunciationErrors;
  final DateTime timestamp;
  
  const TurnData({
    required this.action,
    required this.word,
    required this.pronunciationScore,
    required this.complexity,
    required this.damageDealt,
    required this.damageReceived,
    required this.pronunciationErrors,
    required this.timestamp,
  });
}

// Battle tracking state notifier
class BattleTrackingNotifier extends StateNotifier<BattleMetrics?> {
  BattleTrackingNotifier() : super(null);
  
  void startBattle({
    required int playerStartingHealth,
    required int bossMaxHealth,
  }) {
    state = BattleMetrics(
      battleStartTime: DateTime.now(),
      playerStartingHealth: playerStartingHealth,
      bossMaxHealth: bossMaxHealth,
    );
  }
  
  void addTurn({
    required String action,
    required String word,
    required double pronunciationScore,
    required int complexity,
    required double damageDealt,
    required double damageReceived,
    required List<String> pronunciationErrors,
  }) {
    if (state == null) return;
    
    final newTurn = TurnData(
      action: action,
      word: word,
      pronunciationScore: pronunciationScore,
      complexity: complexity,
      damageDealt: damageDealt,
      damageReceived: damageReceived,
      pronunciationErrors: pronunciationErrors,
      timestamp: DateTime.now(),
    );
    
    // Update current streak
    int newCurrentStreak = state!.currentStreak;
    int newMaxStreak = state!.maxStreak;
    
    if (pronunciationScore >= 75) {
      newCurrentStreak++;
      newMaxStreak = max(newMaxStreak, newCurrentStreak);
    } else {
      newCurrentStreak = 0;
    }
    
    // Update word tracking
    final newWordsUsed = Set<String>.from(state!.wordsUsed)..add(word);
    final newWordFailureCount = Map<String, int>.from(state!.wordFailureCount);
    final newWordErrors = Map<String, List<String>>.from(state!.wordErrors);
    final newWordScores = Map<String, double>.from(state!.wordScores);
    
    newWordScores[word] = pronunciationScore; // Always update with the latest score

    if (pronunciationScore < 75) {
      newWordFailureCount[word] = (newWordFailureCount[word] ?? 0) + 1;
      newWordErrors[word] = pronunciationErrors;
    }
    
    state = state!.copyWith(
      turns: [...state!.turns, newTurn],
      pronunciationScores: [...state!.pronunciationScores, pronunciationScore],
      currentStreak: newCurrentStreak,
      maxStreak: newMaxStreak,
      totalDamageDealt: state!.totalDamageDealt + damageDealt,
      wordsUsed: newWordsUsed,
      wordFailureCount: newWordFailureCount,
      wordErrors: newWordErrors,
      wordScores: newWordScores,
    );
  }
  
  void endBattle({required int finalPlayerHealth}) {
    if (state == null) return;

    // --- Calculate Final Rewards ---
    // EXP: Base EXP + Bonus for performance
    int baseExp = 50;
    double performanceBonus = (state!.averagePronunciationScore / 100) * 25; // up to 25 bonus EXP
    int finalExp = (baseExp + performanceBonus).round();

    // Gold: Base Gold + Bonus for health remaining
    int baseGold = 10;
    double healthBonus = (finalPlayerHealth / state!.playerStartingHealth) * 10; // up to 10 bonus gold
    int finalGold = (baseGold + healthBonus).round();

    // Newly Mastered Words
    final Set<String> newlyMastered = {};
    state!.wordScores.forEach((word, score) {
      if (score >= 60) {
        newlyMastered.add(word);
      }
    });

    state = state!.copyWith(
      finalPlayerHealth: finalPlayerHealth,
      expGained: finalExp,
      goldEarned: finalGold,
      newlyMasteredWords: newlyMastered,
    );
  }

  // Upload battle session data to Supabase
  Future<void> uploadBattleSession(String bossId) async {
    if (state == null) return;

    final syncService = SyncService();
    
    try {
      await syncService.uploadBattleSession(
        bossId: bossId,
        durationSeconds: state!.battleDuration.inSeconds,
        avgPronunciationScore: state!.averagePronunciationScore,
        totalDamage: state!.totalDamageDealt,
        turnsTaken: state!.actualTurns,
        grade: state!.overallGrade,
        wordsUsed: {'words': state!.wordsUsed.toList()},
        wordScores: state!.wordScores,
        maxStreak: state!.maxStreak,
        finalPlayerHealth: state!.finalPlayerHealth,
        expGained: state!.expGained,
        goldEarned: state!.goldEarned,
        newlyMasteredWords: state!.newlyMasteredWords.toList(),
      );
    } catch (e) {
      debugPrint('Failed to upload battle session: $e');
    }
  }
  
  void resetBattle() {
    state = null;
  }
}

// Provider definition
final battleTrackingProvider = StateNotifierProvider<BattleTrackingNotifier, BattleMetrics?>(
  (ref) => BattleTrackingNotifier(),
); 