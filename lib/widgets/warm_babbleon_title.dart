import 'package:flutter/material.dart';
import 'package:babblelon/theme/font_extensions.dart';

/// Warm-themed BabbleOn title component
/// Uses the app's red/yellow color palette to match the main screen design
class WarmBabbleOnTitle extends StatefulWidget {
  final double? fontSize;
  final bool enableAnimation;
  final TextStyle? style;

  const WarmBabbleOnTitle({
    super.key,
    this.fontSize,
    this.enableAnimation = true,
    this.style,
  });

  @override
  State<WarmBabbleOnTitle> createState() => _WarmBabbleOnTitleState();
}

class _WarmBabbleOnTitleState extends State<WarmBabbleOnTitle>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    if (widget.enableAnimation) {
      _glowController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      );
      
      _glowAnimation = Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));
      
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.enableAnimation) {
      _glowController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ?? BabbleFonts.logo.copyWith(
      fontSize: widget.fontSize ?? 64,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.0,
    );

    final titleWidget = Stack(
      children: [
        // Outer glow shadow layer
        Text(
          'BabbleOn',
          style: effectiveStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6.0
              ..color = const Color(0xFF0D1B2A).withValues(alpha: 0.8), // Navy outline
          ),
        ),
        // Inner shadow for depth
        Text(
          'BabbleOn',
          style: effectiveStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0
              ..color = Colors.black.withValues(alpha: 0.4),
          ),
        ),
        // Main gradient text
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              BabbleFonts.butterYellow, // #FFE07B
              BabbleFonts.cherryRed,    // #FF4F4F
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
          blendMode: BlendMode.srcIn,
          child: Text(
            'BabbleOn',
            style: effectiveStyle.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );

    if (!widget.enableAnimation) {
      return titleWidget;
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              // Warm glow effect that pulses
              BoxShadow(
                color: BabbleFonts.cherryRed.withValues(alpha: _glowAnimation.value * 0.4),
                blurRadius: 20 * _glowAnimation.value,
                spreadRadius: 2 * _glowAnimation.value,
              ),
              BoxShadow(
                color: BabbleFonts.butterYellow.withValues(alpha: _glowAnimation.value * 0.2),
                blurRadius: 30 * _glowAnimation.value,
                spreadRadius: 4 * _glowAnimation.value,
              ),
            ],
          ),
          child: titleWidget,
        );
      },
    );
  }
}

/// Compact version of the warm title for smaller spaces
class WarmBabbleOnTitleCompact extends StatelessWidget {
  final double fontSize;
  
  const WarmBabbleOnTitleCompact({
    super.key,
    this.fontSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return WarmBabbleOnTitle(
      fontSize: fontSize,
      enableAnimation: false,
      style: BabbleFonts.logo.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}