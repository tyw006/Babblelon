import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:babblelon/widgets/modern_design_system.dart' as modern;
import 'package:babblelon/widgets/performance_optimization_helpers.dart';

/// Comprehensive accessibility and error handling system for BabbleOn
/// Implements WCAG 2.1 guidelines and modern accessibility best practices
class AccessibilityEnhancedSystem extends StatefulWidget {
  final Widget child;
  final bool enableHighContrast;
  final bool enableLargeText;
  final bool enableScreenReader;
  final bool enableHapticFeedback;
  final ErrorBoundaryConfig? errorConfig;

  const AccessibilityEnhancedSystem({
    super.key,
    required this.child,
    this.enableHighContrast = false,
    this.enableLargeText = false,
    this.enableScreenReader = true,
    this.enableHapticFeedback = true,
    this.errorConfig,
  });

  @override
  State<AccessibilityEnhancedSystem> createState() => _AccessibilityEnhancedSystemState();
}

class _AccessibilityEnhancedSystemState extends State<AccessibilityEnhancedSystem> {
  late AccessibilityThemeData _accessibilityTheme;
  ErrorInfo? _currentError;

  @override
  void initState() {
    super.initState();
    _initializeAccessibilityTheme();
    _setupErrorHandling();
  }

  void _initializeAccessibilityTheme() {
    _accessibilityTheme = AccessibilityThemeData(
      highContrast: widget.enableHighContrast,
      largeText: widget.enableLargeText,
      reducedMotion: false, // Will be determined from MediaQuery
    );
  }

  void _setupErrorHandling() {
    if (widget.errorConfig != null) {
      FlutterError.onError = (FlutterErrorDetails details) {
        _handleError(ErrorInfo.fromFlutterError(details));
      };
    }
  }

  void _handleError(ErrorInfo error) {
    setState(() {
      _currentError = error;
    });
    
    if (widget.enableHapticFeedback) {
      HapticFeedback.heavyImpact();
    }
    
    widget.errorConfig?.onError?.call(error);
  }

  void _clearError() {
    setState(() {
      _currentError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isReducedMotion = mediaQuery.disableAnimations;
    
    // Update accessibility theme based on system settings
    _accessibilityTheme = _accessibilityTheme.copyWith(
      reducedMotion: isReducedMotion,
    );

    return AccessibilityTheme(
      data: _accessibilityTheme,
      child: ErrorBoundary(
        errorInfo: _currentError,
        onErrorDismissed: _clearError,
        child: AccessibilityWrapper(
          enableScreenReader: widget.enableScreenReader,
          enableHapticFeedback: widget.enableHapticFeedback,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Accessibility theme data for consistent accessibility styling
class AccessibilityThemeData {
  final bool highContrast;
  final bool largeText;
  final bool reducedMotion;

  const AccessibilityThemeData({
    required this.highContrast,
    required this.largeText,
    required this.reducedMotion,
  });

  AccessibilityThemeData copyWith({
    bool? highContrast,
    bool? largeText,
    bool? reducedMotion,
  }) {
    return AccessibilityThemeData(
      highContrast: highContrast ?? this.highContrast,
      largeText: largeText ?? this.largeText,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }

  // Color adjustments for high contrast mode
  Color getContrastAdjustedColor(Color baseColor) {
    if (!highContrast) return baseColor;
    
    // Increase contrast for better visibility
    final luminance = baseColor.computeLuminance();
    if (luminance > 0.5) {
      return Colors.black; // Light colors become black
    } else {
      return Colors.white; // Dark colors become white
    }
  }

  // Text scale for large text mode
  double getTextScale() {
    return largeText ? 1.3 : 1.0;
  }

  // Animation duration adjustment for reduced motion
  Duration getAnimationDuration(Duration baseDuration) {
    return reducedMotion ? Duration.zero : baseDuration;
  }
}

/// Inherited widget for accessing accessibility theme
class AccessibilityTheme extends InheritedWidget {
  final AccessibilityThemeData data;

  const AccessibilityTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static AccessibilityThemeData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AccessibilityTheme>()?.data;
  }

  @override
  bool updateShouldNotify(AccessibilityTheme oldWidget) {
    return data != oldWidget.data;
  }
}

/// Enhanced accessibility wrapper with semantic annotations
class AccessibilityWrapper extends StatelessWidget {
  final Widget child;
  final bool enableScreenReader;
  final bool enableHapticFeedback;

  const AccessibilityWrapper({
    super.key,
    required this.child,
    required this.enableScreenReader,
    required this.enableHapticFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: enableScreenReader,
      child: child,
    );
  }
}

/// Error boundary for graceful error handling
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final ErrorInfo? errorInfo;
  final VoidCallback? onErrorDismissed;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorInfo,
    this.onErrorDismissed,
  });

  @override
  Widget build(BuildContext context) {
    if (errorInfo != null) {
      return ErrorDisplay(
        errorInfo: errorInfo!,
        onDismissed: onErrorDismissed,
      );
    }
    
    return child;
  }
}

/// Error display widget with accessibility support
class ErrorDisplay extends StatelessWidget {
  final ErrorInfo errorInfo;
  final VoidCallback? onDismissed;

  const ErrorDisplay({
    super.key,
    required this.errorInfo,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityTheme = AccessibilityTheme.of(context);
    
    return Scaffold(
      backgroundColor: accessibilityTheme?.getContrastAdjustedColor(
        modern.ModernDesignSystem.backgroundDark,
      ) ?? modern.ModernDesignSystem.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(modern.ModernDesignSystem.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Semantics(
                label: 'Error occurred',
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: accessibilityTheme?.getContrastAdjustedColor(
                    modern.ModernDesignSystem.accentOrange,
                  ) ?? modern.ModernDesignSystem.accentOrange,
                ),
              ),
              
              const SizedBox(height: modern.ModernDesignSystem.spaceLG),
              
              // Error title
              Semantics(
                header: true,
                child: Text(
                  'Oops! Something went wrong',
                  style: modern.ModernDesignSystem.headlineLarge.copyWith(
                    color: accessibilityTheme?.getContrastAdjustedColor(
                      modern.ModernDesignSystem.darkBlue,
                    ) ?? modern.ModernDesignSystem.darkBlue,
                    fontSize: modern.ModernDesignSystem.headlineLarge.fontSize! *
                        (accessibilityTheme?.getTextScale() ?? 1.0),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: modern.ModernDesignSystem.spaceMD),
              
              // Error message
              Semantics(
                liveRegion: true,
                child: Text(
                  errorInfo.userFriendlyMessage,
                  style: modern.ModernDesignSystem.bodyLarge.copyWith(
                    color: accessibilityTheme?.getContrastAdjustedColor(
                      modern.ModernDesignSystem.softGray,
                    ) ?? modern.ModernDesignSystem.softGray,
                    fontSize: modern.ModernDesignSystem.bodyLarge.fontSize! * 
                        (accessibilityTheme?.getTextScale() ?? 1.0),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: modern.ModernDesignSystem.spaceXL),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (onDismissed != null)
                    Expanded(
                      child: AccessibilityEnhancedButton(
                        text: 'Try Again',
                        onPressed: onDismissed,
                        style: modern.ButtonStyle.primary,
                        semanticLabel: 'Try again button',
                        icon: Icons.refresh,
                      ),
                    ),
                  
                  const SizedBox(width: modern.ModernDesignSystem.spaceMD),
                  
                  Expanded(
                    child: AccessibilityEnhancedButton(
                      text: 'Report Issue',
                      onPressed: () => _reportError(context, errorInfo),
                      style: modern.ButtonStyle.outline,
                      semanticLabel: 'Report this issue',
                      icon: Icons.bug_report,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reportError(BuildContext context, ErrorInfo errorInfo) {
    // In a real app, this would send error reports to a logging service
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error report sent. Thank you for your feedback!'),
        backgroundColor: modern.ModernDesignSystem.secondaryTeal,
      ),
    );
  }
}

/// Accessibility-enhanced button with semantic annotations
class AccessibilityEnhancedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final modern.ButtonStyle style;
  final String? semanticLabel;
  final String? semanticHint;
  final IconData? icon;
  final bool enableHapticFeedback;

  const AccessibilityEnhancedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style = modern.ButtonStyle.primary,
    this.semanticLabel,
    this.semanticHint,
    this.icon,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityTheme = AccessibilityTheme.of(context);
    
    return Semantics(
      label: semanticLabel ?? text,
      hint: semanticHint,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed != null ? () {
        if (enableHapticFeedback) {
          HapticFeedback.lightImpact();
        }
        onPressed!();
      } : null,
      child: modern.ModernButton(
        text: text,
        onPressed: onPressed,
        style: style,
        icon: icon,
      ),
    );
  }
}

/// Enhanced text widget with accessibility support
class AccessibilityEnhancedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String? semanticLabel;
  final bool isHeader;
  final bool isLiveRegion;
  final TextAlign? textAlign;

  const AccessibilityEnhancedText({
    super.key,
    required this.text,
    this.style,
    this.semanticLabel,
    this.isHeader = false,
    this.isLiveRegion = false,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityTheme = AccessibilityTheme.of(context);
    final adjustedStyle = style?.copyWith(
      fontSize: (style?.fontSize ?? 16) * (accessibilityTheme?.getTextScale() ?? 1.0),
      color: accessibilityTheme?.getContrastAdjustedColor(
        style?.color ?? modern.ModernDesignSystem.darkBlue,
      ) ?? style?.color,
    );

    return Semantics(
      label: semanticLabel ?? text,
      header: isHeader,
      liveRegion: isLiveRegion,
      child: Text(
        text,
        style: adjustedStyle,
        textAlign: textAlign,
      ),
    );
  }
}

/// Error information class
class ErrorInfo {
  final String message;
  final String userFriendlyMessage;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String errorId;

  ErrorInfo({
    required this.message,
    required this.userFriendlyMessage,
    this.stackTrace,
    DateTime? timestamp,
    String? errorId,
  }) : timestamp = timestamp ?? DateTime.now(),
       errorId = errorId ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory ErrorInfo.fromFlutterError(FlutterErrorDetails details) {
    return ErrorInfo(
      message: details.exception.toString(),
      userFriendlyMessage: _getUserFriendlyMessage(details.exception.toString()),
      stackTrace: details.stack,
    );
  }

  static String _getUserFriendlyMessage(String technicalMessage) {
    // Convert technical errors to user-friendly messages
    if (technicalMessage.contains('network') || technicalMessage.contains('connection')) {
      return 'Please check your internet connection and try again.';
    }
    if (technicalMessage.contains('permission')) {
      return 'Permission denied. Please check your device settings.';
    }
    if (technicalMessage.contains('storage') || technicalMessage.contains('space')) {
      return 'Not enough storage space. Please free up some space and try again.';
    }
    
    return 'An unexpected error occurred. We\'re working to fix this issue.';
  }
}

/// Error boundary configuration
class ErrorBoundaryConfig {
  final Function(ErrorInfo)? onError;
  final bool enableCrashReporting;
  final bool showErrorDetails;

  const ErrorBoundaryConfig({
    this.onError,
    this.enableCrashReporting = false,
    this.showErrorDetails = false,
  });
}

/// Focus management helper for keyboard navigation
class FocusManagementHelper {
  static void announceFocusChange(String announcement) {
    SemanticsService.announce(announcement, TextDirection.ltr);
  }

  static void announcePageChange(String pageName) {
    SemanticsService.announce('Navigated to $pageName', TextDirection.ltr);
  }

  static void announceAction(String action) {
    SemanticsService.announce(action, TextDirection.ltr);
  }
}

/// Loading state with accessibility support
class AccessibleLoadingIndicator extends StatelessWidget {
  final String? loadingText;
  final Color? color;

  const AccessibleLoadingIndicator({
    super.key,
    this.loadingText,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: loadingText ?? 'Loading',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? modern.ModernDesignSystem.primaryBlue,
              ),
            ),
            if (loadingText != null) ...[
              const SizedBox(height: modern.ModernDesignSystem.spaceMD),
              AccessibilityEnhancedText(
                text: loadingText!,
                style: modern.ModernDesignSystem.bodyMedium,
                isLiveRegion: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}