import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_navigation_screen.dart';
import 'package:babblelon/screens/enhanced_onboarding_screen.dart';
import 'package:babblelon/screens/cartoon_splash_screen.dart';
import 'package:babblelon/screens/authentication_screen.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart';

/// Streamlined test navigation screen with 3 essential testing scenarios
/// Focuses on real Supabase integration testing without test user system
class TestNavigationScreen extends ConsumerStatefulWidget {
  const TestNavigationScreen({super.key});

  @override
  ConsumerState<TestNavigationScreen> createState() => _TestNavigationScreenState();
}

class _TestNavigationScreenState extends ConsumerState<TestNavigationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.science, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              'BabbleOn Testing Lab',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.videogame_asset), text: 'Start Game'),
            Tab(icon: Icon(Icons.person_add), text: 'Fresh User'),
            Tab(icon: Icon(Icons.login), text: 'New User'),
            Tab(icon: Icon(Icons.refresh), text: 'Returning User'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStartGameTab(),
          _buildFreshUserTab(),
          _buildNewUserTab(),
          _buildReturningUserTab(),
        ],
      ),
    );
  }


  Widget _buildStartGameTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            '🎮 Start Game Flow',
            'Test the complete production-like game flow with authentication',
          ),
          const SizedBox(height: 24),
          
          _buildGameFlowCard(),
          
          const SizedBox(height: 16),
          _buildTestCard(
            title: 'Quick Auth Test',
            description: 'Skip 3D Earth, go directly to authentication screen',
            icon: Icons.login,
            color: Colors.blue,
            onTap: () => _testQuickAuth(),
          ),
          
          const SizedBox(height: 16),
          _buildTestCard(
            title: 'Auth State Reset',
            description: 'Clear authentication state for fresh testing',
            icon: Icons.logout,
            color: Colors.orange,
            onTap: () => _resetAuthState(),
          ),
          
          const SizedBox(height: 24),
          _buildInfoBox(
            'Production Flow Testing:\n'
            '• 3D Earth screen with proper animations\n'
            '• Authentication check on "Start Journey"\n'
            '• Apple Sign-In, Google Sign-In, Email options\n'
            '• Onboarding for new users\n'
            '• Main navigation for returning users',
          ),
        ],
      ),
    );
  }

  Widget _buildFreshUserTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            '👤 Fresh User Onboarding Test',
            'Complete onboarding process with real Supabase integration',
          ),
          const SizedBox(height: 24),
          
          _buildTestCard(
            title: 'Start Fresh Onboarding',
            description: 'Test complete signup flow with username availability checking and Supabase writes',
            icon: Icons.person_add,
            color: Colors.green,
            onTap: () => _testFreshUserOnboarding(),
          ),
          
          const SizedBox(height: 16),
          _buildTestCard(
            title: 'Reset All Progress',
            description: 'Clear all tutorial progress to simulate completely fresh user',
            icon: Icons.restart_alt,
            color: Colors.red,
            onTap: () => _resetAllProgress(),
          ),
          
          const SizedBox(height: 24),
          _buildInfoBox(
            'This tests:\n'
            '• Real authentication flow\n'
            '• Username availability checking\n'
            '• Supabase player table writes\n'
            '• Tutorial system initialization',
          ),
        ],
      ),
    );
  }

  Widget _buildNewUserTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            '🌟 New User Flow Test',
            'Test app start for authenticated user with no progress',
          ),
          const SizedBox(height: 24),
          
          _buildTestCard(
            title: 'Start as New User',
            description: 'Start from 3D earth screen, test authentication flow',
            icon: Icons.public,
            color: Colors.blue,
            onTap: () => _testNewUserFlow(),
          ),
          
          const SizedBox(height: 16),
          _buildTestCard(
            title: 'Direct to Main Navigation',
            description: 'Test main navigation screen with clean slate',
            icon: Icons.navigation,
            color: Colors.teal,
            onTap: () => _testMainNavigation(),
          ),
          
          const SizedBox(height: 24),
          _buildInfoBox(
            'This tests:\n'
            '• 3D earth → authentication check\n'
            '• Profile setup flow\n'
            '• Initial tutorial triggers\n'
            '• First-time user experience',
          ),
        ],
      ),
    );
  }

  Widget _buildReturningUserTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            '🔄 Returning User Test',
            'Test app behavior for users with completed tutorials',
          ),
          const SizedBox(height: 24),
          
          _buildTestCard(
            title: 'Simulate Returning User',
            description: 'Mark key tutorials as completed and test flow',
            icon: Icons.check_circle,
            color: Colors.purple,
            onTap: () => _simulateReturningUser(),
          ),
          
          const SizedBox(height: 16),
          _buildTestCard(
            title: 'Test Tutorial Skipping',
            description: 'Verify tutorials are skipped for experienced users',
            icon: Icons.skip_next,
            color: Colors.orange,
            onTap: () => _testTutorialSkipping(),
          ),
          
          const SizedBox(height: 16),
          _buildTestCard(
            title: 'View Supabase Metrics',
            description: 'Read user progress and statistics from database',
            icon: Icons.analytics,
            color: Colors.indigo,
            onTap: () => _viewSupabaseMetrics(),
          ),
          
          const SizedBox(height: 24),
          _buildInfoBox(
            'This tests:\n'
            '• Tutorial completion tracking\n'
            '• Supabase metrics reading\n'
            '• User progress persistence\n'
            '• Returning user experience',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildGameFlowCard() {
    return GestureDetector(
      onTap: () => _startProductionFlow(),
      onLongPress: () => _startGameWithAuthBypass(),
      child: Card(
        color: const Color(0xFF16213E),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Icon(Icons.play_arrow, color: Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Game (Full Flow)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '3D Earth → Start Journey → Authentication → Game',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '💡 Long press to bypass auth for testing',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade600,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF16213E),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
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
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade600,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Test methods
  
  // Game Flow Test Methods
  void _startProductionFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartoonSplashScreen()),
    );
  }
  
  void _testQuickAuth() {
    // Import needed for AuthenticationScreen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthenticationScreen()),
    );
  }
  
  void _resetAuthState() async {
    try {
      // Import needed for auth service
      final authService = AuthServiceFactory.getInstance();
      await authService.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication state cleared - ready for fresh auth test')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing auth state: $e')),
        );
      }
    }
  }
  
  // Component Test Methods
  void _testFreshUserOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EnhancedOnboardingScreen()),
    );
  }

  void _resetAllProgress() async {
    await ref.read(tutorialCompletionProvider.notifier).resetAllTutorials();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All progress reset - ready for fresh user test')),
      );
    }
  }

  void _testNewUserFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartoonSplashScreen()),
    );
  }

  void _testMainNavigation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
    );
  }

  void _simulateReturningUser() async {
    // Mark some key tutorials as completed
    await ref.read(tutorialCompletionProvider.notifier).markTutorialCompleted('main_navigation_intro');
    await ref.read(tutorialCompletionProvider.notifier).markTutorialCompleted('game_loading_intro');
    await ref.read(tutorialCompletionProvider.notifier).markTutorialCompleted('first_npc_interaction');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User marked as returning - key tutorials completed')),
      );
    }
  }

  void _testTutorialSkipping() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
    );
  }

  void _startGameWithAuthBypass() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auth bypassed - went directly to main navigation'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _viewSupabaseMetrics() async {
    // TODO: Implement Supabase metrics reading
    final stats = await ref.read(tutorialStatsProvider.future);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Supabase Metrics'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Completed: ${stats['total_completed'] ?? 0}'),
                Text('Completed Tutorials: ${stats['completed_tutorials']?.join(', ') ?? 'None'}'),
                Text('Last Active: ${stats['last_active'] ?? 'Never'}'),
                Text('Profile Created: ${stats['profile_created'] ?? 'Not set'}'),
                const SizedBox(height: 16),
                const Text(
                  'TODO: Add more metrics from players table:\n'
                  '• User learning progress\n'
                  '• Pronunciation scores\n'
                  '• Game completion rates',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}