import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/performance_optimization_helpers.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/theme/unified_dark_theme.dart';

/// Modern design system with dark, sophisticated colors
/// Replaces CartoonDesignSystem for unified theme experience
/// Implements BabbleOn Modern UI Design Guide v2.0 (August 2025)
class ModernDesignSystem {
  // ===== PRIMARY COLOR PALETTE =====
  
  // Core colors from UnifiedDarkTheme
  static const Color primaryAccent = UnifiedDarkTheme.primaryAccent; // Electric violet
  static const Color secondaryAccent = UnifiedDarkTheme.secondaryAccent; // Warm coral
  static const Color tertiaryAccent = UnifiedDarkTheme.tertiaryAccent; // Teal
  
  // Background colors
  static const Color primaryBackground = UnifiedDarkTheme.primaryBackground; // Rich dark
  static const Color primarySurface = UnifiedDarkTheme.primarySurface; // Elevated surfaces
  static const Color primarySurfaceVariant = UnifiedDarkTheme.primarySurfaceVariant; // Subtle variations
  
  // Semantic colors
  static const Color success = UnifiedDarkTheme.success; // Emerald green
  static const Color warning = UnifiedDarkTheme.warning; // Sunset orange
  static const Color error = UnifiedDarkTheme.error; // Soft red
  static const Color info = UnifiedDarkTheme.info; // Light blue
  
  // Text colors
  static const Color textPrimary = UnifiedDarkTheme.textPrimary; // High contrast white
  static const Color textSecondary = UnifiedDarkTheme.textSecondary; // Muted blue
  static const Color textTertiary = UnifiedDarkTheme.textTertiary; // Dark gray
  static const Color textOnColor = UnifiedDarkTheme.textOnColor; // Pure white
  
  // Text colors for light backgrounds (proper contrast)
  static const Color textOnLight = Color(0xFF1A1A1A); // Dark gray for white backgrounds
  static const Color textOnLightSecondary = Color(0xFF666666); // Medium gray for secondary text on white
  static const Color textOnLightTertiary = Color(0xFF999999); // Light gray for disabled text on white
  
  // Border colors
  static const Color borderPrimary = UnifiedDarkTheme.borderPrimary;
  static const Color borderSecondary = UnifiedDarkTheme.borderSecondary;
  
  // Core color aliases
  static const Color sunshineYellow = primaryAccent;
  static const Color cherryRed = secondaryAccent;
  static const Color warmOrange = warning;
  static const Color skyBlue = info;
  static const Color creamWhite = primaryBackground;
  static const Color softPeach = primarySurface;
  static const Color forestGreen = success;
  static const Color coralPink = secondaryAccent;
  static const Color lavenderPurple = primaryAccent;
  static const Color chocolateBrown = textSecondary;
  static const Color textMuted = textTertiary;
  static const Color textOnBright = textOnColor;

  // ===== GRADIENT COLLECTIONS =====
  
  static const LinearGradient primaryGradient = UnifiedDarkTheme.primaryGradient;
  static const LinearGradient secondaryGradient = UnifiedDarkTheme.secondaryGradient;
  static const LinearGradient successGradient = UnifiedDarkTheme.successGradient;
  static const LinearGradient surfaceGradient = UnifiedDarkTheme.surfaceGradient;
  static const RadialGradient accentGlow = UnifiedDarkTheme.accentGlow;

  // Gradient aliases
  static const LinearGradient accentGradient = secondaryGradient;
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, Color(0xFFE17055)],
  );
  static const LinearGradient backgroundGradient = surfaceGradient;
  static const LinearGradient heroButtonGradient = primaryGradient;
  static const RadialGradient glowGradient = accentGlow;
  static const RadialGradient buttonGlowGradient = RadialGradient(
    center: Alignment.center,
    radius: 1.0,
    colors: [secondaryAccent, Colors.transparent],
  );

  // Sunset gradient with dark theme colors
  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF6C5CE7), // Electric violet
      Color(0xFF5B4DDB), // Deeper purple
      Color(0xFFE17055), // Soft red
      Color(0xFFFD79A8), // Warm coral
    ],
  );

  // ===== TYPOGRAPHY SCALE =====
  
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.5,
    fontFamily: 'Quicksand',
    color: textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    fontFamily: 'Quicksand',
    color: textPrimary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
    fontFamily: 'Quicksand',
    color: textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
    fontFamily: 'Quicksand',
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0.1,
    fontFamily: 'Nunito',
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    fontFamily: 'Nunito',
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFamily: 'Nunito',
    color: textSecondary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
    fontFamily: 'Nunito',
    color: textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.2,
    fontFamily: 'Nunito',
    color: textSecondary,
  );

  // ===== SPACING SCALE =====
  
  // Using UnifiedDarkTheme spacing
  static const double spaceXXS = UnifiedDarkTheme.spaceXXS;
  static const double spaceXS = UnifiedDarkTheme.spaceXS;
  static const double spaceSM = UnifiedDarkTheme.spaceSM;
  static const double spaceMD = UnifiedDarkTheme.spaceMD;
  static const double spaceLG = UnifiedDarkTheme.spaceLG;
  static const double spaceXL = UnifiedDarkTheme.spaceXL;
  static const double spaceXXL = UnifiedDarkTheme.spaceXXL;
  static const double spaceXXXL = 80; // Extra large for modern spacing

  // ===== TOUCH TARGET SIZES =====
  
  static const double touchTargetMin = UnifiedDarkTheme.touchTargetMin;
  static const double touchTargetButton = UnifiedDarkTheme.touchTargetButton;
  static const double touchTargetLarge = UnifiedDarkTheme.touchTargetLarge;
  static const double touchTargetHuge = 88; // Extra large for modern design

  // ===== BORDER RADIUS =====
  
  static const double radiusSmall = UnifiedDarkTheme.radiusSM; // 12 -> more modern
  static const double radiusMedium = UnifiedDarkTheme.radiusMD; // 16 -> standard
  static const double radiusLarge = UnifiedDarkTheme.radiusLG; // 20 -> large cards
  static const double radiusXLarge = UnifiedDarkTheme.radiusXL; // 24 -> hero elements
  static const double radiusRound = UnifiedDarkTheme.radiusRound; // 100 -> fully rounded

  // ===== ANIMATION & MOTION CONSTANTS =====
  
  static const Duration microInteraction = UnifiedDarkTheme.microInteraction;
  static const Duration quickTransition = UnifiedDarkTheme.quickTransition;
  static const Duration standardTransition = UnifiedDarkTheme.standardTransition;
  static const Duration slowTransition = UnifiedDarkTheme.slowTransition;
  static const Duration bounceTransition = UnifiedDarkTheme.bounceTransition;
  
  // Modern motion constants
  static const double bounceOffset = UnifiedDarkTheme.bounceOffset;
  static const double cardHoverScale = UnifiedDarkTheme.hoverScale;
  static const double cardPressScale = UnifiedDarkTheme.pressScale;
  static const double wobbleAngle = 0.03; // Reduced for modern feel

  // ===== HAPTIC FEEDBACK PATTERNS =====
  
  static Future<void> lightHaptic() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyHaptic() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> selectionHaptic() async {
    await HapticFeedback.selectionClick();
  }

  // Modern interaction helpers
  static void triggerSelectionFeedback() {
    lightHaptic(); // Lighter feedback for modern feel
  }

  static void triggerSuccessFeedback() {
    mediumHaptic(); // Moderate celebration
  }

  static void triggerPlayfulFeedback() {
    selectionHaptic(); // Subtle click feedback
  }
}

/// Modern Card Component with clean, elevated design
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool isSelected;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double borderRadius;
  final bool enableHover;
  final bool showElevation;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.isSelected = false,
    this.gradient,
    this.backgroundColor,
    this.borderRadius = ModernDesignSystem.radiusMedium,
    this.enableHover = true,
    this.showElevation = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: ModernDesignSystem.standardTransition,
      vsync: this,
    );
    _tapController = AnimationController(
      duration: ModernDesignSystem.quickTransition,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: ModernDesignSystem.cardHoverScale,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 12.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _tapController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _tapController.reverse();
    if (widget.onTap != null) {
      ModernDesignSystem.triggerSelectionFeedback();
      widget.onTap!.call();
    }
  }

  void _onTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return OptimizedRepaintBoundary(
      debugLabel: 'ModernCard',
      child: MouseRegion(
        onEnter: widget.enableHover ? (_) => _hoverController.forward() : null,
        onExit: widget.enableHover ? (_) => _hoverController.reverse() : null,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hoverController, _tapController]),
            builder: (context, child) {
              final tapScale = 1.0 - (_tapController.value * 0.02);
              final finalScale = _scaleAnimation.value * tapScale;

              return Transform.scale(
                scale: finalScale,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  padding: widget.padding ?? const EdgeInsets.all(ModernDesignSystem.spaceLG),
                  decoration: BoxDecoration(
                    gradient: widget.gradient ?? 
                      (widget.isSelected ? ModernDesignSystem.primaryGradient : null),
                    color: widget.backgroundColor ?? 
                      (widget.isSelected ? null : ModernDesignSystem.primarySurface),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: widget.showElevation ? [
                      // Main shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: _elevationAnimation.value,
                        offset: Offset(0, _elevationAnimation.value / 3),
                      ),
                      // Selection glow
                      if (widget.isSelected)
                        BoxShadow(
                          color: ModernDesignSystem.primaryAccent.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                    ] : null,
                    border: widget.isSelected
                      ? Border.all(
                          color: ModernDesignSystem.primaryAccent,
                          width: 2,
                        )
                      : Border.all(
                          color: ModernDesignSystem.borderPrimary,
                          width: 1,
                        ),
                  ),
                  child: widget.child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Modern Button Component with clean, elevated design
class ModernButton extends ConsumerStatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ModernButtonStyle style;
  final IconData? icon;
  final double? width;
  final bool isLarge;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.style = ModernButtonStyle.primary,
    this.icon,
    this.width,
    this.isLarge = false,
  });

  @override
  ConsumerState<ModernButton> createState() => _ModernButtonState();
}

enum ModernButtonStyle { primary, secondary, accent, outline, ghost }

class _ModernButtonState extends ConsumerState<ModernButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: ModernDesignSystem.quickTransition,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: ModernDesignSystem.cardPressScale,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    
    if (!widget.isLoading && widget.onPressed != null) {
      ModernDesignSystem.triggerSelectionFeedback();
      ref.playButtonSound();
      widget.onPressed!.call();
    }
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final buttonHeight = widget.isLarge 
      ? ModernDesignSystem.touchTargetLarge 
      : ModernDesignSystem.touchTargetButton;
    
    return GestureDetector(
      onTapDown: isEnabled ? _onTapDown : null,
      onTapUp: isEnabled ? _onTapUp : null,
      onTapCancel: isEnabled ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: buttonHeight,
              decoration: BoxDecoration(
                gradient: _getGradient(),
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(ModernDesignSystem.radiusSmall),
                border: _getBorder(),
                boxShadow: isEnabled ? UnifiedDarkTheme.shadowMD : null,
              ),
              child: Center(
                child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: _getTextColor(),
                            size: 22,
                          ),
                          const SizedBox(width: ModernDesignSystem.spaceSM),
                        ],
                        Text(
                          widget.text,
                          style: ModernDesignSystem.bodyLarge.copyWith(
                            color: _getTextColor(),
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isLarge ? 18 : 16,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  Gradient? _getGradient() {
    if (!_isEnabled()) return null;
    switch (widget.style) {
      case ModernButtonStyle.primary:
        return ModernDesignSystem.primaryGradient;
      case ModernButtonStyle.accent:
        return ModernDesignSystem.secondaryGradient;
      default:
        return null;
    }
  }

  Color? _getBackgroundColor() {
    if (!_isEnabled()) return ModernDesignSystem.textTertiary.withValues(alpha: 0.3);
    switch (widget.style) {
      case ModernButtonStyle.secondary:
        return ModernDesignSystem.primarySurface;
      case ModernButtonStyle.outline:
      case ModernButtonStyle.ghost:
        return Colors.transparent;
      default:
        return null;
    }
  }

  Border? _getBorder() {
    switch (widget.style) {
      case ModernButtonStyle.outline:
        return Border.all(
          color: _isEnabled() 
            ? ModernDesignSystem.primaryAccent 
            : ModernDesignSystem.textTertiary,
          width: 2,
        );
      case ModernButtonStyle.secondary:
        return Border.all(
          color: ModernDesignSystem.borderPrimary,
          width: 1,
        );
      default:
        return null;
    }
  }

  Color _getTextColor() {
    if (!_isEnabled()) return ModernDesignSystem.textTertiary;
    switch (widget.style) {
      case ModernButtonStyle.primary:
      case ModernButtonStyle.accent:
        return ModernDesignSystem.textOnColor;
      case ModernButtonStyle.outline:
        return ModernDesignSystem.primaryAccent;
      case ModernButtonStyle.ghost:
        return ModernDesignSystem.textSecondary;
      default:
        return ModernDesignSystem.textPrimary;
    }
  }

  bool _isEnabled() {
    return widget.onPressed != null && !widget.isLoading;
  }
}