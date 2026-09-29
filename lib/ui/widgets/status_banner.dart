import 'package:flutter/material.dart';

/// A horizontal status banner indicating current mode or activity.
class StatusBanner extends StatefulWidget {
  final String statusText;
  final bool isActive;
  final IconData? icon;

  const StatusBanner({
    super.key,
    required this.statusText,
    this.isActive = false,
    this.icon,
  });

  @override
  State<StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: ${widget.statusText}',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey[900], // Dark background
          border: const Border(
            left: BorderSide(color: Colors.yellowAccent, width: 6.0), // Colored left border
          ),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.yellowAccent, size: 28.0),
              const SizedBox(width: 12.0),
            ],
            Expanded(
              child: Text(
                widget.statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.isActive)
              FadeTransition(
                opacity: _controller,
                child: Container(
                  width: 12.0,
                  height: 12.0,
                  decoration: const BoxDecoration(
                    color: Colors.yellowAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
