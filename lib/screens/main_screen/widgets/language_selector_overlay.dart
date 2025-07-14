import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:babblelon/screens/main_screen/widgets/glassmorphic_card.dart';

class LanguageSelectorOverlay extends StatelessWidget {
  final Function(String) onLanguageSelected;
  final bool isRotating;

  const LanguageSelectorOverlay({
    super.key,
    required this.onLanguageSelected,
    required this.isRotating,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        blur: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Language',
              style: TextStyle(
                fontSize: 16, // Reduced from 18
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10), // Reduced from 20
            
            // Thai language option (enabled)
            _buildLanguageOption(
              'Thai',
              '🇹🇭',
              'Start your Thai adventure!',
              true,
              () => onLanguageSelected('thai'),
            ),
            
            const SizedBox(height: 8), // Reduced from 15,10
            
            // Other languages (coming soon)
            _buildLanguageOption(
              'Spanish',
              '🇪🇸',
              'Coming soon...',
              false,
              null,
            ),
            
            const SizedBox(height: 8), // Reduced from 15,10
            
            _buildLanguageOption(
              'French',
              '🇫🇷',
              'Coming soon...',
              false,
              null,
            ),
            
            const SizedBox(height: 8), // Reduced from 15,10
            
            _buildLanguageOption(
              'Japanese',
              '🇯🇵',
              'Coming soon...',
              false,
              null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    String language,
    String flag,
    String subtitle,
    bool isEnabled,
    VoidCallback? onTap,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: isEnabled && !isRotating ? onTap : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), // Reduced from 20,15
            decoration: BoxDecoration(
              color: isEnabled 
                  ? (isRotating 
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.blue.withValues(alpha: 0.2))
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isEnabled 
                    ? (isRotating 
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.blue.withValues(alpha: 0.3))
                    : Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  flag,
                  style: const TextStyle(fontSize: 20), // Reduced from 28
                ),
                const SizedBox(width: 10), // Reduced from 15
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language,
                        style: TextStyle(
                          fontSize: 14, // Reduced from 16
                          fontWeight: FontWeight.bold,
                          color: isEnabled ? Colors.white : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 1), // Reduced from 2
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10, // Reduced from 12
                          color: isEnabled 
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.grey.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRotating && isEnabled)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                else if (isEnabled)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 14, // Reduced from 16
                  )
                else
                  Icon(
                    Icons.lock,
                    color: Colors.grey.withValues(alpha: 0.5),
                    size: 14, // Reduced from 16
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate(target: isEnabled ? 1 : 0)
      .scaleXY(begin: 0.95, end: 1.0, duration: 300.ms)
      .fadeIn(duration: 300.ms);
  }
}