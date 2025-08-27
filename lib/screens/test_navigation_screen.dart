import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/theme/unified_dark_theme.dart';
import 'package:babblelon/screens/intro_splash_screen.dart';
import 'package:babblelon/screens/enhanced_onboarding_screen.dart';
import 'package:babblelon/screens/authentication_screen.dart';
import 'package:babblelon/widgets/character_tracing_widget.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/models/battle_item.dart';
import 'package:babblelon/providers/battle_providers.dart';
import 'package:babblelon/widgets/victory_report_dialog.dart';
import 'package:babblelon/widgets/defeat_dialog.dart';
import 'package:babblelon/widgets/character_assessment_dialog.dart';
import 'package:babblelon/models/character_assessment_model.dart';
import 'package:babblelon/overlays/dialogue_overlay.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:babblelon/widgets/modern_calculation_display.dart';
import 'package:babblelon/models/assessment_model.dart';
import 'package:babblelon/widgets/resume_game_dialog.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math';

/// Streamlined test navigation screen with modern dark theme and tab-based organization
class TestNavigationScreen extends ConsumerStatefulWidget {
  const TestNavigationScreen({super.key});

  @override
  ConsumerState<TestNavigationScreen> createState() => _TestNavigationScreenState();
}

class _TestNavigationScreenState extends ConsumerState<TestNavigationScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedDarkTheme.primaryBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.science, color: UnifiedDarkTheme.primaryAccent),
            SizedBox(width: 8),
            Text(
              'BabbleOn Testing Lab',
              style: TextStyle(
                color: UnifiedDarkTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: UnifiedDarkTheme.primarySurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: UnifiedDarkTheme.primaryAccent),
            onPressed: _resetAllTestStates,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: UnifiedDarkTheme.primaryAccent,
          labelColor: UnifiedDarkTheme.textPrimary,
          unselectedLabelColor: UnifiedDarkTheme.textSecondary,
          tabs: const [
            Tab(text: 'Flows', icon: Icon(Icons.alt_route)),
            Tab(text: 'Game', icon: Icon(Icons.videogame_asset)),
            Tab(text: 'Components', icon: Icon(Icons.widgets)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlowTestsTab(),
          _buildGameTestsTab(),
          _buildComponentTestsTab(),
        ],
      ),
    );
  }

  Widget _buildFlowTestsTab() {
    return Container(
      color: UnifiedDarkTheme.primaryBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader('User Flow Tests', Icons.account_tree),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildTestCard(
                  title: 'Intro Splash',
                  subtitle: 'App launch animation and loading',
                  icon: Icons.launch,
                  onTap: () => _launchScreen(const IntroSplashScreen()),
                ),
                _buildTestCard(
                  title: 'Enhanced Onboarding',
                  subtitle: 'Character selection and tutorial introduction',
                  icon: Icons.person_add,
                  onTap: () => _launchScreen(const EnhancedOnboardingScreen()),
                ),
                _buildTestCard(
                  title: 'Authentication',
                  subtitle: 'Sign in and sign up flows',
                  icon: Icons.login,
                  onTap: () => _launchScreen(const AuthenticationScreen()),
                ),
                _buildTestCard(
                  title: 'Game Experience',
                  subtitle: 'Complete gameplay with NPCs and interactions',
                  icon: Icons.videogame_asset,
                  onTap: () => _launchScreen(const GameScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameTestsTab() {
    return Container(
      color: UnifiedDarkTheme.primaryBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader('Game Component Tests', Icons.sports_esports),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildTestCard(
                  title: 'Boss Battle',
                  subtitle: 'Combat system with enhanced mechanics',
                  icon: Icons.shield,
                  onTap: () => _launchBossFight(),
                ),
                _buildTestCard(
                  title: 'NPC Chat',
                  subtitle: 'Interactive dialogue with AI NPCs',
                  icon: Icons.chat,
                  onTap: () => _launchNPCDialogue(),
                ),
                _buildTestCard(
                  title: 'Character Tracing',
                  subtitle: 'Thai writing practice with ML assessment',
                  icon: Icons.draw,
                  onTap: () => _launchCharacterTracing(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentTestsTab() {
    return Container(
      color: UnifiedDarkTheme.primaryBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader('UI Component Tests', Icons.widgets),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildTestCard(
                  title: 'Victory Dialog',
                  subtitle: 'Boss battle victory celebration',
                  icon: Icons.celebration,
                  onTap: () => _showSampleDialog(_createVictoryDialog()),
                ),
                _buildTestCard(
                  title: 'Defeat Dialog',
                  subtitle: 'Boss battle defeat handling',
                  icon: Icons.sentiment_dissatisfied,
                  onTap: () => _showSampleDialog(_createDefeatDialog()),
                ),
                _buildTestCard(
                  title: 'Writing Assessment',
                  subtitle: 'Character tracing results display',
                  icon: Icons.assessment,
                  onTap: () => _showSampleDialog(_createWritingAssessmentDialog()),
                ),
                _buildTestCard(
                  title: 'Pronunciation Assessment',
                  subtitle: 'Speech recognition results with modern calculation display',
                  icon: Icons.mic,
                  onTap: () => _showSampleDialog(_createPronunciationAssessmentDialog()),
                ),
                _buildTestCard(
                  title: 'Resume Game Dialog',
                  subtitle: 'Test save/resume functionality with mock data',
                  icon: Icons.save_alt_rounded,
                  onTap: () => _showSampleDialog(_createResumeGameDialog()),
                ),
                _buildTestCard(
                  title: 'Save State Simulator',
                  subtitle: 'Interactive save/load scenario testing',
                  icon: Icons.cloud_sync,
                  onTap: () => _showSampleDialog(_createSaveStateSimulator()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: UnifiedDarkTheme.primaryAccent, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: UnifiedDarkTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTestCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: UnifiedDarkTheme.primarySurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: UnifiedDarkTheme.primaryAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UnifiedDarkTheme.primaryAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: UnifiedDarkTheme.primaryAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: UnifiedDarkTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: UnifiedDarkTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: UnifiedDarkTheme.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetAllTestStates() {
    // Reset any test-specific states here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test states reset'),
        backgroundColor: UnifiedDarkTheme.success,
      ),
    );
  }

  void _launchScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showSampleDialog(Widget dialog) {
    showDialog(
      context: context,
      builder: (context) => dialog,
    );
  }

  void _launchBossFight() {
    const bossData = BossData(
      name: 'Test Guardian',
      spritePath: 'assets/images/bosses/test_boss.png',
      maxHealth: 100,
      vocabularyPath: 'assets/data/beginner_food_vocabulary.json',
      backgroundPath: 'assets/images/backgrounds/test_background.png',
      languageName: 'Thai',
      languageFlag: '🇹🇭',
    );

    const attackItem = BattleItem(
      name: 'Test Sword',
      assetPath: 'assets/images/items/test_sword.png',
    );

    const defenseItem = BattleItem(
      name: 'Test Shield',
      assetPath: 'assets/images/items/test_shield.png',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BossFightScreen(
          bossData: bossData,
          attackItem: attackItem,
          defenseItem: defenseItem,
          game: BabblelonGame.instance,
        ),
      ),
    );
  }

  void _launchNPCDialogue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('NPC Chat Test'),
            backgroundColor: UnifiedDarkTheme.primarySurface,
          ),
          backgroundColor: UnifiedDarkTheme.primaryBackground,
          body: DialogueOverlay(
            game: BabblelonGame.instance,
            npcId: 'amara',
          ),
        ),
      ),
    );
  }

  void _launchCharacterTracing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Character Tracing Test'),
            backgroundColor: UnifiedDarkTheme.primarySurface,
          ),
          backgroundColor: UnifiedDarkTheme.primaryBackground,
          body: Center(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _loadSampleVocabularyForTracing(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: UnifiedDarkTheme.primaryAccent,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading sample word for tracing...',
                        style: TextStyle(color: UnifiedDarkTheme.textSecondary),
                      ),
                    ],
                  );
                }
                
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error,
                          color: UnifiedDarkTheme.warning,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Character Tracing Test Error',
                          style: TextStyle(
                            color: UnifiedDarkTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error loading vocabulary: ${snapshot.error}',
                          style: const TextStyle(
                            color: UnifiedDarkTheme.warning,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(
                    child: Text(
                      'No vocabulary data available for testing',
                      style: TextStyle(color: UnifiedDarkTheme.textSecondary),
                    ),
                  );
                }
                
                // If successful, create the actual character tracing widget
                final vocabularyItem = snapshot.data!;
                final wordMapping = List<Map<String, dynamic>>.from(vocabularyItem['word_mapping'] ?? []);
                
                if (wordMapping.isEmpty) {
                  return const Center(
                    child: Text(
                      'No word mapping available for character tracing',
                      style: TextStyle(color: UnifiedDarkTheme.textSecondary),
                    ),
                  );
                }
                
                return TestCharacterTracingWrapper(
                  vocabularyItem: vocabularyItem,
                  wordMapping: wordMapping,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Load a random vocabulary item for character tracing testing
  Future<Map<String, dynamic>?> _loadSampleVocabularyForTracing() async {
    try {
      // Load the vocabulary file
      final String jsonString = await rootBundle.loadString('assets/data/beginner_food_vocabulary.json');
      final Map<String, dynamic> vocabularyData = json.decode(jsonString);
      final List<dynamic> vocabulary = vocabularyData['vocabulary'] ?? [];
      
      if (vocabulary.isEmpty) {
        throw Exception('No vocabulary items found');
      }
      
      // Filter for items that have word_mapping (required for character tracing)
      final List<Map<String, dynamic>> tracingVocabulary = vocabulary
          .cast<Map<String, dynamic>>()
          .where((item) => item['word_mapping'] != null && (item['word_mapping'] as List).isNotEmpty)
          .toList();
      
      if (tracingVocabulary.isEmpty) {
        throw Exception('No vocabulary items with word mapping found');
      }
      
      // Pick a random item for testing
      final random = Random();
      final selectedItem = tracingVocabulary[random.nextInt(tracingVocabulary.length)];
      
      debugPrint('🧪 TestCharacterTracing: Selected "${selectedItem['thai']}" for tracing test');
      return selectedItem;
    } catch (e) {
      debugPrint('💥 TestCharacterTracing: Error loading vocabulary: $e');
      rethrow;
    }
  }

  Widget _createVictoryDialog() {
    debugPrint('🧪 TEST: Creating Victory Dialog with sample metrics');
    debugPrint('   - This will show complete victory flow');
    debugPrint('   - Victory should reset ALL game state and saves');
    debugPrint('   - Inventory: CLEARED');
    debugPrint('   - Boss fight save: DELETED');
    debugPrint('   - Exploration save: DELETED');
    debugPrint('   - Player returns to exploration mode');
    
    return VictoryReportDialog(
      metrics: _createSampleBattleMetrics(),
    );
  }

  Widget _createDefeatDialog() {
    debugPrint('🧪 TEST: Creating Defeat Dialog with sample metrics');
    debugPrint('   - This will show defeat options: Retry vs Exit');
    debugPrint('   - RETRY: HP reset, inventory preserved, randomized turn');
    debugPrint('   - EXIT: Current state saved, can resume later');
    debugPrint('   - Both options preserve inventory in save file');
    
    return DefeatDialog(
      metrics: _createSampleBattleMetrics(),
    );
  }

  Widget _createWritingAssessmentDialog() {
    return CharacterAssessmentDialog(
      assessmentResult: _createSampleTracingResult(),
      characterNames: const ['ก', 'อ', 'ย'],
      onDismiss: () {},
    );
  }

  Widget _createPronunciationAssessmentDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              UnifiedDarkTheme.primarySurface,
              UnifiedDarkTheme.primarySurface.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: UnifiedDarkTheme.primaryAccent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mic,
              color: UnifiedDarkTheme.primaryAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pronunciation Assessment',
              style: TextStyle(
                color: UnifiedDarkTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ModernCalculationDisplay(
              explanation: _createSamplePronunciationResult().calculationBreakdown.explanation,
              isDefenseCalculation: false,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: UnifiedDarkTheme.primaryAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BattleMetrics _createSampleBattleMetrics() {
    return BattleMetrics(
      battleStartTime: DateTime.now().subtract(const Duration(minutes: 2, seconds: 30)),
      playerStartingHealth: 100,
      bossMaxHealth: 100,
      turns: const [],
      pronunciationScores: const [82.5, 78.0, 90.5, 76.5],
      currentStreak: 2,
      maxStreak: 3,
      totalDamageDealt: 85,
      wordsUsed: const {'สวัสดี', 'ขอบคุณ', 'อร่อย', 'สบายดี'},
      wordFailureCount: const {},
      wordErrors: const {},
      finalPlayerHealth: 55,
      expGained: 75,
      goldEarned: 15,
      newlyMasteredWords: const {'สวัสดี', 'ขอบคุณ'},
      wordScores: const {'สวัสดี': 82.5, 'ขอบคุณ': 78.0, 'อร่อย': 90.5, 'สบายดี': 76.5},
    );
  }

  TracingAssessmentResult _createSampleTracingResult() {
    final characterResults = <int, CharacterAssessmentResult>{
      0: const CharacterAssessmentResult(
        expectedCharacter: 'ก',
        recognizedText: 'ก',
        confidenceScore: 1.2,
        candidates: [],
        isCorrect: true,
        accuracyLevel: 'Excellent',
        accuracyPercentage: 92.5,
        hasStrokes: true,
      ),
      1: const CharacterAssessmentResult(
        expectedCharacter: 'อ',
        recognizedText: 'อ',
        confidenceScore: 1.8,
        candidates: [],
        isCorrect: true,
        accuracyLevel: 'Good',
        accuracyPercentage: 78.0,
        hasStrokes: true,
      ),
      2: const CharacterAssessmentResult(
        expectedCharacter: 'ย',
        recognizedText: 'ข',
        confidenceScore: 2.5,
        candidates: [],
        isCorrect: false,
        accuracyLevel: 'Needs Improvement',
        accuracyPercentage: 65.0,
        hasStrokes: true,
      ),
    };

    return TracingAssessmentResult(
      characterResults: characterResults,
      overallAccuracy: 78.5,
      correctCount: 2,
      totalCount: 3,
      overallGrade: 'B',
      hasAnyStrokes: true,
      charactersThatNeedPractice: [2],
      transliteration: 'gauy',
      translation: 'test word',
    );
  }

  PronunciationAssessmentResponse _createSamplePronunciationResult() {
    return PronunciationAssessmentResponse(
      rating: 'Good',
      pronunciationScore: 82.5,
      accuracyScore: 78.0,
      fluencyScore: 85.0,
      completenessScore: 90.0,
      attackMultiplier: 1.3,
      defenseMultiplier: 1.0,
      detailedFeedback: [],
      wordFeedback: 'Good pronunciation! Focus on tone clarity.',
      calculationBreakdown: DamageCalculationBreakdown(
        baseValue: 20.0,
        pronunciationMultiplier: 1.3,
        complexityMultiplier: 1.1,
        itemMultiplier: 1.0,
        penalty: 0.0,
        explanation: 'Base Damage: 20\nPronunciation Bonus: +30%\nComplexity Bonus: +10%\nTotal Attack: 28.6',
      ),
    );
  }

  Widget _createResumeGameDialog() {
    return ResumeGameDialog(
      levelId: 'test_level_1',
      saveData: _createSampleGameSaveState(),
      onResume: () {
        Navigator.of(context).pop();
        debugPrint('🎮 TEST: Resume game selected - inventory preserved');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resume Game - Inventory preserved in memory'),
            backgroundColor: UnifiedDarkTheme.success,
          ),
        );
      },
      onStartNew: () {
        Navigator.of(context).pop();
        debugPrint('🎮 TEST: Start new game selected - all saves cleared');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start New Game - All saves cleared'),
            backgroundColor: UnifiedDarkTheme.warning,
          ),
        );
      },
    );
  }

  GameSaveState _createSampleGameSaveState() {
    final saveState = GameSaveState()
      ..levelId = 'test_level_1'
      ..gameType = 'boss_fight'
      ..timestamp = DateTime.now().subtract(const Duration(minutes: 15))
      ..progressPercentage = 65.0
      ..npcsVisited = 3
      ..itemsCollected = 8
      ..playerHealth = 75
      ..bossHealth = 40
      ..bossId = 'test_boss'
      ..currentTurn = 'player'
      ..inventoryJson = jsonEncode({
        'healing_potion': 'Small Health Potion',
        'magic_sword': 'Enchanted Blade',
        'shield': 'Iron Shield',
      })
      ..usedFlashcardsJson = jsonEncode([1, 3, 7, 12])
      ..activeFlashcardsJson = jsonEncode([2, 8, 15])
      ..revealedCardsJson = jsonEncode(['card_5', 'card_9'])
      ..battleMetricsJson = jsonEncode({
        'totalDamageDealt': 60,
        'currentStreak': 2,
        'pronunciationScores': [78.5, 82.0, 76.3],
      });

    debugPrint('🧪 TEST: Created mock save state with:');
    debugPrint('   - Game Type: ${saveState.gameType}');
    debugPrint('   - Progress: ${saveState.progressPercentage}%');
    debugPrint('   - Player HP: ${saveState.playerHealth}');
    debugPrint('   - Boss HP: ${saveState.bossHealth}');
    debugPrint('   - Inventory: healing_potion, magic_sword, shield');
    debugPrint('   - Used Flashcards: [1, 3, 7, 12]');
    debugPrint('   - Active Flashcards: [2, 8, 15]');
    
    return saveState;
  }

  Widget _createSaveStateSimulator() {
    return const SaveStateSimulatorDialog();
  }
}

/// Interactive dialog for testing save/load scenarios
class SaveStateSimulatorDialog extends ConsumerStatefulWidget {
  const SaveStateSimulatorDialog({super.key});

  @override
  ConsumerState<SaveStateSimulatorDialog> createState() => _SaveStateSimulatorDialogState();
}

class _SaveStateSimulatorDialogState extends ConsumerState<SaveStateSimulatorDialog> {
  String _currentScenario = 'fresh_start';
  Map<String, String> _inventory = {
    'healing_potion': 'Small Health Potion',
    'magic_sword': 'Enchanted Blade',
  };
  int _playerHP = 100;
  int _bossHP = 100;
  bool _hasSave = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          gradient: UnifiedDarkTheme.surfaceGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: UnifiedDarkTheme.primaryAccent.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.cloud_sync,
                    color: UnifiedDarkTheme.primaryAccent,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Save State Simulator',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: UnifiedDarkTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: UnifiedDarkTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current State Display
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Game State',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: UnifiedDarkTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Player HP: $_playerHP/100',
                                        style: const TextStyle(color: UnifiedDarkTheme.textSecondary),
                                      ),
                                      Text(
                                        'Boss HP: $_bossHP/100',
                                        style: const TextStyle(color: UnifiedDarkTheme.textSecondary),
                                      ),
                                      Text(
                                        'Save File: ${_hasSave ? 'EXISTS' : 'NONE'}',
                                        style: TextStyle(
                                          color: _hasSave ? UnifiedDarkTheme.success : UnifiedDarkTheme.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Inventory:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: UnifiedDarkTheme.textSecondary,
                                      ),
                                    ),
                                    ..._inventory.entries.map((entry) => Text(
                                      '• ${entry.value}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: UnifiedDarkTheme.textTertiary,
                                      ),
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Scenario Buttons
                      const Text(
                        'Test Scenarios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: UnifiedDarkTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildScenarioButton(
                        'Boss Fight Victory',
                        'Win boss fight → Complete reset',
                        Icons.celebration,
                        UnifiedDarkTheme.success,
                        () => _simulateVictory(),
                      ),
                      _buildScenarioButton(
                        'Boss Fight Defeat → Retry',
                        'Lose → Retry (preserve inventory)',
                        Icons.refresh,
                        UnifiedDarkTheme.warning,
                        () => _simulateDefeatRetry(),
                      ),
                      _buildScenarioButton(
                        'Boss Fight Defeat → Exit',
                        'Lose → Exit (save with inventory)',
                        Icons.exit_to_app,
                        UnifiedDarkTheme.info,
                        () => _simulateDefeatExit(),
                      ),
                      _buildScenarioButton(
                        'Resume Game',
                        'Load from existing save',
                        Icons.play_arrow,
                        UnifiedDarkTheme.primaryAccent,
                        () => _simulateResume(),
                        enabled: _hasSave,
                      ),
                      _buildScenarioButton(
                        'Reset Everything',
                        'Clear all saves and state',
                        Icons.delete_sweep,
                        UnifiedDarkTheme.error,
                        () => _resetEverything(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: enabled 
                ? color.withValues(alpha: 0.1) 
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled 
                  ? color.withValues(alpha: 0.3) 
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? color : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled 
                            ? UnifiedDarkTheme.textPrimary 
                            : Colors.grey,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled 
                            ? UnifiedDarkTheme.textSecondary 
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _simulateVictory() {
    setState(() {
      _playerHP = 100;
      _bossHP = 100;
      _inventory.clear();
      _hasSave = false;
      _currentScenario = 'victory';
    });
    
    debugPrint('🏆 TEST SCENARIO: Boss Fight Victory');
    debugPrint('   - All saves cleared');
    debugPrint('   - Inventory cleared');
    debugPrint('   - HP reset to 100/100');
    debugPrint('   - Player returns to exploration');
    
    _showResultSnackBar('Victory! Everything reset for new game', UnifiedDarkTheme.success);
  }

  void _simulateDefeatRetry() {
    setState(() {
      _playerHP = 100;
      _bossHP = 100;
      // Inventory preserved
      _hasSave = true;
      _currentScenario = 'defeat_retry';
    });
    
    debugPrint('🔄 TEST SCENARIO: Boss Fight Defeat → Retry');
    debugPrint('   - HP reset to 100/100');
    debugPrint('   - Inventory preserved: $_inventory');
    debugPrint('   - Boss fight save updated with retry state');
    debugPrint('   - Turn randomized');
    
    _showResultSnackBar('Defeat Retry! HP reset, inventory preserved', UnifiedDarkTheme.warning);
  }

  void _simulateDefeatExit() {
    setState(() {
      // Current HP maintained
      _hasSave = true;
      _currentScenario = 'defeat_exit';
    });
    
    debugPrint('🚪 TEST SCENARIO: Boss Fight Defeat → Exit');
    debugPrint('   - HP preserved as-is: $_playerHP/$_bossHP');
    debugPrint('   - Inventory preserved: $_inventory');
    debugPrint('   - Boss fight save created for later resumption');
    debugPrint('   - Can resume exactly where left off');
    
    _showResultSnackBar('Defeat Exit! Save created for resumption', UnifiedDarkTheme.info);
  }

  void _simulateResume() {
    if (!_hasSave) return;
    
    debugPrint('▶️ TEST SCENARIO: Resume Game');
    debugPrint('   - Loading from existing save');
    debugPrint('   - HP: $_playerHP/$_bossHP');
    debugPrint('   - Inventory: $_inventory');
    debugPrint('   - All state restored exactly');
    
    _showResultSnackBar('Game resumed from save!', UnifiedDarkTheme.primaryAccent);
  }

  void _resetEverything() {
    setState(() {
      _playerHP = 100;
      _bossHP = 100;
      _inventory = {
        'healing_potion': 'Small Health Potion',
        'magic_sword': 'Enchanted Blade',
      };
      _hasSave = false;
      _currentScenario = 'fresh_start';
    });
    
    debugPrint('🗑️ TEST SCENARIO: Reset Everything');
    debugPrint('   - All saves cleared');
    debugPrint('   - Fresh game state');
    debugPrint('   - Ready for new testing');
    
    _showResultSnackBar('Everything reset to fresh state', UnifiedDarkTheme.error);
  }

  void _showResultSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Wrapper widget for character tracing that handles completion and assessment display
class TestCharacterTracingWrapper extends ConsumerStatefulWidget {
  final Map<String, dynamic> vocabularyItem;
  final List<Map<String, dynamic>> wordMapping;

  const TestCharacterTracingWrapper({
    super.key,
    required this.vocabularyItem,
    required this.wordMapping,
  });

  @override
  ConsumerState<TestCharacterTracingWrapper> createState() => _TestCharacterTracingWrapperState();
}

class _TestCharacterTracingWrapperState extends ConsumerState<TestCharacterTracingWrapper> {
  bool _showAssessment = false;
  TracingAssessmentResult? _assessmentResult;

  @override
  Widget build(BuildContext context) {
    if (_showAssessment && _assessmentResult != null) {
      return Scaffold(
        backgroundColor: UnifiedDarkTheme.primaryBackground,
        appBar: AppBar(
          title: const Text('Writing Assessment'),
          backgroundColor: UnifiedDarkTheme.primarySurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _showAssessment = false;
                _assessmentResult = null;
              });
            },
          ),
        ),
        body: CharacterAssessmentDialog(
          assessmentResult: _assessmentResult!,
          characterNames: _getCharacterNames(),
          originalVocabularyItem: widget.vocabularyItem,
          onDismiss: () {
            setState(() {
              _showAssessment = false;
              _assessmentResult = null;
            });
          },
        ),
      );
    }

    return CharacterTracingWidget(
      wordMapping: widget.wordMapping,
      originalVocabularyItem: widget.vocabularyItem,
      headerTitle: widget.vocabularyItem['thai'] ?? 'Test Word',
      headerSubtitle: widget.vocabularyItem['english'] ?? 'Test Translation',
      showBackButton: true,
      onBack: () => Navigator.of(context).pop(),
      onComplete: () {
        // Generate sample assessment result
        _generateSampleAssessment();
      },
    );
  }

  List<String> _getCharacterNames() {
    return widget.wordMapping.map<String>((mapping) => mapping['thai']?.toString() ?? '').toList();
  }

  void _generateSampleAssessment() {
    // Generate realistic assessment data based on the vocabulary item
    final characterNames = _getCharacterNames();
    final random = Random();
    
    // Create character assessment results
    final Map<int, CharacterAssessmentResult> characterResults = {};
    int correctCount = 0;
    
    for (int i = 0; i < characterNames.length; i++) {
      final char = characterNames[i];
      final accuracyPercentage = 70.0 + (random.nextDouble() * 25); // 70-95%
      final isCorrect = accuracyPercentage >= 75.0;
      
      if (isCorrect) correctCount++;
      
      characterResults[i] = CharacterAssessmentResult(
        expectedCharacter: char,
        recognizedText: isCorrect ? char : _getRandomIncorrectChar(),
        confidenceScore: random.nextDouble() * 2.0, // 0-2.0 (lower is better)
        candidates: [], // Empty for test
        isCorrect: isCorrect,
        accuracyLevel: _getAccuracyLevel(accuracyPercentage),
        accuracyPercentage: accuracyPercentage,
        hasStrokes: true,
      );
    }
    
    // Calculate overall accuracy
    final overallAccuracy = characterResults.values
        .map((result) => result.accuracyPercentage)
        .reduce((a, b) => a + b) / characterResults.length;
    
    // Determine characters that need practice (those with accuracy < 80%)
    final charactersThatNeedPractice = <int>[];
    characterResults.forEach((index, result) {
      if (result.accuracyPercentage < 80.0) {
        charactersThatNeedPractice.add(index);
      }
    });
    
    final assessment = TracingAssessmentResult(
      characterResults: characterResults,
      overallAccuracy: overallAccuracy,
      correctCount: correctCount,
      totalCount: characterNames.length,
      overallGrade: _getGradeFromScore(overallAccuracy),
      hasAnyStrokes: true,
      charactersThatNeedPractice: charactersThatNeedPractice,
      transliteration: widget.vocabularyItem['transliteration'],
      translation: widget.vocabularyItem['english'],
    );

    setState(() {
      _assessmentResult = assessment;
      _showAssessment = true;
    });
  }
  
  String _getRandomIncorrectChar() {
    final incorrectChars = ['ก', 'ข', 'ค', 'ง', 'จ', 'ฉ', 'ช', 'ซ', 'ญ', 'ด'];
    return incorrectChars[Random().nextInt(incorrectChars.length)];
  }
  
  String _getAccuracyLevel(double percentage) {
    if (percentage >= 90) return 'Excellent';
    if (percentage >= 80) return 'Good';
    if (percentage >= 70) return 'Needs Improvement';
    return 'Failed';
  }

  String _getGradeFromScore(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}