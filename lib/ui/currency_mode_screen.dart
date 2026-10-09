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
  Timer? _scanTimer;
  bool _isProcessingSnapshot = false;
  StreamSubscription<dynamic>? _frameSub;
  bool _isActive = false;
  String? _lastAnnouncedDenomination;
  DateTime? _lastAnnouncedTime;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isActive = true;
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('currency');

      await ref.read(cameraStateProvider.notifier).initializeCamera();

      await ref.read(currencyStateProvider.notifier).initialize();
      ref.read(currencyStateProvider.notifier).startScanning();

      _startFrameStream();
      _startScanLoop();

      if (!mounted || !_isActive) return;
      ref.read(ttsStateProvider.notifier).speak(
        'Currency mode active. Point camera at banknote.',
        interrupt: true,
      );
    });
  }

  void _announceDenominationIfNeeded(String denom, {bool force = false}) {
    if (!mounted || !_isActive) return;
    final now = DateTime.now();
    final isSameDenom = denom == _lastAnnouncedDenomination;
    final cooldownElapsed = _lastAnnouncedTime == null ||
        now.difference(_lastAnnouncedTime!).inMilliseconds > 4000;

    if (force || !isSameDenom || cooldownElapsed) {
      _lastAnnouncedDenomination = denom;
      _lastAnnouncedTime = now;
      HapticFeedback.heavyImpact();
      ref.read(ttsStateProvider.notifier).speak('$denom Rupees detected', interrupt: true);
    }
  }

  void _startFrameStream() {
    _frameSub?.cancel();
    _frameSub = null;
    final cameraService = ref.read(cameraServiceProvider);
    final source = cameraService.currentSource;
    if (!source.isUsbCamera) {
      _frameSub = source.frameStream.listen((image) async {
        if (!mounted || !_isActive) return;
        final denom = await ref.read(currencyStateProvider.notifier).processFrame(image);
        if (denom != null && mounted && _isActive) {
          _announceDenominationIfNeeded(denom);
        }
      });
    }
  }

  void _startScanLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) async {
      if (!mounted || !_isActive) return;

      final cameraService = ref.read(cameraServiceProvider);
      if (cameraService.currentSource.isUsbCamera) {
        if (_frameSub != null) {
          _frameSub?.cancel();
          _frameSub = null;
        }
        await _captureAndScan();
      } else {
        if (_frameSub == null) {
          _startFrameStream();
        }
      }
    });
  }

  Future<void> _captureAndScan({bool forceAnnounce = false}) async {
    if (_isProcessingSnapshot || !mounted || !_isActive) return;
    if (!forceAnnounce && ref.read(ttsStateProvider).isSpeaking) return;

    try {
      _isProcessingSnapshot = true;
      final cameraService = ref.read(cameraServiceProvider);
      final bytes = await cameraService.extractFrame();
      if (bytes != null && bytes.isNotEmpty && mounted && _isActive) {
        final result = await ref.read(currencyStateProvider.notifier).processImageBytes(bytes);
        if (result != null) {
          _announceDenominationIfNeeded(result, force: forceAnnounce);
        } else if (forceAnnounce) {
          ref.read(ttsStateProvider.notifier).speak(
            'No banknote detected yet. Hold note steady in front of camera.',
            interrupt: true,
          );
        }
      }
    } catch (e) {
      debugPrint('CurrencyMode: capture error: $e');
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

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.greenAccent;
    if (confidence >= 0.5) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final currencyState = ref.watch(currencyStateProvider);

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
            child: const Text('Currency Recognition',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0)),
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
            HapticFeedback.mediumImpact();
            _lastAnnouncedDenomination = null;
            _lastAnnouncedTime = null;
            final cameraService = ref.read(cameraServiceProvider);
            if (cameraService.currentSource.isUsbCamera) {
              await _captureAndScan(forceAnnounce: true);
            } else {
              final currentDenom = ref.read(currencyStateProvider).denomination;
              if (currentDenom != null) {
                _announceDenominationIfNeeded(currentDenom, force: true);
              } else {
                ref.read(ttsStateProvider.notifier).speak(
                  'Scanning banknote. Hold note steady.',
                  interrupt: true,
                );
              }
            }
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
