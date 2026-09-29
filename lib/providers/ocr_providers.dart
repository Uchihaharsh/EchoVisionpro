import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/services/ocr_service.dart';

/// Provider for OcrService
final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

/// State for OCR
class OcrState {
  final bool isScanning;
  final String? lastResult;
  final bool continuousMode;
  final String? error;

  OcrState({
    this.isScanning = false,
    this.lastResult,
    this.continuousMode = false,
    this.error,
  });

  String? get recognizedText => lastResult;

  OcrState copyWith({
    bool? isScanning,
    String? lastResult,
    bool? continuousMode,
    String? error,
  }) {
    return OcrState(
      isScanning: isScanning ?? this.isScanning,
      lastResult: lastResult ?? this.lastResult,
      continuousMode: continuousMode ?? this.continuousMode,
      error: error ?? this.error,
    );
  }
}

/// StateNotifier for OCR logic
class OcrStateNotifier extends StateNotifier<OcrState> {
  final OcrService _ocrService;

  OcrStateNotifier(this._ocrService) : super(OcrState());

  /// Starts scanning
  void startScanning({bool continuous = false}) {
    state = state.copyWith(isScanning: true, lastResult: null, continuousMode: continuous);
  }

  /// Alias for continuous scanning
  void startContinuousScan() => startScanning(continuous: true);

  /// Stops scanning
  void stopScanning() {
    state = state.copyWith(isScanning: false, continuousMode: false);
  }

  /// Alias for stopScanning
  void stopOcr() => stopScanning();

  /// Processes raw JPEG bytes (from IMX378 USB Camera or snapshot)
  Future<void> processImageBytes(Uint8List jpegBytes) async {
    if (!state.isScanning) return;

    try {
      final result = await _ocrService.processImageBytes(jpegBytes);
      if (!state.isScanning) return;
      
      if (result != null && result.hasText) {
        final text = result.fullText.trim();
        if (text.isNotEmpty && state.lastResult != text) {
          state = state.copyWith(
            lastResult: text,
            isScanning: state.continuousMode,
          );
        }
      }
    } catch (e) {
      if (state.isScanning) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  /// Processes a single frame for text detection
  Future<void> processFrame(dynamic frameData) async {
    if (!state.isScanning) return;

    try {
      final result = await _ocrService.processFrame(frameData);
      if (!state.isScanning) return;
      
      if (result != null && result.hasText) {
        final text = result.fullText.trim();
        if (text.isNotEmpty && state.lastResult != text) {
          state = state.copyWith(
            lastResult: text,
            isScanning: state.continuousMode,
          );
        }
      }
    } catch (e) {
      if (state.isScanning) {
        state = state.copyWith(error: e.toString());
      }
    }
  }
}

/// Provider exposing OCR state notifier
final ocrStateProvider = StateNotifierProvider<OcrStateNotifier, OcrState>((ref) {
  return OcrStateNotifier(ref.read(ocrServiceProvider));
});
