import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_glasses/core/utils/image_utils.dart';
import 'package:smart_glasses/models/currency_result.dart';

/// Service responsible for recognizing currency notes.
/// Uses multi-orientation OCR to detect Indian banknote denominations (2000, 500, 200, 100, 50, 20, 10).
class CurrencyService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessing = false;

  CurrencyService();

  Future<void> initialize() async {}

  String? _cachedFramePath;

  /// Extracts Indian banknote denomination from recognized OCR text.
  String? _extractDenomination(String rawText) {
    if (rawText.trim().isEmpty) return null;
    final lower = rawText.toLowerCase();

    // 1. Check explicit verbal denominations printed on Indian banknotes
    if (lower.contains('two thousand')) return '2000';
    if (lower.contains('five hundred') || lower.contains('ve hundred')) return '500';
    if (lower.contains('two hundred')) return '200';
    if (lower.contains('one hundred')) return '100';
    if (lower.contains('fifty rupees') || lower.contains('fifty')) return '50';
    if (lower.contains('twenty rupees') || lower.contains('twenty')) return '20';
    if (lower.contains('ten rupees')) return '10';

    // 2. Normalize common OCR letter-for-zero substitutions (e.g. 5OO -> 500, R500 -> 500)
    final normalized = rawText
        .replaceAll(RegExp(r'(?<=[521])[oO]{2}'), '00')
        .replaceAll(RegExp(r'(?<=[521])[oO]'), '0');

    // Match denomination numbers even when preceded by ₹ / R / Rs (non-digit boundary)
    // but NOT inside longer serial numbers (like 650012).
    final regExp = RegExp(r'(?:^|[^\d])(2000|500|200|100|50|20|10)(?!\d)');
    final matches = regExp.allMatches(normalized);

    if (matches.isEmpty) return null;

    // Count occurrences of each denomination in the frame (notes print denomination multiple times)
    final counts = <String, int>{};
    for (final m in matches) {
      final val = m.group(1);
      if (val != null) {
        counts[val] = (counts[val] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return null;

    // Prefer denomination that appears most frequently; break ties by larger denomination
    const order = ['2000', '500', '200', '100', '50', '20', '10'];
    String? best;
    int bestCount = 0;
    for (final denom in order) {
      final c = counts[denom] ?? 0;
      if (c > bestCount) {
        bestCount = c;
        best = denom;
      }
    }
    return best;
  }

  /// Classifies currency from high-resolution JPEG frames (IMX378 USB Camera)
  Future<CurrencyResult?> classifyImageBytes(Uint8List jpegBytes) async {
    if (_isProcessing) return null;

    try {
      _isProcessing = true;
      if (_cachedFramePath == null) {
        final tempDir = await getTemporaryDirectory();
        _cachedFramePath = '${tempDir.path}/live_currency_frame.jpg';
      }
      final file = File(_cachedFramePath!);
      await file.writeAsBytes(jpegBytes, flush: false);

      final inputImage = InputImage.fromFilePath(file.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final denom = _extractDenomination(recognizedText.text);
      if (denom != null) {
        return CurrencyResult(
          denomination: denom,
          confidence: 0.95,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error in classifyImageBytes: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Classifies the denomination of the currency note in the image frame.
  /// Checks both portrait (90°) and landscape (0° / 270°) orientations.
  Future<CurrencyResult?> classifyCurrency(dynamic frameData) async {
    if (_isProcessing) return null;
    if (frameData is! CameraImage) return null;

    try {
      _isProcessing = true;
      final nv21Bytes = ImageUtils.convertCameraImageToNV21(frameData);
      if (nv21Bytes == null) return null;

      // Try portrait (90°) and landscape (0°, 270°) orientations using the same NV21 buffer
      for (final rotation in const [
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation0deg,
        InputImageRotation.rotation270deg,
      ]) {
        final inputImage = InputImage.fromBytes(
          bytes: nv21Bytes,
          metadata: InputImageMetadata(
            size: Size(frameData.width.toDouble(), frameData.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: frameData.width,
          ),
        );

        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        final denom = _extractDenomination(recognizedText.text);
        if (denom != null) {
          return CurrencyResult(
            denomination: denom,
            confidence: 0.95,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error in CurrencyService: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    try {
      _textRecognizer.close();
    } catch (_) {}
  }
}
