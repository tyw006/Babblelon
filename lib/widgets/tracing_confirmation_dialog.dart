import 'package:flutter/material.dart';
import 'package:babblelon/screens/main_screen/widgets/glassmorphic_card.dart';

/// Dialog that shows which canvases have strokes and confirms assessment
/// Styled to match the app's dark theme like pronunciation assessments
class TracingConfirmationDialog extends StatelessWidget {
  /// Map of character index to character name/text for display
  final Map<int, String> characterNames;
  
  /// Map of character index to whether they have strokes
  final Map<int, bool> charactersWithStrokes;
  
  /// Called when user confirms assessment
  final VoidCallback onConfirm;
  
  /// Called when user cancels
  final VoidCallback onCancel;

  const TracingConfirmationDialog({
    super.key,
    required this.characterNames,
    required this.charactersWithStrokes,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tracedCount = charactersWithStrokes.values.where((hasStrokes) => hasStrokes).length;
    final totalCount = characterNames.length;
    final untracedCount = totalCount - tracedCount;
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
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECCA3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4ECCA3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in,
                      color: Color(0xFF4ECCA3),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        'Ready for Assessment?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Review your character tracings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Progress Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildProgressIndicator(
                      'Traced',
                      tracedCount,
                      const Color(0xFF4ECCA3),
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildProgressIndicator(
                      'Untraced',
                      untracedCount,
                      Colors.grey[500]!,
                      Icons.radio_button_unchecked,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildProgressIndicator(
                      'Total',
                      totalCount,
                      const Color(0xFF6C63FF),
                      Icons.grid_view,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Character Grid
            Text(
              'Character Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: _buildCharacterGrid(),
            ),
            
            const SizedBox(height: 20),
            
            // Warning for untraced characters
            if (untracedCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[400]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange[400]!.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        untracedCount == 1 
                            ? '1 character has no tracing and will receive 0% accuracy.'
                            : '$untracedCount characters have no tracings and will receive 0% accuracy.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECCA3),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assessment, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          tracedCount == 0 ? 'Skip Assessment' : 'Continue',
                          style: const TextStyle(
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
          ],
        ),
      ),
    ));
  }

  Widget _buildProgressIndicator(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterGrid() {
    final sortedIndices = characterNames.keys.toList()..sort();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedIndices.map((index) {
        final character = characterNames[index] ?? '';
        final hasStrokes = charactersWithStrokes[index] ?? false;
        
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: hasStrokes 
                ? const Color(0xFF4ECCA3).withOpacity(0.2) 
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasStrokes 
                  ? const Color(0xFF4ECCA3) 
                  : Colors.white.withOpacity(0.3),
              width: hasStrokes ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  character,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: hasStrokes 
                        ? const Color(0xFF4ECCA3) 
                        : Colors.white70,
                  ),
                ),
              ),
              if (hasStrokes)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECCA3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}