import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ffi_uvc/flutter_ffi_uvc.dart';
import 'package:smart_glasses/core/utils/image_utils.dart';

/// Abstract interface for camera sources (Strategy Pattern).
/// Swaps between native smartphone camera and external IMX378 USB Smart Glasses.
abstract class CameraSource {
  Future<void> initialize({ResolutionPreset resolution});
  Stream<CameraImage> get frameStream;
  CameraController? get controller;
  int? get textureId;
  String get name;
  bool get isUsbCamera;
  int get sensorOrientation;
  double get aspectRatio;
  Future<Uint8List?> extractFrame();
  Future<void> dispose();
  bool get isInitialized;
}

class NativeCameraSource implements CameraSource {
  CameraController? _controller;
  final StreamController<CameraImage> _frameStreamController = StreamController<CameraImage>.broadcast();
  DateTime? _lastFrameTime;
  CameraImage? _latestFrame;
  
  @override
  String get name => 'Phone Camera';

  @override
  bool get isUsbCamera => false;

  @override
  int? get textureId => null;

  @override
  int get sensorOrientation => _controller?.description.sensorOrientation ?? 90;

  @override
  double get aspectRatio => _controller?.value.aspectRatio ?? (16 / 9);
  
  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  
  @override
  CameraController? get controller => _controller;
  
  @override
  Stream<CameraImage> get frameStream => _frameStreamController.stream;

  @override
  Future<void> initialize({ResolutionPreset resolution = ResolutionPreset.medium}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      
      CameraDescription targetCamera = cameras.first;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          targetCamera = camera;
          break;
        }
      }
      
      _controller = CameraController(
        targetCamera,
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      
      await _controller!.initialize();
      
      await _controller!.startImageStream((CameraImage image) {
        _latestFrame = image;
        final now = DateTime.now();
        // Throttle frames to roughly 8 fps (125ms per frame) for ML processing
        if (_lastFrameTime == null || now.difference(_lastFrameTime!).inMilliseconds >= 125) {
          _lastFrameTime = now;
          if (!_frameStreamController.isClosed) {
            _frameStreamController.add(image);
          }
        }
      });
    } catch (e) {
      debugPrint('Error initializing native camera source: $e');
      rethrow;
    }
  }

  @override
  Future<Uint8List?> extractFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;

    // If live streaming is active, convert the latest camera frame directly
    if (_latestFrame != null) {
      try {
        final bytes = ImageUtils.convertYUV420ToRGB(_latestFrame!);
        if (bytes != null && bytes.isNotEmpty) return bytes;
      } catch (e) {
        debugPrint('Error converting latest frame: $e');
      }
    }

    try {
      if (!_controller!.value.isStreamingImages) {
        final XFile file = await _controller!.takePicture();
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_controller != null) {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      await _controller!.dispose();
      _controller = null;
    }
    if (!_frameStreamController.isClosed) {
      await _frameStreamController.close();
    }
  }
}

/// External USB-C UVC Camera Source for IMX378 12MP USB Camera (A) 30 fps.
class UvcCameraSource implements CameraSource {
  int? _textureId;
  bool _isInitialized = false;
  double _aspectRatio = 16 / 9;
  final StreamController<CameraImage> _frameStreamController = StreamController<CameraImage>.broadcast();

  @override
  String get name => 'IMX378 Smart Glasses';

  @override
  bool get isUsbCamera => true;

  @override
  int? get textureId => _textureId;

  @override
  CameraController? get controller => null;

  @override
  int get sensorOrientation => 0;

  @override
  double get aspectRatio => _aspectRatio;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<CameraImage> get frameStream => _frameStreamController.stream;

  @override
  Future<void> initialize({ResolutionPreset resolution = ResolutionPreset.medium}) async {
    try {
      await uvcCamera.ensureCameraPermission();
      final devices = await uvcCamera.listUsbDevices();
      if (devices.isEmpty) {
        throw Exception('No IMX378 USB Camera detected on USB-C port.');
      }

      final device = devices.first;
      await uvcCamera.openUsbDevice(device.deviceId);

      _textureId = await uvcCamera.createPreviewTexture();
      
      // Request highest quality HD mode from Sony IMX378 sensor
      final result = await uvcCamera.startPreviewAuto(
        preference: UvcAutoPreviewPreference.quality,
      );

      if (result.success && result.mode != null) {
        final width = result.mode!.width;
        final height = result.mode!.height;

        if (height > 0) {
          _aspectRatio = width / height;
        }

        await uvcCamera.attachPreviewTexture(
          _textureId!,
          width: width,
          height: height,
        );
        _isInitialized = true;
        debugPrint('IMX378 USB Camera (${width}x$height @ ${result.mode!.fps}fps) initialized successfully with textureId: $_textureId');
      } else {
        throw Exception('Failed to start USB Camera preview stream');
      }
    } catch (e) {
      debugPrint('Error initializing UvcCameraSource: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  @override
  Future<Uint8List?> extractFrame() async {
    try {
      final picture = uvcCamera.takePicture();
      return picture?.jpegBytes;
    } catch (e) {
      debugPrint('Error taking picture from USB Camera: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      uvcCamera.stopPreview();
      if (_textureId != null) {
        await uvcCamera.disposePreviewTexture(_textureId!);
        _textureId = null;
      }
      await uvcCamera.closeUsbDevice();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error disposing UvcCameraSource: $e');
    }
  }
}

class CameraService {
  CameraSource _currentSource = NativeCameraSource();

  CameraSource get currentSource => _currentSource;

  Future<bool> hasUsbCameraAttached() async {
    try {
      await uvcCamera.ensureCameraPermission();
      final devices = await uvcCamera.listUsbDevices();
      return devices.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> initialize({ResolutionPreset resolution = ResolutionPreset.medium}) async {
    if (_currentSource.isInitialized) {
      debugPrint('Camera is already initialized, keeping stream active.');
      return;
    }
    // Check if external IMX378 USB Camera is connected
    final hasUsb = await hasUsbCameraAttached();
    if (hasUsb) {
      try {
        _currentSource = UvcCameraSource();
        await _currentSource.initialize(resolution: resolution);
        return;
      } catch (e) {
        debugPrint('Falling back to native phone camera: $e');
        _currentSource = NativeCameraSource();
      }
    }
    await _currentSource.initialize(resolution: resolution);
  }

  Future<void> switchToUsbCamera({ResolutionPreset resolution = ResolutionPreset.medium}) async {
    await _currentSource.dispose();
    _currentSource = UvcCameraSource();
    await _currentSource.initialize(resolution: resolution);
  }

  Future<void> switchToPhoneCamera({ResolutionPreset resolution = ResolutionPreset.medium}) async {
    await _currentSource.dispose();
    _currentSource = NativeCameraSource();
    await _currentSource.initialize(resolution: resolution);
  }

  Future<void> toggleCameraSource({ResolutionPreset resolution = ResolutionPreset.medium}) async {
    if (_currentSource is UvcCameraSource) {
      await switchToPhoneCamera(resolution: resolution);
    } else {
      await switchToUsbCamera(resolution: resolution);
    }
  }

  Future<Uint8List?> extractFrame() async {
    return await _currentSource.extractFrame();
  }

  Future<void> dispose() async {
    await _currentSource.dispose();
  }
}
