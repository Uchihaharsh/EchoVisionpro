import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TTSPriority {
  low,
  normal,
  high,
  critical
}

class _TTSItem {
  final String text;
  final TTSPriority priority;

  _TTSItem(this.text, this.priority);
}

class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  final Queue<_TTSItem> _queue = Queue<_TTSItem>();
  final StreamController<bool> _speakingStateController = StreamController<bool>.broadcast();
  Timer? _speechWatchdogTimer;

  Stream<bool> get speakingStream => _speakingStateController.stream;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.52).timeout(const Duration(seconds: 2));
      await _tts.setPitch(1.0).timeout(const Duration(seconds: 2));

      _tts.setStartHandler(() {
        _isSpeaking = true;
        _speakingStateController.add(true);
      });

      _tts.setCompletionHandler(() {
        _speechWatchdogTimer?.cancel();
        if (_queue.isEmpty) {
          _isSpeaking = false;
          _speakingStateController.add(false);
        } else {
          _processQueue();
        }
      });

      _tts.setCancelHandler(() {
        _speechWatchdogTimer?.cancel();
        // Since cancel can arrive asynchronously AFTER we already started the next phrase,
        // we DO NOT aggressively set _isSpeaking = false here if we've already bumped the session!
        // We only clear the queue.
        _queue.clear();
      });

      _tts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _speechWatchdogTimer?.cancel();
        _isSpeaking = false;
        _speakingStateController.add(false);
        _processQueue();
      });
    } catch (e) {
      debugPrint('Error initializing TTS Service: $e');
    }
  }

  void _armWatchdog(String text) {
    _speechWatchdogTimer?.cancel();
    final wordCount = text.split(' ').where((w) => w.isNotEmpty).length;
    final timeoutSec = (wordCount * 0.6).ceil() + 3;
    _speechWatchdogTimer = Timer(Duration(seconds: timeoutSec.clamp(2, 10)), () {
      if (_isSpeaking) {
        debugPrint('TTS Watchdog expired after ${timeoutSec}s. Resetting isSpeaking to false.');
        _isSpeaking = false;
        _speakingStateController.add(false);
        if (_queue.isNotEmpty) {
          _processQueue();
        }
      }
    });
  }

  int _ttsSessionId = 0;

  Future<void> speak(String text, {TTSPriority priority = TTSPriority.normal, bool interrupt = false}) async {
    try {
      if (text.isEmpty) return;

      if (interrupt || priority == TTSPriority.critical) {
        _queue.clear();
        _ttsSessionId++;
        final currentSession = _ttsSessionId;
        await _tts.stop();
        
        // Only start if we are still the active session (i.e. another interrupt didn't happen)
        if (_ttsSessionId != currentSession) return;
        
        _isSpeaking = true;
        _speakingStateController.add(true);
        _armWatchdog(text);
        await _tts.speak(text);
        if (_ttsSessionId == currentSession && _isSpeaking) {
          _speechWatchdogTimer?.cancel();
          _isSpeaking = false;
          if (_queue.isEmpty) {
            _speakingStateController.add(false);
          } else {
            _processQueue();
          }
        }
        return;
      }

      final item = _TTSItem(text, priority);

      if (priority == TTSPriority.high) {
        _queue.addFirst(item);
      } else {
        _queue.addLast(item);
      }

      if (!_isSpeaking) {
        _processQueue();
      }
    } catch (e) {
      debugPrint('Error during TTS speak: $e');
    }
  }

  Future<void> stop() async {
    try {
      _ttsSessionId++;
      _speechWatchdogTimer?.cancel();
      _queue.clear();
      await _tts.stop();
      _isSpeaking = false;
      _speakingStateController.add(false);
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty || _isSpeaking) {
      return;
    }

    try {
      _ttsSessionId++;
      final currentSession = _ttsSessionId;
      final item = _queue.removeFirst();
      _isSpeaking = true;
      _speakingStateController.add(true);
      _armWatchdog(item.text);
      await _tts.speak(item.text);
      if (_ttsSessionId == currentSession && _isSpeaking) {
        _speechWatchdogTimer?.cancel();
        _isSpeaking = false;
        if (_queue.isEmpty) {
          _speakingStateController.add(false);
        } else {
          _processQueue();
        }
      }
    } catch (e) {
      debugPrint('Error processing TTS queue: $e');
      _speechWatchdogTimer?.cancel();
      _isSpeaking = false;
      _speakingStateController.add(false);
      _processQueue();
    }
  }

  Future<void> setLanguage(String lang) async {
    try {
      await _tts.setLanguage(lang);
    } catch (e) {
      debugPrint('Error setting language $lang: $e');
    }
  }

  Future<void> setSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('Error setting speech rate: $e');
    }
  }

  Future<void> dispose() async {
    _speechWatchdogTimer?.cancel();
    await stop();
    _speakingStateController.close();
  }
}
