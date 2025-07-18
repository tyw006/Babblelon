import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/battle_providers.dart';
import 'package:lottie/lottie.dart';
import 'package:babblelon/widgets/shared/app_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VictoryReportDialog extends ConsumerStatefulWidget {
  final BattleMetrics metrics;

  const VictoryReportDialog({super.key, required this.metrics});

  @override
  ConsumerState<VictoryReportDialog> createState() => _VictoryReportDialogState();
}

class _VictoryReportDialogState extends ConsumerState<VictoryReportDialog>
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

    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _numberController.forward();
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
                      _buildPage1_InstantResultAndCore(),
                      _buildPage2_LanguageReport(),
                      _buildPage3_ProgressAndRewards(),
                    ],
                  ),
                ),
                
                // Page Indicator
                _buildPageIndicator(),
                
                // Continue Button (Fixed Footer)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: AppStyles.cardDecoration,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: AppStyles.primaryButtonStyle.copyWith(
                        backgroundColor: WidgetStateProperty.all(Colors.green),
                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'CONTINUE',
                        style: AppStyles.bodyTextStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          SizedBox(
            height: 60,
            width: 60,
            child: Lottie.asset(
              'assets/lottie/victory_confetti.json',
              repeat: false,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.emoji_events,
                  size: 40,
                  color: Colors.amber,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'VICTORY!',
            style: AppStyles.subtitleTextStyle.copyWith(
              color: Colors.amber,
              fontSize: 22,
            ),
          ),
          Text(
            'Battle Complete',
            style: AppStyles.bodyTextStyle.copyWith(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1_InstantResultAndCore() {
    final dpt = widget.metrics.damagePerTurn;
    final isPersonalBest = _isPersonalBest();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Overall Grade and Personal Best
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: AppStyles.cardDecoration,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Overall Grade
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getGradeColor(widget.metrics.overallGrade),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Center(
                              child: Text(
                                widget.metrics.overallGrade,
                                style: AppStyles.subtitleTextStyle.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    if (isPersonalBest) ...[
                      const SizedBox(width: 20),
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return Column(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 24,
                              ),
                              Text(
                                'New Personal\nBest!',
                                style: AppStyles.bodyTextStyle.copyWith(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Overall Grade',
                  style: AppStyles.bodyTextStyle.copyWith(
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Core Performance Metrics
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: AppStyles.cardDecoration,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildAnimatedStatCard(
                        Icons.timer,
                        '${widget.metrics.totalTurns}',
                        'Turns\nTime to Win',
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        Icons.flash_on,
                        '${dpt.toStringAsFixed(0)}',
                        'DPT\nDamage Per Turn',
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnimatedStatCard(
                        Icons.favorite,
                        '${widget.metrics.finalPlayerHealth}/${widget.metrics.playerStartingHealth}',
                        'HP\nHP Remaining',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAnimatedStatCard(
                        Icons.trending_up,
                        '${widget.metrics.maxStreak}',
                        'Streak\nLongest Combo',
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

  Widget _buildPage2_LanguageReport() {
    final avgPronScore = widget.metrics.averagePronunciationScore;
    final masteredWords = _getMasteredWordsCount();
    final totalLevelWords = _getTotalLevelWords();
    final wordsToePractice = _getWordsToePractice();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LANGUAGE REPORT',
            style: AppStyles.subtitleTextStyle.copyWith(
              fontSize: 18,
              color: Colors.green,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Average Pronunciation
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: AppStyles.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Average Pronunciation:',
                        style: AppStyles.bodyTextStyle,
                      ),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _numberAnimation,
                        builder: (context, child) {
                          final animatedScore = (avgPronScore * _numberAnimation.value).toInt();
                          final grade = _getPronunciationGrade(avgPronScore);
                          // Shorten text for smaller screens
                          final isSmallScreen = MediaQuery.of(context).size.width < 400;
                          final scoreText = isSmallScreen 
                              ? '$animatedScore% ($grade)'
                              : '$animatedScore/100 ($grade)';
                          return Text(
                            scoreText,
                            textAlign: TextAlign.end,
                            style: AppStyles.bodyTextStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(avgPronScore),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: ((avgPronScore / 100) * _progressAnimation.value).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade800,
                      valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(avgPronScore)),
                    ).animate().scaleX(alignment: Alignment.centerLeft, duration: 1200.ms, curve: Curves.easeOutCubic);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Vocabulary Mastery
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
                      'Level Vocabulary Mastered:',
                      style: AppStyles.bodyTextStyle,
                    ),
                    AnimatedBuilder(
                      animation: _numberAnimation,
                      builder: (context, child) {
                        final animatedMastered = (masteredWords * _numberAnimation.value).toInt();
                        final percentage = ((masteredWords / totalLevelWords) * 100).toInt();
                        return Text(
                          '$animatedMastered/$totalLevelWords ($percentage%)',
                          style: AppStyles.bodyTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
                    final progress = masteredWords / totalLevelWords;
                    return LinearProgressIndicator(
                      value: (progress * _progressAnimation.value).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ).animate().scaleX(alignment: Alignment.centerLeft, duration: 1200.ms, curve: Curves.easeOutCubic);
                  },
                ),
                if (widget.metrics.newlyMasteredWords.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'New Words Acquired:',
                    style: AppStyles.smallTextStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.metrics.newlyMasteredWords.take(5).map((word) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          word,
                          style: AppStyles.smallTextStyle.copyWith(
                            color: Colors.green.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Words to Practice (Expandable)
          if (wordsToePractice.isNotEmpty)
            Container(
              decoration: AppStyles.cardDecoration,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    'Words to Practice:',
                    style: AppStyles.bodyTextStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white70,
                  children: wordsToePractice.map((wordData) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wordData['word'] as String,
                                  style: AppStyles.bodyTextStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Avg: ${wordData['score']}%',
                                  style: AppStyles.smallTextStyle.copyWith(
                                    color: _getScoreColor(wordData['score'] as double),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Implement listen functionality
                              },
                              icon: const Icon(Icons.volume_up, size: 16),
                              label: const Text('Listen', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: BorderSide(color: Colors.blue.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Implement practice functionality
                              },
                              icon: const Icon(Icons.mic, size: 16),
                              label: const Text('Practice', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage3_ProgressAndRewards() {
    final dailyStreak = _getDailyStreak();
    final weeklyProgress = _getWeeklyProgress();
    final socialBenchmark = _getSocialBenchmark();
    final nextTip = _getNextTip();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROGRESS & REWARDS',
            style: AppStyles.subtitleTextStyle.copyWith(
              fontSize: 18,
              color: Colors.purple,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Rewards Section
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: AppStyles.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rewards:',
                  style: AppStyles.bodyTextStyle.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnimatedRewardCard(
                        Icons.star,
                        '+${widget.metrics.expGained}',
                        'EXP',
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAnimatedRewardCard(
                        Icons.monetization_on,
                        '+${widget.metrics.goldEarned}',
                        'Gold',
                        Colors.amber,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Daily Streak
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Daily Streak: Day ${dailyStreak['current']} of ${dailyStreak['target']}',
                      style: AppStyles.bodyTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Weekly Goal Progress
                Text(
                  'Weekly Goal: ${weeklyProgress['description']}',
                  style: AppStyles.bodyTextStyle,
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    final progress = (weeklyProgress['current'] as int) / (weeklyProgress['target'] as int);
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: (progress * _progressAnimation.value).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade800,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                        ).animate().scaleX(alignment: Alignment.centerLeft, duration: 1200.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${weeklyProgress['current']}/${weeklyProgress['target']}',
                              style: AppStyles.smallTextStyle,
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: AppStyles.smallTextStyle.copyWith(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Social Benchmark
          if (socialBenchmark != null)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: AppStyles.cardDecoration,
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.cyan, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      socialBenchmark,
                      style: AppStyles.bodyTextStyle.copyWith(
                        color: Colors.cyan.shade200,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Next Time Tip
          if (nextTip != null)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: AppStyles.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Next Time, Try This!',
                        style: AppStyles.bodyTextStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextTip,
                    style: AppStyles.bodyTextStyle.copyWith(
                      color: Colors.green.shade200,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatCard(IconData icon, String value, String label, Color color) {
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
                const SizedBox(height: 8),
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

  Widget _buildAnimatedRewardCard(IconData icon, String value, String label, Color color) {
    return AnimatedBuilder(
      animation: _numberAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: AppStyles.bodyTextStyle.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: AppStyles.smallTextStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppStyles.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index ? Colors.amber : Colors.white30,
            ),
          );
        }),
      ),
    );
  }

  // Helper Methods
  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'S': return Colors.purple;
      case 'A': return Colors.green;
      case 'B': return Colors.blue;
      case 'C': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  String _getPronunciationGrade(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Needs Work';
  }

  bool _isPersonalBest() {
    // Mock implementation - would check against saved personal records
    return widget.metrics.overallGrade == 'S' || widget.metrics.averagePronunciationScore >= 90;
  }

  int _getMasteredWordsCount() {
    return widget.metrics.wordScores.values.where((score) => score >= 60).length;
  }

  int _getTotalLevelWords() {
    // Mock implementation - would be based on the actual level's word count
    return 12;
  }

  List<Map<String, dynamic>> _getWordsToePractice() {
    return widget.metrics.wordScores.entries
        .where((entry) => entry.value < 75)
        .map((entry) => {
              'word': entry.key,
              'score': entry.value,
            })
        .take(3)
        .toList();
  }

  Map<String, int> _getDailyStreak() {
    // Mock implementation
    return {'current': 3, 'target': 7};
  }

  Map<String, dynamic> _getWeeklyProgress() {
    // Mock implementation
    return {
      'description': 'Land 10 Critical Hits',
      'current': 7,
      'target': 10,
    };
  }

  String? _getSocialBenchmark() {
    // Mock implementation
    if (widget.metrics.averagePronunciationScore >= 85) {
      return 'Your Pronunciation Score is in the Top 15% on this level!';
    }
    return null;
  }

  String? _getNextTip() {
    // Mock implementation based on performance
    if (widget.metrics.finalPlayerHealth <= widget.metrics.playerStartingHealth * 0.5) {
      return "You've mastered attacking! Try using Great Defense next time.";
    } else if (widget.metrics.maxStreak < 3) {
      return "Focus on consecutive perfect pronunciations for bigger damage bonuses!";
    }
    return "Try experimenting with higher complexity phrases for bonus damage!";
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
} 