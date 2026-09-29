import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/services/camera_service.dart';

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
    int? textureId,
    bool? isUsbCamera,
    String? cameraName,
    double? aspectRatio,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: errorMessage ?? this.errorMessage,
      controller: controller ?? this.controller,
      textureId: textureId ?? this.textureId,
      isUsbCamera: isUsbCamera ?? this.isUsbCamera,
      cameraName: cameraName ?? this.cameraName,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}

/// StateNotifier for handling camera state transitions
class CameraStateNotifier extends StateNotifier<CameraState> {
  final CameraService _cameraService;

  CameraStateNotifier(this._cameraService) : super(CameraState());

  /// Initializes the camera service
  Future<void> initialize() async {
    try {
      await _cameraService.initialize();
      final source = _cameraService.currentSource;
      state = state.copyWith(
        isInitialized: true,
        errorMessage: null,
        controller: source.controller,
        textureId: source.textureId,
        isUsbCamera: source.isUsbCamera,
        cameraName: source.name,
        aspectRatio: source.aspectRatio,
      );
    } catch (e) {
      state = state.copyWith(isInitialized: false, errorMessage: e.toString());
    }
  }

  /// Alias for initialize
  Future<void> initializeCamera() => initialize();

  /// Toggles between IMX378 USB Smart Glasses Camera and Built-in Phone Camera
  Future<void> toggleCameraSource() async {
    try {
      await _cameraService.toggleCameraSource();
      final source = _cameraService.currentSource;
      state = state.copyWith(
        isInitialized: true,
        errorMessage: null,
        controller: source.controller,
        textureId: source.textureId,
        isUsbCamera: source.isUsbCamera,
        cameraName: source.name,
        aspectRatio: source.aspectRatio,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Starts the camera stream
  Future<void> startStream() async {
    if (!state.isInitialized) {
      state = state.copyWith(errorMessage: 'Camera not initialized');
      return;
    }
    try {
      state = state.copyWith(isStreaming: true, errorMessage: null);
    } catch (e) {
      state = state.copyWith(isStreaming: false, errorMessage: e.toString());
    }
  }

  /// Alias for startStream
  Future<void> startCamera() => startStream();

  /// Stops the camera stream
  Future<void> stopStream() async {
    try {
      state = state.copyWith(isStreaming: false, errorMessage: null);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Alias for stopStream
  Future<void> stopCamera() => stopStream();
}

/// Provider exposing the camera state notifier
final cameraStateProvider = StateNotifierProvider<CameraStateNotifier, CameraState>((ref) {
  return CameraStateNotifier(ref.read(cameraServiceProvider));
});

/// Stream provider for live camera frames
final cameraFrameStreamProvider = StreamProvider.autoDispose<CameraImage>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.currentSource.frameStream;
});
