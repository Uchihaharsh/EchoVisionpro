import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:smart_glasses/ui/widgets/accessible_button.dart';
import 'package:smart_glasses/ui/widgets/voice_assistant_bar.dart';
import 'package:smart_glasses/providers/navigation_providers.dart';
import 'package:smart_glasses/providers/tts_providers.dart';
import 'package:smart_glasses/providers/voice_assistant_providers.dart';

class NavigateModeScreen extends ConsumerStatefulWidget {
  final String? initialDestination;
  const NavigateModeScreen({super.key, this.initialDestination});

  @override
  ConsumerState<NavigateModeScreen> createState() => _NavigateModeScreenState();
}

class _NavigateModeScreenState extends ConsumerState<NavigateModeScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final MapController _mapController = MapController();

  final List<String> _quickDestinations = [
    'Hospital',
    'Pharmacy',
    'Bus Stop',
    'Supermarket',
    'Metro Station',
    'ATM',
  ];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('navigate');
      ref.read(locationServiceProvider).startTracking();
      if (widget.initialDestination != null && widget.initialDestination!.trim().isNotEmpty) {
        _startNavigation(widget.initialDestination!.trim());
      } else {
        ref.read(ttsStateProvider.notifier).speak(
          'Navigation Mode Active. Interactive map ready. Enter a destination or tap Where Am I.',
        );
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _destinationController.dispose();
    ref.read(locationServiceProvider).stopTracking();
    ref.read(navigationStateProvider.notifier).stopNavigation();
    super.dispose();
  }

  void _startNavigation(String destination) {
    if (destination.trim().isNotEmpty) {
      _destinationController.text = destination;
      ref.read(navigationStateProvider.notifier).startNavigation(destination);
    }
  }

  void _stopNavigation() {
    ref.read(navigationStateProvider.notifier).stopNavigation();
    _destinationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);
    final userLat = navState.userLat ?? 20.5937; // Default India Center fallback
    final userLng = navState.userLng ?? 78.9629;
    final userPos = LatLng(userLat, userLng);

    // Track live position and update map & navigation state
    ref.listen(locationServiceProvider.select((s) => s.startTracking()), (previous, next) {
      next.listen((position) {
        ref.read(navigationStateProvider.notifier).updatePosition(position);
        if (mounted && navState.userLat != null && navState.userLng != null) {
          _mapController.move(LatLng(position.latitude, position.longitude), 17.0);
        }
      });
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('home');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Semantics(
            header: true,
            child: const Text('Navigation & Live Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0)),
          ),
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.orangeAccent,
          iconTheme: const IconThemeData(size: 32.0),
          actions: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.yellowAccent, size: 28.0),
              tooltip: 'Return to Home Screen',
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(ttsStateProvider.notifier).speak('Returning to home screen');
                ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('home');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      body: Column(
        children: [
          // 1. Interactive Live Visual Map (OpenStreetMap Vector/Raster Tiles)
          Expanded(
            flex: navState.isNavigating ? 4 : 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: userPos,
                    initialZoom: 16.0,
                    minZoom: 4.0,
                    maxZoom: 19.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smart_glasses',
                    ),
                    
                    // Route Polyline (Blue Navigation Path)
                    if (navState.routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: navState.routePoints,
                            strokeWidth: 6.0,
                            color: Colors.blueAccent,
                          ),
                        ],
                      ),

                    // Markers (Live User Location + Destination Pin)
                    MarkerLayer(
                      markers: [
                        // Current User Marker (Pulsing Blue Dot)
                        if (navState.userLat != null && navState.userLng != null)
                          Marker(
                            point: LatLng(navState.userLat!, navState.userLng!),
                            width: 50.0,
                            height: 50.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.navigation,
                                  color: Colors.blueAccent,
                                  size: 32.0,
                                ),
                              ),
                            ),
                          ),

                        // Destination Flag Marker
                        if (navState.targetLat != null && navState.targetLng != null)
                          Marker(
                            point: LatLng(navState.targetLat!, navState.targetLng!),
                            width: 45.0,
                            height: 45.0,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 45.0,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Recenter GPS Button
                Positioned(
                  right: 16.0,
                  bottom: 16.0,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.orangeAccent,
                    onPressed: () {
                      if (navState.userLat != null && navState.userLng != null) {
                        _mapController.move(LatLng(navState.userLat!, navState.userLng!), 17.0);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // 2. Navigation Controls & Accessible Information Panel
          Expanded(
            flex: navState.isNavigating ? 5 : 4,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: navState.isNavigating
                  ? _buildActiveNavigationPanel(navState)
                  : _buildDestinationSelectionPanel(navState),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDestinationSelectionPanel(NavigationState navState) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Voice Assistant Bar for voice destination and navigation commands
          const VoiceAssistantBar(),
          const SizedBox(height: 12.0),

          // "Where Am I?" 1-Tap Location Announcement
          AccessibleButton(
            label: 'Where Am I Right Now?',
            icon: Icons.my_location,
            backgroundColor: Colors.blueAccent,
            textColor: Colors.white,
            onPressed: () {
              ref.read(navigationStateProvider.notifier).announceCurrentLocation();
            },
          ),
          const SizedBox(height: 12.0),

          if (navState.currentAddress != null)
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: Colors.blueGrey[900],
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.blueAccent, width: 2.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.blueAccent, size: 24.0),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      navState.currentAddress!,
                      style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Destination Search Field
          Semantics(
            label: 'Destination Input Field',
            child: TextField(
              controller: _destinationController,
              style: const TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Enter Destination / Landmark',
                labelStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 16.0),
                hintText: 'e.g. City Mall, Apollo Hospital',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.orangeAccent, size: 26.0),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orangeAccent, width: 2.0),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.yellowAccent, width: 3.0),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              onSubmitted: (val) => _startNavigation(val),
            ),
          ),
          const SizedBox(height: 12.0),

          // Start Walking Navigation Button
          AccessibleButton(
            label: navState.isLoading ? 'Calculating Route...' : 'Start Walking Navigation',
            icon: Icons.directions_walk,
            backgroundColor: Colors.orangeAccent,
            textColor: Colors.black,
            onPressed: navState.isLoading
                ? () {}
                : () => _startNavigation(_destinationController.text),
          ),
          const SizedBox(height: 16.0),

          const Text(
            'Quick Destinations:',
            style: TextStyle(color: Colors.white70, fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),

          // Quick Destination Chips
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _quickDestinations.map((dest) {
              return ActionChip(
                backgroundColor: Colors.grey[900],
                side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
                label: Text(
                  dest,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                avatar: const Icon(Icons.location_on, color: Colors.orangeAccent, size: 18.0),
                onPressed: () => _startNavigation('Nearby $dest'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNavigationPanel(NavigationState navState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Voice Assistant Bar for hands-free navigation commands
        const VoiceAssistantBar(),
        const SizedBox(height: 8.0),

        // Giant Turn Card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.orangeAccent, width: 3.0),
          ),
          child: Column(
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  navState.currentInstruction ?? 'Proceeding along route...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  '${navState.distanceToNextTurn.toInt()} meters away',
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 22.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8.0),

        // Upcoming Route Steps
        Expanded(
          child: ListView.builder(
            itemCount: navState.upcomingSteps.length,
            itemBuilder: (context, index) {
              final isFirst = index == 0;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2.0),
                decoration: BoxDecoration(
                  color: isFirst ? Colors.orangeAccent.withValues(alpha: 0.15) : Colors.grey[900],
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isFirst ? Colors.orangeAccent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.arrow_forward,
                    color: isFirst ? Colors.orangeAccent : Colors.white60,
                    size: 22.0,
                  ),
                  title: Text(
                    navState.upcomingSteps[index],
                    style: TextStyle(
                      color: isFirst ? Colors.white : Colors.white70,
                      fontSize: 16.0,
                      fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8.0),

        // Stop Navigation Button
        AccessibleButton(
          label: 'Stop Navigation',
          icon: Icons.stop,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          onPressed: _stopNavigation,
        ),
      ],
    );
  }
}
