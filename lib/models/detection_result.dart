/// Represents an object detected by the TFLite object detection model.
/// This class handles spatial positioning relative to the user's field of view,
/// converting raw bounding boxes into accessible natural language descriptions.
class DetectionResult {
  final String label;
  final double confidence;
  final double left;
  final double top;
  final double width;
  final double height;
  final String relativePosition;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.relativePosition,
  });

  List<double> get boundingBox => [left, top, width, height];

  /// Factory constructor to create a DetectionResult from raw TFLite output.
  /// [location] should be a list containing [left, top, width, height] or similar.
  /// Note: The actual parsing depends on the specific model's output tensor shapes.
  factory DetectionResult.fromTFLiteOutput(
      String label, double confidence, List<double> location, double imageWidth) {
    
    double left = location[0];
    double top = location[1];
    double width = location[2];
    double height = location[3];

    // Instantiate result, calculating the relative position dynamically based on width
    return DetectionResult(
      label: label,
      confidence: confidence,
      left: left,
      top: top,
      width: width,
      height: height,
      relativePosition: _calculateRelativePosition(left, width, imageWidth),
    );
  }

  /// Internal helper to calculate the relative position during factory construction.
  static String _calculateRelativePosition(double left, double width, double imageWidth) {
    double centerX = left + (width / 2);
    double third = imageWidth / 3.0;
    
    if (centerX < third) {
      return 'left';
    } else if (centerX > 2 * third) {
      return 'right';
    } else {
      return 'ahead';
    }
  }

  /// Method to determine position based on bounding box center x position
  /// relative to the full image width. (left third = 'left', right third = 'right', middle = 'ahead')
  String getRelativePosition(double imageWidth) {
    double centerX = left + (width / 2);
    double third = imageWidth / 3.0;
    
    if (centerX < third) {
      return 'left';
    } else if (centerX > 2 * third) {
      return 'right';
    } else {
      return 'ahead';
    }
  }

  @override
  String toString() {
    // E.g., 'Chair ahead' or 'Person to the left'
    if (relativePosition == 'ahead') {
      return '$label ahead';
    } else {
      return '$label to the $relativePosition';
    }
  }

  /// Returns a natural language string optimized for Text-To-Speech (TTS) readout,
  /// ensuring maximum accessibility and clear understanding for the visually impaired user.
  String toSpeechText() {
    return toString();
  }
}
