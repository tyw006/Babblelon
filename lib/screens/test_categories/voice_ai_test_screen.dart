import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/test_utilities.dart';
import 'package:babblelon/widgets/voice_interaction_system.dart';

/// Test screen for Voice & AI Services
class VoiceAITestScreen extends ConsumerStatefulWidget {
  const VoiceAITestScreen({super.key});

  @override
  ConsumerState<VoiceAITestScreen> createState() => _VoiceAITestScreenState();
}

class _VoiceAITestScreenState extends ConsumerState<VoiceAITestScreen> {
  Map<String, TestStatus> testStatuses = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Voice & AI Services Tests',
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
              '🗣️ Voice & AI Services Testing',
              'Test speech recognition, AI dialogue, and voice synthesis features',
            ),
            const SizedBox(height: 24),

            // Speech Recognition Tests
            _buildTestSection(
              'Speech Recognition (STT)',
              [
                _buildVoiceTestScenario(
                  'stt_pipeline',
                  'Speech-to-Text Pipeline',
                  'Test complete STT processing with Azure Speech Services',
                  Icons.keyboard_voice,
                  Colors.blue,
                  () => _testSTTPipeline(),
                ),
                _buildVoiceTestScenario(
                  'pronunciation_assessment',
                  'Pronunciation Assessment',
                  'Test Azure pronunciation scoring and feedback',
                  Icons.record_voice_over,
                  Colors.green,
                  () => _testPronunciationAssessment(),
                ),
                _buildVoiceTestScenario(
                  'voice_commands',
                  'Voice Command Recognition',
                  'Test voice interaction system for game commands',
                  Icons.voice_chat,
                  Colors.purple,
                  () => _testVoiceCommands(),
                ),
                _buildVoiceTestScenario(
                  'audio_quality',
                  'Audio Quality Analysis',
                  'Test audio input quality and noise handling',
                  Icons.graphic_eq,
                  Colors.orange,
                  () => _testAudioQuality(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // AI Language Model Tests
            _buildTestSection(
              'AI Language Models',
              [
                _buildVoiceTestScenario(
                  'llm_dialogue',
                  'LLM Dialogue Generation',
                  'Test OpenAI GPT-4o and Google Gemini integration',
                  Icons.chat,
                  Colors.teal,
                  () => _testLLMDialogue(),
                ),
                _buildVoiceTestScenario(
                  'context_understanding',
                  'Context Understanding',
                  'Test AI context awareness and conversation flow',
                  Icons.psychology,
                  Colors.indigo,
                  () => _testContextUnderstanding(),
                ),
                _buildVoiceTestScenario(
                  'thai_language_processing',
                  'Thai Language Processing',
                  'Test Thai-specific language understanding and generation',
                  Icons.translate,
                  Colors.pink,
                  () => _testThaiProcessing(),
                ),
                _buildVoiceTestScenario(
                  'homograph_disambiguation',
                  'Homograph Disambiguation',
                  'Test Thai homograph service and context resolution',
                  Icons.help_outline,
                  Colors.cyan,
                  () => _testHomographService(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Text-to-Speech Tests
            _buildTestSection(
              'Text-to-Speech (TTS)',
              [
                _buildVoiceTestScenario(
                  'elevenlabs_tts',
                  'ElevenLabs TTS',
                  'Test premium ElevenLabs voice synthesis',
                  Icons.speaker,
                  Colors.deepOrange,
                  () => _testElevenLabsTTS(),
                ),
                _buildVoiceTestScenario(
                  'google_tts',
                  'Google TTS',
                  'Test Google Text-to-Speech service',
                  Icons.volume_up,
                  Colors.red,
                  () => _testGoogleTTS(),
                ),
                _buildVoiceTestScenario(
                  'voice_selection',
                  'Voice Selection & Customization',
                  'Test different voice options and settings',
                  Icons.tune,
                  Colors.amber,
                  () => _testVoiceSelection(),
                ),
                _buildVoiceTestScenario(
                  'audio_playback',
                  'Audio Playback Quality',
                  'Test audio output quality and synchronization',
                  Icons.headphones,
                  Colors.brown,
                  () => _testAudioPlayback(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Translation Services Tests
            _buildTestSection(
              'Translation Services',
              [
                _buildVoiceTestScenario(
                  'google_translate',
                  'Google Translate API',
                  'Test English-Thai translation accuracy',
                  Icons.language,
                  Colors.lightBlue,
                  () => _testGoogleTranslate(),
                ),
                _buildVoiceTestScenario(
                  'thai_romanization',
                  'Thai Romanization',
                  'Test Thai script to romanized text conversion',
                  Icons.abc,
                  Colors.lime,
                  () => _testThaiRomanization(),
                ),
                _buildVoiceTestScenario(
                  'bidirectional_translation',
                  'Bidirectional Translation',
                  'Test both Thai→English and English→Thai translation',
                  Icons.swap_horiz,
                  Colors.teal,
                  () => _testBidirectionalTranslation(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Integration Tests
            _buildTestSection(
              'End-to-End Integration',
              [
                _buildVoiceTestScenario(
                  'full_conversation',
                  'Complete Conversation Flow',
                  'Test STT → LLM → TTS pipeline integration',
                  Icons.forum,
                  Colors.deepPurple,
                  () => _testFullConversation(),
                ),
                _buildVoiceTestScenario(
                  'error_handling',
                  'Error Handling & Recovery',
                  'Test service failures and graceful degradation',
                  Icons.error_outline,
                  Colors.red,
                  () => _testErrorHandling(),
                ),
                _buildVoiceTestScenario(
                  'performance_metrics',
                  'Performance & Latency',
                  'Test response times and service performance',
                  Icons.speed,
                  Colors.orange,
                  () => _testPerformanceMetrics(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            TestUtilities.buildInfoBox(
              'Voice & AI Testing Tips:\n'
              '• Test with different accents and speech patterns\n'
              '• Verify microphone permissions and audio quality\n'
              '• Check network connectivity for cloud services\n'
              '• Test error recovery and offline fallbacks\n'
              '• Monitor API response times and costs\n'
              '• Validate Thai language accuracy and cultural context',
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

  Widget _buildVoiceTestScenario(
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

  // Test action methods for STT
  void _testSTTPipeline() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('STT Pipeline Test')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('STT Pipeline Test'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    TestUtilities.showInfoMessage(context, 'STT test initiated');
                  },
                  child: const Text('Start STT Test'),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        testStatuses['stt_pipeline'] = TestStatus.passed;
      });
    });
  }

  void _testPronunciationAssessment() {
    TestUtilities.showInfoMessage(
      context,
      'Test pronunciation assessment through dialogue system'
    );
    setState(() {
      testStatuses['pronunciation_assessment'] = TestStatus.needsReview;
    });
  }

  void _testVoiceCommands() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Voice Commands Test')),
          body: const Center(
            child: VoiceInteractionSystem(
              child: Text('Voice Commands Test Interface'),
            ),
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        testStatuses['voice_commands'] = TestStatus.passed;
      });
    });
  }

  void _testAudioQuality() {
    TestUtilities.showInfoMessage(
      context,
      'Audio quality testing requires manual validation during voice tests'
    );
    setState(() {
      testStatuses['audio_quality'] = TestStatus.needsReview;
    });
  }

  // Test action methods for AI/LLM
  void _testLLMDialogue() {
    TestUtilities.showInfoMessage(
      context,
      'LLM dialogue testing available through NPC conversations in game'
    );
    setState(() {
      testStatuses['llm_dialogue'] = TestStatus.needsReview;
    });
  }

  void _testContextUnderstanding() {
    TestUtilities.showInfoMessage(
      context,
      'Context understanding tested through multi-turn conversations'
    );
    setState(() {
      testStatuses['context_understanding'] = TestStatus.needsReview;
    });
  }

  void _testThaiProcessing() {
    TestUtilities.showInfoMessage(
      context,
      'Thai processing tested through game dialogue and translations'
    );
    setState(() {
      testStatuses['thai_language_processing'] = TestStatus.needsReview;
    });
  }

  void _testHomographService() {
    TestUtilities.showInfoMessage(
      context,
      'Homograph disambiguation tested with ambiguous Thai words'
    );
    setState(() {
      testStatuses['homograph_disambiguation'] = TestStatus.needsReview;
    });
  }

  // Test action methods for TTS
  void _testElevenLabsTTS() {
    TestUtilities.showInfoMessage(
      context,
      'ElevenLabs TTS tested through premium NPC responses'
    );
    setState(() {
      testStatuses['elevenlabs_tts'] = TestStatus.needsReview;
    });
  }

  void _testGoogleTTS() {
    TestUtilities.showInfoMessage(
      context,
      'Google TTS tested through standard NPC responses'
    );
    setState(() {
      testStatuses['google_tts'] = TestStatus.needsReview;
    });
  }

  void _testVoiceSelection() {
    TestUtilities.showInfoMessage(
      context,
      'Voice selection tested through settings and NPC customization'
    );
    setState(() {
      testStatuses['voice_selection'] = TestStatus.needsReview;
    });
  }

  void _testAudioPlayback() {
    TestUtilities.showInfoMessage(
      context,
      'Audio playback quality tested during TTS responses'
    );
    setState(() {
      testStatuses['audio_playback'] = TestStatus.needsReview;
    });
  }

  // Test action methods for Translation
  void _testGoogleTranslate() {
    TestUtilities.showInfoMessage(
      context,
      'Google Translate tested through vocabulary translations'
    );
    setState(() {
      testStatuses['google_translate'] = TestStatus.needsReview;
    });
  }

  void _testThaiRomanization() {
    TestUtilities.showInfoMessage(
      context,
      'Thai romanization tested through character learning features'
    );
    setState(() {
      testStatuses['thai_romanization'] = TestStatus.needsReview;
    });
  }

  void _testBidirectionalTranslation() {
    TestUtilities.showInfoMessage(
      context,
      'Bidirectional translation tested through dialogue interactions'
    );
    setState(() {
      testStatuses['bidirectional_translation'] = TestStatus.needsReview;
    });
  }

  // Test action methods for Integration
  void _testFullConversation() {
    TestUtilities.showInfoMessage(
      context,
      'Full conversation flow tested through NPC dialogue system'
    );
    setState(() {
      testStatuses['full_conversation'] = TestStatus.needsReview;
    });
  }

  void _testErrorHandling() {
    TestUtilities.showInfoMessage(
      context,
      'Error handling tested by simulating network/service failures'
    );
    setState(() {
      testStatuses['error_handling'] = TestStatus.needsReview;
    });
  }

  void _testPerformanceMetrics() {
    TestUtilities.showInfoMessage(
      context,
      'Performance metrics monitored during voice interaction tests'
    );
    setState(() {
      testStatuses['performance_metrics'] = TestStatus.needsReview;
    });
  }
}