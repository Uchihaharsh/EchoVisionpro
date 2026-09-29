import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/services/tflite_service.dart';
import 'package:smart_glasses/services/object_detection_service.dart';
import 'package:smart_glasses/providers/tts_providers.dart';
import 'package:smart_glasses/providers/camera_providers.dart';

/// Provider for TFLiteService singleton
final tfliteServiceProvider = Provider<TFLiteService>((ref) {
  final service = TFLiteService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for ObjectDetectionService
final objectDetectionServiceProvider = Provider<ObjectDetectionService>((ref) {
  return ObjectDetectionService();
});

/// State for Detection
class DetectionState {
  final bool isDetecting;
  final List<dynamic> results;
  final bool isModelLoaded;

  DetectionState({
    this.isDetecting = false,
    this.results = const [],
    this.isModelLoaded = false,
  });

  List<dynamic> get objects => results;
  String get announcement => results.isNotEmpty ? results.first.toString() : '';

  DetectionState copyWith({
    bool? isDetecting,
    List<dynamic>? results,
    bool? isModelLoaded,
  }) {
    return DetectionState(
      isDetecting: isDetecting ?? this.isDetecting,
      results: results ?? this.results,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
    );
  }
}

/// StateNotifier for Detection logic
class DetectionStateNotifier extends StateNotifier<DetectionState> {
  final ObjectDetectionService _detectionService;
  final Ref _ref;
  DateTime? _lastSpeechTime;
  String? _lastSpokenObject;

  DetectionStateNotifier(this._detectionService, this._ref) : super(DetectionState());

  /// Initializes the model
  Future<void> initialize() async {
    try {
      await _detectionService.initialize();
      state = state.copyWith(isModelLoaded: true);
    } catch (e) {
      debugPrint('Model load error: $e');
      state = state.copyWith(isModelLoaded: false);
    }
  }

  /// Starts detection
  void startDetection() {
    state = state.copyWith(isDetecting: true);
    _lastSpeechTime = null;
    _lastSpokenObject = null;
  }

  /// Stops detection
  void stopDetection() {
    state = state.copyWith(isDetecting: false);
  }

  /// Processes raw JPEG bytes (from IMX378 USB Camera or snapshot)
  Future<void> processImageBytes(Uint8List jpegBytes, {bool forceSpeak = false, bool useCloudGemini = false}) async {
    try {
      final results = await _detectionService.processImageBytes(jpegBytes, useCloudGemini: useCloudGemini);
      if (!state.isDetecting && !forceSpeak) return;
      state = state.copyWith(results: results);

      if (results.isNotEmpty) {
        final nearest = results.first;
        final now = DateTime.now();

        final isDifferentObject = _lastSpokenObject != nearest.label;
        final timeSinceLastSpeech = _lastSpeechTime == null
            ? const Duration(seconds: 999)
            : now.difference(_lastSpeechTime!);

        // Anti-recursion rule:
        // Announce immediately if forced (user tapped screen),
        // OR if a different object entered view,
        // OR if at least 10 seconds have passed with the same object.
        // Never announce if TTS is currently speaking!
        final isTtsSpeaking = _ref.read(ttsStateProvider).isSpeaking;

        if (!isTtsSpeaking && (forceSpeak || isDifferentObject || timeSinceLastSpeech.inSeconds >= 10)) {
          _lastSpokenObject = nearest.label;
          _lastSpeechTime = now;
          _ref.read(ttsStateProvider.notifier).speak('${nearest.label} detected');
        }
      } else {
        // When field of view becomes empty, clear last object so reappearance triggers fresh announcement
        _lastSpokenObject = null;
        if (forceSpeak) {
          _ref.read(ttsStateProvider.notifier).speak('No clear object detected.');
        }
      }
    } catch (e) {
      debugPrint('Image bytes detection error: $e');
    }
  }

  DateTime? _lastDetectionTime;
  bool _isProcessingFrame = false;

  /// Processes frame and detects objects
  Future<void> processFrame(dynamic frameData) async {
    if (!state.isDetecting || _isProcessingFrame) return;

    final now = DateTime.now();
    if (_lastDetectionTime != null && now.difference(_lastDetectionTime!).inMilliseconds < 350) {
      return;
    }
    _lastDetectionTime = now;
    _isProcessingFrame = true;

    if (!state.isModelLoaded) {
      await initialize();
      if (!state.isModelLoaded) {
        _isProcessingFrame = false;
        return;
      }
    }

    try {
      final cameraService = _ref.read(cameraServiceProvider);
      final rotation = cameraService.currentSource.sensorOrientation;
      final results = await _detectionService.detectObjects(frameData, 300, 300, rotation: rotation);
      if (!state.isDetecting) return;
      state = state.copyWith(results: results);

      if (results.isNotEmpty) {
        final nearest = results.first;
        final now = DateTime.now();
        final isDifferentObject = _lastSpokenObject != nearest.label;
        final timeSinceLastSpeech = _lastSpeechTime != null
            ? now.difference(_lastSpeechTime!)
            : const Duration(seconds: 999);

        final isTtsSpeaking = _ref.read(ttsStateProvider).isSpeaking;

        if (!isTtsSpeaking && (isDifferentObject || timeSinceLastSpeech.inSeconds >= 8)) {
          _lastSpokenObject = nearest.label;
          _lastSpeechTime = now;
          _ref.read(ttsStateProvider.notifier).speak('${nearest.label} detected');
        }
      } else {
        _lastSpokenObject = null;
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Processes a high-quality focused image file (from snapshot or tap-to-identify)
  Future<void> processImageFile(String filePath, {bool forceSpeak = false}) async {
    try {
      final results = await _detectionService.processImageFile(filePath);
      state = state.copyWith(results: results);

      if (results.isNotEmpty) {
        final nearest = results.first;
        final now = DateTime.now();

        final shouldSpeak = forceSpeak ||
            _lastSpokenObject != nearest.label ||
            _lastSpeechTime == null ||
            now.difference(_lastSpeechTime!).inMilliseconds >= 2000;

        if (shouldSpeak) {
          _lastSpokenObject = nearest.label;
          _lastSpeechTime = now;
          _ref.read(ttsStateProvider.notifier).speak('${nearest.label} detected');
        }
      } else if (forceSpeak) {
        _ref.read(ttsStateProvider.notifier).speak('No objects detected.');
      }
    } catch (e) {
      debugPrint('Image file detection error: $e');
    }
  }
}

/// Provider exposing detection state notifier
final detectionStateProvider = StateNotifierProvider<DetectionStateNotifier, DetectionState>((ref) {
  return DetectionStateNotifier(
    ref.read(objectDetectionServiceProvider),
    ref,
  );
});
