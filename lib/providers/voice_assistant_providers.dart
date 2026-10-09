import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/app.dart';
import 'package:smart_glasses/services/voice_assistant_service.dart';
import 'package:smart_glasses/services/gemini_assistant_service.dart';
import 'package:smart_glasses/providers/tts_providers.dart';
import 'package:smart_glasses/providers/camera_providers.dart';
import 'package:smart_glasses/providers/navigation_providers.dart';
import 'package:smart_glasses/providers/detection_providers.dart';
import 'package:smart_glasses/ui/detect_mode_screen.dart';
import 'package:smart_glasses/ui/currency_mode_screen.dart';
import 'package:smart_glasses/ui/read_mode_screen.dart';
import 'package:smart_glasses/ui/navigate_mode_screen.dart';

final geminiAssistantServiceProvider = Provider<GeminiAssistantService>((ref) {
  return GeminiAssistantService();
});

final voiceAssistantServiceProvider = Provider<VoiceAssistantService>((ref) {
  final service = VoiceAssistantService();
  ref.onDispose(() => service.dispose());
  return service;
});

class VoiceAssistantState {
  final bool isListening;
  final bool isThinking;
  final bool isAvailable;
  final String spokenText;
  final String aiResponse;
  final VoiceCommand? lastCommand;
  final String status;
  final String currentScreen;

  const VoiceAssistantState({
    this.isListening = false,
    this.isThinking = false,
    this.isAvailable = false,
    this.spokenText = '',
    this.aiResponse = '',
    this.lastCommand,
    this.status = "Listening for 'Hey Echo'...",
    this.currentScreen = 'home',
  });

  VoiceAssistantState copyWith({
    bool? isListening,
    bool? isThinking,
    bool? isAvailable,
    String? spokenText,
    String? aiResponse,
    VoiceCommand? lastCommand,
    String? status,
    String? currentScreen,
  }) {
    return VoiceAssistantState(
      isListening: isListening ?? this.isListening,
      isThinking: isThinking ?? this.isThinking,
      isAvailable: isAvailable ?? this.isAvailable,
      spokenText: spokenText ?? this.spokenText,
      aiResponse: aiResponse ?? this.aiResponse,
      lastCommand: lastCommand ?? this.lastCommand,
      status: status ?? this.status,
      currentScreen: currentScreen ?? this.currentScreen,
    );
  }
}

class VoiceAssistantNotifier extends StateNotifier<VoiceAssistantState> {
  final VoiceAssistantService _voiceService;
  final GeminiAssistantService _geminiService;
  final Ref _ref;

  StreamSubscription<bool>? _statusSub;
  StreamSubscription<String>? _wordsSub;
  StreamSubscription<VoiceCommand>? _cmdSub;

  VoiceAssistantNotifier(this._voiceService, this._geminiService, this._ref)
      : super(const VoiceAssistantState()) {
    _init();
  }

  void _init() {
    // Notify speech service of TTS playback to prevent mic collisions
    _ref.listen<TTSState>(ttsStateProvider, (previous, next) {
      _voiceService.notifyTtsSpeaking(next.isSpeaking, next.currentText);
      if (next.isSpeaking) {
        _voiceService.pauseForTts();
      } else if (previous?.isSpeaking == true && !next.isSpeaking) {
        // TTS just finished speaking! Immediately verify mic is active so user can speak next command
        _voiceService.resumeAfterTts();
      }
    });

    _statusSub = _voiceService.listeningStatusStream.listen((listening) {
      state = state.copyWith(
        isListening: listening,
        status: listening ? "Echo listening... Say 'Hey Echo'" : 'Mic ready',
        spokenText: listening ? state.spokenText : '',
      );
    });

    _wordsSub = _voiceService.partialWordsStream.listen((words) {
      state = state.copyWith(spokenText: words);
    });

    _cmdSub = _voiceService.commandStream.listen((cmd) {
      debugPrint('VoiceAssistantNotifier received: type=${cmd.type}, raw="${cmd.rawText}"');

      // Stop ongoing speech immediately when a new command arrives (barge-in!)
      if (cmd.type != VoiceCommandType.wakeWordPrompt) {
        _ref.read(ttsStateProvider.notifier).stop();
      }

      if (cmd.type != VoiceCommandType.unknown) {
        // FAST PATH (0ms latency): Actionable command matched locally! Execute immediately!
        state = state.copyWith(
          isThinking: false,
          lastCommand: cmd,
          spokenText: cmd.rawText,
          status: 'Executing: "${cmd.rawText}"',
        );
        _executeCommandGlobally(cmd);
      } else {
        // SLOW/AI PATH: Conversational query or unknown phrasing -> query Gemini AI
        _processCommandWithGemini(cmd);
      }
    });
  }

  /// Sets current screen tag to prevent duplicate screen pushes
  void setCurrentScreen(String screenName) {
    if (state.currentScreen != screenName) {
      state = state.copyWith(currentScreen: screenName);
    }
  }

  /// Processes conversational or unknown queries through Gemini AI
  Future<void> _processCommandWithGemini(VoiceCommand cmd) async {
    state = state.copyWith(
      isThinking: true,
      status: 'Gemini thinking...',
      spokenText: cmd.rawText,
    );

    try {
      final geminiResp = await _geminiService.processUserSpeech(cmd.rawText);

      // 1. Multimodal Scene Description ("What am I looking at?")
      if (geminiResp.isMultimodalSceneDescription) {
        await _describeCameraSceneWithGemini(cmd.rawText);
        return;
      }

      // 2. Action Routing (Currency, OCR, Navigation, Object Detection, etc.)
      final effectiveCmd = VoiceCommand(
        type: geminiResp.intent != VoiceCommandType.unknown ? geminiResp.intent : cmd.type,
        rawText: cmd.rawText,
        argument: geminiResp.argument ?? cmd.argument,
      );

      state = state.copyWith(
        isThinking: false,
        lastCommand: effectiveCmd,
        aiResponse: geminiResp.speechResponse,
        status: 'Recognized: "${cmd.rawText}"',
      );

      _executeCommandGlobally(effectiveCmd);
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        lastCommand: cmd,
        status: 'Recognized: "${cmd.rawText}"',
      );
      _executeCommandGlobally(cmd);
    }
  }

  /// Multimodal Vision Scene Description using Gemini Vision with offline sensor fallback
  Future<void> _describeCameraSceneWithGemini(String prompt) async {
    state = state.copyWith(
      isThinking: true,
      status: 'Echo analyzing view...',
      spokenText: prompt,
    );
    _ref.read(ttsStateProvider.notifier).speak("Analyzing view through camera...");

    try {
      final cameraService = _ref.read(cameraServiceProvider);
      final frameBytes = await cameraService.extractFrame();

      if (frameBytes != null && frameBytes.isNotEmpty) {
        final description = await _geminiService.describeCameraScene(frameBytes, prompt);
        state = state.copyWith(
          isThinking: false,
          aiResponse: description,
          status: 'Echo described scene',
        );
        _ref.read(ttsStateProvider.notifier).speak(description);
      } else {
        _describeSceneOfflineFallback();
      }
    } catch (e) {
      _describeSceneOfflineFallback();
    }
  }

  void _describeSceneOfflineFallback() {
    final detectionResults = _ref.read(detectionStateProvider).results;
    if (detectionResults.isNotEmpty) {
      final labels = detectionResults.map((r) => r.label.toString()).toSet().toList();
      final itemsStr = labels.join(', ');
      final response = "In front of you, I see $itemsStr.";
      state = state.copyWith(isThinking: false, aiResponse: response, status: 'Scene described');
      _ref.read(ttsStateProvider.notifier).speak(response);
    } else {
      const response = "Looking straight ahead, the path appears clear. Point camera closer to inspect items.";
      state = state.copyWith(isThinking: false, aiResponse: response, status: 'Scene described');
      _ref.read(ttsStateProvider.notifier).speak(response);
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return "The time is $hour:$minute $period";
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dayName = weekdays[now.weekday - 1];
    final monthName = months[now.month - 1];
    return "Today is $dayName, $monthName ${now.day}";
  }

  /// Global command execution: works anywhere in the app at all times
  void _executeCommandGlobally(VoiceCommand cmd) {
    HapticFeedback.heavyImpact();

    switch (cmd.type) {
      case VoiceCommandType.wakeWordPrompt:
        _ref.read(ttsStateProvider.notifier).speak("Yes?", interrupt: true);
        state = state.copyWith(status: "Listening for command...");
        break;

      case VoiceCommandType.stopSpeaking:
        _ref.read(ttsStateProvider.notifier).stop();
        break;

      case VoiceCommandType.tellTime:
        final timeStr = _formatCurrentTime();
        _ref.read(ttsStateProvider.notifier).speak(timeStr);
        state = state.copyWith(status: timeStr);
        break;

      case VoiceCommandType.tellDate:
        final dateStr = _formatCurrentDate();
        _ref.read(ttsStateProvider.notifier).speak(dateStr);
        state = state.copyWith(status: dateStr);
        break;

      case VoiceCommandType.tellStatus:
        final cameraName = _ref.read(cameraStateProvider).cameraName;
        final screenName = state.currentScreen == 'home'
            ? 'Home Screen'
            : (state.currentScreen == 'detect'
                ? 'Object Detection Mode'
                : (state.currentScreen == 'currency'
                    ? 'Currency Mode'
                    : (state.currentScreen == 'read' ? 'Read Text Mode' : 'Navigation Mode')));
        final statusStr = "You are on $screenName using $cameraName.";
        _ref.read(ttsStateProvider.notifier).speak(statusStr);
        state = state.copyWith(status: statusStr);
        break;

      case VoiceCommandType.describeScene:
        _describeCameraSceneWithGemini(cmd.rawText);
        break;

      case VoiceCommandType.openCurrency:
        _globalNavigate(const CurrencyModeScreen(), 'currency', 'Opening Currency Recognition');
        break;

      case VoiceCommandType.openObjectDetection:
        _globalNavigate(const DetectModeScreen(), 'detect', 'Opening Object Detection');
        break;

      case VoiceCommandType.openReadText:
        _globalNavigate(const ReadModeScreen(), 'read', 'Opening Read Text Mode');
        break;

      case VoiceCommandType.openNavigation:
        _globalNavigate(
          NavigateModeScreen(initialDestination: cmd.argument),
          'navigate',
          cmd.argument != null && cmd.argument!.isNotEmpty
              ? 'Opening Navigation to ${cmd.argument}'
              : 'Opening Navigation Mode',
        );
        break;

      case VoiceCommandType.goHome:
        _globalGoHome();
        break;

      case VoiceCommandType.switchCamera:
        _ref.read(cameraStateProvider.notifier).toggleCameraSource();
        final updatedCamera = _ref.read(cameraStateProvider).cameraName;
        _ref.read(ttsStateProvider.notifier).speak('Switched to $updatedCamera');
        break;

      case VoiceCommandType.whereAmI:
        _ref.read(navigationStateProvider.notifier).announceCurrentLocation();
        break;

      case VoiceCommandType.help:
        speakHelp();
        break;

      case VoiceCommandType.unknown:
        if (state.aiResponse.isNotEmpty) {
          _ref.read(ttsStateProvider.notifier).speak(state.aiResponse);
        } else {
          _ref.read(ttsStateProvider.notifier).speak(
            "I heard: ${cmd.rawText}. You can say open currency, detect objects, read text, where am I, what time is it, or go home.",
          );
        }
        break;
    }
  }

  void _globalNavigate(Widget screen, String screenKey, String announcement) {
    if (state.currentScreen == screenKey) {
      HapticFeedback.lightImpact();
      _ref.read(ttsStateProvider.notifier).speak('You are already in $announcement.');
      return;
    }

    _ref.read(ttsStateProvider.notifier).stop();
    HapticFeedback.heavyImpact();
    state = state.copyWith(currentScreen: screenKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = appNavigatorKey.currentState;
      if (nav != null) {
        final Future<dynamic> routeFuture;
        if (nav.canPop()) {
          // Atomic screen swap: replaces current feature screen with new feature screen!
          routeFuture = nav.pushReplacement(MaterialPageRoute(builder: (_) => screen));
        } else {
          routeFuture = nav.push(MaterialPageRoute(builder: (_) => screen));
        }
        routeFuture.then((_) {
          if (!(appNavigatorKey.currentState?.canPop() ?? false)) {
            setCurrentScreen('home');
          }
        });
      }
    });
  }

  void _globalGoHome() {
    if (state.currentScreen == 'home') {
      _ref.read(ttsStateProvider.notifier).speak('You are already on the home screen.');
      return;
    }

    _ref.read(ttsStateProvider.notifier).stop();
    HapticFeedback.heavyImpact();
    state = state.copyWith(currentScreen: 'home');
    _ref.read(ttsStateProvider.notifier).speak('Going to Home Screen', interrupt: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = appNavigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    });
  }

  /// Starts continuous listening on app launch (after permissions are granted)
  Future<void> startContinuousListening() async {
    await _voiceService.enableContinuousListening();
    state = state.copyWith(isAvailable: _voiceService.isInitialized);
  }

  /// Manual tap to force listen immediately with sound and haptics
  Future<void> startListening() async {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    state = state.copyWith(status: 'Listening...');
    await _voiceService.startListening();
    state = state.copyWith(isAvailable: _voiceService.isInitialized);
  }

  /// Stops listening
  Future<void> stopListening() async {
    HapticFeedback.mediumImpact();
    await _voiceService.stopListening();
  }

  /// Toggles speech listening
  Future<void> toggleListening() async {
    if (state.isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Speak help commands aloud
  Future<void> speakHelp() async {
    _ref.read(ttsStateProvider.notifier).speak(
      "You can say: Open object detection, Open currency, Read text, Navigate, Where am I, What time is it, What is today's date, or Go home.",
    );
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _wordsSub?.cancel();
    _cmdSub?.cancel();
    super.dispose();
  }
}

final voiceAssistantStateProvider =
    StateNotifierProvider<VoiceAssistantNotifier, VoiceAssistantState>((ref) {
  return VoiceAssistantNotifier(
    ref.read(voiceAssistantServiceProvider),
    ref.read(geminiAssistantServiceProvider),
    ref,
  );
});

final voiceCommandStreamProvider = StreamProvider<VoiceCommand>((ref) {
  final service = ref.watch(voiceAssistantServiceProvider);
  return service.commandStream;
});
