import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_glasses/services/navigation_service.dart';
import 'package:smart_glasses/services/location_service.dart';
import 'package:smart_glasses/providers/tts_providers.dart';

/// Provider for NavigationService
final navigationServiceProvider = Provider<NavigationService>((ref) {
  final service = NavigationService();
  service.initialize();
  return service;
});

/// Provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  service.initialize();
  return service;
});

/// State for Navigation
class NavigationState {
  final bool isNavigating;
  final String? currentStep;
  final List<dynamic> steps;
  final List<LatLng> routePoints;
  final String? destination;
  final double distanceToNextTurn;
  final String? currentAddress;
  final bool isLoading;
  final double? userLat;
  final double? userLng;
  final double? targetLat;
  final double? targetLng;

  NavigationState({
    this.isNavigating = false,
    this.currentStep,
    this.steps = const [],
    this.routePoints = const [],
    this.destination,
    this.distanceToNextTurn = 0.0,
    this.currentAddress,
    this.isLoading = false,
    this.userLat,
    this.userLng,
    this.targetLat,
    this.targetLng,
  });

  String? get currentInstruction => currentStep;
  List<String> get upcomingSteps => steps.map((s) => s.instruction.toString()).toList();

  NavigationState copyWith({
    bool? isNavigating,
    String? currentStep,
    List<dynamic>? steps,
    List<LatLng>? routePoints,
    String? destination,
    double? distanceToNextTurn,
    String? currentAddress,
    bool? isLoading,
    double? userLat,
    double? userLng,
    double? targetLat,
    double? targetLng,
  }) {
    return NavigationState(
      isNavigating: isNavigating ?? this.isNavigating,
      currentStep: currentStep ?? this.currentStep,
      steps: steps ?? this.steps,
      routePoints: routePoints ?? this.routePoints,
      destination: destination ?? this.destination,
      distanceToNextTurn: distanceToNextTurn ?? this.distanceToNextTurn,
      currentAddress: currentAddress ?? this.currentAddress,
      isLoading: isLoading ?? this.isLoading,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      targetLat: targetLat ?? this.targetLat,
      targetLng: targetLng ?? this.targetLng,
    );
  }
}

/// StateNotifier for Navigation logic
class NavigationStateNotifier extends StateNotifier<NavigationState> {
  final NavigationService _navService;
  final LocationService _locationService;
  final Ref _ref;
  String? _lastSpokenInstruction;

  NavigationStateNotifier(this._navService, this._locationService, this._ref)
      : super(NavigationState());

  /// Announces the user's current street location out loud
  Future<void> announceCurrentLocation() async {
    try {
      state = state.copyWith(isLoading: true);
      _ref.read(ttsStateProvider.notifier).speak('Finding your current location...');

      final pos = await _locationService.getCurrentPosition();
      final address = await _navService.getCurrentAddress(pos.latitude, pos.longitude);

      state = state.copyWith(
        currentAddress: address,
        isLoading: false,
        userLat: pos.latitude,
        userLng: pos.longitude,
      );
      _ref.read(ttsStateProvider.notifier).speak('You are near $address');
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _ref.read(ttsStateProvider.notifier).speak('Could not determine current location. Please ensure GPS is enabled.');
    }
  }

  /// Starts turn-by-turn navigation to a destination name or address
  Future<void> startNavigation(String destination) async {
    try {
      state = state.copyWith(isLoading: true, destination: destination);
      _ref.read(ttsStateProvider.notifier).speak('Calculating walking route to $destination...');

      final currentPos = await _locationService.getCurrentPosition();
      final targetCoords = await _navService.geocodeAddress(
        destination,
        currentLat: currentPos.latitude,
        currentLng: currentPos.longitude,
      );

      if (targetCoords == null) {
        state = state.copyWith(isLoading: false);
        _ref.read(ttsStateProvider.notifier).speak('Could not find destination $destination. Please try another place.');
        return;
      }

      final steps = await _navService.getDirections(
        currentPos.latitude,
        currentPos.longitude,
        targetCoords.lat,
        targetCoords.lng,
      );

      if (steps.isEmpty) {
        state = state.copyWith(isLoading: false);
        _ref.read(ttsStateProvider.notifier).speak('No walking route found to $destination.');
        return;
      }

      final firstInstruction = steps.first.instruction;
      _lastSpokenInstruction = firstInstruction;

      state = state.copyWith(
        isNavigating: true,
        isLoading: false,
        steps: steps,
        routePoints: _navService.routeCoordinates,
        currentStep: firstInstruction,
        distanceToNextTurn: steps.first.distanceMeters,
        userLat: currentPos.latitude,
        userLng: currentPos.longitude,
        targetLat: targetCoords.lat,
        targetLng: targetCoords.lng,
      );

      _ref.read(ttsStateProvider.notifier).speak('Starting walking navigation. $firstInstruction');
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _ref.read(ttsStateProvider.notifier).speak('Navigation error. Please check your internet connection.');
    }
  }

  /// Stops navigation
  void stopNavigation() {
    _navService.stopNavigation();
    _lastSpokenInstruction = null;
    state = state.copyWith(
      isNavigating: false,
      destination: null,
      steps: [],
      routePoints: [],
      currentStep: null,
      distanceToNextTurn: 0.0,
    );
    _ref.read(ttsStateProvider.notifier).speak('Navigation stopped');
  }

  /// Updates position and triggers spoken instructions as user walks
  void updatePosition(dynamic position) {
    final double lat = position.latitude;
    final double lng = position.longitude;

    state = state.copyWith(userLat: lat, userLng: lng);

    if (!state.isNavigating || state.steps.isEmpty) return;

    try {
      final instruction = _navService.getCurrentInstruction(lat, lng);
      final distance = _navService.getDistanceToNextTurn(lat, lng);

      if (instruction != null) {
        final speechText = instruction.instruction;
        state = state.copyWith(
          distanceToNextTurn: distance,
          currentStep: speechText,
        );

        if (_lastSpokenInstruction != speechText) {
          _lastSpokenInstruction = speechText;
          _ref.read(ttsStateProvider.notifier).speak(speechText);
        }
      } else {
        // Arrived
        _ref.read(ttsStateProvider.notifier).speak('You have arrived at your destination.');
        stopNavigation();
      }
    } catch (e) {
      // Ignored
    }
  }
}

/// Provider exposing navigation state notifier
final navigationStateProvider = StateNotifierProvider<NavigationStateNotifier, NavigationState>((ref) {
  return NavigationStateNotifier(
    ref.read(navigationServiceProvider),
    ref.read(locationServiceProvider),
    ref,
  );
});
