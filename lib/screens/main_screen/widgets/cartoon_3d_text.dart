import 'package:flutter/material.dart';
import 'package:text_3d/text_3d.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'dart:math';

class Cartoon3DText extends StatefulWidget {
  final String text;
  final double fontSize;
  final Color primaryColor;
  final Color secondaryColor;
  final double depth;
  final TextAlign textAlign;
  final FontWeight fontWeight;
  final bool enableGlow;
  final bool enableAnimation;

  const Cartoon3DText({
    super.key,
    required this.text,
    this.fontSize = 32,
    this.primaryColor = CartoonDesignSystem.textPrimary, // Use cartoon text color
    this.secondaryColor = CartoonDesignSystem.cherryRed, // Use cherry red
    this.depth = 8.0,
    this.textAlign = TextAlign.center,
    this.fontWeight = FontWeight.bold,
    this.enableGlow = true,
    this.enableAnimation = true,
  });

  @override
  State<Cartoon3DText> createState() => _Cartoon3DTextState();
}

class _Cartoon3DTextState extends State<Cartoon3DText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    if (widget.enableAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Enhanced glow effect background
            if (widget.enableGlow) ...[
              Transform.translate(
                offset: const Offset(3, 3),
                child: ThreeDText(
                  text: widget.text,
                  textStyle: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: widget.fontWeight,
                    color: widget.secondaryColor.withValues(
                      alpha: _glowAnimation.value * 0.5, // Stronger glow
                    ),
                    shadows: [
                      Shadow(
                        color: widget.secondaryColor.withValues(alpha: 0.8),
                        blurRadius: 15,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  depth: widget.depth * 0.6,
                  style: ThreeDStyle.perspectiveRaised,
                  angle: pi / 10, // Slightly steeper angle
                ),
              ),
            ],
            // Main 3D text with enhanced effects
            ThreeDText(
              text: widget.text,
              textStyle: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: widget.fontWeight,
                color: widget.primaryColor,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              depth: widget.depth,
              style: ThreeDStyle.perspectiveRaised,
              angle: pi / 10, // Slightly steeper angle for more dramatic effect
            ),
          ],
        );
      },
    );
  }
}

class CartoonTitleText extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool enableAnimation;

  const CartoonTitleText({
    super.key,
    required this.title,
    this.subtitle,
    this.enableAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main title - Using cartoon design typography
        Cartoon3DText(
          text: title,
          fontSize: 40, // Design guide displayLarge size
          primaryColor: CartoonDesignSystem.textPrimary,
          secondaryColor: CartoonDesignSystem.cherryRed,
          depth: 12.0, // Moderate depth for better performance
          fontWeight: FontWeight.w800, // Design guide Baloo 2 Bold weight
          enableAnimation: enableAnimation,
        ).animate()
          .fadeIn(duration: 1000.ms)
          .slideY(begin: -30, duration: 800.ms)
          .shimmer(
            duration: 2000.ms,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        
        if (subtitle != null) ...[
          const SizedBox(height: 16),
          // Two-line tagline with Live/Learn highlights
          _buildTwoLineTagline(),
        ],
      ],
    );
  }
  
  Widget _buildTwoLineTagline() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First line: "Live the City"
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Cartoon3DText(
              text: 'Live',
              fontSize: 60, // Increased by 50% from 40 for better visibility
              primaryColor: CartoonDesignSystem.forestGreen, // Success color for "Live"
              secondaryColor: CartoonDesignSystem.cherryRed,
              depth: 6.0, // Reduced depth for better performance
              fontWeight: FontWeight.w600, // Design guide headlineLarge weight
              enableAnimation: enableAnimation,
            ),
            const SizedBox(width: 12),
            Cartoon3DText(
              text: 'the City',
              fontSize: 54, // Increased by 50% from 36 for better visibility
              primaryColor: CartoonDesignSystem.textPrimary.withValues(alpha: 0.8),
              secondaryColor: CartoonDesignSystem.textSecondary,
              depth: 4.0, // Reduced depth
              fontWeight: FontWeight.w500,
              enableAnimation: false,
            ),
          ],
        ).animate()
          .fadeIn(duration: 1000.ms, delay: 500.ms)
          .slideY(begin: 30, duration: 800.ms, delay: 500.ms),
        
        const SizedBox(height: 4),
        
        // Second line: "Learn the Language"
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Cartoon3DText(
              text: 'Learn',
              fontSize: 60, // Increased by 50% from 40 for better visibility
              primaryColor: CartoonDesignSystem.sunshineYellow, // Butter Yellow for "Learn"
              secondaryColor: CartoonDesignSystem.cherryRed,
              depth: 6.0, // Reduced depth for better performance
              fontWeight: FontWeight.w600, // Design guide headlineLarge weight
              enableAnimation: enableAnimation,
            ),
            const SizedBox(width: 12),
            Cartoon3DText(
              text: 'the Language',
              fontSize: 54, // Increased by 50% from 36 for better visibility
              primaryColor: CartoonDesignSystem.textPrimary.withValues(alpha: 0.8),
              secondaryColor: CartoonDesignSystem.textSecondary,
              depth: 4.0, // Reduced depth
              fontWeight: FontWeight.w500,
              enableAnimation: false,
            ),
          ],
        ).animate()
          .fadeIn(duration: 1000.ms, delay: 700.ms)
          .slideY(begin: 30, duration: 800.ms, delay: 700.ms),
      ],
    );
  }
}

class CartoonGameButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final Color primaryColor;
  final Color secondaryColor;

  const CartoonGameButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isEnabled = true,
    this.primaryColor = const Color(0xFF00D4FF),
    this.secondaryColor = const Color(0xFF0099CC),
  });

  @override
  State<CartoonGameButton> createState() => _CartoonGameButtonState();
}

class _CartoonGameButtonState extends State<CartoonGameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: widget.isEnabled ? (_) => _controller.forward() : null,
            onTapUp: widget.isEnabled ? (_) => _controller.reverse() : null,
            onTapCancel: widget.isEnabled ? () => _controller.reverse() : null,
            onTap: widget.isEnabled ? widget.onPressed : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall), // 16dp from design guide
                gradient: widget.isEnabled
                    ? CartoonDesignSystem.accentGradient // Cherry Red gradient
                    : LinearGradient(
                        colors: [
                          CartoonDesignSystem.textSecondary.withValues(alpha: 0.5),
                          CartoonDesignSystem.textSecondary.withValues(alpha: 0.3),
                        ],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isEnabled
                        ? CartoonDesignSystem.cherryRed.withValues(alpha: _glowAnimation.value * 0.3)
                        : Colors.transparent,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ThreeDText(
                text: widget.text,
                textStyle: TextStyle(
                  fontSize: 16, // Design guide button text size
                  fontWeight: FontWeight.w700, // Poppins Bold equivalent
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 6,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                depth: 6.0, // Enhanced depth
                style: ThreeDStyle.perspectiveRaised,
                angle: pi / 10, // Steeper angle
              ),
            ),
          ),
        );
      },
    );
  }
}