import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:smart_glasses/ui/widgets/accessible_button.dart';
import 'package:smart_glasses/ui/widgets/voice_assistant_bar.dart';
import 'package:smart_glasses/ui/widgets/gemini_wave_overlay.dart';
import 'package:smart_glasses/ui/read_mode_screen.dart';
import 'package:smart_glasses/ui/detect_mode_screen.dart';
import 'package:smart_glasses/ui/currency_mode_screen.dart';
import 'package:smart_glasses/ui/navigate_mode_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_glasses/providers/tts_providers.dart';
import 'package:smart_glasses/providers/camera_providers.dart';
import 'package:smart_glasses/providers/voice_assistant_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen('home');
      ref.read(ttsStateProvider.notifier).initialize();
      _requestPermissionsAndStartAssistant();
    });
  }

  Future<void> _requestPermissionsAndStartAssistant() async {
    final statuses = await [
      Permission.camera,
      Permission.location,
      Permission.microphone,
    ].request();

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final camGranted = statuses[Permission.camera]?.isGranted ?? false;

    if (micGranted && camGranted) {
      // Initialize Camera ONLY AFTER permissions are granted to prevent UVC plugin deadlock
      ref.read(cameraStateProvider.notifier).initialize();
      
      await ref.read(voiceAssistantStateProvider.notifier).startContinuousListening();
      ref.read(ttsStateProvider.notifier).speak(
        'Echo is listening. Say Hey Echo, double tap anywhere, or tap any button.',
      );
    } else {
      ref.read(ttsStateProvider.notifier).speak(
        'Critical permissions were denied. Please go to your phone Settings, find Echo Vision, and allow both Microphone and Camera access for the app to function.',
        
      );
    }
  }

  void _navigateTo(BuildContext context, Widget screen, String screenKey, String announcement) {
    ref.read(voiceAssistantStateProvider.notifier).setCurrentScreen(screenKey);
    HapticFeedback.heavyImpact();
    ref.read(ttsStateProvider.notifier).speak(announcement);

    // Pop all child screens back to root so previous screens run their dispose cleanly
    if (Navigator.canPop(context)) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Push new screen cleanly
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraStateProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Double tap anywhere on screen to trigger Gemini listening for blind users!
      onDoubleTap: () {
        ref.read(voiceAssistantStateProvider.notifier).startListening();
      },
      child: Scaffold(
        backgroundColor: Colors.black, // High contrast background
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Semantics(
                  header: true,
                  child: const Text(
                    'VisionAssist',
                    style: TextStyle(
                      fontSize: 34.0,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.yellowAccent,
                          blurRadius: 10.0,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 2.0),
                const Text(
                  'Gemini AI Smart Glasses Assistant',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),

                // Camera Source Switcher Bar (IMX378 USB Smart Glasses vs Phone Camera)
                Semantics(
                  button: true,
                  label: 'Active camera: ${cameraState.cameraName}. Tap to switch camera.',
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(cameraStateProvider.notifier).toggleCameraSource();
                      final updatedCamera = ref.read(cameraStateProvider).cameraName;
                      ref.read(ttsStateProvider.notifier).speak('Switched to $updatedCamera');
                    },
                    borderRadius: BorderRadius.circular(14.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(
                          color: cameraState.isUsbCamera ? Colors.cyanAccent : Colors.yellowAccent,
                          width: 2.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cameraState.isUsbCamera ? Icons.usb : Icons.camera_alt,
                            color: cameraState.isUsbCamera ? Colors.cyanAccent : Colors.yellowAccent,
                            size: 22.0,
                          ),
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: Text(
                              cameraState.isUsbCamera
                                  ? 'Camera: IMX378 Smart Glasses'
                                  : 'Camera: Phone (Tap to Switch)',
                              style: TextStyle(
                                color: cameraState.isUsbCamera ? Colors.cyanAccent : Colors.white,
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8.0),

                // Voice Assistant Bar (Microphone activator + Live Status)
                const VoiceAssistantBar(),

                // Animated Gemini AI Wave / Thinking Overlay
                const GeminiWaveOverlay(),

                const SizedBox(height: 12.0),

                // 4 Accessible Primary Buttons (Touch Response 100% active)
                AccessibleButton(
                  label: 'Read Text',
                  icon: Icons.menu_book,
                  backgroundColor: Colors.amber,
                  onPressed: () => _navigateTo(context, const ReadModeScreen(), 'read', 'Read Text Mode Selected'),
                ),
                const SizedBox(height: 10.0),
                AccessibleButton(
                  label: 'Detect Objects',
                  icon: Icons.visibility,
                  backgroundColor: Colors.blueAccent,
                  onPressed: () => _navigateTo(context, const DetectModeScreen(), 'detect', 'Object Detection Mode Selected'),
                ),
                const SizedBox(height: 10.0),
                AccessibleButton(
                  label: 'Currency',
                  icon: Icons.currency_rupee,
                  backgroundColor: Colors.greenAccent,
                  onPressed: () => _navigateTo(context, const CurrencyModeScreen(), 'currency', 'Currency Mode Selected'),
                ),
                const SizedBox(height: 10.0),
                AccessibleButton(
                  label: 'Navigate',
                  icon: Icons.navigation,
                  backgroundColor: Colors.orangeAccent,
                  onPressed: () => _navigateTo(context, const NavigateModeScreen(), 'navigate', 'Navigation Mode Selected'),
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
