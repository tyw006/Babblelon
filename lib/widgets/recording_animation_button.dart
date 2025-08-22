import 'package:flutter/material.dart';
import '../theme/unified_dark_theme.dart';

/// A reusable recording button widget with pulse and scale animations
/// Provides consistent recording UI/UX across the app
class RecordingAnimationButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final double? size;
  final Color? inactiveColor;
  final Color? activeColor;
  final Color? iconColor;
  final IconData? inactiveIcon;
  final IconData? activeIcon;

  const RecordingAnimationButton({
    Key? key,
    required this.isRecording,
    required this.onStartRecording,
    required this.onStopRecording,
    this.size = 72.0,
    this.inactiveColor,
    this.activeColor,
    this.iconColor,
    this.inactiveIcon = Icons.mic,
    this.activeIcon = Icons.stop,
  }) : super(key: key);

  @override
  State<RecordingAnimationButton> createState() => _RecordingAnimationButtonState();
}

class _RecordingAnimationButtonState extends State<RecordingAnimationButton>
    with TickerProviderStateMixin {
  
  // Animation controllers for recording button
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Pulse animation - continuous for recording state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Scale animation - triggered on press
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Start pulse animation when recording
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordingAnimationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animations based on recording state
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
      _scaleController.forward();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
      _scaleController.reverse();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isRecording) {
      widget.onStopRecording();
    } else {
      widget.onStartRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = widget.inactiveColor ?? UnifiedDarkTheme.primaryAccent;
    final activeColor = widget.activeColor ?? UnifiedDarkTheme.secondaryAccent;
    final iconColor = widget.iconColor ?? UnifiedDarkTheme.textOnColor;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _scaleController]),
        builder: (context, child) {
          return ScaleTransition(
            scale: _scaleController.drive(
              Tween(begin: 1.0, end: 1.1).chain(
                CurveTween(curve: Curves.elasticOut),
              ),
            ),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording 
                    ? activeColor.withValues(alpha: 0.8 + 0.2 * _pulseController.value)
                    : inactiveColor.withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRecording ? activeColor : inactiveColor)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: widget.isRecording 
                        ? 5 + 10 * _pulseController.value 
                        : 5,
                  ),
                ],
              ),
              child: Icon(
                widget.isRecording 
                    ? widget.activeIcon 
                    : widget.inactiveIcon,
                color: iconColor,
                size: widget.size! * 0.4,
              ),
            ),
          );
        },
      ),
    );
  }
}