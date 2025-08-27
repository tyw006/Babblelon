import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/test_utilities.dart';

/// Test screen for Core Game Mechanics
class GameMechanicsTestScreen extends ConsumerStatefulWidget {
  const GameMechanicsTestScreen({super.key});

  @override
  ConsumerState<GameMechanicsTestScreen> createState() => _GameMechanicsTestScreenState();
}

class _GameMechanicsTestScreenState extends ConsumerState<GameMechanicsTestScreen> {
  Map<String, TestStatus> testStatuses = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.videogame_asset, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Core Game Mechanics Tests',
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
              '🎮 Core Game Mechanics Testing',
              'Test player movement, collision detection, dialogue systems, and game flow',
            ),
            const SizedBox(height: 24),

            // Player & Movement Tests
            _buildTestSection(
              'Player & Movement',
              [
                _buildGameTestScenario(
                  'player_movement',
                  'Player Movement Controls',
                  'Test player character movement and controls',
                  Icons.directions_walk,
                  Colors.blue,
                  () => _testPlayerMovement(),
                ),
                _buildGameTestScenario(
                  'collision_detection',
                  'Collision Detection',
                  'Test collision system with NPCs and environment',
                  Icons.touch_app,
                  Colors.green,
                  () => _testCollisionDetection(),
                ),
                _buildGameTestScenario(
                  'camera_system',
                  'Camera System',
                  'Test camera following and game view management',
                  Icons.videocam,
                  Colors.purple,
                  () => _testCameraSystem(),
                ),
                _buildGameTestScenario(
                  'capybara_companion',
                  'Capybara Companion',
                  'Test pet companion AI and interactions',
                  Icons.pets,
                  Colors.brown,
                  () => _testCapybaraCompanion(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // NPC & Dialogue Tests
            _buildTestSection(
              'NPC & Dialogue System',
              [
                _buildGameTestScenario(
                  'npc_interactions',
                  'NPC Interactions',
                  'Test NPC detection and interaction triggers',
                  Icons.people,
                  Colors.teal,
                  () => _testNPCInteractions(),
                ),
                _buildGameTestScenario(
                  'dialogue_overlay',
                  'Dialogue Overlay System',
                  'Test conversation interface and speech bubbles',
                  Icons.chat_bubble,
                  Colors.indigo,
                  () => _testDialogueOverlay(),
                ),
                _buildGameTestScenario(
                  'speech_recognition',
                  'Speech Recognition Integration',
                  'Test voice input during conversations',
                  Icons.mic,
                  Colors.red,
                  () => _testSpeechRecognition(),
                ),
                _buildGameTestScenario(
                  'npc_responses',
                  'NPC Response Generation',
                  'Test AI-generated NPC dialogue responses',
                  Icons.psychology,
                  Colors.pink,
                  () => _testNPCResponses(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Portal & Navigation Tests
            _buildTestSection(
              'Portal & Navigation',
              [
                _buildGameTestScenario(
                  'portal_system',
                  'Portal Transportation',
                  'Test portal detection and scene transitions',
                  Icons.circle,
                  Colors.orange,
                  () => _testPortalSystem(),
                ),
                _buildGameTestScenario(
                  'map_navigation',
                  'Map Navigation',
                  'Test Thailand map screen and location selection',
                  Icons.map,
                  Colors.cyan,
                  () => _testMapNavigation(),
                ),
                _buildGameTestScenario(
                  'scene_loading',
                  'Scene Loading',
                  'Test game scene loading and asset management',
                  Icons.refresh,
                  Colors.amber,
                  () => _testSceneLoading(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Progress & Tracking Tests
            _buildTestSection(
              'Progress & Tracking',
              [
                _buildGameTestScenario(
                  'vocabulary_tracking',
                  'Vocabulary Progress Tracking',
                  'Test word learning and retention tracking',
                  Icons.book,
                  Colors.deepPurple,
                  () => _testVocabularyTracking(),
                ),
                _buildGameTestScenario(
                  'charm_system',
                  'NPC Charm System',
                  'Test relationship tracking with NPCs',
                  Icons.favorite,
                  Colors.pink,
                  () => _testCharmSystem(),
                ),
                _buildGameTestScenario(
                  'score_calculation',
                  'Score Calculation',
                  'Test pronunciation and conversation scoring',
                  Icons.calculate,
                  Colors.blue,
                  () => _testScoreCalculation(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            TestUtilities.buildInfoBox(
              'Game Mechanics Testing Tips:\n'
              '• Test on different device sizes and orientations\n'
              '• Verify smooth frame rate during gameplay\n'
              '• Check collision accuracy and responsiveness\n'
              '• Test dialogue flow interruption and resumption\n'
              '• Validate progress persistence across sessions',
              color: Colors.blue,
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

  Widget _buildGameTestScenario(
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

  // Test action methods - placeholder implementations
  void _testPlayerMovement() {
    TestUtilities.showInfoMessage(context, 'Player movement tested through main game interface');
    setState(() => testStatuses['player_movement'] = TestStatus.needsReview);
  }

  void _testCollisionDetection() {
    TestUtilities.showInfoMessage(context, 'Collision detection tested through NPC interactions');
    setState(() => testStatuses['collision_detection'] = TestStatus.needsReview);
  }

  void _testCameraSystem() {
    TestUtilities.showInfoMessage(context, 'Camera system tested during gameplay');
    setState(() => testStatuses['camera_system'] = TestStatus.needsReview);
  }

  void _testCapybaraCompanion() {
    TestUtilities.showInfoMessage(context, 'Capybara companion tested through game scenes');
    setState(() => testStatuses['capybara_companion'] = TestStatus.needsReview);
  }

  void _testNPCInteractions() {
    TestUtilities.showInfoMessage(context, 'NPC interactions tested through dialogue triggers');
    setState(() => testStatuses['npc_interactions'] = TestStatus.needsReview);
  }

  void _testDialogueOverlay() {
    TestUtilities.showInfoMessage(context, 'Dialogue overlay tested through NPC conversations');
    setState(() => testStatuses['dialogue_overlay'] = TestStatus.needsReview);
  }

  void _testSpeechRecognition() {
    TestUtilities.showInfoMessage(context, 'Speech recognition tested through voice interactions');
    setState(() => testStatuses['speech_recognition'] = TestStatus.needsReview);
  }

  void _testNPCResponses() {
    TestUtilities.showInfoMessage(context, 'NPC responses tested through AI dialogue generation');
    setState(() => testStatuses['npc_responses'] = TestStatus.needsReview);
  }

  void _testPortalSystem() {
    TestUtilities.showInfoMessage(context, 'Portal system tested through map transitions');
    setState(() => testStatuses['portal_system'] = TestStatus.needsReview);
  }

  void _testMapNavigation() {
    TestUtilities.showInfoMessage(context, 'Map navigation tested through Thailand map screen');
    setState(() => testStatuses['map_navigation'] = TestStatus.needsReview);
  }

  void _testSceneLoading() {
    TestUtilities.showInfoMessage(context, 'Scene loading tested through game transitions');
    setState(() => testStatuses['scene_loading'] = TestStatus.needsReview);
  }

  void _testVocabularyTracking() {
    TestUtilities.showInfoMessage(context, 'Vocabulary tracking tested through learning progress');
    setState(() => testStatuses['vocabulary_tracking'] = TestStatus.needsReview);
  }

  void _testCharmSystem() {
    TestUtilities.showInfoMessage(context, 'Charm system tested through NPC relationship tracking');
    setState(() => testStatuses['charm_system'] = TestStatus.needsReview);
  }

  void _testScoreCalculation() {
    TestUtilities.showInfoMessage(context, 'Score calculation tested through pronunciation assessment');
    setState(() => testStatuses['score_calculation'] = TestStatus.needsReview);
  }
}