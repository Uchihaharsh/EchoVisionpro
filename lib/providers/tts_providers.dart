import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/services/tts_service.dart';

/// Provider for the TTSService singleton
final ttsServiceProvider = Provider<TTSService>((ref) {
  final service = TTSService();
  ref.onDispose(() => service.dispose());
  return service;
  });

/// State for TTS management
class TTSState {
  final bool isSpeaking;
  final String? currentText;
  final String language;

  TTSState({
    this.isSpeaking = false,
    this.currentText,
    this.language = 'en-US',
  });

  TTSState copyWith({
    bool? isSpeaking,
    String? currentText,
    String? language,
  }) {
    return TTSState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentText: currentText ?? this.currentText,
      language: language ?? this.language,
    );
  }
}

/// StateNotifier for TTS state management
class TTSStateNotifier extends StateNotifier<TTSState> {
  final TTSService _ttsService;
  StreamSubscription<bool>? _speakingSub;

  TTSStateNotifier(this._ttsService) : super(TTSState()) {
    _speakingSub = _ttsService.speakingStream.listen((speaking) {
      state = state.copyWith(isSpeaking: speaking);
    });
  }

  /// Initialize TTS settings
  Future<void> initialize() async {
    await _ttsService.initialize();
    await _ttsService.setLanguage(state.language);
  }

  /// Speaks the given text
  Future<void> speak(String text, {bool interrupt = false}) async {
    state = state.copyWith(isSpeaking: true, currentText: text);
    await _ttsService.speak(text, interrupt: interrupt);
  }

  /// Stops current speech
  Future<void> stop() async {
    await _ttsService.stop();
    state = state.copyWith(isSpeaking: false, currentText: null);
  }

  /// Sets the TTS language
  Future<void> setLanguage(String language) async {
    await _ttsService.setLanguage(language);
    state = state.copyWith(language: language);
  }

  @override
  void dispose() {
    _speakingSub?.cancel();
    super.dispose();
  }
}

/// Provider exposing the TTS state notifier
final ttsStateProvider = StateNotifierProvider<TTSStateNotifier, TTSState>((ref) {
  return TTSStateNotifier(ref.read(ttsServiceProvider));
});
