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
  Timer? _usbScanTimer;
  bool _isProcessingSnapshot = false;

  bool _isNewText(String newText, String? lastSpoken) {
    if (lastSpoken == null || lastSpoken.isEmpty) return true;
    final cleanNew = newText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanLast = lastSpoken.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanNew == cleanLast) return false;
    
    final wordsNew = cleanNew.split(' ').where((w) => w.isNotEmpty).toSet();
    final wordsLast = cleanLast.split(' ').where((w) => w.isNotEmpty).toSet();
    if (wordsNew.isEmpty) return false;
    
    final intersection = wordsNew.intersection(wordsLast);
    final similarity = intersection.length / wordsNew.length;
    // If >75% of words are the same, skip to prevent repetitive audio loops
    if (similarity > 0.75) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('read');
      ref.read(cameraStateProvider.notifier).initializeCamera();
      ref.read(ocrStateProvider.notifier).startContinuousScan();
      ref.read(ttsStateProvider.notifier).speak('Read Mode Active. Point camera at text.');
      _startUsbScanLoop();
    });
  }

  void _startUsbScanLoop() {
    _usbScanTimer?.cancel();
    // Calm 3.5 second cadence to prevent audio spam and lag
    _usbScanTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (_isContinuous && mounted) {
        _captureAndScan();
      }
    });
  }

  Future<void> _captureAndScan() async {
    if (_isProcessingSnapshot || !mounted) return;
    // Skip if TTS is actively reading text out loud
    if (ref.read(ttsStateProvider).isSpeaking) return;

    try {
      _isProcessingSnapshot = true;
      final cameraService = ref.read(cameraServiceProvider);
      final bytes = await cameraService.extractFrame();
      if (bytes != null && bytes.isNotEmpty && mounted) {
        await ref.read(ocrStateProvider.notifier).processImageBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error in _captureAndScan: $e');
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
    ref.read(ocrStateProvider.notifier).stopOcr();
    super.dispose();
  }

  void _toggleContinuous() {
    setState(() {
      _isContinuous = !_isContinuous;
      _lastSpokenText = null;
    });
    ref.read(ttsStateProvider.notifier).speak(_isContinuous ? 'Continuous scanning on' : 'Continuous scanning off');
    if (_isContinuous) {
      ref.read(ocrStateProvider.notifier).startContinuousScan();
    } else {
      ref.read(ocrStateProvider.notifier).stopOcr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrStateProvider);

    // Listen to camera frame stream for phone camera fallback
    ref.listen(cameraFrameStreamProvider, (previous, next) {
      if (!mounted) return;
      next.whenData((image) {
        if (!mounted) return;
        ref.read(ocrStateProvider.notifier).processFrame(image);
      });
    });

    // Auto-read recognized text smoothly without repeating identical text
    ref.listen(ocrStateProvider, (previous, next) {
      if (!mounted) return;
      final text = next.recognizedText;
      final isSpeaking = ref.read(ttsStateProvider).isSpeaking;
      
      // Do not interrupt while TTS is actively reading
      if (isSpeaking) return;

      if (text != null && text.isNotEmpty) {
        if (_isNewText(text, _lastSpokenText)) {
          _lastSpokenText = text;
          ref.read(ttsStateProvider.notifier).speak(text);
        }
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
            child: const Text('Read Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0)),
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
                  style: const TextStyle(color: Colors.redAccent, fontSize: 24.0, backgroundColor: Colors.black54),
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
