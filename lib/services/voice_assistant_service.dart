import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

enum VoiceCommandType {
  openCurrency,
  openReadText,
  openObjectDetection,
  openNavigation,
  whereAmI,
  switchCamera,
  describeScene,
  goHome,
  wakeWordPrompt,
  stopSpeaking,
  tellTime,
  tellDate,
  tellStatus,
  help,
  unknown
}

class VoiceCommand {
  final VoiceCommandType type;
  final String rawText;
  final String? argument;

  const VoiceCommand({
    required this.type,
    required this.rawText,
    this.argument,
  });

  @override
  String toString() => 'VoiceCommand(type: $type, raw: "$rawText", arg: "$argument")';
}

/// Robust speech recognition service with continuous "Hey Echo" wake-word listening.
/// Runs non-stop in the background like "OK Google", allowing barge-in across all app features.
class VoiceAssistantService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _continuousMode = true;
  DateTime? _lastCommandExecutedTime;
  String? _cachedLocaleId;

  // Liveness watchdog and continuous restart timers
  Timer? _livenessWatchdog;
  Timer? _restartTimer;
  Timer? _wakeWordDebounceTimer;
  bool _isRestarting = false;

  // Acoustic echo tracking
  String? _lastTtsPhrase;
  DateTime? _lastTtsTime;
  bool _isPausedForTts = false;
  Timer? _ttsPauseSafetyTimer;

  // Active wake-word conversational window (e.g. after "Hey Echo" or mic button tap)
  DateTime? _wakeWordActiveUntil;

  static final RegExp _wakeWordPattern = RegExp(
    r'\b(hey echo|ok echo|okay echo|hi echo|hello echo|hey eco|ok eco|hi eco|hey eko|ok eko|hi eko|hey iko|eko|eco|ekho|aiko|he echo|hay echo|ok google|hey google|echo|ego|hey ego|akko|hey akko|aako|hey aako|heko|gecko|deco|niko|reco)\b',
    caseSensitive: false,
  );

  final StreamController<bool> _listeningStatusController = StreamController<bool>.broadcast();
  final StreamController<String> _partialWordsController = StreamController<String>.broadcast();
  final StreamController<VoiceCommand> _commandController = StreamController<VoiceCommand>.broadcast();

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get continuousMode => _continuousMode;
  Stream<bool> get listeningStatusStream => _listeningStatusController.stream;
  Stream<String> get partialWordsStream => _partialWordsController.stream;
  Stream<VoiceCommand> get commandStream => _commandController.stream;

  VoiceAssistantService();

  /// Initializes the speech engine and caches the optimal locale
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech
          .initialize(
            onStatus: (status) {
              debugPrint('SpeechToText status: $status');
              if (status == 'listening') {
                _isListening = true;
                _listeningStatusController.add(true);
              } else if (status == 'notListening') {
                _isListening = false;
                _listeningStatusController.add(false);
              } else if (status == 'done') {
                _isListening = false;
                _listeningStatusController.add(false);
                // Wait 650ms so Android's delayed onError (~410ms after done) arrives first
                // without triggering overlapping listen() calls.
                if (!_isPausedForTts) {
                  _restartContinuousListeningIfNeeded(delayMs: 650);
                }
              }
            },
            onError: (SpeechRecognitionError error) {
              debugPrint('SpeechToText error: ${error.errorMsg}');
              _isListening = false;
              _listeningStatusController.add(false);
              if (!_isPausedForTts) {
                final isNativeBusy =
                    error.errorMsg == 'error_busy' || error.errorMsg == 'error_client';
                _restartContinuousListeningIfNeeded(
                  delayMs: isNativeBusy ? 1000 : 600,
                  forceDelay: true,
                );
              }
            },
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (_isInitialized) {
        try {
          final locales = await _speech.locales().timeout(const Duration(seconds: 2));
          for (var loc in locales) {
            if (loc.localeId == 'en_IN' || loc.localeId.startsWith('en_IN')) {
              _cachedLocaleId = loc.localeId;
              break;
            }
          }
        } catch (_) {}
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing SpeechToText: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Watchdog timer that runs periodically to guarantee continuous listening never halts
  void _startLivenessWatchdog() {
    _livenessWatchdog?.cancel();
    _livenessWatchdog = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_continuousMode && !_isPausedForTts && !_speech.isListening && !_isRestarting) {
        debugPrint('Voice watchdog: Recognizer idle. Re-arming continuous listening...');
        _restartContinuousListeningIfNeeded(delayMs: 350);
      }
    });
  }

  /// Smoothly restarts speech listening without overloading the native Android recognizer
  void _restartContinuousListeningIfNeeded({int delayMs = 500, bool forceDelay = false}) {
    if (!_continuousMode || _isPausedForTts) return;
    if (_isRestarting && !forceDelay) return;

    _isRestarting = true;
    _restartTimer?.cancel();

    _restartTimer = Timer(Duration(milliseconds: delayMs), () async {
      _isRestarting = false;
      if (_continuousMode && !_isPausedForTts && !_speech.isListening) {
        await startListening(userInitiated: false);
      }
    });
  }

  /// Informs the assistant of TTS output for acoustic echo filtering
  void notifyTtsSpeaking(bool isSpeaking, String? phrase) {
    if (isSpeaking && phrase != null && phrase.trim().isNotEmpty) {
      _lastTtsPhrase = phrase.toLowerCase().trim();
      _lastTtsTime = DateTime.now();
    }
  }

  void pauseForTts() {
    // Physically pause the microphone to prevent Android SpeechRecognizer error_busy crashes
    // due to audio focus collisions or acoustic feedback loops during TTS playback.
    _isPausedForTts = true;
    _isRestarting = false;
    _livenessWatchdog?.cancel();
    _restartTimer?.cancel();
    _ttsPauseSafetyTimer?.cancel();
    _ttsPauseSafetyTimer = Timer(const Duration(seconds: 4), () {
      if (_isPausedForTts) {
        debugPrint('TTS pause safety timer expired; resuming voice assistant mic.');
        resumeAfterTts();
      }
    });
    try {
      if (_speech.isListening) {
        _speech.stop();
      }
    } catch (_) {}
  }

  void resumeAfterTts() {
    _ttsPauseSafetyTimer?.cancel();
    _isPausedForTts = false;
    if (_continuousMode) {
      _startLivenessWatchdog();
      if (!_speech.isListening) {
        _restartContinuousListeningIfNeeded(delayMs: 300, forceDelay: true);
      }
    }
  }

  /// Checks if recognized speech is merely an echo of recent TTS output
  bool _isAcousticEcho(String words) {
    if (_lastTtsPhrase == null || _lastTtsTime == null) return false;
    if (DateTime.now().difference(_lastTtsTime!).inSeconds > 4) return false;

    final clean = words.toLowerCase().trim();
    if (clean.isEmpty) return true;
    // If the words contain an actionable command keyword, do NOT consider it an echo (user barge-in!)
    final hasCommandKeyword = RegExp(
      r'\b(echo|currency|money|rupee|read|text|object|detect|navigate|map|where|camera|home|back|help|stop|quiet|shut|silence|cancel)\b',
    ).hasMatch(clean);

    if (hasCommandKeyword) return false;

    if (_lastTtsPhrase!.contains(clean) || clean.contains(_lastTtsPhrase!)) {
      return true;
    }
    return false;
  }

  /// Starts listening for voice commands
  Future<void> startListening({
    Duration timeout = const Duration(seconds: 30),
    bool userInitiated = true,
  }) async {
    if (!userInitiated && _isPausedForTts) return;

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (userInitiated) {
      _isPausedForTts = false;
      _ttsPauseSafetyTimer?.cancel();
      _wakeWordActiveUntil = DateTime.now().add(const Duration(seconds: 20));
      SystemSound.play(SystemSoundType.click);
    }

    if (_speech.isListening) {
      _isListening = true;
      _listeningStatusController.add(true);
      return;
    }

    try {
      _isListening = true;
      _listeningStatusController.add(true);

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _partialWordsController.add(words);
          }

          // Ignore speaker acoustic echo
          if (_isAcousticEcho(words)) {
            return;
          }

          final now = DateTime.now();
          final isDebounced = _lastCommandExecutedTime == null ||
              now.difference(_lastCommandExecutedTime!).inMilliseconds > 800;

          if (!isDebounced) return;

          final cmd = parseCommand(words);
          final hasWakeWord = _wakeWordPattern.hasMatch(words.toLowerCase());
          final isWakeActive = hasWakeWord ||
              (_wakeWordActiveUntil != null && now.isBefore(_wakeWordActiveUntil!));

          // If wake word was heard, prime the follow-up window for 20 seconds
          if (hasWakeWord) {
            _wakeWordActiveUntil = now.add(const Duration(seconds: 20));
          }

          // Cancel previous debounce timer on ANY new speech activity
          _wakeWordDebounceTimer?.cancel();

          // Case 0: User said ONLY "Hey Echo" / "Echo" -> Wait for final result OR a 550ms pause before answering!
          if (cmd.type == VoiceCommandType.wakeWordPrompt) {
            if (result.finalResult) {
              _wakeWordActiveUntil = now.add(const Duration(seconds: 20));
              _dispatchCommand(cmd);
            } else {
              _wakeWordDebounceTimer = Timer(const Duration(milliseconds: 550), () {
                _wakeWordActiveUntil = DateTime.now().add(const Duration(seconds: 20));
                _dispatchCommand(cmd);
              });
            }
            return;
          }

          // Case 1: Actionable command (e.g. "open currency", "open object detection", "go home", "tell time", etc.)
          // Execute immediately whether spoken with "Hey Echo"/"Echo" or spoken directly!
          if (cmd.type != VoiceCommandType.unknown) {
            _wakeWordDebounceTimer?.cancel();
            _wakeWordActiveUntil = now.add(const Duration(seconds: 15));
            _dispatchCommand(cmd);
            return;
          }

          // Case 2: User said "Hey Echo" + conversational question, or tapped mic button
          if (result.finalResult && isWakeActive) {
            _wakeWordActiveUntil = now.add(const Duration(seconds: 15));
            if (words.isNotEmpty) {
              _dispatchCommand(VoiceCommand(type: VoiceCommandType.unknown, rawText: words));
            }
          }
        },
        // ignore: deprecated_member_use
        listenFor: timeout,
        // ignore: deprecated_member_use
        pauseFor: const Duration(seconds: 6),
        // ignore: deprecated_member_use
        localeId: _cachedLocaleId,
        // ignore: deprecated_member_use
        cancelOnError: false,
        // ignore: deprecated_member_use
        partialResults: true,
      );
    } catch (e) {
      debugPrint('Error starting listening: $e');
      _isListening = false;
      _listeningStatusController.add(false);
      _restartContinuousListeningIfNeeded(delayMs: 700, forceDelay: true);
    }
  }

  void _dispatchCommand(VoiceCommand cmd) {
    _lastCommandExecutedTime = DateTime.now();
    _commandController.add(cmd);
    try {
      _speech.stop();
    } catch (_) {}
    _isListening = false;
    _listeningStatusController.add(false);
    _partialWordsController.add('');
  }

  /// Stops speech listening
  Future<void> stopListening() async {
    _continuousMode = false;
    _restartTimer?.cancel();
    _ttsPauseSafetyTimer?.cancel();
    try {
      await _speech.cancel();
    } catch (_) {}
    _isListening = false;
    _listeningStatusController.add(false);
  }

  /// Enables continuous listening mode
  Future<void> enableContinuousListening() async {
    _continuousMode = true;
    final ok = await initialize();
    if (!ok) return;
    _startLivenessWatchdog();
    if (!_isPausedForTts && !_speech.isListening) {
      await startListening(userInitiated: false);
    }
  }

  /// Parses spoken text into a clean VoiceCommand
  VoiceCommand parseCommand(String input) {
    String clean = input.toLowerCase().trim();
    clean = clean.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (clean.isEmpty) {
      return VoiceCommand(type: VoiceCommandType.unknown, rawText: input);
    }

    final hasWakeWord = _wakeWordPattern.hasMatch(clean);

    // Strip wake word for command analysis
    String withoutWake = clean.replaceAll(_wakeWordPattern, '').trim();

    // If user literally said ONLY the wake word
    if (hasWakeWord && withoutWake.isEmpty) {
      return VoiceCommand(type: VoiceCommandType.wakeWordPrompt, rawText: input);
    }

    // Work with text with or without wake word
    final target = withoutWake.isNotEmpty ? withoutWake : clean;

    // Strip conversational polite prefixes and fillers to match Google Assistant natural phrasing
    String naturalTarget = target
        .replaceAll(RegExp(r'\b(can you please|could you please|please can you|please|can you|could you|would you|will you|i want to|i want you to|help me|tell me|show me)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (naturalTarget.isEmpty) naturalTarget = target;

    // 0. STOP SPEAKING / MUTE
    if (_containsAny(target, [
          'stop talking', 'shut up', 'quiet', 'be quiet', 'silence', 'mute', 'pause speaking', 'stop speak', 'stop audio'
        ]) ||
        _containsAny(naturalTarget, [
          'stop talking', 'shut up', 'quiet', 'be quiet', 'silence', 'mute', 'pause speaking', 'stop speak', 'stop audio'
        ])) {
      return VoiceCommand(type: VoiceCommandType.stopSpeaking, rawText: input);
    }

    // Direct standalone "stop" command
    if (naturalTarget == 'stop' || target == 'stop') {
      return VoiceCommand(type: VoiceCommandType.stopSpeaking, rawText: input);
    }

    // 1. CURRENCY DETECTION
    final currencyKeywords = [
      'currency', 'money', 'rupee', 'rupees', 'cash', 'banknote', 'banknotes',
      'bank note', 'bank notes', 'note', 'notes', 'bill', 'bills', 'wallet',
      'count money', 'count cash', 'counting', 'count notes', 'how much money',
      'how much cash', 'how many rupees', 'check money', 'check cash', 'check note',
      'check currency', 'pay', 'payment', '500', '200', '100', '50', '20', '10',
      'five hundred', 'two hundred', 'one hundred', 'fifty', 'twenty', 'ten',
      'show money', 'show currency', 'detect currency', 'open currency', 'start currency', 'currency mode'
    ];
    if (_containsAny(target, currencyKeywords) || _containsAny(naturalTarget, currencyKeywords)) {
      return VoiceCommand(type: VoiceCommandType.openCurrency, rawText: input);
    }

    // 2. READ TEXT / OCR
    final readKeywords = [
      'read text', 'reading', 'read', 'reader', 'ocr', 'text', 'document', 'documents',
      'book', 'books', 'words', 'word', 'page', 'pages', 'paper', 'papers',
      'letter', 'letters', 'sign', 'signs', 'signboard', 'signboards', 'board', 'boards',
      'receipt', 'receipts', 'menu', 'menus', 'scan text', 'what is written',
      'what does it say', 'what does this say', 'read this', 'read out', 'start reading',
      'open read', 'open reading', 'text reader', 'read mode'
    ];
    if (_containsAny(target, readKeywords) || _containsAny(naturalTarget, readKeywords)) {
      return VoiceCommand(type: VoiceCommandType.openReadText, rawText: input);
    }

    // 3. MULTIMODAL SCENE INQUIRY ("What am I looking at?", "What is this?")
    final sceneKeywords = [
      'what am i looking at', 'what is this', 'what is in front of me', "what's in front of me",
      'describe what you see', 'describe the scene', 'describe scene', 'describe',
      'describe the room', 'describe room', 'what do you see', 'look around',
      'what am i seeing', 'tell me what you see', 'look and tell', 'what is that',
      'what is ahead', "what's ahead", 'look in front', 'see around'
    ];
    if (_containsAny(target, sceneKeywords) || _containsAny(naturalTarget, sceneKeywords)) {
      return VoiceCommand(type: VoiceCommandType.describeScene, rawText: input);
    }

    // 4. OBJECT DETECTION
    final objectKeywords = [
      'object', 'objects', 'detect', 'detecting', 'detection', 'detector',
      'obstacle', 'obstacles', 'barrier', 'barriers', 'hurdle', 'hurdles',
      'what objects', 'see objects', 'identify object', 'recognize object',
      'object detection', 'find objects', 'detect obstacles', 'is there anything',
      'is anything in front', 'open object', 'open objects', 'start detection',
      'detect items', 'detect things', 'what is around me', 'surroundings', 'detect mode'
    ];
    if (_containsAny(target, objectKeywords) || _containsAny(naturalTarget, objectKeywords)) {
      return VoiceCommand(type: VoiceCommandType.openObjectDetection, rawText: input);
    }

    // 5. NAVIGATION & MAPS (Supports destination extraction)
    final navPrefixPattern = RegExp(
        r'^(navigate to|take me to|go to|walk to|directions to|route to|lead me to|guide me to|how to get to|where is)\s*');
    if (navPrefixPattern.hasMatch(target) || navPrefixPattern.hasMatch(naturalTarget)) {
      final effectiveStr = navPrefixPattern.hasMatch(naturalTarget) ? naturalTarget : target;
      final dest = effectiveStr.replaceFirst(navPrefixPattern, '').trim();
      return VoiceCommand(
        type: VoiceCommandType.openNavigation,
        rawText: input,
        argument: dest.isNotEmpty ? dest : null,
      );
    }

    final navKeywords = [
      'navigation', 'navigate', 'map', 'maps', 'directions', 'direction',
      'route', 'routes', 'take me', 'find way', 'walking directions', 'walking route',
      'open navigation', 'open map', 'start navigation', 'guide me', 'navigation mode'
    ];
    if (_containsAny(target, navKeywords) || _containsAny(naturalTarget, navKeywords)) {
      return VoiceCommand(type: VoiceCommandType.openNavigation, rawText: input);
    }

    // 6. WHERE AM I / LOCATION
    final locationKeywords = [
      'where am i', 'where are we', 'where am i right now', 'my location',
      'current location', 'what street', 'which street', 'where i am', 'address',
      'my address', 'gps', 'what is my location'
    ];
    if (_containsAny(target, locationKeywords) || _containsAny(naturalTarget, locationKeywords)) {
      return VoiceCommand(type: VoiceCommandType.whereAmI, rawText: input);
    }

    // 7. TELL TIME
    final timeKeywords = [
      'time', 'what time is it', "what's the time", 'tell me time', 'tell time',
      'current time', 'what time', 'clock', 'what is the time'
    ];
    if (_containsAny(target, timeKeywords) || _containsAny(naturalTarget, timeKeywords)) {
      return VoiceCommand(type: VoiceCommandType.tellTime, rawText: input);
    }

    // 8. TELL DATE
    final dateKeywords = [
      'date', 'what is today', "what's today", 'what day is today', 'what day is it',
      'today date', "today's date", 'what is the date', "what's the date", 'current date'
    ];
    if (_containsAny(target, dateKeywords) || _containsAny(naturalTarget, dateKeywords)) {
      return VoiceCommand(type: VoiceCommandType.tellDate, rawText: input);
    }

    // 9. APP STATUS / CURRENT MODE
    final statusKeywords = [
      'status', 'app status', 'current mode', 'what mode', 'where am i in the app',
      'which screen', 'what screen', 'current screen'
    ];
    if (_containsAny(target, statusKeywords) || _containsAny(naturalTarget, statusKeywords)) {
      return VoiceCommand(type: VoiceCommandType.tellStatus, rawText: input);
    }

    // 10. CAMERA SWITCH (IMX378 Smart Glasses vs Phone Camera)
    final cameraKeywords = [
      'switch camera', 'change camera', 'toggle camera', 'smart glasses',
      'glasses camera', 'phone camera', 'switch to glasses', 'switch to phone',
      'flip camera', 'use glasses', 'use phone'
    ];
    if (_containsAny(target, cameraKeywords) || _containsAny(naturalTarget, cameraKeywords)) {
      return VoiceCommand(type: VoiceCommandType.switchCamera, rawText: input);
    }

    // 11. GO HOME / EXIT
    final homeKeywords = [
      'go home', 'home screen', 'home', 'main menu', 'menu', 'go back', 'back', 'exit', 'close', 'quit', 'return'
    ];
    if (_containsAny(target, homeKeywords) || _containsAny(naturalTarget, homeKeywords)) {
      return VoiceCommand(type: VoiceCommandType.goHome, rawText: input);
    }

    // 12. HELP
    final helpKeywords = [
      'help', 'what can you do', 'commands', 'instructions', 'how to use', 'who are you'
    ];
    if (_containsAny(target, helpKeywords) || _containsAny(naturalTarget, helpKeywords)) {
      return VoiceCommand(type: VoiceCommandType.help, rawText: input);
    }

    return VoiceCommand(type: VoiceCommandType.unknown, rawText: input);
  }

  bool _containsAny(String input, List<String> patterns) {
    for (var p in patterns) {
      if (p.isEmpty) continue;
      // Word boundary matching prevents substring false positives (e.g. 'already' matching 'read', 'background' matching 'back')
      final reg = RegExp(r'\b' + RegExp.escape(p) + r'\b', caseSensitive: false);
      if (reg.hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _livenessWatchdog?.cancel();
    _restartTimer?.cancel();
    _wakeWordDebounceTimer?.cancel();
    stopListening();
    _listeningStatusController.close();
    _partialWordsController.close();
    _commandController.close();
  }
}
