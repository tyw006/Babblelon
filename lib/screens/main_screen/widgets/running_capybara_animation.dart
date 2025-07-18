import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A widget that displays an animated running capybara for the loading screen
class RunningCapybaraAnimation extends StatefulWidget {
  final double size;
  final Color? shadowColor;
  
  const RunningCapybaraAnimation({
    super.key,
    this.size = 120,
    this.shadowColor,
  });

  @override
  State<RunningCapybaraAnimation> createState() => _RunningCapybaraAnimationState();
}

class _RunningCapybaraAnimationState extends State<RunningCapybaraAnimation>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _runController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _runAnimation;

  @override
  void initState() {
    super.initState();
    
    // Bounce animation for vertical movement
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    
    // Run animation for horizontal movement
    _runController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
    
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));
    
    _runAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _runController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _runController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 1.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow
          AnimatedBuilder(
            animation: Listenable.merge([_bounceAnimation, _runAnimation]),
            builder: (context, child) {
              return Positioned(
                bottom: 10,
                left: (widget.size * 0.5) + (_runAnimation.value * 20),
                child: Container(
                  width: widget.size * 0.8,
                  height: 12,
                  decoration: BoxDecoration(
                    color: (widget.shadowColor ?? Colors.black).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            },
          ),
          
          // Capybara
          AnimatedBuilder(
            animation: Listenable.merge([_bounceAnimation, _runAnimation]),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _runAnimation.value * 20,
                  -_bounceAnimation.value,
                ),
                child: Transform.scale(
                  scaleX: _runAnimation.value > 0 ? 1 : -1,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/player/capybara.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Speed lines effect
          AnimatedBuilder(
            animation: _runController,
            builder: (context, child) {
              return Positioned(
                left: (widget.size * 0.3) + (_runAnimation.value * 15),
                child: Opacity(
                  opacity: 0.6,
                  child: Row(
                    children: List.generate(3, (index) {
                      return Container(
                        width: 20 - (index * 4),
                        height: 2,
                        margin: EdgeInsets.only(
                          right: 4,
                          top: index * 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7 - (index * 0.2)),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A widget that displays loading tips with smooth transitions
class LoadingTipsWidget extends StatefulWidget {
  final List<String> tips;
  final Duration switchDuration;
  
  const LoadingTipsWidget({
    super.key,
    required this.tips,
    this.switchDuration = const Duration(seconds: 3),
  });

  @override
  State<LoadingTipsWidget> createState() => _LoadingTipsWidgetState();
}

class _LoadingTipsWidgetState extends State<LoadingTipsWidget> {
  int _currentTipIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _startTipRotation();
  }
  
  void _startTipRotation() {
    Future.delayed(widget.switchDuration, () {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % widget.tips.length;
        });
        _startTipRotation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey(_currentTipIndex),
        children: [
          Text(
            'Did you know?',
            style: const TextStyle(
              color: Color(0xFF29B6F6),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.tips[_currentTipIndex],
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}