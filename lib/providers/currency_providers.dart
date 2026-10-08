import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/services/currency_service.dart';

/// Provider for CurrencyService
final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService();
});

/// State for Currency Classification
class CurrencyState {
  final bool isClassifying;
  final String? lastResult;
  final bool isModelLoaded;
  final String? error;

  CurrencyState({
    this.isClassifying = false,
    this.lastResult,
    this.isModelLoaded = false,
    this.error,
  });

  String? get detectedCurrency => lastResult;
  String? get denomination => lastResult;
  double get confidence => lastResult != null ? 0.95 : 0.0;
  String get announcement => lastResult != null ? 'Detected $lastResult note' : '';

  CurrencyState copyWith({
    bool? isClassifying,
    String? lastResult,
    bool? isModelLoaded,
    String? error,
  }) {
    return CurrencyState(
      isClassifying: isClassifying ?? this.isClassifying,
      lastResult: lastResult ?? this.lastResult,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      error: error ?? this.error,
    );
  }
}

/// StateNotifier for Currency logic
class CurrencyStateNotifier extends StateNotifier<CurrencyState> {
  final CurrencyService _currencyService;

  CurrencyStateNotifier(this._currencyService) : super(CurrencyState());

  /// Initializes currency model
  Future<void> initialize() async {
    try {
      await _currencyService.initialize();
      state = state.copyWith(isModelLoaded: true);
    } catch (e) {
      state = state.copyWith(isModelLoaded: false, error: e.toString());
    }
  }

  /// Alias method for initializing
  Future<void> initializeCurrency() => initialize();

  bool _isScanning = false;

  /// Starts scanning
  void startScanning() {
    _isScanning = true;
    state = state.copyWith(isClassifying: true);
  }

  /// Stops scanning
  void stopScanning() {
    _isScanning = false;
    state = state.copyWith(isClassifying: false);
  }

  /// Processes raw JPEG bytes.
  /// Returns the detected denomination string (e.g. "500") or null if none found.
  /// The CALLER (screen) is responsible for announcing via TTS.
  Future<String?> processImageBytes(Uint8List jpegBytes) async {
    if (!_isScanning) return null;
    try {
      final result = await _currencyService.classifyImageBytes(jpegBytes);
      if (!_isScanning) return null;
      if (result != null && result.isConfident) {
        final label = result.denomination;
        state = state.copyWith(lastResult: label);
        return label;
      }
    } catch (e) {
      if (_isScanning) {
        state = state.copyWith(error: e.toString());
      }
    }
    return null;
  }

  /// Processes a camera frame for currency.
  /// Returns the detected denomination string or null.
  Future<String?> processFrame(dynamic frameData) async {
    if (!_isScanning || !state.isModelLoaded || state.isClassifying) return null;
    state = state.copyWith(isClassifying: true);
    try {
      final result = await _currencyService.classifyCurrency(frameData);
      if (!_isScanning) return null;
      if (result != null && result.isConfident) {
        final label = result.denomination;
        state = state.copyWith(lastResult: label);
        return label;
      }
    } catch (e) {
      if (_isScanning) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      if (_isScanning) {
        state = state.copyWith(isClassifying: false);
      }
    }
    return null;
  }
}

/// Provider exposing currency state notifier
final currencyStateProvider = StateNotifierProvider<CurrencyStateNotifier, CurrencyState>((ref) {
  return CurrencyStateNotifier(ref.read(currencyServiceProvider));
});
