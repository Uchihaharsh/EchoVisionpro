import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:smart_glasses/ui/widgets/camera_preview.dart';
import 'package:smart_glasses/ui/widgets/status_banner.dart';
import 'package:smart_glasses/ui/widgets/voice_assistant_bar.dart';
import 'package:smart_glasses/providers/detection_providers.dart';
import 'package:smart_glasses/providers/camera_providers.dart';
import 'package:smart_glasses/providers/tts_providers.dart';
import 'package:smart_glasses/providers/voice_assistant_providers.dart';

class DetectModeScreen extends ConsumerStatefulWidget {
  const DetectModeScreen({super.key});

  @override
  ConsumerState<DetectModeScreen> createState() => _DetectModeScreenState();
}

class _DetectModeScreenState extends ConsumerState<DetectModeScreen> {
  Timer? _usbScanTimer;
  bool _isProcessingSnapshot = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('detect');
      ref.read(cameraStateProvider.notifier).initializeCamera();
      ref.read(detectionStateProvider.notifier).initialize();
      ref.read(detectionStateProvider.notifier).startDetection();
      ref.read(ttsStateProvider.notifier).speak('Object Detection Active. Point at objects or tap to analyze.');
      _startUsbScanLoop();
    });
  }

  void _startUsbScanLoop() {
    _usbScanTimer?.cancel();
    // Calm 3.5 second cadence to prevent lag and recursive audio spam
    _usbScanTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted) {
        _captureAndDetect(forceSpeak: false, useCloudGemini: false);
      }
    });
  }

  Future<void> _captureAndDetect({required bool forceSpeak, bool useCloudGemini = false}) async {
    if (_isProcessingSnapshot || !mounted) return;
    // Skip automatic background detection while TTS is speaking to prevent audio overlap
    if (!forceSpeak && ref.read(ttsStateProvider).isSpeaking) return;

    try {
      _isProcessingSnapshot = true;
      final cameraService = ref.read(cameraServiceProvider);
      final bytes = await cameraService.extractFrame();
      if (bytes != null && bytes.isNotEmpty && mounted) {
        await ref.read(detectionStateProvider.notifier).processImageBytes(
              bytes,
              forceSpeak: forceSpeak,
              useCloudGemini: useCloudGemini,
            );
      }
    } catch (e) {
      debugPrint('Error in Detect _captureAndDetect: $e');
    } finally {
      _isProcessingSnapshot = false;
    }
  }

  @override
  void deactivate() {
    _usbScanTimer?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _usbScanTimer?.cancel();
    WakelockPlus.disable();
    ref.read(detectionStateProvider.notifier).stopDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detectionState = ref.watch(detectionStateProvider);

    // Listen to camera frame stream for real-time smartphone camera detection
    ref.listen(cameraFrameStreamProvider, (previous, next) {
      if (!mounted) return;
      next.whenData((image) {
        if (!mounted) return;
        ref.read(detectionStateProvider.notifier).processFrame(image);
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
            child: const Text(
              'Object Detection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0),
            ),
          ),
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.blueAccent,
          iconTheme: const IconThemeData(size: 32.0),
          actions: [
            // Clear Home / Exit button
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap anywhere to run high-accuracy Gemini Vision inspection
        onTap: () async {
          HapticFeedback.heavyImpact();
          ref.read(ttsStateProvider.notifier).speak('Analyzing object with Gemini...');
          await _captureAndDetect(forceSpeak: true, useCloudGemini: true);
        },
        child: Stack(
          children: [
            // Full Screen Camera Feed
            const Positioned.fill(
              child: CameraPreviewWidget(),
            ),

            // Top Status Banner
            Positioned(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              child: StatusBanner(
                statusText: detectionState.isDetecting
                    ? (detectionState.results.isNotEmpty
                        ? 'Detected: ${detectionState.results.first.label}'
                        : 'Scanning for physical objects...')
                    : 'Detection paused',
                isActive: detectionState.results.isNotEmpty,
              ),
            ),

            // Center Visual Bounding Box for High-Confidence Objects
            if (detectionState.results.isNotEmpty)
              ...detectionState.results.map((result) {
                final screenW = MediaQuery.of(context).size.width;
                final screenH = MediaQuery.of(context).size.height;
                final w = (screenW * result.width).clamp(40.0, screenW * 0.85);
                final h = (screenH * result.height).clamp(40.0, screenH * 0.7);
                final l = (screenW * result.left).clamp(10.0, screenW - w - 10.0);
                final t = (screenH * result.top).clamp(70.0, screenH - h - 120.0);

                return Positioned(
                  left: l,
                  top: t,
                  width: w,
                  height: h,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 3.5),
                      borderRadius: BorderRadius.circular(12.0),
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        color: Colors.blueAccent,
                        child: Text(
                          '${result.label} ${(result.confidence * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

            // Bottom Instructions & On-Demand Scan Target
              Positioned(
                bottom: 24.0,
                left: 16.0,
                right: 16.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const VoiceAssistantBar(),
                    const SizedBox(height: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.blueAccent, width: 2.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app, color: Colors.yellowAccent, size: 28.0),
                        const SizedBox(width: 12.0),
                        Flexible(
                          child: Text(
                            detectionState.results.isNotEmpty
                                ? '${detectionState.results.first.label} (Tap to Re-Scan)'
                                : 'Tap anywhere to analyze object with Gemini',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
