import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_glasses/core/utils/image_utils.dart';
import 'package:smart_glasses/models/ocr_result.dart' hide TextBlock;

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessing = false;

  Future<void> initialize() async {
    // TextRecognizer is initialized inline
  }

  String? _cachedFramePath;

  /// Processes high-resolution JPEG frames from IMX378 USB Camera
  Future<OcrResult?> processImageBytes(Uint8List jpegBytes) async {
    if (_isProcessing) return null;
    
    try {
      _isProcessing = true;
      if (_cachedFramePath == null) {
        final tempDir = await getTemporaryDirectory();
        _cachedFramePath = '${tempDir.path}/live_ocr_frame.jpg';
      }
      final file = File(_cachedFramePath!);
      await file.writeAsBytes(jpegBytes, flush: false);

      final inputImage = InputImage.fromFilePath(file.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final blocks = List<TextBlock>.from(recognizedText.blocks);
      blocks.sort((a, b) {
        final aTop = a.boundingBox.top;
        final bTop = b.boundingBox.top;
        return aTop.compareTo(bTop);
      });
      final currentText = blocks.map((b) => b.text.trim()).where((t) => t.isNotEmpty).join('\n');

      if (currentText.isEmpty) {
        return null;
      }

      return OcrResult(
        fullText: currentText,
        blocks: [],
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error processing image bytes for OCR: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  Future<OcrResult?> processFrame(CameraImage image) async {
    if (_isProcessing) return null;
    
    try {
      _isProcessing = true;
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        return null;
      }

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      final blocks = List<TextBlock>.from(recognizedText.blocks);
      blocks.sort((a, b) {
        final aTop = a.boundingBox.top;
        final bTop = b.boundingBox.top;
        return aTop.compareTo(bTop);
      });
      final currentText = blocks.map((b) => b.text.trim()).where((t) => t.isNotEmpty).join('\n');

      if (currentText.isEmpty) {
        return null;
      }

      final result = OcrResult(
        fullText: currentText,
        blocks: [],
        timestamp: DateTime.now(),
      );
      return result;
    } catch (e) {
      debugPrint('Error processing frame for OCR: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    return ImageUtils.buildInputImage(image, rotation: 90);
  }

  Future<void> dispose() async {
    try {
      await _textRecognizer.close();
    } catch (e) {
      debugPrint('Error disposing TextRecognizer: $e');
    }
  }
}
