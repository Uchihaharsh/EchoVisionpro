import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:smart_glasses/core/constants.dart';
import 'package:smart_glasses/models/navigation_step.dart';

/// Service responsible for fetching directions, geocoding, and tracking walking route progress.
/// Supports both OSRM (Open Source Routing Machine - 100% Free & Keyless) and Google Directions API.
class NavigationService {
  String _apiKey = '';
  List<NavigationStep> _currentRoute = [];
  List<LatLng> _routeCoordinates = [];
  int _currentStepIndex = 0;

  bool get isNavigating => _currentRoute.isNotEmpty && _currentStepIndex < _currentRoute.length;
  List<NavigationStep> get currentRoute => _currentRoute;
  List<LatLng> get routeCoordinates => _routeCoordinates;
  int get currentStepIndex => _currentStepIndex;

  /// Initializes the navigation service
  void initialize() {
    _apiKey = AppConstants.googleMapsApiKey;
  }

  /// Reverse geocodes the user's current GPS position to a human-readable street address
  Future<String> getCurrentAddress(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'SmartGlassesAssistiveApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Format shorter human friendly address (first 2-3 parts)
          final parts = displayName.split(',');
          if (parts.length > 3) {
            return parts.take(3).join(',').trim();
          }
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
    return 'Latitude: ${lat.toStringAsFixed(4)}, Longitude: ${lng.toStringAsFixed(4)}';
  }

  /// Geocodes a place name/address string to coordinates (lat, lng)
  Future<({double lat, double lng})?> geocodeAddress(String address, {double? currentLat, double? currentLng}) async {
    try {
      String queryUrl = 'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(address)}&limit=1';
      if (currentLat != null && currentLng != null) {
        // Bias search results towards user's current location
        queryUrl += '&lat=$currentLat&lon=$currentLng';
      }

      final response = await http.get(Uri.parse(queryUrl), headers: {
        'User-Agent': 'SmartGlassesAssistiveApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lng = double.parse(data[0]['lon']);
          return (lat: lat, lng: lng);
        }
      }
    } catch (e) {
      debugPrint('Error geocoding address: $e');
    }
    return null;
  }

  /// Fetches walking directions between two coordinates.
  /// Automatically uses OSRM Free Routing with automatic Google Directions fallback.
  Future<List<NavigationStep>> getDirections(double originLat, double originLng, double destLat, double destLng) async {
    // 1. Try OSRM Walking Engine (Free, Keyless, Fast & Global)
    try {
      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/$originLng,$originLat;$destLng,$destLat?overview=full&geometries=geojson&steps=true',
      );
      final response = await http.get(osrmUrl).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          
          // Parse full route polyline geometry
          if (route['geometry'] != null && route['geometry']['coordinates'] != null) {
            final coords = route['geometry']['coordinates'] as List;
            _routeCoordinates = coords.map((c) {
              final lng = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lng);
            }).toList();
          }

          final legs = route['legs'] as List;
          if (legs.isNotEmpty) {
            final stepsJson = legs[0]['steps'] as List;
            List<NavigationStep> steps = [];

            for (var step in stepsJson) {
              final double distance = (step['distance'] as num?)?.toDouble() ?? 0.0;
              final double duration = (step['duration'] as num?)?.toDouble() ?? 0.0;
              final String name = step['name'] ?? '';
              final maneuverType = step['maneuver']?['type'] ?? 'straight';
              final modifier = step['maneuver']?['modifier'] ?? '';
              
              String instruction = _buildStepInstruction(maneuverType, modifier, name, distance);

              final location = step['maneuver']?['location'] as List?;
              double stepLng = (location != null && location.isNotEmpty) ? (location[0] as num).toDouble() : originLng;
              double stepLat = (location != null && location.length > 1) ? (location[1] as num).toDouble() : originLat;

              steps.add(NavigationStep(
                instruction: instruction,
                distanceMeters: distance,
                durationSeconds: duration,
                maneuver: modifier.isNotEmpty ? modifier : maneuverType,
                startLat: stepLat,
                startLng: stepLng,
                endLat: destLat,
                endLng: destLng,
              ));
            }

            if (steps.isNotEmpty) {
              _currentRoute = steps;
              _currentStepIndex = 0;
              return _currentRoute;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM routing error: $e');
    }

    // 2. Google Directions Fallback if a valid key is provided
    final hasValidGoogleKey = _apiKey.isNotEmpty && !_apiKey.contains('YOUR_GOOGLE_MAPS_API_KEY');
    if (hasValidGoogleKey) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$originLat,$originLng'
          '&destination=$destLat,$destLng'
          '&mode=walking'
          '&key=$_apiKey',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final stepsJson = data['routes'][0]['legs'][0]['steps'] as List;
            _currentRoute = stepsJson.map((step) => NavigationStep.fromJson(step)).toList();
            _currentStepIndex = 0;
            _routeCoordinates = [
              LatLng(originLat, originLng),
              LatLng(destLat, destLng),
            ];
            return _currentRoute;
          }
        }
      } catch (e) {
        debugPrint('Google Directions API error: $e');
      }
    }

    // Safety: If no verified pedestrian walking route could be obtained,
    // do NOT guide the blind user along a blind straight line. Return empty route.
    debugPrint('No verified pedestrian walking route found.');
    _currentRoute = [];
    _routeCoordinates = [];
    _currentStepIndex = 0;
    return [];
  }

  String _buildStepInstruction(String type, String modifier, String streetName, double distance) {
    int dist = distance.round();
    String street = streetName.isNotEmpty ? ' onto $streetName' : '';

    if (type == 'depart') {
      return 'Head straight$street for $dist meters';
    } else if (type == 'arrive') {
      return 'You have arrived at your destination';
    } else if (modifier.contains('left')) {
      return 'Turn left$street and walk $dist meters';
    } else if (modifier.contains('right')) {
      return 'Turn right$street and walk $dist meters';
    } else if (type == 'turn') {
      return 'Turn ${modifier.isNotEmpty ? modifier : "straight"}$street and walk $dist meters';
    }
    return 'Continue straight$street for $dist meters';
  }

  /// Evaluates user position and advances navigation step
  NavigationStep? getCurrentInstruction(double currentLat, double currentLng) {
    if (!isNavigating) return null;

    NavigationStep currentStep = _currentRoute[_currentStepIndex];
    
    double distanceToEnd = _haversineDistance(
      currentLat, currentLng, 
      currentStep.endLat, currentStep.endLng,
    );

    // If within 15 meters of waypoint, advance to next instruction
    if (distanceToEnd <= 15.0) {
      if (_currentStepIndex < _currentRoute.length - 1) {
        _currentStepIndex++;
        currentStep = _currentRoute[_currentStepIndex];
      } else {
        // Arrived at destination
        stopNavigation();
        return null;
      }
    }
    
    return currentStep;
  }

  double getDistanceToNextTurn(double currentLat, double currentLng) {
    if (!isNavigating) return 0.0;
    
    NavigationStep currentStep = _currentRoute[_currentStepIndex];
    return _haversineDistance(
      currentLat, currentLng,
      currentStep.endLat, currentStep.endLng,
    );
  }

  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000.0; // meters
    double dLat = _toRadians(lat2 - lat1);
    double dLng = _toRadians(lng2 - lng1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
               sin(dLng / 2) * sin(dLng / 2);
               
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180.0;
  }

  void stopNavigation() {
    _currentRoute.clear();
    _routeCoordinates.clear();
    _currentStepIndex = 0;
  }
}
