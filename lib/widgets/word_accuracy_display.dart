import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WordAccuracyDisplay extends StatelessWidget {
  final List<WordAccuracy> words;
  final Duration animationDuration;

  const WordAccuracyDisplay({
    super.key,
    required this.words,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Word-by-Word Accuracy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              return _buildWordChip(word, index);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(WordAccuracy word, int index) {
    final accuracy = word.accuracyScore;
    final errorType = _getErrorType(accuracy);
    final color = _getAccuracyColor(accuracy);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.originalText,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (word.transliteratedText.isNotEmpty)
                    Text(
                      word.transliteratedText,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
              Text(
                accuracy.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Tooltip(
            message: 'Accuracy Score: $accuracy\nError: $errorType',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: accuracy / 100,
                backgroundColor: Colors.grey.shade700,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getErrorType(double accuracy) {
    if (accuracy == 100) {
      return 'None';
    } else if (accuracy >= 75) {
      return 'Minor';
    } else if (accuracy >= 50) {
      return 'Moderate';
    } else {
      return 'Severe';
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy == 100) {
      return Colors.green;
    } else if (accuracy >= 75) {
      return Colors.yellow;
    } else if (accuracy >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

class WordAccuracy {
  final String originalText;
  final String transliteratedText;
  final String errorMessage;
  final bool isCorrect;
  final double accuracyScore;

  const WordAccuracy({
    required this.originalText,
    this.transliteratedText = '',
    this.errorMessage = '',
    required this.isCorrect,
    this.accuracyScore = 0.0,
  });
} 