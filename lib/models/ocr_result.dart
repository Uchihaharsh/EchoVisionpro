/// A block of text recognized from the image (simplified for ML Kit representation).
class TextBlock {
  final String text;
  TextBlock({required this.text});
}

/// Represents the result of an Optical Character Recognition (OCR) scan.
/// Used for reading documents, signs, or any text in the environment out loud.
class OcrResult {
  final String fullText;
  final List<TextBlock> blocks;
  final DateTime timestamp;

  OcrResult({
    required this.fullText,
    required this.blocks,
    required this.timestamp,
  });

  /// Returns true if any valid text was recognized.
  bool get hasText => fullText.trim().isNotEmpty;

  /// Returns the full text to be spoken by Text-To-Speech (TTS).
  String toSpeechText() {
    return fullText;
  }

  /// Compares this OCR result with a previous one to ensure camera stability.
  /// If the text is stable (similar above threshold), returns the text.
  /// Otherwise, returns null, indicating the camera might be moving too much.
  /// Uses a simple character overlap ratio for similarity calculation.
  String? getStableText(OcrResult? previous, {double similarityThreshold = 0.8}) {
    if (previous == null || previous.fullText.isEmpty || fullText.isEmpty) {
      return null;
    }

    // Convert text to sets of characters (runes)
    Set<String> currentChars = fullText.runes.map((r) => String.fromCharCode(r)).toSet();
    Set<String> previousChars = previous.fullText.runes.map((r) => String.fromCharCode(r)).toSet();

    Set<String> intersection = currentChars.intersection(previousChars);
    Set<String> union = currentChars.union(previousChars);

    if (union.isEmpty) return null;

    double similarity = intersection.length / union.length;

    if (similarity >= similarityThreshold) {
      return fullText;
    }
    return null;
  }
}
