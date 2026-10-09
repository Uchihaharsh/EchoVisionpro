import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Converts any Android CameraImage (YUV_420_888 3-plane, NV21 2-plane, or 1-plane)
  /// into a tightly-packed NV21 byte array required by Google ML Kit's InputImageConverter on Android.
  static Uint8List? convertCameraImageToNV21(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      if (width <= 0 || height <= 0 || image.planes.isEmpty) return null;

      final int ySize = width * height;
      final int uvSize = (width ~/ 2) * (height ~/ 2) * 2;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      // 1-plane already packed NV21
      if (image.planes.length == 1) {
        final bytes = image.planes[0].bytes;
        final copyLen = bytes.length < nv21.length ? bytes.length : nv21.length;
        nv21.setRange(0, copyLen, bytes);
        return nv21;
      }

      // Copy Y plane (accounting for row stride padding)
      final Plane yPlane = image.planes[0];
      final Uint8List yBytes = yPlane.bytes;
      final int yRowStride = yPlane.bytesPerRow;

      if (yRowStride == width && yBytes.length >= ySize) {
        nv21.setRange(0, ySize, yBytes);
      } else {
        int dstOffset = 0;
        for (int row = 0; row < height; row++) {
          final int srcOffset = row * yRowStride;
          if (srcOffset + width <= yBytes.length) {
            nv21.setRange(dstOffset, dstOffset + width, yBytes, srcOffset);
          }
          dstOffset += width;
        }
      }

      final int uvWidth = width ~/ 2;
      final int uvHeight = height ~/ 2;
      int uvDstOffset = ySize;

      // 2-plane (Y + interleaved UV/VU)
      if (image.planes.length == 2) {
        final Plane uvPlane = image.planes[1];
        final Uint8List uvBytes = uvPlane.bytes;
        final int uvRowStride = uvPlane.bytesPerRow;
        final int rowBytes = uvWidth * 2;

        if (uvRowStride == rowBytes && uvBytes.length >= uvSize) {
          nv21.setRange(ySize, ySize + uvSize, uvBytes);
        } else {
          for (int row = 0; row < uvHeight; row++) {
            final int srcOffset = row * uvRowStride;
            final int avail = (srcOffset + rowBytes <= uvBytes.length)
                ? rowBytes
                : (uvBytes.length - srcOffset).clamp(0, rowBytes);
            if (avail > 0) {
              nv21.setRange(uvDstOffset, uvDstOffset + avail, uvBytes, srcOffset);
            }
            uvDstOffset += rowBytes;
          }
        }
        return nv21;
      }

      // 3-plane YUV_420_888 (Y, U, V) -> interleave V then U for NV21
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];
      final Uint8List uBytes = uPlane.bytes;
      final Uint8List vBytes = vPlane.bytes;
      final int uRowStride = uPlane.bytesPerRow;
      final int vRowStride = vPlane.bytesPerRow;
      final int uPixelStride = uPlane.bytesPerPixel ?? 1;
      final int vPixelStride = vPlane.bytesPerPixel ?? 1;

      for (int row = 0; row < uvHeight; row++) {
        final int uRowOffset = row * uRowStride;
        final int vRowOffset = row * vRowStride;
        for (int col = 0; col < uvWidth; col++) {
          final int uIdx = uRowOffset + col * uPixelStride;
          final int vIdx = vRowOffset + col * vPixelStride;
          nv21[uvDstOffset++] = (vIdx < vBytes.length) ? vBytes[vIdx] : 128;
          nv21[uvDstOffset++] = (uIdx < uBytes.length) ? uBytes[uIdx] : 128;
        }
      }

      return nv21;
    } catch (e) {
      debugPrint('Error converting CameraImage to NV21: $e');
      return null;
    }
  }

  /// Builds a Google ML Kit [InputImage] from a [CameraImage], always using NV21 format
  /// so Android's InputImageConverter never rejects YUV_420_888 frames.
  static InputImage? buildInputImage(CameraImage image, {int rotation = 90}) {
    try {
      final nv21Bytes = convertCameraImageToNV21(image);
      if (nv21Bytes == null || nv21Bytes.isEmpty) return null;

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final InputImageRotation imageRotation =
          InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation90deg;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      );

      return InputImage.fromBytes(bytes: nv21Bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint('Error building InputImage: $e');
      return null;
    }
  }

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
    return convertCameraImageToNV21(cameraImage) ?? Uint8List(0);
  }
}
