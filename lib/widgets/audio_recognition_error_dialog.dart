import 'package:flutter/material.dart';
import 'package:babblelon/screens/main_screen/widgets/glassmorphic_card.dart';

/// Dialog that appears when audio recognition fails, offering a retry option
class AudioRecognitionErrorDialog extends StatelessWidget {
  /// User-friendly error message to display
  final String message;
  
  /// Called when user wants to try recording again
  final VoidCallback onTryAgain;

  const AudioRecognitionErrorDialog({
    super.key,
    required this.message,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isSmallScreen ? 10.0 : 20.0),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(20),
        blur: 20,
        opacity: 0.15,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with warning icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.hearing,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Audio Not Recognized',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Error message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Helpful tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.blue[300],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tips for better recognition:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[300],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Speak clearly and at a normal pace\n'
                      '• Reduce background noise\n'
                      '• Hold your device closer to your mouth',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Try Again button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTryAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECCA3),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}