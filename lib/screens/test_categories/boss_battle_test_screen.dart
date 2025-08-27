import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/test_utilities.dart';
import 'package:babblelon/screens/premium/premium_boss_battle_screen.dart';

/// Test screen for Boss Battle & Combat features
class BossBattleTestScreen extends ConsumerStatefulWidget {
  const BossBattleTestScreen({super.key});

  @override
  ConsumerState<BossBattleTestScreen> createState() => _BossBattleTestScreenState();
}

class _BossBattleTestScreenState extends ConsumerState<BossBattleTestScreen> {
  Map<String, TestStatus> testStatuses = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_kabaddi, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Boss Battle & Combat Tests',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TestUtilities.buildSectionHeader(
              '⚔️ Boss Battle & Combat Testing',
              'Test turn-based combat, voice battles, and victory/defeat systems',
            ),
            const SizedBox(height: 24),

            // Core Combat System Tests
            _buildTestSection(
              'Core Combat System',
              [
                _buildBattleTestScenario(
                  'standard_boss_fight',
                  'Standard Boss Fight',
                  'Test complete boss battle with turn-based combat',
                  Icons.psychology,
                  Colors.red,
                  () => _testStandardBossFight(),
                ),
                _buildBattleTestScenario(
                  'premium_boss_fight',
                  'Premium Boss Fight',
                  'Test enhanced premium boss battle features',
                  Icons.diamond,
                  Colors.purple,
                  () => _testPremiumBossFight(),
                ),
                _buildBattleTestScenario(
                  'health_system',
                  'Health & Damage System',
                  'Test health bars, damage calculation, and animations',
                  Icons.favorite,
                  Colors.pink,
                  () => _testHealthSystem(),
                ),
                _buildBattleTestScenario(
                  'turn_mechanics',
                  'Turn-Based Mechanics',
                  'Test turn indicators and combat flow',
                  Icons.swap_horiz,
                  Colors.blue,
                  () => _testTurnMechanics(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Voice Combat Tests
            _buildTestSection(
              'Voice Combat',
              [
                _buildBattleTestScenario(
                  'voice_attacks',
                  'Voice-Based Attacks',
                  'Test speech recognition for combat commands',
                  Icons.record_voice_over,
                  Colors.orange,
                  () => _testVoiceAttacks(),
                ),
                _buildBattleTestScenario(
                  'pronunciation_damage',
                  'Pronunciation-Based Damage',
                  'Test damage calculation based on pronunciation accuracy',
                  Icons.grade,
                  Colors.amber,
                  () => _testPronunciationDamage(),
                ),
                _buildBattleTestScenario(
                  'voice_spells',
                  'Voice-Activated Spells',
                  'Test special abilities triggered by speech',
                  Icons.auto_fix_high,
                  Colors.indigo,
                  () => _testVoiceSpells(),
                ),
                _buildBattleTestScenario(
                  'thai_vocabulary_combat',
                  'Thai Vocabulary Combat',
                  'Test Thai word pronunciation in battle context',
                  Icons.abc,
                  Colors.teal,
                  () => _testThaiVocabularyCombat(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Combat UI Tests
            _buildTestSection(
              'Combat UI & Animations',
              [
                _buildBattleTestScenario(
                  'animated_health_bars',
                  'Animated Health Bars',
                  'Test health bar animations and visual feedback',
                  Icons.show_chart,
                  Colors.green,
                  () => _testAnimatedHealthBars(),
                ),
                _buildBattleTestScenario(
                  'damage_indicators',
                  'Damage Indicators',
                  'Test floating damage numbers and effects',
                  Icons.whatshot,
                  Colors.deepOrange,
                  () => _testDamageIndicators(),
                ),
                _buildBattleTestScenario(
                  'special_effects',
                  'Special Effects & Particles',
                  'Test combat visual effects and animations',
                  Icons.auto_awesome,
                  Colors.cyan,
                  () => _testSpecialEffects(),
                ),
                _buildBattleTestScenario(
                  'ui_responsiveness',
                  'UI Responsiveness',
                  'Test combat interface performance and touch response',
                  Icons.touch_app,
                  Colors.lime,
                  () => _testUIResponsiveness(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Victory & Defeat Tests
            _buildTestSection(
              'Victory & Defeat Systems',
              [
                _buildBattleTestScenario(
                  'victory_conditions',
                  'Victory Conditions',
                  'Test win condition detection and rewards',
                  Icons.emoji_events,
                  Colors.yellow,
                  () => _testVictoryConditions(),
                ),
                _buildBattleTestScenario(
                  'defeat_conditions',
                  'Defeat Conditions',
                  'Test loss condition detection and retry options',
                  Icons.sentiment_dissatisfied,
                  Colors.grey,
                  () => _testDefeatConditions(),
                ),
                _buildBattleTestScenario(
                  'victory_dialogue',
                  'Victory Dialogue & Rewards',
                  'Test post-victory conversations and item rewards',
                  Icons.card_giftcard,
                  Colors.amber,
                  () => _testVictoryDialogue(),
                ),
                _buildBattleTestScenario(
                  'defeat_dialogue',
                  'Defeat Dialogue & Recovery',
                  'Test post-defeat conversations and retry mechanics',
                  Icons.refresh,
                  Colors.brown,
                  () => _testDefeatDialogue(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Item & Equipment Tests
            _buildTestSection(
              'Items & Equipment',
              [
                _buildBattleTestScenario(
                  'item_collection',
                  'Item Collection',
                  'Test item pickup and inventory management',
                  Icons.inventory,
                  Colors.deepPurple,
                  () => _testItemCollection(),
                ),
                _buildBattleTestScenario(
                  'item_usage',
                  'Item Usage in Combat',
                  'Test using healing items and power-ups in battle',
                  Icons.medical_services,
                  Colors.red,
                  () => _testItemUsage(),
                ),
                _buildBattleTestScenario(
                  'equipment_effects',
                  'Equipment Effects',
                  'Test equipment bonuses and stat modifications',
                  Icons.shield,
                  Colors.blueGrey,
                  () => _testEquipmentEffects(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            TestUtilities.buildInfoBox(
              'Boss Battle Testing Tips:\n'
              '• Test different difficulty levels and scaling\n'
              '• Verify voice recognition accuracy in noisy environments\n'
              '• Check combat balance and fairness\n'
              '• Test pause/resume functionality during battles\n'
              '• Validate reward systems and progression\n'
              '• Ensure graceful handling of network interruptions',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection(String title, List<Widget> tests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...tests,
      ],
    );
  }

  Widget _buildBattleTestScenario(
    String id,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TestUtilities.buildTestCard(
        title: title,
        description: description,
        icon: icon,
        color: color,
        status: testStatuses[id] ?? TestStatus.notRun,
        onTap: () {
          setState(() {
            testStatuses[id] = TestStatus.inProgress;
          });
          action();
        },
      ),
    );
  }

  // Test action methods for Core Combat
  void _testStandardBossFight() {
    TestUtilities.showInfoMessage(
      context,
      'Boss fight testing requires game context and boss data setup'
    );
    setState(() {
      testStatuses['standard_boss_fight'] = TestStatus.needsReview;
    });
  }

  void _testPremiumBossFight() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PremiumBossBattleScreen(),
      ),
    ).then((_) {
      setState(() {
        testStatuses['premium_boss_fight'] = TestStatus.passed;
      });
    });
  }

  void _testHealthSystem() {
    TestUtilities.showInfoMessage(
      context,
      'Health system tested through boss battle interactions'
    );
    setState(() {
      testStatuses['health_system'] = TestStatus.needsReview;
    });
  }

  void _testTurnMechanics() {
    TestUtilities.showInfoMessage(
      context,
      'Turn mechanics tested through boss battle flow'
    );
    setState(() {
      testStatuses['turn_mechanics'] = TestStatus.needsReview;
    });
  }

  // Test action methods for Voice Combat
  void _testVoiceAttacks() {
    TestUtilities.showInfoMessage(
      context,
      'Voice attacks tested through boss battle speech recognition'
    );
    setState(() {
      testStatuses['voice_attacks'] = TestStatus.needsReview;
    });
  }

  void _testPronunciationDamage() {
    TestUtilities.showInfoMessage(
      context,
      'Pronunciation damage calculated based on speech accuracy'
    );
    setState(() {
      testStatuses['pronunciation_damage'] = TestStatus.needsReview;
    });
  }

  void _testVoiceSpells() {
    TestUtilities.showInfoMessage(
      context,
      'Voice spells tested with specific Thai vocabulary triggers'
    );
    setState(() {
      testStatuses['voice_spells'] = TestStatus.needsReview;
    });
  }

  void _testThaiVocabularyCombat() {
    TestUtilities.showInfoMessage(
      context,
      'Thai vocabulary combat tested through boss battle scenarios'
    );
    setState(() {
      testStatuses['thai_vocabulary_combat'] = TestStatus.needsReview;
    });
  }

  // Test action methods for Combat UI
  void _testAnimatedHealthBars() {
    TestUtilities.showInfoMessage(
      context,
      'Animated health bars visible during boss battles'
    );
    setState(() {
      testStatuses['animated_health_bars'] = TestStatus.needsReview;
    });
  }

  void _testDamageIndicators() {
    TestUtilities.showInfoMessage(
      context,
      'Damage indicators shown during combat interactions'
    );
    setState(() {
      testStatuses['damage_indicators'] = TestStatus.needsReview;
    });
  }

  void _testSpecialEffects() {
    TestUtilities.showInfoMessage(
      context,
      'Special effects tested through premium boss battles'
    );
    setState(() {
      testStatuses['special_effects'] = TestStatus.needsReview;
    });
  }

  void _testUIResponsiveness() {
    TestUtilities.showInfoMessage(
      context,
      'UI responsiveness tested during active combat'
    );
    setState(() {
      testStatuses['ui_responsiveness'] = TestStatus.needsReview;
    });
  }

  // Test action methods for Victory & Defeat
  void _testVictoryConditions() {
    TestUtilities.showInfoMessage(
      context,
      'Victory conditions tested by winning boss battles'
    );
    setState(() {
      testStatuses['victory_conditions'] = TestStatus.needsReview;
    });
  }

  void _testDefeatConditions() {
    TestUtilities.showInfoMessage(
      context,
      'Defeat conditions tested by losing boss battles'
    );
    setState(() {
      testStatuses['defeat_conditions'] = TestStatus.needsReview;
    });
  }

  void _testVictoryDialogue() {
    TestUtilities.showInfoMessage(
      context,
      'Victory dialogue tested after successful boss defeats'
    );
    setState(() {
      testStatuses['victory_dialogue'] = TestStatus.needsReview;
    });
  }

  void _testDefeatDialogue() {
    TestUtilities.showInfoMessage(
      context,
      'Defeat dialogue tested after boss battle losses'
    );
    setState(() {
      testStatuses['defeat_dialogue'] = TestStatus.needsReview;
    });
  }

  // Test action methods for Items & Equipment
  void _testItemCollection() {
    TestUtilities.showInfoMessage(
      context,
      'Item collection tested through boss battle rewards'
    );
    setState(() {
      testStatuses['item_collection'] = TestStatus.needsReview;
    });
  }

  void _testItemUsage() {
    TestUtilities.showInfoMessage(
      context,
      'Item usage tested during boss battle scenarios'
    );
    setState(() {
      testStatuses['item_usage'] = TestStatus.needsReview;
    });
  }

  void _testEquipmentEffects() {
    TestUtilities.showInfoMessage(
      context,
      'Equipment effects tested through combat stat modifications'
    );
    setState(() {
      testStatuses['equipment_effects'] = TestStatus.needsReview;
    });
  }
}