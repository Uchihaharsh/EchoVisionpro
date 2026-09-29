import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:smart_glasses/ui/widgets/camera_preview.dart';
import 'package:smart_glasses/ui/widgets/status_banner.dart';
import 'package:smart_glasses/ui/widgets/voice_assistant_bar.dart';
import 'package:smart_glasses/providers/currency_providers.dart';
import 'package:smart_glasses/providers/camera_providers.dart';
import 'package:smart_glasses/providers/tts_providers.dart';
import 'package:smart_glasses/providers/voice_assistant_providers.dart';

class CurrencyModeScreen extends ConsumerStatefulWidget {
  const CurrencyModeScreen({super.key});

  @override
  ConsumerState<CurrencyModeScreen> createState() => _CurrencyModeScreenState();
}

class _CurrencyModeScreenState extends ConsumerState<CurrencyModeScreen> {
  Timer? _usbScanTimer;
  bool _isProcessingSnapshot = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('currency');
      ref.read(cameraStateProvider.notifier).initializeCamera();
      ref.read(currencyStateProvider.notifier).initialize();
      ref.read(currencyStateProvider.notifier).startScanning();
      ref.read(ttsStateProvider.notifier).speak('Currency Recognition Active. Point camera at banknote.');
      _startUsbScanLoop();
    });
  }

  void _startUsbScanLoop() {
    _usbScanTimer?.cancel();
    // Calm 3.0 second cadence to prevent audio spam and lag
    _usbScanTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (mounted) {
        _captureAndScan();
      }
    });
  }

  Future<void> _captureAndScan() async {
    if (_isProcessingSnapshot || !mounted) return;
    // Skip if TTS is currently announcing a denomination
    if (ref.read(ttsStateProvider).isSpeaking) return;

    try {
      _isProcessingSnapshot = true;
      final cameraService = ref.read(cameraServiceProvider);
      final bytes = await cameraService.extractFrame();
      if (bytes != null && bytes.isNotEmpty && mounted) {
        await ref.read(currencyStateProvider.notifier).processImageBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error in Currency _captureAndScan: $e');
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
    ref.read(currencyStateProvider.notifier).stopScanning();
    super.dispose();
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.greenAccent;
    if (confidence >= 0.5) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final currencyState = ref.watch(currencyStateProvider);

    // Listen to camera frame stream for phone camera fallback
    ref.listen(cameraFrameStreamProvider, (previous, next) {
      if (!mounted) return;
      next.whenData((image) {
        if (!mounted) return;
        ref.read(currencyStateProvider.notifier).processFrame(image);
      });
    });

    ref.listen(currencyStateProvider, (previous, next) {
      if (!mounted) return;
      if (next.denomination != null && next.denomination != previous?.denomination) {
        ref.read(ttsStateProvider.notifier).speak('${next.denomination} Rupees detected', interrupt: true);
      }
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
            child: const Text('Currency Recognition', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0)),
          ),
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.greenAccent,
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
          ref.read(ttsStateProvider.notifier).speak('Scanning banknote.');
          await _captureAndScan();
        },
        child: Stack(
          children: [
            const CameraPreviewWidget(),
            
            const Align(
              alignment: Alignment.topCenter,
              child: StatusBanner(
                statusText: 'Point camera at a bank note',
                isActive: true,
                icon: Icons.currency_rupee,
              ),
            ),
            
            if (currencyState.denomination != null)
              Center(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(
                        color: _getConfidenceColor(currencyState.confidence),
                        width: 4.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: '${currencyState.denomination} Rupees',
                          child: Text(
                            '₹${currencyState.denomination}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 72.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Confidence: ${(currencyState.confidence * 100).toInt()}%',
                          style: TextStyle(
                            color: _getConfidenceColor(currencyState.confidence),
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Persistent Voice Assistant Bar for voice & touch access
            const Positioned(
              bottom: 24.0,
              left: 16.0,
              right: 16.0,
              child: VoiceAssistantBar(),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
