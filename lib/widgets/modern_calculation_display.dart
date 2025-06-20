import 'package:flutter/material.dart';

class ModernCalculationDisplay extends StatefulWidget {
  final String explanation;
  final bool isDefenseCalculation;

  const ModernCalculationDisplay({
    super.key,
    required this.explanation,
    required this.isDefenseCalculation,
  });

  @override
  State<ModernCalculationDisplay> createState() => _ModernCalculationDisplayState();
}

class _ModernCalculationDisplayState extends State<ModernCalculationDisplay>
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
    
    _parseExplanation();
    _startAnimations();
  }
  
  void _parseExplanation() {
    final lines = widget.explanation.split('\n');
    _steps = [];
    
    // Initialize all possible bonuses with zero values
    double pronunciationBonus = 0.0;
    double complexityBonus = 0.0;
    double cardRevealPenaltyValue = 0.0; // The value from the explanation
    bool isDefenseTurn = false;
    
    // Determine if the card was actually revealed from the explanation content
    // Look for specific patterns that indicate actual penalty application
    final bool wasActuallyRevealed = widget.explanation.contains('Card Reveal Penalty: -20%') || 
                                     widget.explanation.contains('Card revealed before assessment');

    // Parse actual values from explanation
    for (String line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      
      // Check if this is a defense turn for penalty logic
      if (trimmedLine.contains('Defense') || trimmedLine.contains('defense')) {
        isDefenseTurn = true;
      }
      
      if (trimmedLine.contains('Pronunciation Bonus')) {
        final regex = RegExp(r'([+-]?\d+(?:\.\d+)?)%');
        final match = regex.firstMatch(trimmedLine);
        if (match != null) {
          pronunciationBonus = double.tryParse(match.group(1)!) ?? 0.0;
        }
      } else if (trimmedLine.contains('Complexity Bonus')) {
        final regex = RegExp(r'([+-]?\d+(?:\.\d+)?)%');
        final match = regex.firstMatch(trimmedLine);
        if (match != null) {
          complexityBonus = double.tryParse(match.group(1)!) ?? 0.0;
        }
      } else if (trimmedLine.contains('Card Reveal Penalty')) {
        final regex = RegExp(r'([+-]?\d+(?:\.\d+)?)%');
        final match = regex.firstMatch(trimmedLine);
        if (match != null) {
          cardRevealPenaltyValue = double.tryParse(match.group(1)!) ?? 0.0;
        }
      }
    }
    
    // Determine the actual card reveal penalty to display
    double displayCardRevealPenalty = 0.0;
    if (wasActuallyRevealed) {
      if (isDefenseTurn) {
        // For defense turns, penalty equals the sum of all other bonuses to negate them
        displayCardRevealPenalty = -(pronunciationBonus + complexityBonus);
      } else {
        // For attack turns, it's a fixed -20% penalty
        displayCardRevealPenalty = -20.0;
      }
    }
    
    // Build the calculation steps for display
    // Always show Pronunciation Bonus
    _steps.add(CalculationStep(
      label: 'Pronunciation Bonus',
      value: pronunciationBonus,
      isBonus: pronunciationBonus >= 0,
      tooltip: _getTooltipForStep('Pronunciation Bonus'),
    ));
    
    // Always show Complexity Bonus
    _steps.add(CalculationStep(
      label: 'Complexity Bonus', 
      value: complexityBonus,
      isBonus: complexityBonus >= 0,
      tooltip: _getTooltipForStep('Complexity Bonus'),
    ));
    
    // Always show Card Reveal Penalty (even when 0)
    _steps.add(CalculationStep(
      label: 'Card Reveal Penalty',
      value: displayCardRevealPenalty,
      isBonus: displayCardRevealPenalty >= 0,
      tooltip: _getTooltipForStep('Card Reveal Penalty'),
    ));
    
    // Calculate bonus total for display
    _bonusTotal = pronunciationBonus + complexityBonus + displayCardRevealPenalty;
  }
  
  String _getTooltipForStep(String label) {
    switch (label) {
      case 'Pronunciation Bonus':
        return 'Based on pronunciation accuracy, fluency, and completeness scores. Higher scores give better bonuses.';
      case 'Complexity Bonus':
        return 'Bonus for attempting more complex vocabulary. Higher difficulty levels give larger bonuses when mastered.';
      case 'Card Reveal Penalty':
        // Determine if this is a defense turn by checking the explanation
        final isDefenseTurn = widget.explanation.contains('Defense') || widget.explanation.contains('defense');
        if (isDefenseTurn) {
          return 'Defense turn penalty: Revealing the card completely negates all pronunciation and complexity bonuses, making defense ineffective.';
        } else {
          return 'Attack turn penalty: Revealing the card reduces your base attack damage by a fixed 20%.';
        }
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
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
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
                    ? step.color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: step.isFinal 
                    ? Border.all(color: step.color.withOpacity(0.3), width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: step.color.withOpacity(0.2),
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
                  
                  // Value
                  Text(
                    step.formattedValue,
                    style: TextStyle(
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