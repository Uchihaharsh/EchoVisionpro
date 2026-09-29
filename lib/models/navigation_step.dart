/// Represents a single step in a turn-by-turn navigation route.
/// Used to guide the visually impaired user via clear auditory cues.
class NavigationStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuver;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  NavigationStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuver,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  });

  /// Factory constructor alias for fromDirectionsApi
  factory NavigationStep.fromJson(Map<String, dynamic> step) => NavigationStep.fromDirectionsApi(step);

  ({double latitude, double longitude}) get endLocation => (latitude: endLat, longitude: endLng);
  ({double latitude, double longitude}) get startLocation => (latitude: startLat, longitude: startLng);

  /// Factory constructor to parse a step from the Google Directions API response.
  factory NavigationStep.fromDirectionsApi(Map<String, dynamic> step) {
    // Strip HTML tags from instruction if present (API typically returns HTML)
    String rawInstruction = step['html_instructions'] ?? '';
    String cleanInstruction = rawInstruction.replaceAll(RegExp(r'<[^>]*>'), '');

    return NavigationStep(
      instruction: cleanInstruction,
      distanceMeters: (step['distance']?['value'] ?? 0).toDouble(),
      durationSeconds: (step['duration']?['value'] ?? 0).toDouble(),
      maneuver: step['maneuver'] ?? 'straight',
      startLat: (step['start_location']?['lat'] ?? 0.0).toDouble(),
      startLng: (step['start_location']?['lng'] ?? 0.0).toDouble(),
      endLat: (step['end_location']?['lat'] ?? 0.0).toDouble(),
      endLng: (step['end_location']?['lng'] ?? 0.0).toDouble(),
    );
  }

  /// Generates a spoken instruction based on the current distance to this step.
  /// Example: 'Turn left in 10 meters'
  String toSpeechText(double currentDistanceToStep) {
    int dist = currentDistanceToStep.round();
    
    // Format the maneuver text to be readable
    String maneuverText = maneuver.replaceAll('-', ' ');
    if (maneuverText.isEmpty || maneuverText == 'straight') {
       return 'Continue straight for $dist meters';
    }
    
    // Providing a clear, timely instruction for TTS
    return 'In $dist meters, $maneuverText';
  }

  /// Checks if the user is close enough to the step's destination to trigger the next instruction.
  /// Returns true if within 15 meters.
  bool isNearby(double currentDistanceMeters) {
    return currentDistanceMeters <= 15.0;
  }
}
