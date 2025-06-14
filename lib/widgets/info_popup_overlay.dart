import 'package:flutter/material.dart';

class InfoPopupOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: Colors.black.withOpacity(0.8),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
                    ElevatedButton(
                      onPressed: () => onCancel!(context),
                      child: Text(cancelText!),
                    ),
                  if (cancelText != null && onCancel != null && confirmText != null && onConfirm != null)
                    const SizedBox(width: 16),
                  if (confirmText != null && onConfirm != null)
                    ElevatedButton(
                      onPressed: () => onConfirm!(context),
                      child: Text(confirmText!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 