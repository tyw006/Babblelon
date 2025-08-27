import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration class for popup dialogs
@immutable
class PopupConfig {
  final String title;
  final String message;
  final String? confirmText;
  final void Function(BuildContext context)? onConfirm;
  final String? cancelText;
  final void Function(BuildContext context)? onCancel;

  const PopupConfig({
    required this.title,
    required this.message,
    this.confirmText,
    this.onConfirm,
    this.cancelText,
    this.onCancel,
  });
}

/// Provider for managing popup configurations
final popupConfigProvider = StateProvider<PopupConfig?>((ref) => null);