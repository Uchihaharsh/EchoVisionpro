import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/providers/voice_assistant_providers.dart';

/// High-contrast accessible Voice Assistant Bar and Microphone activator.
/// Provides visual, tactile, and screen reader feedback for blind and low-vision users.
class VoiceAssistantBar extends ConsumerWidget {
  const VoiceAssistantBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantState = ref.watch(voiceAssistantStateProvider);
    final isListening = assistantState.isListening;

    return Semantics(
      button: true,
      label: isListening
          ? 'Voice assistant listening. Speak your command now.'
          : 'Voice Assistant. Tap to activate voice commands, or say Hey Echo.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(voiceAssistantStateProvider.notifier).toggleListening();
          },
          borderRadius: BorderRadius.circular(20.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isListening ? Colors.blueGrey[900] : Colors.grey[900],
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: isListening ? Colors.cyanAccent : Colors.yellowAccent,
                width: isListening ? 3.5 : 2.0,
              ),
              boxShadow: isListening
                  ? [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.4),
                        blurRadius: 16.0,
                        spreadRadius: 2.0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Animated Glowing Microphone Icon
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: isListening ? Colors.cyanAccent : Colors.yellowAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.black,
                    size: 28.0,
                  ),
                ),
                const SizedBox(width: 14.0),

                // Live Assistant Status & Spoken Words
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            isListening ? 'Echo Listening...' : 'Hey Echo Assistant',
                            style: TextStyle(
                              color: isListening ? Colors.cyanAccent : Colors.yellowAccent,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isListening) ...[
                            const SizedBox(width: 6.0),
                            const SizedBox(
                              width: 10.0,
                              height: 10.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        assistantState.spokenText.isNotEmpty
                            ? '"${assistantState.spokenText}"'
                            : assistantState.status,
                        style: TextStyle(
                          color: assistantState.spokenText.isNotEmpty ? Colors.white : Colors.white70,
                          fontSize: 14.0,
                          fontWeight: assistantState.spokenText.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          fontStyle: assistantState.spokenText.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Help hint button
                IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white70, size: 24.0),
                  tooltip: 'Voice Commands Help',
                  onPressed: () {
                    ref.read(voiceAssistantStateProvider.notifier).speakHelp();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
