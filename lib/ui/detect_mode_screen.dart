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
  Timer? _scanTimer;
  bool _isProcessingSnapshot = false;
  StreamSubscription<dynamic>? _frameSub;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isActive = true;
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('detect');

      // Ensure camera is ready — only initialize if not already done
      final camState = ref.read(cameraStateProvider);
      if (!camState.isInitialized) {
        await ref.read(cameraStateProvider.notifier).initializeCamera();
      }

      await ref.read(detectionStateProvider.notifier).initialize();
      ref.read(detectionStateProvider.notifier).startDetection();

      // Wait for: (1) voice assistant TTS to finish, (2) old screen's deactivate() to run
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || !_isActive) return;
      ref.read(ttsStateProvider.notifier).speak('Object Detection active. Tap to analyze.');

      _startFrameStream();
      _startScanLoop();
    });
  }

  /// Subscribe to native camera frame stream ONLY while this screen is active
  void _startFrameStream() {
    final cameraService = ref.read(cameraServiceProvider);
    // Only subscribe to frame stream for phone camera (USB camera uses snapshot timer)
    final source = cameraService.currentSource;
    if (!source.isUsbCamera) {
      _frameSub = source.frameStream.listen((image) {
        if (!mounted || !_isActive) return;
        ref.read(detectionStateProvider.notifier).processFrame(image);
      });
    }
  }

  String? _lastAnnouncedObject;
  DateTime? _lastObjectSpeechTime;

  void _startScanLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (!mounted || !_isActive) return;
      
      final cameraService = ref.read(cameraServiceProvider);
      if (cameraService.currentSource.isUsbCamera) {
        // USB camera path: periodic snapshot every 3.5 seconds
        await _captureAndDetect(forceSpeak: false, useCloudGemini: false);
      }
      
      // Auto-announce if object changed or 10s passed
      if (!mounted || !_isActive) return;
      final results = ref.read(detectionStateProvider).results;
      if (results.isNotEmpty && !ref.read(ttsStateProvider).isSpeaking) {
        final label = results.first.label as String;
        final now = DateTime.now();
        final elapsed = _lastObjectSpeechTime == null
            ? 999
            : now.difference(_lastObjectSpeechTime!).inSeconds;
        if (label != _lastAnnouncedObject || elapsed >= 10) {
          _lastAnnouncedObject = label;
          _lastObjectSpeechTime = now;
          ref.read(ttsStateProvider.notifier).speak('$label detected');
        }
      }
    });
  }

  Future<void> _captureAndDetect({required bool forceSpeak, bool useCloudGemini = false}) async {
    if (_isProcessingSnapshot || !mounted || !_isActive) return;
    // Never run while TTS is speaking (prevents audio overlap)
    if (!forceSpeak && ref.read(ttsStateProvider).isSpeaking) return;

    try {
      _isProcessingSnapshot = true;
      final cameraService = ref.read(cameraServiceProvider);
      final bytes = await cameraService.extractFrame();
      if (bytes != null && bytes.isNotEmpty && mounted && _isActive) {
        await ref.read(detectionStateProvider.notifier).processImageBytes(
              bytes,
              forceSpeak: forceSpeak,
              useCloudGemini: useCloudGemini,
            );
      }
    } catch (e) {
      debugPrint('DetectMode: capture error: $e');
    } finally {
      _isProcessingSnapshot = false;
    }
  }

  void _cleanup() {
    _isActive = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    _frameSub?.cancel();
    _frameSub = null;
    
    // Capture notifier synchronously to safely call it after deactivate/dispose
    final notifier = ref.read(detectionStateProvider.notifier);
    Future.microtask(() {
      notifier.stopDetection();
    });
  }

  @override
  void deactivate() {
    _cleanup();
    super.deactivate();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detectionState = ref.watch(detectionStateProvider);

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
          onTap: () async {
            HapticFeedback.heavyImpact();
            ref.read(ttsStateProvider.notifier).speak('Analyzing with Gemini...');
            await _captureAndDetect(forceSpeak: true, useCloudGemini: true);
          },
          child: Stack(
            children: [
              const Positioned.fill(child: CameraPreviewWidget()),

              Positioned(
                top: 16.0,
                left: 16.0,
                right: 16.0,
                child: StatusBanner(
                  statusText: detectionState.isDetecting
                      ? (detectionState.results.isNotEmpty
                          ? 'Detected: ${detectionState.results.first.label}'
                          : 'Scanning for objects...')
                      : 'Detection paused',
                  isActive: detectionState.results.isNotEmpty,
                ),
              ),

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
                                  : 'Tap anywhere to analyze with Gemini',
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
