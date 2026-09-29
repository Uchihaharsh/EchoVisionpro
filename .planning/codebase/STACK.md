# Technology Stack & Environment

**Project Name:** `smart_glasses` (VisionAssist)  
**Description:** Smart Glasses for Visually Impaired - Assistive Technology App  
**Target Platform:** Primary: Android (USB Host / OTG & Phone Camera); Secondary/Future: iOS  
**Last Updated:** September 2026

---

## 1. Languages & Runtimes

| Component | Specified Constraint | Resolved Version (Lockfile) | Notes |
|---|---|---|---|
| **Flutter SDK** | SDK channel / framework | `>=3.44.0` | Material 3 enabled (`uses-material-design: true`) |
| **Dart SDK** | `^3.7.0` | `>=3.12.0 <4.0.0` | Null safety, pattern matching, records, sealed classes |
| **Java Runtime** | Java 17 (`JavaVersion.VERSION_17`) | JVM 17 (`JVM_17`) | Configured in `android/app/build.gradle.kts` |
| **Kotlin** | Gradle plugin `2.2.20` | `2.2.20` | Configured in `android/settings.gradle.kts` |
| **Android Gradle Plugin** | `com.android.application: 8.9.1` | `8.9.1` | Modern Gradle 8.x declarative plugin management |

---

## 2. Core Frameworks & Dependencies

### 2.1 Dependency Overview

| Package | Declared Version | Resolved Version | Functional Domain | Primary Role |
|---|---|---|---|---|
| `flutter_riverpod` | `^2.6.1` | `2.6.1` | State Management | Dependency injection, `StateNotifierProvider`, reactive UI binding |
| `camera` | `^0.11.3+1` | `0.11.4` | Vision & Sensors | Smartphone camera capture and NV21 frame streaming |
| `flutter_ffi_uvc` | `^0.11.0` | `0.11.0` | Hardware Vision | USB-C OTG external smart glasses camera (IMX378 12MP UVC) |
| `google_mlkit_text_recognition` | `^0.15.1` | `0.15.1` | Edge AI / OCR | On-device text recognition for document reading and currency reading |
| `google_mlkit_image_labeling` | `^0.14.2` | `0.14.2` | Edge AI / Vision | Real-world everyday object detection with calibrated thresholding |
| `google_mlkit_object_detection` | `^0.15.1` | `0.15.1` | Edge AI / Vision | Declared for native ML Kit object detection bounding boxes |
| `tflite_flutter` | `^0.12.1` | `0.12.1` | Edge Machine Learning | On-device TensorFlow Lite model execution with multi-threading |
| `google_generative_ai` | `^0.4.7` | `0.4.7` | Cloud Generative AI | Google Gemini API (`gemini-1.5-flash`) for NLP and multimodal vision |
| `flutter_tts` | `^4.2.5` | `4.2.5` | Speech Output | Synthesized speech output with priority queue and safety watchdog |
| `speech_to_text` | `^7.4.0` | `7.4.0` | Voice Input | Continuous voice listening and "Hey Echo" wake-word detection |
| `flutter_map` | `^8.3.1` | `8.3.1` | Mapping & UI | Interactive raster tile visual map rendering with OSM tiles |
| `latlong2` | `^0.10.1` | `0.10.1` | Geodesics | Coordinate modeling and distance calculations for maps |
| `google_maps_flutter` | `^2.17.0` | `2.18.0` | Mapping | Declared Google Maps Flutter plugin |
| `geolocator` | `^14.0.3` | `14.0.3` | Geolocation | High-accuracy pedestrian GPS location tracking |
| `flutter_compass` | `^0.8.1` | `0.8.1` | Magnetometer | Compass heading sensor access |
| `permission_handler` | `^11.3.1` | `11.3.1` | Permissions | Dynamic runtime permission requests (Camera, Mic, GPS) |
| `wakelock_plus` | `^1.1.4` | `1.7.0` | Power Management | Prevents device screen timeout during active navigation and camera usage |
| `http` | `^1.3.0` | `1.6.0` | Networking | HTTP client for OSRM, Nominatim, and Google Directions APIs |
| `path_provider` | `^2.1.5` | `2.1.5` | Filesystem | Locating temporary cache directory for processing camera frames |
| `image` | `^4.7.0` | `4.7.0` | Image Processing | Image byte conversion and manipulation utilities |

---

## 3. Subsystem Breakdown

### 3.1 State Management (`flutter_riverpod`)
- **Pattern:** Provider-based dependency injection with `StateNotifier` and `StateNotifierProvider`.
- **Root Injection:** `ProviderScope` wraps the application at `lib/main.dart:10`.
- **Navigation Coupling:** Global `appNavigatorKey` in `lib/app.dart` enables voice commands in `VoiceAssistantNotifier` to route between screens without direct BuildContext references.

### 3.2 Vision & Dual Camera Architecture (`camera` & `flutter_ffi_uvc`)
- **Pattern:** Strategy pattern via `CameraSource` interface (`lib/services/camera_service.dart`).
- **Implementations:**
  - `NativeCameraSource`: Built-in phone camera using `camera` plugin; streaming throttled to ~8 fps (125ms debounce) to avoid CPU starvation.
  - `UvcCameraSource`: Direct USB-C OTG communication with Sony IMX378 12MP external smart glasses module using FFI bindings to libuvc; renders into Flutter preview texture (`createPreviewTexture`, `attachPreviewTexture`).
- **Resolution:** Medium resolution preset (`ResolutionPreset.medium`) for balance between accuracy and frame latency.

### 3.3 Machine Learning & Computer Vision
- **Dual Pipeline:**
  1. **Google ML Kit (Primary Active Pipeline):**
     - `google_mlkit_text_recognition`: Latin script OCR in `OcrService` and `CurrencyService`.
     - `google_mlkit_image_labeling`: Configured with confidence threshold `0.28` and an 18-category physical object mapping table in `ObjectDetectionService`.
  2. **TensorFlow Lite Engine (`tflite_flutter`):**
     - Infrastructure service `TFLiteService` supports multi-threaded inference (`InterpreterOptions()..threads = 4`).
     - Models packaged in `assets/models/` (`ssd_mobilenet.tflite`, `efficientdet-lite0.tflite`).

### 3.4 Speech & Assistive Voice Interaction
- **Speech Synthesis (`flutter_tts`):**
  - Managed by `TTSService`.
  - Configured with language `en-US`, rate `0.5`, pitch `1.0`.
  - Queue management supporting priority levels (`low`, `normal`, `high`, `critical`).
  - Implements an adaptive watchdog timer (2s–10s) based on word count to prevent audio lockups.
- **Voice Recognition (`speech_to_text`):**
  - Managed by `VoiceAssistantService`.
  - Continuous listening loop with automatic recovery.
  - Target locale auto-negotiation (`en_IN` preferred, falling back to system default).
  - Acoustic echo cancellation: listens to `TTSService.speakingStream` to mute the microphone while speech is playing.

### 3.5 Mapping & Navigation
- **Visual Map Rendering:** Rendered via `flutter_map` (v8.3.1) and `TileLayer` pointing to OpenStreetMap standard tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
- **Routing Engine:** Open Source Routing Machine (OSRM) walking profile (`/route/v1/foot/`) with fallback to Google Directions API.
- **Geolocation (`geolocator`):** Pedestrian mode configured with `LocationAccuracy.high` and `distanceFilter: 2` meters.

---

## 4. Development Dependencies & Tooling

| Package | Version | Purpose |
|---|---|---|
| `flutter_test` | SDK | Widget and unit testing framework (`test/widget_test.dart`) |
| `flutter_lints` | `^5.0.0` (locked 5.0.0) | Standard Flutter community lint rules |

### Analysis Options (`analysis_options.yaml`)
- Inherits rules from `package:flutter_lints/flutter.yaml`.
- Default strictness enabled; no custom rule overrides applied.

---

## 5. Platform Configuration & Native Specifications

### 5.1 Android Setup (`android/`)
- **Application Namespace:** `com.anity.smartglasses.smart_glasses`
- **Application Label:** `VisionAssist`
- **Compile SDK:** `36` (`compileSdk = 36` in `android/app/build.gradle.kts`)
- **Min SDK:** Flutter default (`flutter.minSdkVersion`, typically 21+)
- **Target SDK:** Flutter default (`flutter.targetSdkVersion`, typically 34+)
- **JVM Target:** Java 17 (`JavaVersion.VERSION_17`, Kotlin JVM target 17)
- **NDK Version:** Managed by Flutter (`flutter.ndkVersion`)

#### Android Permissions Declared (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.USB_PERMISSION" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

#### Hardware Features Declared
- `android.hardware.usb.host` (`android:required="false"`) - Allows USB OTG host communication with UVC glasses without preventing install on devices without USB-host.
- `android.hardware.camera` (`android:required="false"`)
- `android.hardware.camera.autofocus` (`android:required="false"`)

#### USB Host Filter (`android/app/src/main/res/xml/device_filter.xml`)
Matches Universal USB Video Class (UVC) cameras attached via USB-C OTG:
- Class `239`, Subclass `2` (UVC Miscellaneous)
- Class `14`, Subclass `1` (Video Control)
- Class `14`, Subclass `2` (Video Streaming)
- Class `255` (Vendor-specific USB devices)

#### Package Visibility Queries (`<queries>`)
- `android.speech.RecognitionService`: Required on Android 11+ (API 30+) for `speech_to_text` to query speech recognition services.
- `android.intent.action.PROCESS_TEXT`: Required for Flutter engine text processing.

### 5.2 iOS Platform Status (`ios/`)
- Standard Flutter iOS runner configuration present (`ios/Runner/Info.plist`).
- **Gaps / Action Items for iOS Support:**
  - Missing privacy permission descriptions (`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSLocationWhenInUseUsageDescription`).
  - `flutter_ffi_uvc` relies on Linux/Android USB host FFI APIs; USB smart glasses camera over USB-C OTG is currently Android-only.

### 5.3 Web, Desktop, & Other Platforms
- `web/`, `windows/`, `macos/`, and `linux/` folders exist as standard Flutter project scaffolds.
- The app's core value propositions (UVC FFI camera, mobile ML Kit pipelines, mobile SpeechToText) are tailored for mobile form factors.

---

## 6. Build System & Assets Configuration

### 6.1 Declared Assets in `pubspec.yaml`
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/models/
    - assets/labels/
```

### 6.2 Asset Directory Inventory
| Asset File Path | Size | Description | Status / Codebase Usage |
|---|---|---|---|
| `assets/models/ssd_mobilenet.tflite` | 4,185,175 bytes (~4.18 MB) | MobileNet SSD object detection model | Declared in `AppConstants.objectDetectionModel` |
| `assets/models/efficientdet-lite0.tflite` | 13,836,895 bytes (~13.84 MB) | EfficientDet Lite0 object detection model | Present on disk; alternative high-accuracy detector |
| `assets/models/.gitkeep` | 181 bytes | Notes on required models | Mentions `currency_classifier.tflite` |
| `assets/labels/labelmap.txt` | 665 bytes | 80 COCO dataset class labels | Declared in `AppConstants.objectLabels` |
| `assets/labels/currency_labels.txt` | 39 bytes | 6 Indian Rupee denominations (`₹10`, `₹20`, `₹50`, `₹100`, `₹200`, `₹500`) | Declared in `AppConstants.currencyLabels` |

### 6.3 Noted Asset & Configuration Gaps
1. **Missing Currency TFLite Model:** `AppConstants.currencyModel` points to `'assets/models/currency_classifier.tflite'`, but this file does not exist on disk. `CurrencyService` currently handles currency via ML Kit OCR regex as a resilient fallback.
2. **Unreferenced EfficientDet Model:** `efficientdet-lite0.tflite` (13.8 MB) is packaged in the app bundle assets but is not currently referenced in `AppConstants` or active services.
