/// Represents the result of a currency denomination classification.
/// Used to provide auditory feedback about the value of physical banknotes
/// to assist visually impaired users with financial transactions.
class CurrencyResult {
  final String denomination;
  final double confidence;
  final int classIndex;

  CurrencyResult({
    required this.denomination,
    required this.confidence,
    this.classIndex = 0,
  });

  /// Factory constructor to create a CurrencyResult from ML classification outputs.
  factory CurrencyResult.fromClassification(int index, double confidence, List<String> labels) {
    String label = 'Unknown';
    if (labels.isNotEmpty && index >= 0 && index < labels.length) {
      label = labels[index];
    }
    return CurrencyResult(
      denomination: label,
      confidence: confidence,
      classIndex: index,
    );
  }

  /// Returns an accessible string for TTS to read out the denomination.
  /// Example: '500 rupee note detected with high confidence'
  String toSpeechText() {
    String confidenceLevel = isConfident ? 'high confidence' : 'low confidence';
    return '$denomination note detected with $confidenceLevel';
  }

  /// Indicates whether the classification confidence is high enough (>0.7) to be reliable.
  bool get isConfident => confidence > 0.7;
}
