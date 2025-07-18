import 'package:flutter/material.dart';
import 'package:babblelon/theme/font_extensions.dart';

/// Modern logo widget following 2024-2025 mobile game design trends
/// Uses Stack-based approach for depth instead of chunky 3D text
class ModernLogo extends StatefulWidget {
  final String text;
  final bool enableAnimations;
  final double fontSize;
  
  const ModernLogo({
    super.key,
    required this.text,
    this.enableAnimations = true,
    this.fontSize = 56.0,
  });

  @override
  State<ModernLogo> createState() => _ModernLogoState();
}

class _ModernLogoState extends State<ModernLogo>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Smooth scale animation (modern feel)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800), // Faster than previous
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic, // Smooth modern curve
    ));
    
    if (widget.enableAnimations) {
      _scaleController.forward();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text != 'BabbleOn') {
      // Fallback to regular text for non-BabbleOn titles
      return _buildRegularText();
    }
    
    return AnimatedBuilder(
      animation: widget.enableAnimations ? _scaleAnimation : 
        const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildBabbleOnLogo(),
        );
      },
    );
  }

  Widget _buildRegularText() {
    return Stack(
      children: [
        // Shadow layer for depth
        Transform.translate(
          offset: const Offset(3, 3),
          child: Text(
            widget.text,
            style: BabbleFonts.logo.copyWith(
              fontSize: widget.fontSize,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
        // Gradient main text
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [BabbleFonts.butterYellow, BabbleFonts.cherryRed],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: BabbleFonts.logo.copyWith(
              fontSize: widget.fontSize,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBabbleOnLogo() {
    return Stack(
      children: [
        // Shadow layer for depth
        Transform.translate(
          offset: const Offset(3, 3),
          child: _buildSimpleTextRow(
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ),
        // Main gradient text - SIMPLIFIED
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [BabbleFonts.butterYellow, BabbleFonts.cherryRed],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
          blendMode: BlendMode.srcIn,
          child: _buildSimpleTextRow(
            color: Colors.white, // This will be replaced by the gradient
          ),
        ),
      ],
    );
  }

  // Simplified text row that works reliably with gradients
  Widget _buildSimpleTextRow({required Color color}) {
    return Text(
      'BabbleOn',
      style: BabbleFonts.logo.copyWith(
        fontSize: widget.fontSize,
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

}

/// Modern tagline with staggered animations
class ModernTagline extends StatefulWidget {
  final bool enableAnimations;
  final double fontSize;
  
  const ModernTagline({
    super.key,
    this.enableAnimations = true,
    this.fontSize = 20.0,
  });

  @override
  State<ModernTagline> createState() => _ModernTaglineState();
}

class _ModernTaglineState extends State<ModernTagline>
    with TickerProviderStateMixin {
  late AnimationController _line1Controller;
  late AnimationController _line2Controller;
  late Animation<double> _line1Animation;
  late Animation<double> _line2Animation;

  @override
  void initState() {
    super.initState();
    
    // Staggered animations for modern feel
    _line1Controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _line2Controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _line1Animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _line1Controller,
      curve: Curves.easeOutCubic,
    ));
    
    _line2Animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _line2Controller,
      curve: Curves.easeOutCubic,
    ));
    
    if (widget.enableAnimations) {
      _startStaggeredAnimation();
    }
  }

  void _startStaggeredAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _line1Controller.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _line2Controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First line: "Live the City"
        AnimatedBuilder(
          animation: widget.enableAnimations ? _line1Animation : 
            const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            return Opacity(
              opacity: _line1Animation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _line1Animation.value)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVerbText('Live', BabbleFonts.butterYellow),
                    const SizedBox(width: 8),
                    _buildParticleText('the City'),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        // Second line: "Learn the Language"
        AnimatedBuilder(
          animation: widget.enableAnimations ? _line2Animation : 
            const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            return Opacity(
              opacity: _line2Animation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _line2Animation.value)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVerbText('Learn', BabbleFonts.cherryRed),
                    const SizedBox(width: 8),
                    _buildParticleText('the Language'),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVerbText(String text, Color color) {
    return Stack(
      children: [
        // Subtle shadow
        Transform.translate(
          offset: const Offset(1, 1),
          child: Text(
            text,
            style: BabbleFonts.taglineVerb.copyWith(
              fontSize: widget.fontSize,
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        // Main text
        Text(
          text,
          style: BabbleFonts.taglineVerb.copyWith(
            fontSize: widget.fontSize,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildParticleText(String text) {
    return Text(
      text,
      style: BabbleFonts.taglineParticle.copyWith(
        fontSize: widget.fontSize,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}

/// Complete modern logo and tagline component
class ModernLogoAndTagline extends StatelessWidget {
  final bool enableAnimations;
  final double logoFontSize;
  final double taglineFontSize;
  
  const ModernLogoAndTagline({
    super.key,
    this.enableAnimations = true,
    this.logoFontSize = 56.0,
    this.taglineFontSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern logo
        ModernLogo(
          text: 'BabbleOn',
          enableAnimations: enableAnimations,
          fontSize: logoFontSize,
        ),
        const SizedBox(height: 20),
        // Modern tagline
        ModernTagline(
          enableAnimations: enableAnimations,
          fontSize: taglineFontSize,
        ),
      ],
    );
  }
}