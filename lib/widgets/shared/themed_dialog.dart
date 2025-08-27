import 'package:flutter/material.dart';
import 'package:babblelon/theme/modern_design_system.dart' as modern;

/// Reusable dark-themed dialog wrapper that ensures consistent theming
/// Fixes Material 3 compatibility issues and provides proper dark theme styling
class ThemedDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsets? contentPadding;
  final EdgeInsets? actionsPadding;
  final EdgeInsets? titlePadding;
  final ScrollController? scrollController;
  final bool scrollable;

  const ThemedDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.actionsPadding,
    this.titlePadding,
    this.scrollController,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dialogTheme: const DialogThemeData(
          backgroundColor: modern.ModernDesignSystem.primarySurface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      child: AlertDialog(
        backgroundColor: modern.ModernDesignSystem.primarySurface,
        surfaceTintColor: Colors.transparent,
        title: title,
        content: content,
        actions: actions,
        contentPadding: contentPadding,
        actionsPadding: actionsPadding,
        titlePadding: titlePadding,
        scrollable: scrollable,
      ),
    );
  }
}

/// Themed SnackBar that follows the app's dark theme
class ThemedSnackBar {
  static SnackBar create({
    required String message,
    Color? backgroundColor,
    Color? textColor,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    return SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: textColor ?? modern.ModernDesignSystem.textPrimary,
        ),
      ),
      backgroundColor: backgroundColor ?? modern.ModernDesignSystem.primarySurface,
      action: action,
      duration: duration,
      behavior: behavior,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  static SnackBar success({
    required String message,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    return create(
      message: message,
      backgroundColor: modern.ModernDesignSystem.forestGreen,
      action: action,
      duration: duration,
    );
  }

  static SnackBar warning({
    required String message,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    return create(
      message: message,
      backgroundColor: modern.ModernDesignSystem.warmOrange,
      action: action,
      duration: duration,
    );
  }

  static SnackBar error({
    required String message,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    return create(
      message: message,
      backgroundColor: modern.ModernDesignSystem.cherryRed,
      action: action,
      duration: duration,
    );
  }
}