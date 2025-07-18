import 'package:flutter/material.dart';
import 'dart:math' as math;

class ScoreProgressBar extends StatefulWidget {
  final String label;
  final double value; // 0.0 to 1.0
  final double score; // The actual score value to display
  final Color primaryColor;
  final Color backgroundColor;
  final double height;
  final Duration animationDuration;
  final bool showTooltipIcon;

  const ScoreProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.score,
    this.primaryColor = Colors.blue,
    this.backgroundColor = Colors.grey,
    this.height = 8.0,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.showTooltipIcon = false,
  });

  @override
  State<ScoreProgressBar> createState() => _ScoreProgressBarState();
}

class _ScoreProgressBarState extends State<ScoreProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _shimmerController;
  late Animation<double> _progressAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _progressController.forward();
    _shimmerController.repeat();
  }

  @override
  void didUpdateWidget(ScoreProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Color _getScoreColor(double value) {
    if (value >= 0.9) return Colors.green.shade400;
    if (value >= 0.75) return Colors.lightGreen.shade400;
    if (value >= 0.6) return Colors.orange.shade400;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor(widget.value);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Conditionally render the label and its spacing
          if (widget.label.isNotEmpty) ...[
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Center(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (widget.showTooltipIcon)
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.white60,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Progress Bar
          Expanded(
            child: Container(
              height: math.max(widget.height, 12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background bar
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Progress bar with inner glow effect
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      final currentProgress = _progressAnimation.value.clamp(0.0, 1.0);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: math.max(currentProgress, 0.02), // Minimum visible progress
                          child: Container(
                            height: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                colors: [
                                  scoreColor.withValues(alpha: 0.3), // More subtle at low values
                                  scoreColor.withValues(alpha: 0.8),
                                  scoreColor.withValues(alpha: 0.9),
                                ],
                                stops: const [0.0, 0.7, 1.0],
                              ),
                            ),
                            child: AnimatedBuilder(
                              animation: _shimmerAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: LinearGradient(
                                      begin: Alignment(-1.0 + 2.0 * _shimmerAnimation.value, 0),
                                      end: Alignment(1.0 + 2.0 * _shimmerAnimation.value, 0),
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: currentProgress > 0.1 ? 0.2 : 0.1), // More subtle shimmer at low values
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Score Text
                  Center(
                    child: Text(
                      '${widget.score.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 1),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 