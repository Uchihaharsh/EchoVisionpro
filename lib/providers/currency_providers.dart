import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/services/currency_service.dart';
import 'package:smart_glasses/providers/tts_providers.dart';

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
  final Ref _ref;

  CurrencyStateNotifier(this._currencyService, this._ref) : super(CurrencyState());

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

  /// Processes raw JPEG bytes (from IMX378 USB Camera or snapshot)
  Future<void> processImageBytes(Uint8List jpegBytes) async {
    if (!_isScanning) return;

    try {
      final result = await _currencyService.classifyImageBytes(jpegBytes);
      if (!_isScanning) return;
      
      if (result != null && result.isConfident) {
        final label = result.denomination;

        if (state.lastResult != label) {
          state = state.copyWith(lastResult: label);
          _ref.read(ttsStateProvider.notifier).speak(result.toSpeechText());
        }
      }
    } catch (e) {
      if (_isScanning) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  /// Processes frame for currency
  Future<void> processFrame(dynamic frameData) async {
    if (!_isScanning || !state.isModelLoaded) return;
    
    state = state.copyWith(isClassifying: true);

    try {
      final result = await _currencyService.classifyCurrency(frameData);
      if (!_isScanning) return;
      
      if (result != null && result.isConfident) {
        final label = result.denomination;

        if (state.lastResult != label) {
          state = state.copyWith(lastResult: label);
          _ref.read(ttsStateProvider.notifier).speak(result.toSpeechText());
        }
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
  }
}

/// Provider exposing currency state notifier
final currencyStateProvider = StateNotifierProvider<CurrencyStateNotifier, CurrencyState>((ref) {
  return CurrencyStateNotifier(
    ref.read(currencyServiceProvider),
    ref,
  );
});
