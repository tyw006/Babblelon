import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/onboarding_provider.dart';
import 'package:babblelon/screens/main_navigation_screen.dart';
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';

/// Streamlined onboarding flow with skip-first design
/// Performance optimized with fast transitions
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to BabbleOn',
      description: 'Learn Thai through immersive conversations with AI-powered NPCs in Bangkok\'s vibrant Yaowarat district.',
      icon: Icons.waving_hand,
      color: ModernDesignSystem.electricCyan,
    ),
    OnboardingPage(
      title: 'Voice Interaction',
      description: 'Practice speaking Thai naturally. Our AI listens, understands, and responds to help you improve your pronunciation.',
      icon: Icons.mic,
      color: ModernDesignSystem.warmOrange,
    ),
    OnboardingPage(
      title: 'Character Learning',
      description: 'Master Thai script by tracing characters. Learn to read and write with interactive guided practice.',
      icon: Icons.edit,
      color: ModernDesignSystem.electricCyan,
    ),
    OnboardingPage(
      title: 'Ready to Start?',
      description: 'Your Thai learning adventure awaits. Explore Bangkok, meet characters, and build your language skills naturally.',
      icon: Icons.rocket_launch,
      color: ModernDesignSystem.warmOrange,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _skipOnboarding() {
    ref.read(onboardingCompletedProvider.notifier).skipOnboarding();
    _navigateToMain();
  }

  void _completeOnboarding() {
    ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
    _navigateToMain();
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainNavigationScreen(),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernDesignSystem.deepSpaceBlue,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (prominent at top)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: AppTheme.textTheme.titleMedium?.copyWith(
                        color: ModernDesignSystem.electricCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Page view content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageWidget(
                    page: _pages[index],
                    isActive: index == _currentPage,
                  );
                },
              ),
            ),
            
            // Bottom navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => _PageIndicator(
                        isActive: index == _currentPage,
                        color: _pages[index].color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Next/Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        foregroundColor: ModernDesignSystem.deepSpaceBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual onboarding page widget
class _OnboardingPageWidget extends StatelessWidget {
  final OnboardingPage page;
  final bool isActive;

  const _OnboardingPageWidget({
    required this.page,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with space theme
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: page.color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Title
          Text(
            page.title,
            style: AppTheme.textTheme.headlineMedium?.copyWith(
              color: page.color,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            style: AppTheme.textTheme.bodyLarge?.copyWith(
              color: ModernDesignSystem.slateGray,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Page indicator dot
class _PageIndicator extends StatelessWidget {
  final bool isActive;
  final Color color;

  const _PageIndicator({
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? color : ModernDesignSystem.slateGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Onboarding page data model
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}