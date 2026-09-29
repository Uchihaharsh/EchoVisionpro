class AppConstants {
  // Model paths
  static const String objectDetectionModel = 'assets/models/ssd_mobilenet.tflite';

  // Label paths
  static const String objectLabels = 'assets/labels/labelmap.txt';
  static const String currencyLabels = 'assets/labels/currency_labels.txt';

  // Google Gemini AI Configuration
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String geminiModel = 'gemini-1.5-flash';

  // Google Maps API Key Configuration (defaults to empty unless supplied via --dart-define)
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
  static const String googleDirectionsApiBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  // ML Constants
  static const int inputSize = 300; // For SSD MobileNet
  static const double confidenceThreshold = 0.5;
  static const int maxDetections = 10;

  // Frame processing
  static const int maxFramesPerSecond = 8; // Process max 8 frames per second to avoid UI thread block

  // Supported currency denominations
  static const List<String> supportedCurrencies = [
    '₹10', '₹20', '₹50', '₹100', '₹200', '₹500'
  ];

  // Navigation thresholds
  static const double turnPromptDistanceMeters = 15.0; // Distance to prompt user for turn
  static const double arrivalDistanceMeters = 10.0; // Distance to declare arrival
}
