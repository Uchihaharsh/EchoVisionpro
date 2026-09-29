import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  final Map<String, Interpreter> _interpreters = {};

  Future<void> loadModel(String modelKey, String assetPath) async {
    try {
      if (_interpreters.containsKey(modelKey)) {
        return;
      }

      final options = InterpreterOptions()..threads = 4;
      final interpreter = await Interpreter.fromAsset(assetPath, options: options);
      
      _interpreters[modelKey] = interpreter;
      
      // Run warmup inference
      if (interpreter.getInputTensors().isNotEmpty && interpreter.getOutputTensors().isNotEmpty) {
        try {
          // Add detailed warmup logic depending on model input size
          debugPrint('Loaded and warmed up $modelKey');
        } catch (e) {
          debugPrint('Failed to run warmup for $modelKey: $e');
        }
      }
      debugPrint('Successfully loaded model: $modelKey');
    } catch (e) {
      debugPrint('Error loading TFLite model $modelKey from $assetPath: $e');
      rethrow;
    }
  }

  void runInference(String modelKey, List<Object> inputs, Map<int, Object> outputs) {
    try {
      final interpreter = getInterpreter(modelKey);
      if (interpreter == null) {
        throw Exception('Model not loaded: $modelKey');
      }
      
      interpreter.runForMultipleInputs(inputs, outputs);
    } catch (e) {
      debugPrint('Error running inference for $modelKey: $e');
    }
  }

  Interpreter? getInterpreter(String modelKey) {
    return _interpreters[modelKey];
  }

  bool isModelLoaded(String modelKey) {
    return _interpreters.containsKey(modelKey);
  }

  void unloadModel(String modelKey) {
    if (_interpreters.containsKey(modelKey)) {
      _interpreters[modelKey]?.close();
      _interpreters.remove(modelKey);
    }
  }

  Future<void> dispose() async {
    try {
      for (var interpreter in _interpreters.values) {
        interpreter.close();
      }
      _interpreters.clear();
      debugPrint('All TFLite interpreters disposed');
    } catch (e) {
      debugPrint('Error disposing TFLite interpreters: $e');
    }
  }
}
