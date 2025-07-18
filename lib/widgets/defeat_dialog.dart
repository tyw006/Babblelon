import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/battle_providers.dart';
import 'package:babblelon/widgets/shared/app_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DefeatDialog extends ConsumerStatefulWidget {
  final BattleMetrics metrics;

  const DefeatDialog({super.key, required this.metrics});

  @override
  ConsumerState<DefeatDialog> createState() => _DefeatDialogState();
}

class _DefeatDialogState extends ConsumerState<DefeatDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _numberController;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;
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

    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _numberController.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      _progressController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
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
        child: Container(
          constraints: BoxConstraints(
            maxHeight: screenSize.height * 0.85,
            maxWidth: isSmallScreen ? screenSize.width * 0.95 : 500,
          ),
          decoration: AppStyles.cardDecoration,
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
                decoration: AppStyles.cardDecoration,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: AppStyles.secondaryButtonStyle,
                        child: Text(
                          'LEAVE BATTLE',
                          style: AppStyles.bodyTextStyle.copyWith(
                            color: AppStyles.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // TODO: Implement retry battle functionality
                        },
                        style: AppStyles.primaryButtonStyle.copyWith(
                          backgroundColor: WidgetStateProperty.all(Colors.orange),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                        ),
                        child: Text(
                          'RETRY BATTLE',
                          style: AppStyles.bodyTextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppStyles.cardDecoration,
      child: Column(
        children: [
          const Icon(
            Icons.sentiment_neutral,
            size: 50,
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          Text(
            'TRY AGAIN!',
            style: AppStyles.titleTextStyle.copyWith(
              color: Colors.orange,
              fontSize: 28,
            ),
          ),
          Text(
            'You were so close! Don\'t give up!',
            style: AppStyles.bodyTextStyle.copyWith(
              fontStyle: FontStyle.italic,
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
            padding: const EdgeInsets.all(16.0),
            decoration: AppStyles.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Boss HP Remaining:',
                      style: AppStyles.subtitleTextStyle,
                    ),
                    AnimatedBuilder(
                      animation: _numberAnimation,
                      builder: (context, child) {
                        final animatedDamage = (widget.metrics.totalDamageDealt * _numberAnimation.value).toInt();
                        final animatedRemaining = (widget.metrics.bossMaxHealth - animatedDamage).clamp(0, widget.metrics.bossMaxHealth);
                        return Text(
                          '$animatedRemaining/${widget.metrics.bossMaxHealth}',
                          style: AppStyles.bodyTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: (bossHealthPercentage * _progressAnimation.value).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade800,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        bossHealthPercentage >= 0.7 ? Colors.green :
                        bossHealthPercentage >= 0.3 ? Colors.orange : Colors.red,
                      ),
                    ).animate().scaleX(alignment: Alignment.centerLeft, duration: 1200.ms, curve: Curves.easeOutCubic);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  bossHealthPercentage >= 0.7 
                      ? 'Amazing! You almost had them!'
                      : bossHealthPercentage >= 0.3
                          ? 'Good progress! You\'re getting there!'
                          : 'Every attempt gets you closer!',
                  style: AppStyles.smallTextStyle.copyWith(
                    color: Colors.green.shade300,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Battle Overview
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: AppStyles.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Overview',
                  style: AppStyles.subtitleTextStyle,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                                             child: _buildAnimatedStatCard(
                         'Damage Dealt', 
                         '${widget.metrics.totalDamageDealt.toInt()}',
                         Icons.flash_on,
                         Colors.red,
                       ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        'Battle Time', 
                        _formatDuration(widget.metrics.battleDuration),
                        Icons.timer,
                        Colors.blue,
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
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        'Best Streak', 
                        '${widget.metrics.maxStreak}',
                        Icons.local_fire_department,
                        Colors.orange,
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
            decoration: AppStyles.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BATTLE ANALYSIS',
                  style: AppStyles.subtitleTextStyle.copyWith(
                    fontSize: 18,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s what to focus on:',
                  style: AppStyles.bodyTextStyle.copyWith(
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
            decoration: AppStyles.cardDecoration.copyWith(
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
                        style: AppStyles.bodyTextStyle.copyWith(
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
                  style: AppStyles.smallTextStyle,
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _numberAnimation,
                  builder: (context, child) {
                    final animatedValue = (primaryChallenge['value'] as double) * _numberAnimation.value;
                    return Text(
                      primaryChallenge['display'](animatedValue),
                      style: AppStyles.bodyTextStyle.copyWith(
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
              decoration: AppStyles.cardDecoration.copyWith(
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
                          style: AppStyles.bodyTextStyle.copyWith(
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
                          style: AppStyles.bodyTextStyle.copyWith(
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
                              style: AppStyles.smallTextStyle.copyWith(
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
            decoration: AppStyles.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STRATEGY TIPS',
                  style: AppStyles.subtitleTextStyle.copyWith(
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s how to improve:',
                  style: AppStyles.bodyTextStyle.copyWith(
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
                  style: AppStyles.bodyTextStyle.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                Text(
                  label,
                  style: AppStyles.smallTextStyle.copyWith(fontSize: 11),
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
              style: AppStyles.bodyTextStyle.copyWith(
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
      decoration: AppStyles.cardDecoration,
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