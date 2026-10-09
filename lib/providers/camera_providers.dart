import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ffi_uvc/flutter_ffi_uvc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/services/camera_service.dart';
import 'package:smart_glasses/providers/tts_providers.dart';

/// Provider for the CameraService singleton
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// State for camera management
class CameraState {
  final bool isInitialized;
  final bool isStreaming;
  final String? errorMessage;
  final CameraController? controller;
  final int? textureId;
  final bool isUsbCamera;
  final String cameraName;
  final double aspectRatio;

  CameraState({
    this.isInitialized = false,
    this.isStreaming = false,
    this.errorMessage,
    this.controller,
    this.textureId,
    this.isUsbCamera = false,
    this.cameraName = 'Phone Camera',
    this.aspectRatio = 16 / 9,
  });

  CameraState copyWith({
    bool? isInitialized,
    bool? isStreaming,
    String? errorMessage,
    CameraController? controller,
    bool clearController = false,
    int? textureId,
    bool clearTextureId = false,
    bool? isUsbCamera,
    String? cameraName,
    double? aspectRatio,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: errorMessage,
      controller: clearController ? null : (controller ?? this.controller),
      textureId: clearTextureId ? null : (textureId ?? this.textureId),
      isUsbCamera: isUsbCamera ?? this.isUsbCamera,
      cameraName: cameraName ?? this.cameraName,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}

/// StateNotifier for handling camera state transitions and automatic USB hot-plugging
class CameraStateNotifier extends StateNotifier<CameraState> {
  final CameraService _cameraService;
  final Ref _ref;
  StreamSubscription<UvcDeviceEvent>? _usbEventSub;
  Timer? _usbPollTimer;
  DateTime? _lastUsbAttemptTime;
  bool _isBusy = false;

  CameraStateNotifier(this._cameraService, this._ref) : super(CameraState());

  void _syncStateFromSource({String? error}) {
    final source = _cameraService.currentSource;
    state = CameraState(
      isInitialized: source.isInitialized,
      isStreaming: source.isInitialized,
      errorMessage: error,
      controller: source.isUsbCamera ? null : source.controller,
      textureId: source.isUsbCamera ? source.textureId : null,
      isUsbCamera: source.isUsbCamera,
      cameraName: source.name,
      aspectRatio: source.aspectRatio,
    );
  }

  void _startUsbHotplugMonitor() {
    _usbEventSub ??= _cameraService.usbDeviceEvents.listen((event) async {
      debugPrint('USB Device Event: ${event.type} (${event.device.productName})');
      if (event.type == UvcDeviceEventType.attached && !state.isUsbCamera) {
        _lastUsbAttemptTime = null;
        await _autoSwitchToUsb();
      } else if (event.type == UvcDeviceEventType.detached && state.isUsbCamera) {
        await _autoSwitchToPhone();
      }
    });

    _usbPollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isBusy || !state.isInitialized) return;
      final hasUsb = await _cameraService.hasUsbCameraAttached();
      if (hasUsb && !state.isUsbCamera) {
        final now = DateTime.now();
        if (_lastUsbAttemptTime == null ||
            now.difference(_lastUsbAttemptTime!).inSeconds >= 8) {
          await _autoSwitchToUsb();
        }
      } else if (!hasUsb && state.isUsbCamera) {
        await _autoSwitchToPhone();
      }
    });
  }

  Future<void> _autoSwitchToUsb() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastUsbAttemptTime = DateTime.now();
    try {
      await _cameraService.switchToUsbCamera();
      _syncStateFromSource();
      _ref.read(ttsStateProvider.notifier).speak('USB Smart Glasses camera connected');
    } catch (e) {
      debugPrint('Auto-switch to USB camera failed: $e');
      _syncStateFromSource(error: e.toString());
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _autoSwitchToPhone() async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      await _cameraService.switchToPhoneCamera();
      _syncStateFromSource();
      _ref.read(ttsStateProvider.notifier).speak('USB camera disconnected, switched to phone camera');
    } catch (e) {
      debugPrint('Auto-switch to Phone camera failed: $e');
      _syncStateFromSource(error: e.toString());
    } finally {
      _isBusy = false;
    }
  }

  /// Initializes the camera service
  Future<void> initialize() async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      await _cameraService.initialize();
      _syncStateFromSource();
      _startUsbHotplugMonitor();
    } catch (e) {
      state = state.copyWith(isInitialized: false, errorMessage: e.toString());
      _startUsbHotplugMonitor();
    } finally {
      _isBusy = false;
    }
  }

  /// Alias for initialize
  Future<void> initializeCamera() => initialize();

  /// Toggles between IMX378 USB Smart Glasses Camera and Built-in Phone Camera
  Future<void> toggleCameraSource() async {
    if (_isBusy) return;
    _isBusy = true;
    _lastUsbAttemptTime = DateTime.now();
    try {
      await _cameraService.toggleCameraSource();
      _syncStateFromSource();
    } catch (e) {
      // Note: CameraService automatically recovers with Phone Camera if USB fails
      _syncStateFromSource(error: e.toString());
    } finally {
      _isBusy = false;
    }
  }

  /// Starts the camera stream
  Future<void> startStream() async {
    if (!state.isInitialized) {
      await initialize();
      return;
    }
    state = state.copyWith(isStreaming: true, errorMessage: null);
  }

  /// Alias for startStream
  Future<void> startCamera() => startStream();

  /// Stops the camera stream
  Future<void> stopStream() async {
    state = state.copyWith(isStreaming: false, errorMessage: null);
  }

  /// Alias for stopStream
  Future<void> stopCamera() => stopStream();

  @override
  void dispose() {
    _usbEventSub?.cancel();
    _usbPollTimer?.cancel();
    super.dispose();
  }
}

/// Provider exposing the camera state notifier
final cameraStateProvider = StateNotifierProvider<CameraStateNotifier, CameraState>((ref) {
  return CameraStateNotifier(ref.read(cameraServiceProvider), ref);
});

/// Stream provider for live camera frames
final cameraFrameStreamProvider = StreamProvider.autoDispose<CameraImage>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.currentSource.frameStream;
});
