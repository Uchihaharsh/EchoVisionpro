import 'package:flutter/services.dart';

class AudioFeedback {
  /// Triggers a light haptic feedback.
  static Future<void> hapticLight() async {
    await HapticFeedback.lightImpact();
  }

  /// Triggers a medium haptic feedback.
  static Future<void> hapticMedium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Triggers a heavy haptic feedback, useful for warnings and critical alerts.
  static Future<void> hapticHeavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Triggers selection haptic feedback.
  static Future<void> hapticSelection() async {
    await HapticFeedback.selectionClick();
  }
}
