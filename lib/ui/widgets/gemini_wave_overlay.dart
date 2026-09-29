import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/providers/voice_assistant_providers.dart';

/// Gemini AI-inspired glowing animated wave and speech visualizer.
/// Displays live user transcript and Gemini responses with high-contrast accessibility.
class GeminiWaveOverlay extends ConsumerStatefulWidget {
  const GeminiWaveOverlay({super.key});

  @override
  ConsumerState<GeminiWaveOverlay> createState() => _GeminiWaveOverlayState();
}

class _GeminiWaveOverlayState extends ConsumerState<GeminiWaveOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(voiceAssistantStateProvider);
    final isListening = assistantState.isListening;
    final isThinking = assistantState.isThinking;

    // Only display wave overlay when actively thinking or showing AI conversational response
    if (!isThinking && assistantState.aiResponse.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final glowScale = 1.0 + (_animController.value * 0.15);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isThinking
                  ? Colors.purpleAccent
                  : isListening
                      ? Colors.cyanAccent
                      : Colors.yellowAccent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isThinking ? Colors.purpleAccent : Colors.cyanAccent)
                    .withValues(alpha: 0.35 * glowScale),
                blurRadius: 18.0 * glowScale,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: Row(
            children: [
              // Glowing Gemini AI Orb
              Transform.scale(
                scale: isListening || isThinking ? glowScale : 1.0,
                child: Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isThinking
                          ? [Colors.purpleAccent, Colors.blueAccent]
                          : [Colors.cyanAccent, Colors.yellowAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isThinking
                          ? Icons.auto_awesome
                          : isListening
                              ? Icons.mic
                              : Icons.check,
                      color: Colors.black,
                      size: 24.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14.0),

              // Transcript & Gemini Response
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isThinking
                          ? 'Gemini Thinking...'
                          : isListening
                              ? 'Echo Listening...'
                              : 'Echo AI',
                      style: TextStyle(
                        color: isThinking
                            ? Colors.purpleAccent
                            : isListening
                                ? Colors.cyanAccent
                                : Colors.yellowAccent,
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      assistantState.spokenText.isNotEmpty
                          ? '"${assistantState.spokenText}"'
                          : assistantState.aiResponse.isNotEmpty
                              ? assistantState.aiResponse
                              : assistantState.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Close / Stop button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20.0),
                onPressed: () {
                  ref.read(voiceAssistantStateProvider.notifier).stopListening();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
