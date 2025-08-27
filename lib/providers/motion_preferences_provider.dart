import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Motion preferences provider for accessibility
/// Manages user preferences for reduced motion animations
class MotionPreferences extends ChangeNotifier {
  bool _reduceMotion = false;
  SharedPreferences? _prefs;

  /// Whether to reduce motion animations
  bool get reduceMotion => _reduceMotion;

  /// Initialize preferences from SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _reduceMotion = _prefs?.getBool('reduce_motion') ?? false;
    notifyListeners();
  }

  /// Toggle motion reduction setting
  Future<void> setReduceMotion(bool value) async {
    _reduceMotion = value;
    await _prefs?.setBool('reduce_motion', value);
    notifyListeners();
  }

  /// Get motion duration based on preference
  Duration getMotionDuration(Duration normalDuration) {
    if (_reduceMotion) {
      return Duration(milliseconds: (normalDuration.inMilliseconds * 0.1).round());
    }
    return normalDuration;
  }

  /// Get motion curve based on preference
  Curve getMotionCurve(Curve normalCurve) {
    if (_reduceMotion) {
      return Curves.linear;
    }
    return normalCurve;
  }

  /// Check if animation should be disabled
  bool get shouldDisableAnimation => _reduceMotion;

  /// Factory method to create provider
  static ChangeNotifierProvider<MotionPreferences> provider() {
    return ChangeNotifierProvider<MotionPreferences>(
      create: (context) => MotionPreferences()..init(),
    );
  }
}

/// Extension for easy access to motion preferences
extension MotionPreferencesExtension on BuildContext {
  /// Get motion preferences from context
  MotionPreferences get motionPrefs => Provider.of<MotionPreferences>(this);
  
  /// Watch motion preferences changes
  MotionPreferences watchMotionPrefs() => watch<MotionPreferences>();
}

/// Utility class for motion-aware animations
class MotionAwareAnimation {
  /// Create a motion-aware duration
  static Duration duration(
    BuildContext context,
    Duration normalDuration,
  ) {
    final motionPrefs = context.motionPrefs;
    return motionPrefs.getMotionDuration(normalDuration);
  }

  /// Create a motion-aware curve
  static Curve curve(
    BuildContext context,
    Curve normalCurve,
  ) {
    final motionPrefs = context.motionPrefs;
    return motionPrefs.getMotionCurve(normalCurve);
  }

  /// Check if animation should be disabled
  static bool shouldDisable(BuildContext context) {
    final motionPrefs = context.motionPrefs;
    return motionPrefs.shouldDisableAnimation;
  }
}

/// Widget that conditionally shows animation based on motion preferences
class ConditionalAnimation extends StatelessWidget {
  final Widget child;
  final Widget Function(BuildContext context, Widget child) animationBuilder;
  final bool respectMotionPreferences;

  const ConditionalAnimation({
    super.key,
    required this.child,
    required this.animationBuilder,
    this.respectMotionPreferences = true,
  });

  @override
  Widget build(BuildContext context) {
    if (respectMotionPreferences && MotionAwareAnimation.shouldDisable(context)) {
      return child;
    }
    return animationBuilder(context, child);
  }
}