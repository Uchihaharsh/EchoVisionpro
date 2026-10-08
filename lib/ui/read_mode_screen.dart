import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:smart_glasses/ui/widgets/camera_preview.dart';
import 'package:smart_glasses/ui/widgets/status_banner.dart';
import 'package:smart_glasses/ui/widgets/voice_assistant_bar.dart';
import 'package:smart_glasses/providers/ocr_providers.dart';
import 'package:smart_glasses/providers/camera_providers.dart';
import 'package:smart_glasses/providers/tts_providers.dart';
import 'package:smart_glasses/providers/voice_assistant_providers.dart';

class ReadModeScreen extends ConsumerStatefulWidget {
  const ReadModeScreen({super.key});

  @override
  ConsumerState<ReadModeScreen> createState() => _ReadModeScreenState();
}

class _ReadModeScreenState extends ConsumerState<ReadModeScreen> {
  bool _isContinuous = true;
  String? _lastSpokenText;
  Timer? _scanTimer;
  bool _isProcessingSnapshot = false;
  StreamSubscription<dynamic>? _frameSub;
  bool _isActive = false;

  bool _isNewText(String newText, String? lastSpoken) {
    if (lastSpoken == null || lastSpoken.isEmpty) return true;
    final cleanNew = newText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cleanLast = lastSpoken
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanNew == cleanLast) return false;
    final wordsNew = cleanNew.split(' ').where((w) => w.isNotEmpty).toSet();
    final wordsLast = cleanLast.split(' ').where((w) => w.isNotEmpty).toSet();
    if (wordsNew.isEmpty) return false;
    final intersection = wordsNew.intersection(wordsLast);
    final similarity = intersection.length / wordsNew.length;
    return similarity <= 0.75;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isActive = true;
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('read');

      final camState = ref.read(cameraStateProvider);
      if (!camState.isInitialized) {
        await ref.read(cameraStateProvider.notifier).initializeCamera();
      }

      ref.read(ocrStateProvider.notifier).startContinuousScan();

      // Wait for: (1) voice assistant TTS to finish, (2) old screen's deactivate() to run
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || !_isActive) return;
      ref.read(ttsStateProvider.notifier).speak('Read mode active. Point camera at text.');

      _startFrameStream();
      _startScanLoop();
    });
  }

  void _startFrameStream() {
    final cameraService = ref.read(cameraServiceProvider);
    final source = cameraService.currentSource;
    if (!source.isUsbCamera) {
      _frameSub = source.frameStream.listen((image) {
        if (!mounted || !_isActive) return;
        ref.read(ocrStateProvider.notifier).processFrame(image);
      });
    }
  }

  void _startScanLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (_isContinuous && mounted && _isActive) {
        await _captureAndScan();
        // After scan, check for new text to announce
        if (!mounted || !_isActive) return;
        final ocrState = ref.read(ocrStateProvider);
        final text = ocrState.recognizedText;
        if (text != null && text.isNotEmpty && !ref.read(ttsStateProvider).isSpeaking) {
          if (_isNewText(text, _lastSpokenText)) {
            _lastSpokenText = text;
            ref.read(ttsStateProvider.notifier).speak(text);
          }
        }
      }
    });
  }

  Future<void> _captureAndScan() async {
    if (_isProcessingSnapshot || !mounted || !_isActive) return;
    if (ref.read(ttsStateProvider).isSpeaking) return;

    try {
      _isProcessingSnapshot = true;
      final cameraService = ref.read(cameraServiceProvider);
      final bytes = await cameraService.extractFrame();
      if (bytes != null && bytes.isNotEmpty && mounted && _isActive) {
        await ref.read(ocrStateProvider.notifier).processImageBytes(bytes);
      }
    } catch (e) {
      debugPrint('ReadMode: capture error: $e');
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
    ref.read(ocrStateProvider.notifier).stopOcr();
  }

  void _toggleContinuous() {
    setState(() {
      _isContinuous = !_isContinuous;
      _lastSpokenText = null;
    });
    ref.read(ttsStateProvider.notifier)
        .speak(_isContinuous ? 'Continuous scanning on' : 'Continuous scanning off');
    if (_isContinuous) {
      ref.read(ocrStateProvider.notifier).startContinuousScan();
    } else {
      ref.read(ocrStateProvider.notifier).stopOcr();
    }
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
    final ocrState = ref.watch(ocrStateProvider);

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
            child: const Text('Read Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0)),
          ),
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.yellowAccent,
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
            _lastSpokenText = null;
            ref.read(ocrStateProvider.notifier).startContinuousScan();
            ref.read(ttsStateProvider.notifier).speak('Scanning text.');
            await _captureAndScan();
            // Immediately read new result on manual tap
            if (!mounted || !_isActive) return;
            final ocrState = ref.read(ocrStateProvider);
            final text = ocrState.recognizedText;
            if (text != null && text.isNotEmpty) {
              _lastSpokenText = text;
              ref.read(ttsStateProvider.notifier).speak(text);
            }
          },
          child: Stack(
            children: [
              const CameraPreviewWidget(),

              Align(
                alignment: Alignment.topCenter,
                child: StatusBanner(
                  statusText: _isContinuous ? 'Scanning continuously...' : 'Point at text to read',
                  isActive: _isContinuous,
                  icon: Icons.text_fields,
                ),
              ),

              if (ocrState.error != null)
                Center(
                  child: Text(
                    'Error: ${ocrState.error}',
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 24.0,
                        backgroundColor: Colors.black54),
                  ),
                ),

              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: VoiceAssistantBar(),
                    ),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.30,
                      width: double.infinity,
                      color: Colors.black87,
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            (ocrState.recognizedText != null && ocrState.recognizedText!.isNotEmpty)
                                ? ocrState.recognizedText!
                                : 'No text detected yet. Tap screen to scan.',
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontSize: 26.0,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Semantics(
          label: _isContinuous ? 'Stop continuous scan' : 'Start continuous scan',
          button: true,
          child: SizedBox(
            width: 80.0,
            height: 80.0,
            child: FloatingActionButton(
              backgroundColor: _isContinuous ? Colors.redAccent : Colors.yellowAccent,
              foregroundColor: Colors.black,
              onPressed: _toggleContinuous,
              child: Icon(_isContinuous ? Icons.stop : Icons.play_arrow, size: 40.0),
            ),
          ),
        ),
      ),
    );
  }
}
