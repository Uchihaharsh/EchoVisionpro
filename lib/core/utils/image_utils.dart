import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Converts a CameraImage (NV21 2-plane, YUV420 3-plane, or single-plane) to JPEG bytes.
  static Uint8List? convertYUV420ToRGB(CameraImage image) {
    try {
      // Fast-path: If image plane already contains encoded JPEG bytes
      if (image.planes.isNotEmpty) {
        final firstBytes = image.planes[0].bytes;
        if (firstBytes.length > 2 && firstBytes[0] == 0xFF && firstBytes[1] == 0xD8) {
          return firstBytes;
        }
      }

      final int width = image.width;
      final int height = image.height;
      if (width <= 0 || height <= 0 || image.planes.isEmpty) return null;

      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;
      final yRowStride = yPlane.bytesPerRow;

      final imgRgb = img.Image(width: width, height: height);

      // Single plane (greyscale / raw)
      if (image.planes.length == 1) {
        for (int y = 0; y < height; y++) {
          final rowOffset = y * yRowStride;
          for (int x = 0; x < width; x++) {
            final idx = rowOffset + x;
            if (idx < yBytes.length) {
              final val = yBytes[idx];
              imgRgb.setPixelRgb(x, y, val, val, val);
            }
          }
        }
        return img.encodeJpg(imgRgb, quality: 80);
      }

      // NV21 (2 planes: Y, and interleaved VU)
      if (image.planes.length == 2) {
        final uvPlane = image.planes[1];
        final uvBytes = uvPlane.bytes;
        final uvRowStride = uvPlane.bytesPerRow;
        final uvPixelStride = uvPlane.bytesPerPixel ?? 2;

        for (int y = 0; y < height; y++) {
          final yRowOffset = y * yRowStride;
          final uvRowOffset = (y >> 1) * uvRowStride;

          for (int x = 0; x < width; x++) {
            final yIdx = yRowOffset + x;
            final uvIdx = uvRowOffset + (x >> 1) * uvPixelStride;

            if (yIdx < yBytes.length && uvIdx + 1 < uvBytes.length) {
              final yVal = yBytes[yIdx];
              // In NV21, V is first, then U
              final vVal = uvBytes[uvIdx] - 128;
              final uVal = uvBytes[uvIdx + 1] - 128;

              final r = (yVal + 1.402 * vVal).round().clamp(0, 255);
              final g = (yVal - 0.344 * uVal - 0.714 * vVal).round().clamp(0, 255);
              final b = (yVal + 1.772 * uVal).round().clamp(0, 255);

              imgRgb.setPixelRgb(x, y, r, g, b);
            }
          }
        }
        return img.encodeJpg(imgRgb, quality: 80);
      }

      // YUV_420_888 (3 planes: Y, U, V)
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        final yRowOffset = y * yRowStride;
        final uvRowOffset = (y >> 1) * uvRowStride;

        for (int x = 0; x < width; x++) {
          final yIdx = yRowOffset + x;
          final uvIdx = uvRowOffset + (x >> 1) * uvPixelStride;

          if (yIdx < yBytes.length && uvIdx < uBytes.length && uvIdx < vBytes.length) {
            final yVal = yBytes[yIdx];
            final uVal = uBytes[uvIdx] - 128;
            final vVal = vBytes[uvIdx] - 128;

            final r = (yVal + 1.402 * vVal).round().clamp(0, 255);
            final g = (yVal - 0.344 * uVal - 0.714 * vVal).round().clamp(0, 255);
            final b = (yVal + 1.772 * uVal).round().clamp(0, 255);

            imgRgb.setPixelRgb(x, y, r, g, b);
          }
        }
      }
      return img.encodeJpg(imgRgb, quality: 80);
    } catch (e) {
      debugPrint("Error converting YUV420 to RGB: $e");
      return null;
    }
  }

  /// Resizes the provided image bytes to the target width and height required by the ML model.
  static Uint8List? resizeImage(Uint8List imageBytes, int targetWidth, int targetHeight) {
    try {
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;
      
      final img.Image resizedImage = img.copyResize(originalImage, width: targetWidth, height: targetHeight);
      return img.encodeJpg(resizedImage);
    } catch (e) {
      debugPrint("Error resizing image: $e");
      return null;
    }
  }

  /// Normalizes image pixels from [0, 255] to [0, 1] range commonly expected by neural networks.
  static Float32List? normalizePixels(Uint8List imageBytes) {
    try {
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return null;

      final Float32List normalized = Float32List(decodedImage.width * decodedImage.height * 3);
      int index = 0;
      
      for (var p in decodedImage) {
        normalized[index++] = p.r / 255.0;
        normalized[index++] = p.g / 255.0;
        normalized[index++] = p.b / 255.0;
      }
      return normalized;
    } catch (e) {
      debugPrint("Error normalizing pixels: $e");
      return null;
    }
  }

  /// Extracts the raw bytes of the CameraImage for ML Kit processing.
  static Uint8List getCameraImageBytes(CameraImage cameraImage) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }
}
