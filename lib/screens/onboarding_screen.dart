import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_navigation_screen.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;

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
      description: 'Learn languages through fun conversations with friendly AI characters in immersive cultural environments!',
      icon: Icons.waving_hand,
      color: cartoon.CartoonDesignSystem.sunshineYellow,
    ),
    OnboardingPage(
      title: 'Voice Adventure',
      description: 'Talk and play! Our friendly AI friends will listen to you speak Thai and help you sound amazing.',
      icon: Icons.mic,
      color: cartoon.CartoonDesignSystem.cherryRed,
    ),
    OnboardingPage(
      title: 'Writing Fun',
      description: 'Draw beautiful Thai letters! Trace characters and learn to write in this exciting adventure.',
      icon: Icons.edit,
      color: cartoon.CartoonDesignSystem.warmOrange,
    ),
    OnboardingPage(
      title: 'Let\'s Go Adventure!',
      description: 'Your amazing Thai learning journey starts now. Meet new friends and explore the wonderful world of Thai!',
      icon: Icons.rocket_launch,
      color: cartoon.CartoonDesignSystem.skyBlue,
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
    // Onboarding completion will be tracked through profile system
    _navigateToMain();
  }

  void _completeOnboarding() {
    // Onboarding completion will be tracked through profile system
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
      backgroundColor: cartoon.CartoonDesignSystem.creamWhite,
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
                      style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
                        color: cartoon.CartoonDesignSystem.cherryRed,
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
                        foregroundColor: cartoon.CartoonDesignSystem.textOnBright,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                        ),
                        elevation: 8,
                        shadowColor: _pages[_currentPage].color.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Let\'s Start!' : 'Next Adventure',
                        style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cartoon.CartoonDesignSystem.textOnBright,
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
              color: page.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: page.color,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.color.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
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
            style: cartoon.CartoonDesignSystem.headlineLarge.copyWith(
              color: cartoon.CartoonDesignSystem.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textSecondary,
              height: 1.6,
              fontSize: 16,
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
        color: isActive ? color : cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.4),
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