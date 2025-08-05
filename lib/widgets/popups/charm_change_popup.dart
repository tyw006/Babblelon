import 'package:flutter/material.dart';

/// A popup dialog that displays charm changes with animations
class CharmChangePopup {
  /// Shows a charm change dialog with animated feedback
  static Future<void> show(
    BuildContext context, {
    required int charmDelta,
    required String charmReason,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _CharmChangeDialogContent(
            charmDelta: charmDelta,
            charmReason: charmReason,
          ),
        ),
      ),
    );
  }
}

class _CharmChangeDialogContent extends StatefulWidget {
  final int charmDelta;
  final String charmReason;

  const _CharmChangeDialogContent({
    required this.charmDelta,
    required this.charmReason,
  });

  @override
  _CharmChangeDialogContentState createState() => _CharmChangeDialogContentState();
}

class _CharmChangeDialogContentState extends State<_CharmChangeDialogContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.charmDelta > 0 ? 800 : 500),
      vsync: this,
    );

    if (widget.charmDelta > 0) {
      // Bouncy, expanding animation for positive charm
      _animation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.6).chain(CurveTween(curve: Curves.easeOut)),
          weight: 50
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.6, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
          weight: 50
        ),
      ]).animate(_controller);
    } else {
      // Shake animation for negative charm
      _animation = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 5),
        TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -8.0), weight: 10),
        TweenSequenceItem(tween: Tween<double>(begin: -8.0, end: 8.0), weight: 20),
        TweenSequenceItem(tween: Tween<double>(begin: 8.0, end: -8.0), weight: 20),
        TweenSequenceItem(tween: Tween<double>(begin: -8.0, end: 4.0), weight: 15),
        TweenSequenceItem(tween: Tween<double>(begin: 4.0, end: -4.0), weight: 15),
        TweenSequenceItem(tween: Tween<double>(begin: -4.0, end: 0.0), weight: 10),
      ]).animate(_controller);
    }
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPositive = widget.charmDelta > 0;
    final Color deltaColor = isPositive ? Colors.green.shade600 : Colors.red.shade600;
    final String sign = isPositive ? '+' : '';

    final Widget textWidget = Text(
      '$sign${widget.charmDelta}',
      style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: deltaColor,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            if (isPositive) {
              return Transform.scale(
                scale: _animation.value,
                child: child,
              );
            } else {
              return Transform.translate(
                offset: Offset(_animation.value, 0),
                child: child,
              );
            }
          },
          child: textWidget,
        ),
        const SizedBox(height: 16),
        Text(
          widget.charmReason,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: deltaColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}