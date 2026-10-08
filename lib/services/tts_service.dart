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
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);

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
        _isSpeaking = false;
        _speakingStateController.add(false);
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

  Future<void> speak(String text, {TTSPriority priority = TTSPriority.normal, bool interrupt = false}) async {
    try {
      if (text.isEmpty) return;

      if (interrupt || priority == TTSPriority.critical) {
        _queue.clear();
        await _tts.stop();
        // Give native Android TTS engine a tiny moment to process the stop and fire CancelHandler
        await Future.delayed(const Duration(milliseconds: 50));
        
        _isSpeaking = true;
        _speakingStateController.add(true);
        _armWatchdog(text);
        await _tts.speak(text);
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
      final item = _queue.removeFirst();
      _isSpeaking = true;
      _speakingStateController.add(true);
      _armWatchdog(item.text);
      await _tts.speak(item.text);
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
