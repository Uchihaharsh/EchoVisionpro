# VisionAssist Smart Glasses — System Architecture

## Architectural Pattern Overview

VisionAssist is built on a **Layered Clean Architecture** combined with **Reactive State Management** using `flutter_riverpod` (v2.6.1). The codebase strictly separates visual presentation, state orchestration, background hardware/network services, domain data models, and core utilities.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           PRESENTATION LAYER                            │
│  UI Screens: HomeScreen, DetectModeScreen, CurrencyModeScreen,          │
│              ReadModeScreen, NavigateModeScreen                         │
│  UI Widgets: CameraPreviewWidget, VoiceAssistantBar, GeminiWaveOverlay, │
│              AccessibleButton, StatusBanner                             │
└────────────────────────────────────▲────────────────────────────────────┘
                                     │ Watches State / Triggers Notifiers
┌────────────────────────────────────▼────────────────────────────────────┐
│                    APPLICATION STATE LAYER (RIVERPOD)                   │
│  StateNotifiers & States:                                               │
│    • CameraStateNotifier (cameraStateProvider)                          │
│    • DetectionStateNotifier (detectionStateProvider)                    │
│    • CurrencyStateNotifier (currencyStateProvider)                      │
│    • OcrStateNotifier (ocrStateProvider)                                │
│    • NavigationStateNotifier (navigationStateProvider)                  │
│    • VoiceAssistantNotifier (voiceAssistantStateProvider)              │
│    • TTSStateNotifier (ttsStateProvider)                                │
│  StreamProviders:                                                       │
│    • cameraFrameStreamProvider, voiceCommandStreamProvider              │
└────────────────────────────────────▲────────────────────────────────────┘
                                     │ Injects & Calls Services
┌────────────────────────────────────▼────────────────────────────────────┐
│                       SERVICES & INFRASTRUCTURE                         │
│  Hardware / Platform Services:                                          │
│    • CameraService (NativeCameraSource vs UvcCameraSource)              │
│    • TTSService (Queue, Priority, Watchdog)                             │
│    • LocationService (Geolocator GPS stream)                            │
│  AI / ML Inference Services:                                            │
│    • ObjectDetectionService (Google ML Kit ImageLabeler)                │
│    • CurrencyService (Google ML Kit TextRecognizer)                     │
│    • OcrService (Google ML Kit Latin TextRecognizer)                    │
│    • TFLiteService (tflite_flutter interpreter pool)                    │
│  Cloud / Conversational Services:                                       │
│    • VoiceAssistantService (SpeechToText continuous listener)           │
│    • GeminiAssistantService (Google Generative AI 1.5 Flash + Vision)   │
│    • NavigationService (OSRM foot engine + Google Directions fallback)  │
└────────────────────────────────────▲────────────────────────────────────┘
                                     │ Uses / Instantiates
┌────────────────────────────────────▼────────────────────────────────────┐
│                        DOMAIN MODELS & CORE UTILS                       │
│  Models: DetectionResult, CurrencyResult, OcrResult, NavigationStep    │
│  Core:   AppConstants, AppTheme, AudioFeedback, ImageUtils              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Subsystem Architectures

### 1. Vision & Camera Pipeline

The camera subsystem supports dual hardware sources via the **Strategy Pattern**:
- **Built-in Smartphone Camera** (`NativeCameraSource`): Powered by Flutter's official `camera` plugin.
- **External IMX378 Smart Glasses Camera** (`UvcCameraSource`): Powered by `flutter_ffi_uvc`, connecting via USB-C OTG to the Sony IMX378 12MP 30 FPS sensor on the smart glasses frame.

```
                    ┌────────────────────────┐
                    │ CameraService (Facade) │
                    └───────────┬────────────┘
                                │ Swaps currentSource
             ┌──────────────────┴──────────────────┐
             ▼                                     ▼
┌─────────────────────────┐           ┌─────────────────────────┐
│   NativeCameraSource    │           │     UvcCameraSource     │
│  (Phone back camera)    │           │ (Sony IMX378 USB-C UVC) │
├─────────────────────────┤           ├─────────────────────────┤
│ • CameraController      │           │ • flutter_ffi_uvc FFI   │
│ • Throttled frameStream │           │ • Native preview texture│
│   (~8 FPS / 125ms)      │           │   (textureId binding)   │
│ • ImageFormatGroup.nv21 │           │ • takePicture() JPEGs   │
│ • extractFrame()        │           │ • extractFrame()        │
└─────────────────────────┘           └─────────────────────────┘
             │                                     │
             └──────────────────┬──────────────────┘
                                ▼
              Stream<CameraImage> / Uint8List JPEG
                                ▼
         ┌──────────────────────────────────────────┐
         │ ImageUtils Processing Pipeline           │
         │ • convertYUV420ToRGB()                   │
         │ • resizeImage() (300x300 / 224x224)      │
         │ • normalizePixels() [0.0, 1.0]           │
         │ • getCameraImageBytes()                  │
         └──────────────────────────────────────────┘
```

#### Dual-Camera Discovery & Switch Mechanics
1. On startup or when toggled, `CameraService.initialize()` calls `hasUsbCameraAttached()`, which queries `uvcCamera.listUsbDevices()`.
2. If an IMX378 camera is connected via USB-C, `UvcCameraSource` is activated:
   - Allocates a Flutter texture with `uvcCamera.createPreviewTexture()`.
   - Starts HD preview using `uvcCamera.startPreviewAuto(preference: UvcAutoPreviewPreference.quality)`.
   - Attaches the texture with the returned hardware aspect ratio (`width / height`).
3. If no USB camera is present or an error occurs, it falls back seamlessly to `NativeCameraSource`.
4. In the UI (`CameraPreviewWidget`), if `textureId != null`, a hardware-accelerated `Texture(textureId: ...)` widget renders the glasses feed. Otherwise, `CameraPreview(controller)` renders the native phone camera.

---

### 2. AI / ML Inference Pipelines

VisionAssist performs real-time edge processing and fallback cloud multimodal processing:

```
                          Camera Frame Extraction
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                 ▼
             Native CameraImage                 USB-C JPEG Bytes
                    │                                 │
                    ▼                                 ▼
         Mode-Specific Service:            Mode-Specific Service:
        • ObjectDetectionService          • ObjectDetectionService
        • CurrencyService                 • CurrencyService
        • OcrService                      • OcrService
                    │                                 │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                 ▼
         [Edge ML Kit Inference]             [Cloud Gemini Vision]
         • ImageLabeler (threshold 0.28)    • gemini-1.5-flash
         • TextRecognizer (Latin script)     • describeCameraScene()
         • Physical Object Rule Engine       • Natural scene summary
                    │                                 │
                    └────────────────┬────────────────┘
                                     ▼
                        Domain Result Generation:
              DetectionResult / CurrencyResult / OcrResult
                                     │
                                     ▼
                           Spoken TTS Feedback
                       (Filtered for Repetition)
```

#### A. Object Detection Architecture (`ObjectDetectionService`)
- **Semantic Rule Filtering**: Bypasses raw abstract ImageNet/COCO labels ("monochrome", "parallel", "font", "material", "ceiling").
- **18 Physical Everyday Object Categories**: Rule groups mapped with prioritized keyword synonym lists:
  1. *Laptop/Computer* (screen, keyboard, macbook, monitor)
  2. *Mobile phone* (smartphone, telephone, cellular)
  3. *Bottle* (water bottle, flask, thermos, drinkware)
  4. *Cup* (mug, coffee cup, ceramic)
  5. *Chair* (seat, armchair, stool, bench, office chair)
  6. *Table* (desk, workstation, dining table, countertop)
  7. *Person* (human, man, woman, face, child)
  8. *Book* (textbook, notebook, document, novel)
  9. *Backpack* (bag, luggage, handbag, tote)
  10. *Door* (entryway, doorway, exit)
  11. *Shoes* (sneakers, footwear, boot)
  12. *Bed* (cot, mattress, pillow)
  13. *Couch* (sofa, futon)
  14. *Television* (tv, monitor, flat panel)
  15. *Vehicle* (car, bus, bicycle, motorcycle)
  16. *Glasses* (eyewear, sunglasses, spectacles)
  17. *Clock* (watch, wrist watch)
  18. *Plate* (dishware, bowl, spoon, fork, cutlery)
- **Spatial Positioning**: Divides the camera width into three zones (`left`, `ahead`, `right`) to speak accessible spatial guidance: `"Chair to the left"`, `"Person ahead"`.
- **Anti-Audio-Spam Gate**: Announces an object immediately on manual tap; for automatic background scanning, only announces if the detected label has changed or if 10 seconds have elapsed, and **never** announces while TTS is currently speaking.

#### B. Banknote Recognition Architecture (`CurrencyService`)
- Uses high-speed Latin `TextRecognizer` scanning for numeric banknote patterns (`\b(500|200|100|50|20|10)\b`).
- Validates against Indian Rupee denomination maps (`₹10`, `₹20`, `₹50`, `₹100`, `₹200`, `₹500`).
- Returns `CurrencyResult` with confidence rating; speaks denomination with interrupt priority when confirmed.

#### C. Optical Character Recognition Architecture (`OcrService`)
- Uses Google ML Kit's `TextRecognizer` to extract text blocks.
- Sorts blocks vertically by `boundingBox.top` to reconstruct natural reading order.
- Applies Jaccard character-set similarity threshold (0.75-0.80) in `ReadModeScreen` to suppress reading repetitions when the camera shakes.

---

### 3. Voice Assistant & Gemini Agent Architecture

The app provides hands-free accessibility via continuous microphone listening and dual-tier intent parsing:

```
                              User Spoken Input
                                     │
                                     ▼
                    ┌─────────────────────────────────┐
                    │      VoiceAssistantService      │
                    │  (continuous speech_to_text)    │
                    │  Auto-restarts after utterance  │
                    └────────────────┬────────────────┘
                                     │ Stream<VoiceCommand>
                                     ▼
                    ┌─────────────────────────────────┐
                    │     VoiceAssistantNotifier      │
                    │   (StateNotifier coordination)  │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │ Intent Dispatching Pipeline     │
                    ▼                                 ▼
       ┌─────────────────────────┐       ┌─────────────────────────┐
       │   Gemini Generative AI  │       │ Offline Semantic Parser │
       │  gemini-1.5-flash (LLM) │       │ (High-resilience regex) │
       │ JSON Schema Structured  │       │ Wake-word: "Hey Echo"   │
       │ Output with 4s Timeout  │       │ Fast zero-latency match │
       └────────────┬────────────┘       └────────────┬────────────┘
                    │                                 │
                    └────────────────┬────────────────┘
                                     ▼
                             VoiceCommandType
  [openCurrency | openReadText | openObjectDetection | openNavigation |
   whereAmI | switchCamera | describeScene | goHome | help | unknown]
                                     │
              ┌──────────────────────┴──────────────────────┐
              ▼                                             ▼
  Screen Navigation / Action                    Auditory Response
  via appNavigatorKey                           via TTSService
```

#### Acoustic Echo Prevention Loop
To prevent the microphone from picking up the app's own TTS output and causing infinite feedback loops:
1. `VoiceAssistantNotifier` listens directly to `ttsStateProvider`.
2. When `next.isSpeaking == true`, it immediately calls `_voiceService.pauseForTts()`, which halts the speech recognizer.
3. When `previous.isSpeaking == true && !next.isSpeaking`, after a 500ms acoustic decay delay, it calls `_voiceService.resumeAfterTts()`.

#### Multimodal Scene Query Handling
When the user asks *"What am I looking at?"* or *"Describe the scene"*:
1. `GeminiAssistantService` identifies the request as `describeScene`.
2. TTS immediately speaks *"Looking through your smart glasses now..."*.
3. `VoiceAssistantNotifier` calls `cameraService.extractFrame()` to snapshot the live IMX378/native camera buffer.
4. The JPEG bytes are transmitted to `gemini-1.5-flash` with a tailored prompt acting as empathetic eyes for a blind individual.
5. The concise 2-sentence spatial description is read aloud via TTS and shown on the `GeminiWaveOverlay`.

---

### 4. Turn-by-Turn Navigation Subsystem

Designed specifically for pedestrian mobility for visually impaired users:

```
 ┌────────────────────────┐                   ┌────────────────────────┐
 │    LocationService     │                   │   NavigationService    │
 │ • Geolocator stream    │                   │ • OSRM Foot Routing    │
 │ • distanceFilter: 2m   │                   │ • Google Dir. Fallback │
 │ • High accuracy GPS    │                   │ • Nominatim Geocoding  │
 └───────────┬────────────┘                   └───────────┬────────────┘
             │                                            │
             └─────────────────────┬──────────────────────┘
                                   ▼
                      NavigationStateNotifier
             ┌─────────────────────────────────────────┐
             │ • Coordinates live location updates     │
             │ • Calculates Haversine distance         │
             │ • Evaluates 15-meter turn prompt gate   │
             │ • Emits spoken turn-by-turn prompts     │
             └─────────────────────┬───────────────────┘
                                   │
             ┌─────────────────────┴─────────────────────┐
             ▼                                           ▼
      Turn Card & Map UI                        TTSService Instruction
 (flutter_map OSM live rendering)            "In 15 meters, turn left..."
```

- **Routing Engine Hierarchy**:
  1. Primary: **OSRM (Open Source Routing Machine)** Foot Engine (`https://router.project-osrm.org/route/v1/foot/`) — free, keyless, global walking geometry.
  2. Secondary: **Google Directions API** walking mode fallback.
  3. Tertiary: **Haversine direct-line vector calculation** if completely offline.
- **Reverse Geocoding**: Uses OpenStreetMap Nominatim API (`https://nominatim.openstreetmap.org/reverse`) to resolve GPS coordinates into human-readable street names ("Where am I right now?").
- **Proximity Step Advancement**: As the user moves within 15 meters of a waypoint (`AppConstants.turnPromptDistanceMeters = 15.0`), the system advances to the next step and announces the turn instruction.
- **Arrival Detection**: Within 10 meters of final destination, announces arrival and terminates navigation.

---

## State Management Architecture (Riverpod)

The app uses `flutter_riverpod` with immutable state objects and `StateNotifier` controllers:

| Provider Name | Type | State Class | Core Responsibility |
|---|---|---|---|
| `cameraServiceProvider` | `Provider<CameraService>` | `CameraService` | Hardware camera lifecycle, USB device scanning, source switching |
| `cameraStateProvider` | `StateNotifierProvider` | `CameraState` | Camera initialization, texture ID, active lens, aspect ratio |
| `cameraFrameStreamProvider` | `StreamProvider.autoDispose` | `CameraImage` | Live CameraImage stream from phone camera (throttled ~8 FPS) |
| `ttsServiceProvider` | `Provider<TTSService>` | `TTSService` | Singleton text-to-speech audio engine with priority queue |
| `ttsStateProvider` | `StateNotifierProvider` | `TTSState` | Speaking state boolean, active utterance text, language |
| `objectDetectionServiceProvider` | `Provider<ObjectDetectionService>` | `ObjectDetectionService` | Google ML Kit ImageLabeler & semantic rule dictionary |
| `tfliteServiceProvider` | `Provider<TFLiteService>` | `TFLiteService` | TFLite interpreter management & multi-tensor inference |
| `detectionStateProvider` | `StateNotifierProvider` | `DetectionState` | Detection results, bounding boxes, anti-repetition speech timer |
| `currencyServiceProvider` | `Provider<CurrencyService>` | `CurrencyService` | OCR-based banknote number detection service |
| `currencyStateProvider` | `StateNotifierProvider` | `CurrencyState` | Banknote denomination, confidence rating, scanning state |
| `ocrServiceProvider` | `Provider<OcrService>` | `OcrService` | Document & sign OCR recognition service |
| `ocrStateProvider` | `StateNotifierProvider` | `OcrState` | Extracted text, continuous scanning toggle, error state |
| `locationServiceProvider` | `Provider<LocationService>` | `LocationService` | High-accuracy GPS position tracking and permissions |
| `navigationServiceProvider` | `Provider<NavigationService>` | `NavigationService` | OSRM / Google routing, geocoding, waypoint tracking |
| `navigationStateProvider` | `StateNotifierProvider` | `NavigationState` | Walking directions, route polyline points, distance to turn |
| `voiceAssistantServiceProvider`| `Provider<VoiceAssistantService>` | `VoiceAssistantService` | Speech-to-text listener and regex parsing |
| `geminiAssistantServiceProvider`| `Provider<GeminiAssistantService>`| `GeminiAssistantService`| Cloud Gemini Generative Model (Flash 1.5) |
| `voiceAssistantStateProvider` | `StateNotifierProvider` | `VoiceAssistantState` | Listening status, partial transcripts, Gemini response text |
| `voiceCommandStreamProvider` | `StreamProvider<VoiceCommand>` | `VoiceCommand` | Reactive stream of detected voice commands |

### Reactivity and Inter-Provider Communication

```
                           ttsStateProvider
                                  ▲
                                  │ speaks announcements
     ┌────────────────────────────┼────────────────────────────┐
     │                            │                            │
detectionStateProvider   currencyStateProvider       navigationStateProvider
     │                            ▲                            ▲
     │ watches frame              │ watches frame              │ watches GPS
cameraServiceProvider    cameraServiceProvider       locationServiceProvider
     ▲                            ▲                            ▲
     └────────────────────────────┼────────────────────────────┘
                                  │ executes voice commands
                     voiceAssistantStateProvider
                                  │
                                  ▼
                         appNavigatorKey.currentState
                         (Pushes / Pops Screens)
```

---

## Global Routing & Navigation Architecture

The app uses a top-level `GlobalKey<NavigatorState>` declared in `lib/app.dart`:

```dart
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
```

### Purpose & Operation
1. **Context-Free Voice Navigation**: When the user speaks a command like *"Open Currency"* or *"Go Home"* from any screen or background state, `VoiceAssistantNotifier._executeCommandGlobally()` accesses `appNavigatorKey.currentState` without needing a `BuildContext`.
2. **Stack Sanitation (`popUntil`)**:
   ```dart
   void _globalNavigate(Widget screen, String announcement) {
     _ref.read(ttsStateProvider.notifier).speak(announcement);
     final nav = appNavigatorKey.currentState;
     if (nav != null) {
       nav.popUntil((route) => route.isFirst);
       nav.push(MaterialPageRoute(builder: (_) => screen));
     }
   }
   ```
   This ensures that any existing camera preview or sub-screen running periodic timers runs its `deactivate()` and `dispose()` methods cleanly before launching the new mode, preventing memory leaks and conflicting camera hardware handles.
3. **Voice Return to Home (`goHome`)**:
   ```dart
   void _globalGoHome() {
     _ref.read(ttsStateProvider.notifier).speak('Going to Home Screen');
     final nav = appNavigatorKey.currentState;
     if (nav != null && nav.canPop()) {
       nav.popUntil((route) => route.isFirst);
     }
   }
   ```
