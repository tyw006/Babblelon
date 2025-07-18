import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:babblelon/widgets/modern_design_system.dart' as modern;
import 'package:babblelon/widgets/performance_optimization_helpers.dart';

/// Voice-first interaction system for 2025 UI/UX trends
/// Provides voice commands, audio feedback, and voice-guided navigation
class VoiceInteractionSystem extends StatefulWidget {
  final Widget child;
  final bool enableVoiceCommands;
  final bool enableAudioFeedback;
  final VoiceNavigationConfig? navigationConfig;
  final Function(String)? onVoiceCommand;

  const VoiceInteractionSystem({
    super.key,
    required this.child,
    this.enableVoiceCommands = true,
    this.enableAudioFeedback = true,
    this.navigationConfig,
    this.onVoiceCommand,
  });

  @override
  State<VoiceInteractionSystem> createState() => _VoiceInteractionSystemState();
}

class _VoiceInteractionSystemState extends State<VoiceInteractionSystem>
    with TickerProviderStateMixin {
  bool _isListening = false;
  bool _showVoiceIndicator = false;
  String _lastCommand = '';
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _startListening() {
    if (!widget.enableVoiceCommands) return;
    
    setState(() {
      _isListening = true;
      _showVoiceIndicator = true;
    });
    
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    
    // Haptic feedback for voice activation
    HapticFeedback.lightImpact();
    
    // Simulate voice command processing
    _simulateVoiceRecognition();
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      _showVoiceIndicator = false;
    });
    
    _pulseController.stop();
    _waveController.stop();
  }

  void _simulateVoiceRecognition() {
    // Simulate voice processing delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isListening) {
        _processVoiceCommand('navigate_to_bangkok');
        _stopListening();
      }
    });
  }

  void _processVoiceCommand(String command) {
    setState(() {
      _lastCommand = command;
    });
    
    widget.onVoiceCommand?.call(command);
    
    // Audio feedback
    if (widget.enableAudioFeedback) {
      HapticFeedback.mediumImpact();
    }
    
    // Show command confirmation
    _showCommandConfirmation(command);
  }

  void _showCommandConfirmation(String command) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: VoiceCommandConfirmation(command: command),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Voice interaction overlay
        if (widget.enableVoiceCommands)
          Positioned(
            bottom: 30,
            right: 20,
            child: _buildVoiceButton(),
          ),
        
        // Voice listening indicator
        if (_showVoiceIndicator)
          Positioned.fill(
            child: _buildVoiceListeningOverlay(),
          ),
        
        // Voice navigation helper
        if (widget.navigationConfig != null)
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: _buildVoiceNavigationHelper(),
          ),
      ],
    );
  }

  Widget _buildVoiceButton() {
    return OptimizedRepaintBoundary(
      debugLabel: 'VoiceButton',
      child: GestureDetector(
        onTap: _isListening ? _stopListening : _startListening,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: _isListening
                      ? modern.ModernDesignSystem.warmGradient
                      : modern.ModernDesignSystem.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _isListening
                          ? modern.ModernDesignSystem.accentOrange.withValues(alpha: 0.4)
                          : modern.ModernDesignSystem.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: _isListening ? 20 : 15,
                      spreadRadius: _isListening ? 8 : 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoiceListeningOverlay() {
    return OptimizedRepaintBoundary(
      debugLabel: 'VoiceListeningOverlay',
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: modern.ModernCard(
            backgroundColor: modern.ModernDesignSystem.warmWhite,
            borderRadius: modern.ModernDesignSystem.radiusXLarge,
            padding: const EdgeInsets.all(modern.ModernDesignSystem.spaceXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated listening waves
                AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(120, 60),
                      painter: VoiceWavePainter(
                        animation: _waveAnimation,
                        color: modern.ModernDesignSystem.primaryBlue,
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: modern.ModernDesignSystem.spaceLG),
                
                Text(
                  'Listening...',
                  style: modern.ModernDesignSystem.headlineMedium.copyWith(
                    color: modern.ModernDesignSystem.darkBlue,
                  ),
                ),
                
                const SizedBox(height: modern.ModernDesignSystem.spaceSM),
                
                Text(
                  'Try saying: "Go to Bangkok" or "Select Thai"',
                  style: modern.ModernDesignSystem.bodyMedium.copyWith(
                    color: modern.ModernDesignSystem.softGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: modern.ModernDesignSystem.spaceLG),
                
                modern.ModernButton(
                  text: 'Cancel',
                  onPressed: _stopListening,
                  style: modern.ButtonStyle.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceNavigationHelper() {
    return OptimizedRepaintBoundary(
      debugLabel: 'VoiceNavigationHelper',
      child: modern.ModernCard(
        backgroundColor: modern.ModernDesignSystem.primaryBlue.withValues(alpha: 0.1),
        borderRadius: modern.ModernDesignSystem.radiusLarge,
        padding: const EdgeInsets.all(modern.ModernDesignSystem.spaceMD),
        child: Row(
          children: [
            Icon(
              Icons.keyboard_voice,
              color: modern.ModernDesignSystem.primaryBlue,
              size: 20,
            ),
            const SizedBox(width: modern.ModernDesignSystem.spaceSM),
            Expanded(
              child: Text(
                widget.navigationConfig!.helpText,
                style: modern.ModernDesignSystem.caption.copyWith(
                  color: modern.ModernDesignSystem.darkBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for voice wave animation
class VoiceWavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  VoiceWavePainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final waveCount = 5;
    
    for (int i = 0; i < waveCount; i++) {
      final x = (size.width / (waveCount - 1)) * i;
      final amplitude = 20 * (1 - (i - waveCount / 2).abs() / (waveCount / 2));
      final waveHeight = amplitude * animation.value;
      
      canvas.drawLine(
        Offset(x, centerY - waveHeight),
        Offset(x, centerY + waveHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceWavePainter oldDelegate) {
    return animation.value != oldDelegate.animation.value;
  }
}

/// Voice command confirmation widget
class VoiceCommandConfirmation extends StatelessWidget {
  final String command;

  const VoiceCommandConfirmation({
    super.key,
    required this.command,
  });

  String _getCommandDisplayText(String command) {
    switch (command) {
      case 'navigate_to_bangkok':
        return '✓ Navigating to Bangkok';
      case 'select_thai':
        return '✓ Thai language selected';
      case 'go_back':
        return '✓ Going back';
      case 'start_lesson':
        return '✓ Starting lesson';
      default:
        return '✓ Command recognized';
    }
  }

  @override
  Widget build(BuildContext context) {
    return modern.ModernCard(
      backgroundColor: modern.ModernDesignSystem.secondaryTeal,
      borderRadius: modern.ModernDesignSystem.radiusMedium,
      padding: const EdgeInsets.symmetric(
        horizontal: modern.ModernDesignSystem.spaceLG,
        vertical: modern.ModernDesignSystem.spaceMD,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: modern.ModernDesignSystem.spaceSM),
          Text(
            _getCommandDisplayText(command),
            style: modern.ModernDesignSystem.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Voice navigation configuration
class VoiceNavigationConfig {
  final String helpText;
  final List<VoiceCommand> availableCommands;

  const VoiceNavigationConfig({
    required this.helpText,
    required this.availableCommands,
  });
}

/// Voice command definition
class VoiceCommand {
  final String id;
  final List<String> phrases;
  final String description;
  final VoidCallback action;

  const VoiceCommand({
    required this.id,
    required this.phrases,
    required this.description,
    required this.action,
  });
}

/// Voice-enabled button that responds to both touch and voice
class VoiceEnabledButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<String> voicePhrases;
  final modern.ButtonStyle style;
  final IconData? icon;

  const VoiceEnabledButton({
    super.key,
    required this.text,
    this.onPressed,
    required this.voicePhrases,
    this.style = modern.ButtonStyle.primary,
    this.icon,
  });

  @override
  State<VoiceEnabledButton> createState() => _VoiceEnabledButtonState();
}

class _VoiceEnabledButtonState extends State<VoiceEnabledButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;
  bool _isVoiceHighlighted = false;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  void highlightForVoice() {
    setState(() {
      _isVoiceHighlighted = true;
    });
    _highlightController.forward();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isVoiceHighlighted = false;
        });
        _highlightController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        return Container(
          decoration: _isVoiceHighlighted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(modern.ModernDesignSystem.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: modern.ModernDesignSystem.accentOrange.withValues(
                        alpha: 0.4 * _highlightAnimation.value,
                      ),
                      blurRadius: 20 * _highlightAnimation.value,
                      spreadRadius: 5 * _highlightAnimation.value,
                    ),
                  ],
                )
              : null,
          child: modern.ModernButton(
            text: widget.text,
            onPressed: widget.onPressed,
            style: widget.style,
            icon: widget.icon,
          ),
        );
      },
    );
  }
}

/// Accessibility-enhanced voice navigation for language learning
class LanguageLearningVoiceSystem extends StatelessWidget {
  final Widget child;
  final String currentLanguage;
  final Function(String)? onLanguageChange;
  final Function(String)? onNavigationCommand;

  const LanguageLearningVoiceSystem({
    super.key,
    required this.child,
    required this.currentLanguage,
    this.onLanguageChange,
    this.onNavigationCommand,
  });

  @override
  Widget build(BuildContext context) {
    return VoiceInteractionSystem(
      enableVoiceCommands: true,
      enableAudioFeedback: true,
      navigationConfig: VoiceNavigationConfig(
        helpText: 'Voice commands: "Go to [location]", "Select [language]", "Start lesson"',
        availableCommands: [
          VoiceCommand(
            id: 'select_language',
            phrases: ['select thai', 'choose thai', 'thai language'],
            description: 'Select Thai language',
            action: () => onLanguageChange?.call('thai'),
          ),
          VoiceCommand(
            id: 'navigate_bangkok',
            phrases: ['go to bangkok', 'bangkok', 'travel bangkok'],
            description: 'Navigate to Bangkok',
            action: () => onNavigationCommand?.call('bangkok'),
          ),
          VoiceCommand(
            id: 'start_lesson',
            phrases: ['start lesson', 'begin learning', 'start game'],
            description: 'Start language lesson',
            action: () => onNavigationCommand?.call('start_lesson'),
          ),
        ],
      ),
      onVoiceCommand: (command) {
        // Process voice commands for language learning
        if (command.contains('thai') || command.contains('ไทย')) {
          onLanguageChange?.call('thai');
        } else if (command.contains('bangkok') || command.contains('กรุงเทพ')) {
          onNavigationCommand?.call('bangkok');
        } else if (command.contains('lesson') || command.contains('learn')) {
          onNavigationCommand?.call('start_lesson');
        }
      },
      child: child,
    );
  }
}