import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/widgets/popups/base_popup_widget.dart';

class InfoPopupOverlay extends ConsumerWidget {
  final String title;
  final String message;
  final String? confirmText;
  final void Function(BuildContext context)? onConfirm;
  final String? cancelText;
  final void Function(BuildContext context)? onCancel;

  const InfoPopupOverlay({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.onConfirm,
    this.cancelText,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: BasePopup.buildPopupContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cancelText != null && onCancel != null)
                  TextButton(
                    onPressed: () {
                      ref.playButtonSound();
                      onCancel!(context);
                    },
                    style: BasePopup.secondaryButtonStyle,
                    child: Text(cancelText!),
                  ),
                if (cancelText != null && onCancel != null && confirmText != null && onConfirm != null)
                  const SizedBox(width: 16),
                if (confirmText != null && onConfirm != null)
                  ElevatedButton(
                    onPressed: () {
                      ref.playButtonSound();
                      onConfirm!(context);
                    },
                    style: BasePopup.primaryButtonStyle,
                    child: Text(confirmText!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 