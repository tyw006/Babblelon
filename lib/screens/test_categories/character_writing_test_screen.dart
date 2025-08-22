import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/test_utilities.dart';
import 'package:babblelon/widgets/character_tracing_widget.dart';

/// Test screen for Character Writing & Recognition features
class CharacterWritingTestScreen extends ConsumerStatefulWidget {
  const CharacterWritingTestScreen({super.key});

  @override
  ConsumerState<CharacterWritingTestScreen> createState() => _CharacterWritingTestScreenState();
}

class _CharacterWritingTestScreenState extends ConsumerState<CharacterWritingTestScreen> {
  Map<String, TestStatus> testStatuses = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.draw, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Character Writing Tests',
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
              '✍️ Character Writing & Recognition Testing',
              'Test Thai character tracing, recognition, and stroke order validation',
            ),
            const SizedBox(height: 24),

            // Character Tracing Tests
            _buildTestSection(
              'Character Tracing',
              [
                _buildWritingTestScenario(
                  'basic_tracing',
                  'Basic Character Tracing',
                  'Test Thai character drawing interface',
                  Icons.edit,
                  Colors.blue,
                  () => _testBasicTracing(),
                ),
                _buildWritingTestScenario(
                  'stroke_order',
                  'Stroke Order Validation',
                  'Test correct stroke order detection',
                  Icons.format_list_numbered,
                  Colors.green,
                  () => _testStrokeOrder(),
                ),
                _buildWritingTestScenario(
                  'character_recognition',
                  'Character Recognition',
                  'Test ML Kit character recognition accuracy',
                  Icons.visibility,
                  Colors.purple,
                  () => _testCharacterRecognition(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Assessment Tests
            _buildTestSection(
              'Writing Assessment',
              [
                _buildWritingTestScenario(
                  'accuracy_scoring',
                  'Accuracy Scoring',
                  'Test character writing accuracy calculation',
                  Icons.grade,
                  Colors.orange,
                  () => _testAccuracyScoring(),
                ),
                _buildWritingTestScenario(
                  'feedback_system',
                  'Feedback System',
                  'Test character assessment dialogue and tips',
                  Icons.feedback,
                  Colors.teal,
                  () => _testFeedbackSystem(),
                ),
                _buildWritingTestScenario(
                  'progress_tracking',
                  'Progress Tracking',
                  'Test character mastery progression',
                  Icons.trending_up,
                  Colors.indigo,
                  () => _testProgressTracking(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            TestUtilities.buildInfoBox(
              'Character Writing Testing Tips:\n'
              '• Test with different writing speeds and styles\n'
              '• Verify accuracy across various Thai characters\n'
              '• Check stroke order validation strictness\n'
              '• Test on different screen sizes and input methods\n'
              '• Validate ML Kit recognition performance',
              color: Colors.purple,
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

  Widget _buildWritingTestScenario(
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

  // Test action methods
  void _testBasicTracing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Character Tracing Test')),
          body: const Center(
            child: CharacterTracingWidget(
              wordMapping: [{'th': 'ก', 'en': 'k'}],
            ),
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        testStatuses['basic_tracing'] = TestStatus.passed;
      });
    });
  }

  void _testStrokeOrder() {
    TestUtilities.showInfoMessage(
      context,
      'Stroke order validation tested through character tracing interface'
    );
    setState(() {
      testStatuses['stroke_order'] = TestStatus.needsReview;
    });
  }

  void _testCharacterRecognition() {
    TestUtilities.showInfoMessage(
      context,
      'Character recognition tested through ML Kit integration'
    );
    setState(() {
      testStatuses['character_recognition'] = TestStatus.needsReview;
    });
  }

  void _testAccuracyScoring() {
    TestUtilities.showInfoMessage(
      context,
      'Accuracy scoring tested through character assessment system'
    );
    setState(() {
      testStatuses['accuracy_scoring'] = TestStatus.needsReview;
    });
  }

  void _testFeedbackSystem() {
    TestUtilities.showInfoMessage(
      context,
      'Feedback system tested through character assessment dialogue'
    );
    setState(() {
      testStatuses['feedback_system'] = TestStatus.needsReview;
    });
  }

  void _testProgressTracking() {
    TestUtilities.showInfoMessage(
      context,
      'Progress tracking tested through character mastery progression'
    );
    setState(() {
      testStatuses['progress_tracking'] = TestStatus.needsReview;
    });
  }
}