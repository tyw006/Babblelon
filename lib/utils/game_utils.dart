import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Utility functions for game development
class GameUtils {
  /// Generate a random position within the game area
  static Vector2 randomPosition(Vector2 gameSize) {
    final random = math.Random();
    return Vector2(
      random.nextDouble() * gameSize.x,
      random.nextDouble() * gameSize.y,
    );
  }
  
  /// Calculate distance between two Vector2 points
  static double distanceBetween(Vector2 a, Vector2 b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }
  
  /// Check if a point is within the game bounds
  static bool isInBounds(Vector2 position, Vector2 gameSize) {
    return position.x >= 0 && 
           position.x <= gameSize.x && 
           position.y >= 0 && 
           position.y <= gameSize.y;
  }
  
  /// Convert game score to a formatted string (e.g., 1500 to 1.5K)
  static String formatScore(int score) {
    if (score < 1000) return score.toString();
    if (score < 1000000) return '${(score / 1000).toStringAsFixed(1)}K';
    return '${(score / 1000000).toStringAsFixed(1)}M';
  }
  
  /// Generate a color based on a value (useful for difficulty levels)
  static Color colorFromValue(double value, {
    Color startColor = Colors.green,
    Color endColor = Colors.red,
  }) {
    // Ensure value is between 0.0 and 1.0
    final normalizedValue = value.clamp(0.0, 1.0);
    
    return Color.lerp(startColor, endColor, normalizedValue)!;
  }
  
  /// Convert seconds to a time format (mm:ss)
  static String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  /// Calculate an angle in radians between two Vector2 points
  static double angleBetween(Vector2 from, Vector2 to) {
    return math.atan2(to.y - from.y, to.x - from.x);
  }
} 