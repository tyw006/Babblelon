import 'package:flutter/material.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_providers.dart';

class ModernCalculationDisplay extends ConsumerStatefulWidget {
  final String explanation;
  final bool isDefenseCalculation;

  const ModernCalculationDisplay({
    super.key,
    required this.explanation,
    required this.isDefenseCalculation,
  });

  @override
  ConsumerState<ModernCalculationDisplay> createState() => _ModernCalculationDisplayState();
}

class _ModernCalculationDisplayState extends ConsumerState<ModernCalculationDisplay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  List<CalculationStep> _steps = [];
  double _bonusTotal = 0.0;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Start with zero values for the animation
    _parseExplanation(useZeroValues: true); 
    
    // Start animations and then update to real values
    _startAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use a post-frame callback to update to the real values after the initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _parseExplanation(useZeroValues: false);
        });
      }
    });
  }
  
  void _parseExplanation({bool useZeroValues = false}) {
    final lines = widget.explanation.split('\n');
    _steps = [];
    
    double pronunciationBonus = 0.0;
    double complexityBonus = 0.0;
    double cardRevealPenalty = 0.0;

    // Parse actual values directly from the explanation string provided by the backend.
    for (String line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      
      // Regex to find signed percentage values like "+15%" or "-20.5%"
      final regex = RegExp(r'([+-]?\d+(?:\.\d+)?)%');
      final match = regex.firstMatch(trimmedLine);
      final value = match != null ? double.tryParse(match.group(1)!) : null;

      if (value == null) continue;

      if (trimmedLine.startsWith('Pronunciation Bonus')) {
        pronunciationBonus = useZeroValues ? 0.0 : value;
      } else if (trimmedLine.startsWith('Complexity Bonus')) {
        complexityBonus = useZeroValues ? 0.0 : value;
      } else if (trimmedLine.startsWith('Card Reveal Penalty')) {
        cardRevealPenalty = useZeroValues ? 0.0 : value;
      }
    }
    
    // For defense calculations, flip the signs to show user-friendly values
    // Backend sends negative values for defense bonuses (because they reduce damage)
    // But we want to show them as positive to the user (because they're beneficial)
    if (widget.isDefenseCalculation) {
      pronunciationBonus = -pronunciationBonus; // Convert -50% to +50%
      complexityBonus = -complexityBonus;       // Convert -10% to +10%
      // Card reveal penalty should be negative for defense (it's bad for the player)
      cardRevealPenalty = -cardRevealPenalty;   // Convert +20% to -20%
    }
    
    // Build the calculation steps for display
    _steps.add(CalculationStep(
      label: 'Pronunciation Bonus',
      value: pronunciationBonus,
      isBonus: pronunciationBonus >= 0,
      tooltip: _getTooltipForStep('Pronunciation Bonus'),
    ));
    
    _steps.add(CalculationStep(
      label: 'Complexity Bonus', 
      value: complexityBonus,
      isBonus: complexityBonus >= 0,
      tooltip: _getTooltipForStep('Complexity Bonus'),
    ));
    
    // For card reveal penalty, it should be negative (bad) for defense, positive (bad) for attack
    // But the backend sends it correctly, so we just need to make sure display is right
    _steps.add(CalculationStep(
      label: 'Card Reveal Penalty',
      value: widget.isDefenseCalculation ? cardRevealPenalty : cardRevealPenalty,
      isBonus: false, // Penalties are never bonuses
      tooltip: _getTooltipForStep('Card Reveal Penalty'),
    ));
    
    // Calculate bonus total for display (using the user-friendly values)
    _bonusTotal = pronunciationBonus + complexityBonus + cardRevealPenalty;
  }
  
  String _getTooltipForStep(String label) {
    switch (label) {
      case 'Pronunciation Bonus':
        if (widget.isDefenseCalculation) {
          return 'Defense Pronunciation Reduction Bonus:\n• Excellent (80-100): 50% (Regular) / 70% (Special)\n• Good (60-79): 30% (Regular) / 50% (Special)\n• Okay (40-59): 10% (Regular) / 25% (Special)\n• Needs Improvement (0-39): 0%\n\nReduces incoming damage by the percentage shown.';
        } else {
          return 'Attack Pronunciation Bonus:\n• Excellent (80-100): +60%\n• Good (60-79): +30%\n• Okay (40-59): +10%\n• Needs Improvement (0-39): 0%\n\nIncreases attack damage by the percentage shown.';
        }
      case 'Complexity Bonus':
        if (widget.isDefenseCalculation) {
          return 'Defense Complexity Reduction Bonus (requires pronunciation score ≥ 60):\n• Level 1: 0%\n• Level 2: 5%\n• Level 3: 10%\n• Level 4: 15%\n• Level 5: 20%\n\nReduces incoming damage by the percentage shown.';
        } else {
          return 'Attack Complexity Bonus (requires pronunciation score ≥ 60):\n• Level 1: 0%\n• Level 2: +15%\n• Level 3: +30%\n• Level 4: +45%\n• Level 5: +60%\n\nIncreases attack damage by the percentage shown.';
        }
      case 'Card Reveal Penalty':
        if (widget.isDefenseCalculation) {
          return 'Defense turn penalty: Revealing the card negates your pronunciation and complexity bonuses, capped at 20%. High bonuses still provide some damage reduction.';
        } else {
          return 'Attack turn penalty: Revealing the card reduces your base attack damage by a fixed 20%.';
        }
      case 'Attack Bonus':
        return 'Attack Bonus: The combined percentage increase to your base attack damage from pronunciation quality and card complexity. Higher pronunciation scores and more complex cards yield greater bonuses.';
      case 'Defense Bonus':
        return 'Defense Bonus: The combined percentage reduction in incoming damage from pronunciation quality and card complexity. Higher pronunciation scores and more complex cards provide better protection.';
      default:
        return '';
    }
  }
  
  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Steps
              ...List.generate(_steps.length, (index) {
                final step = _steps[index];
                return _buildCalculationStep(step, index);
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCalculationStep(CalculationStep step, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 150)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final tooltipKey = GlobalKey<TooltipState>();
        
        final stepWidget = Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0), // Clamp opacity to valid range
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: step.isFinal 
                    ? step.color.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: step.isFinal 
                    ? Border.all(color: step.color.withValues(alpha: 0.3), width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: step.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      step.icon,
                      color: step.color,
                      size: 16,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Label
                  Expanded(
                    child: Text(
                      step.label,
                      style: TextStyle(
                        color: step.isFinal ? Colors.white : Colors.white70,
                        fontSize: step.isFinal ? 14 : 13,
                        fontWeight: step.isFinal ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  // Value with animated counting
                  AnimatedFlipCounter(
                    value: step.value,
                    duration: Duration(milliseconds: 1200 + (index * 400)),
                    curve: Curves.easeOutCubic,
                    prefix: step.value >= 0 ? "+" : "",
                    suffix: "%",
                    textStyle: TextStyle(
                      color: step.color,
                      fontSize: step.isFinal ? 14 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Tap-to-reveal info icon for tooltip if available
                  if (step.tooltip != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ref.playButtonSound();
                        tooltipKey.currentState?.ensureTooltipVisible();
                      },
                      child: Tooltip(
                        key: tooltipKey,
                        message: step.tooltip!,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
        
        return stepWidget;
      },
    );
  }
}

class CalculationStep {
  final String label;
  final double value;
  final bool isBonus;
  final String? tooltip;

  CalculationStep({
    required this.label,
    required this.value,
    required this.isBonus,
    this.tooltip,
  });

  IconData get icon {
    switch (label) {
      case 'Pronunciation Bonus':
        return Icons.record_voice_over;
      case 'Complexity Bonus':
        return Icons.psychology;
      case 'Card Reveal Penalty':
        return Icons.visibility;
      default:
        return isBonus ? Icons.add_circle : Icons.remove_circle;
    }
  }

  Color get color {
    switch (label) {
      case 'Pronunciation Bonus':
        return Colors.cyanAccent;
      case 'Complexity Bonus':
        return Colors.purpleAccent;
      case 'Card Reveal Penalty':
        return Colors.orangeAccent;
      default:
        return isBonus ? Colors.green : Colors.red;
    }
  }

  String get formattedValue {
    if (value == 0) return '0%';
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(0)}%';
  }

  bool get isFinal => isBonus;
} 