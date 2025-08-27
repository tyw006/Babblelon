import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/battle_providers.dart';
import 'package:babblelon/theme/modern_design_system.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:babblelon/screens/main_screen/widgets/glassmorphic_card.dart';
import 'package:babblelon/widgets/popups/base_popup_widget.dart';

class DefeatDialog extends ConsumerStatefulWidget {
  final BattleMetrics metrics;

  const DefeatDialog({super.key, required this.metrics});

  @override
  ConsumerState<DefeatDialog> createState() => _DefeatDialogState();
}

class _DefeatDialogState extends ConsumerState<DefeatDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _numberController;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _numberAnimation;
  late Animation<double> _progressAnimation;
  
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _numberAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _numberController,
      curve: Curves.easeOutCubic,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    // Start staggered animations with assessment dialog timing
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _numberController.forward();
      // TODO: Add sound effects during number animation
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _progressController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    _numberController.dispose();
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isSmallScreen ? 10.0 : 20.0),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: GlassmorphicCard(
            padding: EdgeInsets.zero,
            blur: 20,
            opacity: 0.15,
            margin: EdgeInsets.zero,
            child: Container(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.85,
              maxWidth: isSmallScreen ? screenSize.width * 0.95 : 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(),
                
                // Page Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildPage1_MotivationAndProgress(),
                      _buildPage2_DiagnosticReport(),
                      _buildPage3_StrategyAndActions(),
                    ],
                  ),
                ),
                
                // Page Indicator
                _buildPageIndicator(),
                
                // Action Buttons (Fixed Footer)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false), // false = exit
                          style: BasePopup.secondaryButtonStyle,
                          child: const Text(
                            'LEAVE BATTLE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(true); // true = retry
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4CAF50), // Bright green like assessment
                                  Color(0xFF45A049), // Darker green
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Text(
                              'RETRY BATTLE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
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
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.sentiment_neutral,
            size: 50,
            color: Color(0xFF00BCD4), // Bright cyan like assessment
          ),
          const SizedBox(height: 8),
          Text(
            'TRY AGAIN!',
            style: TextStyle(
              color: const Color(0xFF00BCD4), // Bright cyan like assessment
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: const Color(0xFF00BCD4).withOpacity(0.8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          Text(
            'You were so close! Don\'t give up!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontStyle: FontStyle.italic,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPage1_MotivationAndProgress() {
    final bossHealthRemaining = (widget.metrics.bossMaxHealth - widget.metrics.totalDamageDealt.toInt()).clamp(0, widget.metrics.bossMaxHealth);
    final bossHealthPercentage = (widget.metrics.totalDamageDealt / widget.metrics.bossMaxHealth).clamp(0.0, 1.0);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Boss HP Remaining Section
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // MASSIVE Boss HP Circle - Like Assessment's 98/100
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 120, // Same size as victory grade circle
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF00BCD4).withOpacity(0.9), // Bright cyan like assessment
                              const Color(0xFF0097A7).withOpacity(0.9), // Darker cyan
                            ],
                          ),
                          border: Border.all(color: const Color(0xFF00BCD4), width: 4), // Bright cyan border
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00BCD4).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _numberAnimation,
                            builder: (context, child) {
                              final animatedDamage = (widget.metrics.totalDamageDealt * _numberAnimation.value).toInt();
                              final animatedRemaining = (widget.metrics.bossMaxHealth - animatedDamage).clamp(0, widget.metrics.bossMaxHealth);
                              return Text(
                                '$animatedRemaining\\n/${widget.metrics.bossMaxHealth}',
                                style: TextStyle(
                                  fontSize: 36, // HUGE like assessment - split across 2 lines
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1, // Tight line spacing
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF00BCD4).withOpacity(0.8),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Progress message like assessment's \"Excellent!\" 
                Text(
                  bossHealthPercentage >= 0.7 
                      ? 'So Close!'
                      : bossHealthPercentage >= 0.3
                          ? 'Getting There!'
                          : 'Keep Fighting!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFC107), // Golden yellow like assessment
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFFC107).withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // High contrast progress bar
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade800,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (bossHealthPercentage * _progressAnimation.value).clamp(0.0, 1.0),
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)), // Bright green like assessment
                        ),
                      ),
                    ).animate().scaleX(alignment: Alignment.centerLeft, duration: 1200.ms, curve: Curves.easeOutCubic);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Boss HP Remaining',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Battle Overview
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BATTLE PROGRESS',
                  style: TextStyle(
                    color: const Color(0xFF00BCD4), // Bright cyan like assessment
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnimatedStatCard(
                        'Damage Dealt', 
                        '${widget.metrics.totalDamageDealt.toInt()}',
                        Icons.flash_on,
                        const Color(0xFFEF4444), // Red for damage
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        'Battle Time', 
                        _formatDuration(widget.metrics.battleDuration),
                        Icons.timer,
                        const Color(0xFF6366F1), // Ethereal blue
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnimatedStatCard(
                        'Words Tried', 
                        '${widget.metrics.wordsUsed.length}',
                        Icons.chat_bubble,
                        const Color(0xFF8B5CF6), // Purple
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        'Best Streak', 
                        '${widget.metrics.maxStreak}',
                        Icons.local_fire_department,
                        const Color(0xFF10B981), // Green
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2_DiagnosticReport() {
    final primaryChallenge = _determinePrimaryChallenge();
    final toughestWord = _getToughestWord();
    final unsuccessfulDefenses = _calculateUnsuccessfulDefenses();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Battle Analysis Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: ModernDesignSystem.primarySurface,
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
              border: Border.all(color: ModernDesignSystem.borderPrimary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BATTLE ANALYSIS',
                  style: ModernDesignSystem.headlineMedium.copyWith(
                    fontSize: 18,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s what to focus on:',
                  style: ModernDesignSystem.bodyMedium.copyWith(
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Primary Challenge Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: ModernDesignSystem.primarySurface,
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
              border: Border.all(color: ModernDesignSystem.borderPrimary),
            ).copyWith(
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      primaryChallenge['icon'] as IconData,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Primary Challenge: ${primaryChallenge['title']}',
                        style: ModernDesignSystem.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  primaryChallenge['description'] as String,
                  style: ModernDesignSystem.bodySmall,
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _numberAnimation,
                  builder: (context, child) {
                    final animatedValue = (primaryChallenge['value'] as double) * _numberAnimation.value;
                    return Text(
                      primaryChallenge['display'](animatedValue),
                      style: ModernDesignSystem.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 18,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Toughest Phrase Card
          if (toughestWord != null)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
              color: ModernDesignSystem.primarySurface,
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
              border: Border.all(color: ModernDesignSystem.borderPrimary),
            ).copyWith(
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your Toughest Phrase:',
                          style: ModernDesignSystem.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade300,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toughestWord['word'] as String,
                          style: ModernDesignSystem.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _numberAnimation,
                          builder: (context, child) {
                            final animatedScore = ((toughestWord['score'] as double) * _numberAnimation.value).toInt();
                            return Text(
                              'Avg. Pronunciation Score: $animatedScore% (Needs Improvement)',
                              style: ModernDesignSystem.bodySmall.copyWith(
                                color: Colors.orange.shade200,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  // TODO: Implement listen functionality
                                },
                                icon: const Icon(Icons.volume_up, size: 18),
                                label: const Text('Listen'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  // TODO: Implement practice functionality
                                },
                                icon: const Icon(Icons.mic, size: 18),
                                label: const Text('Practice'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage3_StrategyAndActions() {
    final primaryChallenge = _determinePrimaryChallenge();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Strategy Tips Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: ModernDesignSystem.primarySurface,
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
              border: Border.all(color: ModernDesignSystem.borderPrimary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STRATEGY TIPS',
                  style: ModernDesignSystem.headlineMedium.copyWith(
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s how to improve:',
                  style: ModernDesignSystem.bodyMedium.copyWith(
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Dynamic Tip Based on Primary Challenge
          _buildTipCard(
            '💡',
            primaryChallenge['tip'] as String,
            Colors.blue,
          ),
          
          const SizedBox(height: 12),
          
          // General Encouragement Tip
          _buildTipCard(
            '💡',
            'Acing a high-complexity phrase can turn the tide of battle.',
            Colors.purple,
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatCard(String label, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: const Color(0xFF00BCD4), // Bright cyan like assessment
                    fontWeight: FontWeight.bold,
                    fontSize: 28, // HUGE like victory dialog
                    shadows: [
                      Shadow(
                        color: const Color(0xFF00BCD4).withValues(alpha: 0.8),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTipCard(String emoji, String tip, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.2),
            accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: ModernDesignSystem.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
              color: ModernDesignSystem.primarySurface,
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
              border: Border.all(color: ModernDesignSystem.borderPrimary),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? Colors.orange : Colors.white30,
              ),
            ),
          );
        }),
      ),
    );
  }

  // Helper methods for battle analysis
  Map<String, dynamic> _determinePrimaryChallenge() {
    final avgPron = widget.metrics.averagePronunciationScore;
    final bossHp = widget.metrics.bossMaxHealth;
    final damageDealt = widget.metrics.totalDamageDealt;

    // Scenario 1 – Low Damage Output
    if (damageDealt < bossHp * 0.5) {
      return {
        'title': 'Low Damage Output',
        'description': 'Your attacks weren\'t hitting hard enough. Focus on higher complexity words and better pronunciation.',
        'icon': Icons.trending_down,
        'value': damageDealt,
        'display': (double v) => 'Total Damage: ${v.toStringAsFixed(0)}',
        'tip': "Let's focus on damage! Try using your highest complexity cards first. Better pronunciation on those will make a huge difference. We can do this!",
      };
    }

    // Scenario 2 – Survived but Timed Out (or similar)
    if (widget.metrics.totalTurns > widget.metrics.idealTurns * 1.5) {
      return {
        'title': 'Too Slow',
        'description': 'You survived well, but the battle took too long. Speed up your attacks by choosing phrases quickly.',
        'icon': Icons.hourglass_bottom,
        'value': widget.metrics.totalTurns.toDouble(),
        'display': (double v) => 'Total Turns: ${v.toStringAsFixed(0)}',
        'tip': "We were strong, just not fast enough! Let's try to pick our words a little quicker next time. The faster we attack, the less chance the monster has to hit back!",
      };
    }

    // Scenario 3 – Pronunciation Hurdle
    if (avgPron < 70) {
      return {
        'title': 'Pronunciation Needs Work',
        'description': 'Pronunciation accuracy affected your attacks and defenses.',
        'icon': Icons.mic_off,
        'value': avgPron,
        'display': (double v) => 'Average Pronunciation: ${v.toStringAsFixed(0)}%',
        'tip': "We were so close! I noticed some of the monster's attacks seemed to hit extra hard. I think it's because our pronunciation wasn't quite clear enough for our defenses to work perfectly. Let's look at the Words to Practice below and try them a few times before we go back in!",
      };
    }

    // Default / Fallback Scenario
    return {
      'title': 'So Close!',
      'description': 'You were so close to victory! A little more practice is all you need.',
      'icon': Icons.flag,
      'value': (damageDealt / bossHp) * 100,
      'display': (double v) => 'Boss HP Damaged: ${v.toStringAsFixed(0)}%',
      'tip': "Don't worry, that was just a practice round! Every great hero needs a few tries to learn the monster's patterns. You learned a lot that time! Let's take a quick break, look at the report, and show it who's boss!",
    };
  }

  Map<String, dynamic>? _getToughestWord() {
    if (widget.metrics.wordScores.isEmpty) return null;
    
    final sortedWords = widget.metrics.wordScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final toughestEntry = sortedWords.first;
    return {
      'word': toughestEntry.key,
      'score': toughestEntry.value,
    };
  }

  int _calculateUnsuccessfulDefenses() {
    // This would need to be calculated based on actual battle log
    // For now, return a mock value
    return widget.metrics.wordFailureCount.values.fold(0, (sum, failures) => sum + failures);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
} 