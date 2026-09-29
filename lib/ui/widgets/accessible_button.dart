import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A high-contrast, large touch target button designed for accessibility.
class AccessibleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final String? semanticLabel;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors for high contrast
    final bg = backgroundColor ?? Colors.yellowAccent;
    final textCol = textColor ?? Colors.black;

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      enabled: true,
      child: Material(
        color: bg,
        elevation: 4.0,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact(); // Haptic feedback on press
            onPressed();
          },
          borderRadius: BorderRadius.circular(16.0),
          splashColor: Colors.white.withValues(alpha: 0.3),
          child: Container(
            constraints: const BoxConstraints(minHeight: 80.0), // Min 80dp touch target
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 40.0, // Large icon
                  color: textCol,
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 22.0, // 22sp font size
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
