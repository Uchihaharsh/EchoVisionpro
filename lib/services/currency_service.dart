import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_glasses/core/utils/image_utils.dart';
import 'package:smart_glasses/models/currency_result.dart';

/// Service responsible for recognizing currency notes.
/// Uses high-accuracy OCR to detect Indian banknote numbers (500, 200, 100, 50, 20, 10).
class CurrencyService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessing = false;

  CurrencyService();

  Future<void> initialize() async {}

  String? _cachedFramePath;

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

      final text = recognizedText.text;
      if (text.isEmpty) return null;

      final denominationMap = {
        '500': '500',
        '200': '200',
        '100': '100',
        '50': '50',
        '20': '20',
        '10': '10',
      };

      final regExp = RegExp(r'\b(500|200|100|50|20|10)\b');
      final matches = regExp.allMatches(text);

      if (matches.isNotEmpty) {
        final matchValue = matches.first.group(0);
        if (matchValue != null && denominationMap.containsKey(matchValue)) {
          return CurrencyResult(
            denomination: denominationMap[matchValue]!,
            confidence: 0.95,
          );
        }
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
  Future<CurrencyResult?> classifyCurrency(dynamic frameData) async {
    if (_isProcessing) return null;
    if (frameData is! CameraImage) return null;

    try {
      _isProcessing = true;
      final inputImage = _buildInputImage(frameData);
      if (inputImage == null) return null;

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      if (text.isEmpty) return null;

      final denominationMap = {
        '500': '500',
        '200': '200',
        '100': '100',
        '50': '50',
        '20': '20',
        '10': '10',
      };

      final regExp = RegExp(r'\b(500|200|100|50|20|10)\b');
      final matches = regExp.allMatches(text);

      if (matches.isNotEmpty) {
        final matchValue = matches.first.group(0);
        if (matchValue != null && denominationMap.containsKey(matchValue)) {
          return CurrencyResult(
            denomination: denominationMap[matchValue]!,
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

  InputImage? _buildInputImage(CameraImage image) {
    return ImageUtils.buildInputImage(image, rotation: 90);
  }

  void dispose() {
    try {
      _textRecognizer.close();
    } catch (_) {}
  }
}
