import 'package:flutter/material.dart';
import 'package:babblelon/models/turn.dart';

class TurnIndicator extends StatefulWidget {
  final Turn currentTurn;

  const TurnIndicator({
    super.key,
    required this.currentTurn,
  });

  @override
  State<TurnIndicator> createState() => _TurnIndicatorState();
}

class _TurnIndicatorState extends State<TurnIndicator>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Fade transition when turn changes
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Scale effect for emphasis
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Glow effect for active turn
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  @override
  void didUpdateWidget(TurnIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTurn != widget.currentTurn) {
      _restartAnimations();
    }
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    _glowController.repeat(reverse: true);
  }

  void _restartAnimations() {
    _fadeController.reset();
    _scaleController.reset();
    _startAnimations();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  IconData _getTurnIcon() {
    switch (widget.currentTurn) {
      case Turn.player:
        return Icons.local_fire_department; // Attack icon
      case Turn.boss:
        return Icons.shield; // Defense/Block icon
    }
  }

  String _getTurnText() {
    switch (widget.currentTurn) {
      case Turn.player:
        return 'ATTACK';
      case Turn.boss:
        return 'DEFEND';
    }
  }

  Color _getTurnColor() {
    switch (widget.currentTurn) {
      case Turn.player:
        return Colors.red;
      case Turn.boss:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final turnColor = _getTurnColor();
    final turnIcon = _getTurnIcon();
    final turnText = _getTurnText();

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _glowAnimation]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: turnColor.withOpacity(0.2),
                border: Border.all(
                  color: turnColor.withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: turnColor.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    turnIcon,
                    color: turnColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    turnText,
                    style: TextStyle(
                      color: turnColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: turnColor.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 