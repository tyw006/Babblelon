import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/test_utilities.dart';
import 'package:babblelon/screens/authentication_screen.dart';
import 'package:babblelon/screens/enhanced_onboarding_screen.dart';
import 'package:babblelon/screens/email_verification_screen.dart';
import 'package:babblelon/screens/character_selection_screen.dart';
import 'package:babblelon/widgets/language_selection_modal.dart';

/// Test screen for Authentication & Onboarding features
class AuthTestScreen extends ConsumerStatefulWidget {
  const AuthTestScreen({super.key});

  @override
  ConsumerState<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends ConsumerState<AuthTestScreen> {
  Map<String, TestStatus> testStatuses = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Authentication & Onboarding Tests',
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
              '🔐 Authentication & Onboarding Testing',
              'Test all user registration, login, and profile setup flows',
            ),
            const SizedBox(height: 24),

            // Authentication Flow Tests
            _buildTestSection(
              'Authentication Flows',
              [
                _buildAuthTestScenario(
                  'full_auth_flow',
                  'Complete Authentication Flow',
                  'Test email/password, Google, and Apple sign-in options',
                  Icons.login,
                  Colors.blue,
                  () => _testAuthenticationScreen(),
                ),
                _buildAuthTestScenario(
                  'email_verification',
                  'Email Verification Process',
                  'Test email verification screen and flow',
                  Icons.email,
                  Colors.green,
                  () => _testEmailVerification(),
                ),
                _buildAuthTestScenario(
                  'auth_state_reset',
                  'Authentication State Reset',
                  'Clear auth state for fresh testing',
                  Icons.logout,
                  Colors.orange,
                  () => _resetAuthState(),
                ),
                _buildAuthTestScenario(
                  'guest_to_auth',
                  'Guest to Authenticated User',
                  'Test progressive authentication widget',
                  Icons.person_add,
                  Colors.purple,
                  () => _testGuestToAuth(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Onboarding Flow Tests
            _buildTestSection(
              'Onboarding Flows',
              [
                _buildAuthTestScenario(
                  'complete_onboarding',
                  'Complete Onboarding Flow',
                  'Test full enhanced onboarding with all steps',
                  Icons.account_circle,
                  Colors.teal,
                  () => _testCompleteOnboarding(),
                ),
                _buildAuthTestScenario(
                  'character_selection',
                  'Character Selection',
                  'Test character/avatar selection screen',
                  Icons.face,
                  Colors.pink,
                  () => _testCharacterSelection(),
                ),
                _buildAuthTestScenario(
                  'language_selection',
                  'Language Selection Modal',
                  'Test target language selection',
                  Icons.language,
                  Colors.indigo,
                  () => _testLanguageSelection(),
                ),
                _buildAuthTestScenario(
                  'profile_setup',
                  'Profile Information Setup',
                  'Test personal info, goals, and preferences',
                  Icons.assignment,
                  Colors.cyan,
                  () => _testProfileSetup(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Test Utilities Section
            _buildTestSection(
              'Test Utilities',
              [
                _buildAuthTestScenario(
                  'reset_all_progress',
                  'Reset All Progress',
                  'Clear all user progress and tutorials',
                  Icons.restart_alt,
                  Colors.red,
                  () => _resetAllProgress(),
                ),
                _buildAuthTestScenario(
                  'simulate_new_user',
                  'Simulate New User',
                  'Setup clean state for new user testing',
                  Icons.fiber_new,
                  Colors.green,
                  () => _simulateNewUser(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            TestUtilities.buildInfoBox(
              'Authentication Testing Tips:\n'
              '• Test with different email providers\n'
              '• Verify Google/Apple sign-in integration\n'
              '• Check username availability validation\n'
              '• Test profile setup completion detection\n'
              '• Verify Supabase user data persistence',
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

  Widget _buildAuthTestScenario(
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
  void _testAuthenticationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthenticationScreen()),
    ).then((_) {
      setState(() {
        testStatuses['full_auth_flow'] = TestStatus.passed;
      });
    });
  }

  void _testEmailVerification() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmailVerificationScreen()),
    ).then((_) {
      setState(() {
        testStatuses['email_verification'] = TestStatus.passed;
      });
    });
  }

  void _resetAuthState() async {
    setState(() {
      testStatuses['auth_state_reset'] = TestStatus.inProgress;
    });

    await TestUtilities.resetAuthState();
    
    if (mounted) {
      TestUtilities.showSuccessMessage(
        context, 
        'Authentication state cleared successfully'
      );
      setState(() {
        testStatuses['auth_state_reset'] = TestStatus.passed;
      });
    }
  }

  void _testGuestToAuth() {
    TestUtilities.showInfoMessage(
      context,
      'Progressive auth widget test - check main app flow'
    );
    setState(() {
      testStatuses['guest_to_auth'] = TestStatus.needsReview;
    });
  }

  void _testCompleteOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EnhancedOnboardingScreen()),
    ).then((_) {
      setState(() {
        testStatuses['complete_onboarding'] = TestStatus.passed;
      });
    });
  }

  void _testCharacterSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CharacterSelectionScreen()),
    ).then((_) {
      setState(() {
        testStatuses['character_selection'] = TestStatus.passed;
      });
    });
  }

  void _testLanguageSelection() {
    showDialog(
      context: context,
      builder: (context) => LanguageSelectionModal(
        initialLanguage: 'th',
        onLanguageSelected: (languageCode) {
          TestUtilities.showInfoMessage(context, 'Selected language: $languageCode');
        },
      ),
    ).then((_) {
      setState(() {
        testStatuses['language_selection'] = TestStatus.passed;
      });
    });
  }

  void _testProfileSetup() {
    TestUtilities.showInfoMessage(
      context,
      'Profile setup is part of enhanced onboarding flow'
    );
    setState(() {
      testStatuses['profile_setup'] = TestStatus.needsReview;
    });
  }

  void _resetAllProgress() async {
    setState(() {
      testStatuses['reset_all_progress'] = TestStatus.inProgress;
    });

    await TestUtilities.resetAllTutorials(ref);
    
    if (mounted) {
      TestUtilities.showSuccessMessage(
        context,
        'All progress reset successfully'
      );
      setState(() {
        testStatuses['reset_all_progress'] = TestStatus.passed;
      });
    }
  }

  void _simulateNewUser() async {
    setState(() {
      testStatuses['simulate_new_user'] = TestStatus.inProgress;
    });

    await TestUtilities.resetAuthState();
    await TestUtilities.resetAllTutorials(ref);
    
    if (mounted) {
      TestUtilities.showSuccessMessage(
        context,
        'New user state simulated successfully'
      );
      setState(() {
        testStatuses['simulate_new_user'] = TestStatus.passed;
      });
    }
  }
}