import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Service responsible for managing user location tracking.
/// Uses the geolocator package for high-accuracy background and foreground tracking.
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  /// Checks and requests location permissions from the user.
  /// Must be called before tracking location.
  Future<bool> initialize() async {
    return await checkPermissions();
  }

  /// Verifies location permissions, prompting the user if necessary.
  Future<bool> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again.
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      return false;
    } 

    return true;
  }

  /// Starts tracking the user's location continuously.
  /// Yields a stream of [Position] updates.
  Stream<Position> startTracking() {
    if (_positionSubscription != null) {
      // Already tracking
      return _positionController.stream;
    }

    // High accuracy is crucial for blind user navigation, distanceFilter set to 2m
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(
      (Position position) {
        _positionController.add(position);
      },
      onError: (error) {
        _positionController.addError(error);
      }
    );

    return _positionController.stream;
  }

  /// Stops tracking the user's location.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Retrieves the single current location of the user.
  Future<Position> getCurrentPosition() async {
    bool hasPermission = await checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permissions not granted');
    }
    
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Disposes of active resources.
  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
