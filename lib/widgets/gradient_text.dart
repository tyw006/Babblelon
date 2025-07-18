import 'package:flutter/material.dart';
import 'package:babblelon/theme/font_extensions.dart';

/// Gradient text component with outline effect
/// Implements the design guide gradient + outline pattern
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient? gradient;
  final Color? outlineColor;
  final double outlineWidth;
  final bool hasOutline;

  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient,
    this.outlineColor,
    this.outlineWidth = 2.0,
    this.hasOutline = true,
  });

  /// Factory constructor for logo text with design guide specs
  factory GradientText.logo(
    String text, {
    Key? key,
    bool useAlternateFont = false,
  }) {
    return GradientText(
      text,
      key: key,
      style: useAlternateFont ? BabbleFonts.logoAlternate : BabbleFonts.logo,
      gradient: const LinearGradient(
        colors: [BabbleFonts.butterYellow, BabbleFonts.cherryRed],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      outlineColor: BabbleFonts.navyOutline,
      outlineWidth: 4.0,
      hasOutline: true,
    );
  }

  /// Factory constructor for tagline verbs with design guide specs
  factory GradientText.taglineVerb(
    String text, {
    Key? key,
    bool isLiveVerb = true,
  }) {
    return GradientText(
      text,
      key: key,
      style: BabbleFonts.taglineVerb,
      gradient: LinearGradient(
        colors: [
          isLiveVerb ? BabbleFonts.butterYellow : BabbleFonts.cherryRed,
          isLiveVerb ? BabbleFonts.butterYellow : BabbleFonts.cherryRed,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      hasOutline: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.displayLarge;
    final effectiveGradient = gradient ?? const LinearGradient(
      colors: [BabbleFonts.butterYellow, BabbleFonts.cherryRed],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    if (hasOutline) {
      return Stack(
        children: [
          // Outline layer
          Text(
            text,
            style: effectiveStyle?.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = outlineWidth
                ..color = outlineColor ?? BabbleFonts.navyOutline,
            ),
          ),
          // Gradient fill layer
          ShaderMask(
            shaderCallback: (rect) => effectiveGradient.createShader(rect),
            blendMode: BlendMode.srcIn,
            child: Text(
              text,
              style: effectiveStyle?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    } else {
      // Simple gradient text without outline
      return ShaderMask(
        shaderCallback: (rect) => effectiveGradient.createShader(rect),
        blendMode: BlendMode.srcIn,
        child: Text(
          text,
          style: effectiveStyle?.copyWith(
            color: Colors.white,
          ),
        ),
      );
    }
  }
}

/// Tagline component with color-coded verbs
/// Combines gradient verbs with regular particles
class TaglineText extends StatelessWidget {
  const TaglineText({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First line: "Live the City"
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientText.taglineVerb('Live', isLiveVerb: true),
            const SizedBox(width: 8),
            Text(
              'the City',
              style: BabbleFonts.taglineParticle.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Second line: "Learn the Language"
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientText.taglineVerb('Learn', isLiveVerb: false),
            const SizedBox(width: 8),
            Text(
              'the Language',
              style: BabbleFonts.taglineParticle.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Complete logo and tagline component
class LogoAndTagline extends StatelessWidget {
  final bool useAlternateFont;
  
  const LogoAndTagline({
    super.key,
    this.useAlternateFont = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo with gradient and outline
        GradientText.logo('BabbleOn', useAlternateFont: useAlternateFont),
        const SizedBox(height: 16),
        // Tagline with color-coded verbs
        const TaglineText(),
      ],
    );
  }
}