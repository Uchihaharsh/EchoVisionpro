# External Integrations, Hardware & Machine Learning

**Project Name:** `smart_glasses` (VisionAssist)  
**Scope:** External APIs, Hardware Interfaces, Machine Learning Models, and Data Flows  
**Last Updated:** September 2026

---

## 1. External APIs & Web Services

### 1.1 Google Gemini Generative AI API
- **Package:** `google_generative_ai: ^0.4.7`
- **Service Implementation:** [`GeminiAssistantService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/gemini_assistant_service.dart)
- **Configured Model:** `gemini-1.5-flash` (`AppConstants.geminiModel`)
- **Authentication:** `AppConstants.geminiApiKey` loaded via:
  ```dart
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  ```
  Injected via `--dart-define=GEMINI_API_KEY=<KEY>` at build/run time.

#### Modes of Operation:
1. **Natural Language Speech Understanding (`processUserSpeech`):**
   - **Model Settings:** Temperature `0.2`, Max Tokens `250`.
   - **Timeout:** 4.0 seconds.
   - **Prompt Contract:** Evaluates user speech and responds strictly with structured JSON:
     ```json
     {
       "action": "currency" | "read_text" | "objects" | "navigation" | "where_am_i" | "switch_camera" | "home" | "describe_scene" | "conversation",
       "destination": "target place name or null",
       "response": "short concise voice response spoken to blind user (under 20 words)"
     }
     ```
   - **Resilience Fallback:** If the API key is absent, network fails, or timeout occurs, execution instantly falls back to [`_offlineSemanticClassify()`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/gemini_assistant_service.dart#L201).

2. **Multimodal Scene Description (`describeCameraScene`):**
   - **Model Settings:** Temperature `0.3`, Max Tokens `300`.
   - **Timeout:** 8.0 seconds.
   - **Payload:** `TextPart` (assistive instructions) + `DataPart('image/jpeg', jpegBytes)`.
   - **Prompt Strategy:** Acts as "Echo", an empathetic voice assistant providing a 2-sentence physical description highlighting obstacles (steps, chairs, curbs), openings, people, and hazards directly in the blind user's path.
   - **Fallback:** Returns a default reassurance prompt directing the user to live object tracking mode if offline.

---

### 1.2 OpenStreetMap (OSM) Ecosystem
The application employs an open-source, keyless mapping stack to guarantee zero-cost global accessibility.

```
+-------------------------------------------------------------+
|                      Navigation Stack                       |
+-------------------------------------------------------------+
               |                               |
       (Routing Engine)               (Geocoding & Reverse)
               v                               v
    +--------------------+           +-------------------+
    |    OSRM Walking    |           |    Nominatim      |
    | router.project-    |           | nominatim.        |
    | osrm.org           |           | openstreetmap.org |
    +--------------------+           +-------------------+
               |                               |
               +---------------+---------------+
                               |
                               v
               +-------------------------------+
               |    OSM Raster Tile Server     |
               |  tile.openstreetmap.org       |
               |      (via flutter_map)        |
               +-------------------------------+
```

#### A. Routing Engine (OSRM Walking Router)
- **Endpoint:** `https://router.project-osrm.org/route/v1/foot/{originLng},{originLat};{destLng},{destLat}?overview=full&geometries=geojson&steps=true`
- **Method:** `GET` with 10s timeout in [`NavigationService.getDirections`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/navigation_service.dart#L84).
- **Output:** Decodes GeoJSON route coordinates into `List<LatLng>` and extracts individual turn-by-turn maneuvers (e.g. `turn left onto Main St for 35 meters`).

#### B. Reverse Geocoding (Nominatim)
- **Endpoint:** `https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lng}&zoom=18&addressdetails=1`
- **Headers:** `User-Agent: SmartGlassesAssistiveApp/1.0`
- **Output:** Converts GPS coordinates into street-level address string (truncated to 3 parts for concise spoken TTS output).

#### C. Forward Geocoding (Nominatim)
- **Endpoint:** `https://nominatim.openstreetmap.org/search?format=json&q={encodedAddress}&limit=1&lat={currentLat}&lon={currentLng}`
- **Location Biasing:** Injects current user latitude and longitude to prioritize local landmarks over distant matches.

#### D. Tile Server (OpenStreetMap)
- **Template:** `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- **Render Engine:** [`FlutterMap`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/ui/navigate_mode_screen.dart#L100) widget using `TileLayer` with package identifier `com.example.smart_glasses`.
- **Zoom Constraints:** Min zoom `4.0`, Max zoom `19.0`, default `16.0`.

---

### 1.3 Google Directions API (Fallback)
- **Endpoint:** `https://maps.googleapis.com/maps/api/directions/json` (`AppConstants.googleDirectionsApiBaseUrl`)
- **Query Params:** `origin={lat,lng}&destination={lat,lng}&mode=walking&key={apiKey}`
- **Role:** Automatic secondary fallback inside `NavigationService` if OSRM route fetch encounters network or server errors.
- **Key Status:** Configured with placeholder `'YOUR_GOOGLE_MAPS_API_KEY_HERE'`. If key is empty, the system gracefully degrades to direct Haversine walking guidance.

---

## 2. Hardware Interfaces & Peripheral Integrations

### 2.1 Dual Camera Architecture
Implemented via Strategy Pattern (`CameraSource` in `lib/services/camera_service.dart`).

```
                    +--------------------+
                    |    CameraSource    |
                    |    (Interface)     |
                    +--------------------+
                              ^
                              |
              +---------------+---------------+
              |                               |
   +--------------------+           +--------------------+
   | NativeCameraSource |           |  UvcCameraSource   |
   | (Smartphone Lens)  |           | (Sony IMX378 USB)  |
   | package:camera     |           | package:           |
   |                    |           | flutter_ffi_uvc    |
   +--------------------+           +--------------------+
```

#### A. External UVC Smart Glasses Camera (`UvcCameraSource`)
- **Hardware Target:** Sony IMX378 12MP Ultra-HD USB Camera (A) connected via USB Type-C OTG cable to smartphone.
- **Driver / Plugin:** `flutter_ffi_uvc: ^0.11.0` (direct FFI bindings to native `libuvc`).
- **Initialization Lifecycle:**
  1. `uvcCamera.ensureCameraPermission()` requests USB host permissions.
  2. `uvcCamera.listUsbDevices()` queries connected USB peripherals.
  3. `uvcCamera.openUsbDevice(deviceId)` claims the USB interface.
  4. `uvcCamera.createPreviewTexture()` allocates an OpenGL/Vulkan texture ID.
  5. `uvcCamera.startPreviewAuto(preference: UvcAutoPreviewPreference.quality)` negotiates highest available resolution and framerate.
  6. `uvcCamera.attachPreviewTexture(textureId, width, height)` links video frames directly to Flutter's texture registry.
- **Still Capture:** `uvcCamera.takePicture()?.jpegBytes` captures full-resolution JPEG frames for ML Kit and Gemini vision analysis.
- **Hotplug / Auto-Detection:** `CameraService.initialize()` checks `hasUsbCameraAttached()`. If detected, UVC mode initializes automatically; otherwise, falls back to native phone camera.

#### B. Built-in Smartphone Camera (`NativeCameraSource`)
- **Plugin:** `camera: ^0.11.3+1`
- **Configuration:** Selects back-facing lens (`CameraLensDirection.back`), `ResolutionPreset.medium`, pixel format `ImageFormatGroup.nv21`.
- **Frame Rate Throttling:** Throttled to ~8 fps (125ms debounce interval) to prevent ML inference from stalling the Flutter UI rendering isolate.

---

### 2.2 Microphone & Voice Input
- **Plugin:** `speech_to_text: ^7.4.0`
- **Service Implementation:** [`VoiceAssistantService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/voice_assistant_service.dart)
- **Continuous Listening Loop:** Auto-restarts recognition on status transitions (`notListening`, `done`) or non-fatal errors with 350ms delay.
- **Locale Optimization:** Probes device speech locales and selects Indian English (`en_IN`) if available for optimal accent recognition.
- **Acoustic Echo Prevention (Mic Muting):**
  - Problem: When the glasses or phone speaker speaks TTS announcements, continuous speech recognition picks up the synthesized speech as new commands.
  - Solution: `VoiceAssistantNotifier` listens to `ttsStateProvider`. When TTS begins speaking (`isSpeaking == true`), it calls `_voiceService.pauseForTts()`. When TTS ends, it calls `_voiceService.resumeAfterTts()` with a 500ms acoustic dampening delay.
- **Debounce Guard:** 1500ms execution guard (`_lastCommandExecutedTime`) prevents multiple triggers from a single utterance.

---

### 2.3 Audio Output & Text-to-Speech (TTS)
- **Plugin:** `flutter_tts: ^4.2.5`
- **Service Implementation:** [`TTSService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/tts_service.dart)
- **Engine Configuration:** Language `en-US`, Speech Rate `0.5`, Pitch `1.0`.
- **Priority Queue System:**
  - `TTSPriority.low` / `normal`: Appended to end of speech queue (`_queue.addLast`).
  - `TTSPriority.high`: Pre-pended to front of queue (`_queue.addFirst`).
  - `TTSPriority.critical` or `interrupt: true`: Calls `stop()`, flushes queue, and speaks immediately.
- **Safety Watchdog Timer:** Calculates dynamic timeout based on word count:
  $$\text{timeoutSec} = \text{clamp}(2, 10, \lceil \text{words} \times 0.6 \rceil + 3)$$
  If native completion handlers fail to trigger on platform channel, the watchdog resets `_isSpeaking = false` and pops the next item to prevent audio deadlock.

---

### 2.4 GPS & Geolocation
- **Plugin:** `geolocator: ^14.0.3`
- **Service Implementation:** [`LocationService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/location_service.dart)
- **Configuration:** `LocationAccuracy.high`, `distanceFilter: 2` meters.
- **Reactive Stream:** Broadcast stream emits continuous `Position` updates to Riverpod (`locationServiceProvider`), driving real-time map center tracking and waypoint distance checking.

---

### 2.5 Digital Compass & Magnetometer
- **Plugin:** `flutter_compass: ^0.8.1`
- **Status:** Installed in `pubspec.yaml` and resolved in `pubspec.lock`. Prepared for directional waypoint guidance (e.g. "Turn 30 degrees to your north-east").

---

### 2.6 Haptics & Power Management
- **Haptics:** `HapticFeedback.heavyImpact()` triggers tactile confirmation on screen taps and mode transitions.
- **Screen Keep-Awake:** `wakelock_plus: ^1.1.4` activates during camera recognition and navigation sessions to prevent Android from entering deep sleep.

---

## 3. Machine Learning Models & Edge AI

```
+-------------------------------------------------------------------------+
|                        Edge ML Subsystem                                |
+-------------------------------------------------------------------------+
        |                                                 |
(Google ML Kit)                                   (TensorFlow Lite)
        |                                                 |
  +-----+-----------------+                         +-----+-----+
  |                       |                         |           |
  v                       v                         v           v
Text Recognition    Image Labeling             ssd_mobile-  efficientdet-
(Latin OCR)         (Object Rules)             net.tflite   lite0.tflite
  - OcrService        - ObjectDetection-       (300x300)    (Asset only)
  - CurrencyService     Service (18 classes)
```

### 3.1 Google ML Kit Image Labeling (Object Detection)
- **Plugin:** `google_mlkit_image_labeling: ^0.14.2`
- **Service Implementation:** [`ObjectDetectionService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/object_detection_service.dart)
- **Threshold:** Calibrated to `0.28` via `ImageLabelerOptions`.
- **Abstract Tag Blocklist:** 50+ non-actionable labels are strictly filtered out (e.g., `room`, `flooring`, `wall`, `ceiling`, `material`, `font`, `pattern`, `surface`, `light`, `indoor`, `angle`, `space`).
- **Physical Object Semantic Rules:** Maps raw labels to 18 tangible assistive classes:
  1. `Laptop` (laptop, computer, keyboard, monitor, screen, display device)
  2. `Mobile phone` (smartphone, cell phone, communication device)
  3. `Bottle` (water bottle, plastic bottle, thermos, flask)
  4. `Cup` (mug, coffee cup, teacup, ceramic)
  5. `Chair` (armchair, office chair, seat, stool, bench)
  6. `Table` (desk, dining table, countertop, writing desk)
  7. `Person` (human, face, man, woman, child)
  8. `Book` (textbook, novel, notebook, document, paper)
  9. `Backpack` (bag, handbag, suitcase, luggage)
  10. `Door` (doorway, entryway, exit, sliding door)
  11. `Shoes` (sneakers, footwear, boot, sandal)
  12. `Bed` (mattress, pillow, blanket)
  13. `Couch` (sofa, futon, loveseat)
  14. `Television` (tv, flat panel display)
  15. `Vehicle` (car, automobile, bus, truck, bicycle, motorcycle)
  16. `Glasses` (sunglasses, spectacles, eyewear)
  17. `Clock` (watch, wrist watch, wall clock)
  18. `Plate` (bowl, spoon, fork, dishware, cutlery)

---

### 3.2 Google ML Kit Text Recognition (OCR & Currency)
- **Plugin:** `google_mlkit_text_recognition: ^0.15.1`
- **Script:** `TextRecognitionScript.latin`
- **Services Utilizing ML Kit OCR:**
  1. **[`OcrService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/ocr_service.dart):**
     - Processes both UVC camera high-res JPEG bytes (via temporary cache file) and phone camera `CameraImage` NV21 frames.
     - Performs vertical sorting on `TextBlock` bounds (`a.boundingBox.top.compareTo(b.boundingBox.top)`) to ensure natural top-to-bottom reading order.
  2. **[`CurrencyService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/currency_service.dart):**
     - Extracts recognized text from banknote frames.
     - Evaluates denomination numbers using regex: `r'\b(500|200|100|50|20|10)\b'`.
     - Maps matches to verified Indian Rupee denominations (`₹10` to `₹500`) with high confidence (`0.95`).

---

### 3.3 TensorFlow Lite Runtime (`tflite_flutter`)
- **Plugin:** `tflite_flutter: ^0.12.1`
- **Service Implementation:** [`TFLiteService`](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/tflite_service.dart)
- **Threading:** Configured with `InterpreterOptions()..threads = 4`.
- **Model Files:**
  - `assets/models/ssd_mobilenet.tflite` (4.18 MB, 300x300 input, COCO 80 labels in `assets/labels/labelmap.txt`).
  - `assets/models/efficientdet-lite0.tflite` (13.84 MB, alternative high-resolution detector).
  - *Discrepancy Note:* `currency_classifier.tflite` (referenced in `AppConstants.currencyModel` and `.gitkeep`) is missing on disk; handled smoothly by ML Kit OCR currency recognizer.

---

## 4. End-to-End Data Flows & Credential Architecture

### 4.1 Speech Command to Action Pipeline
```
[User Utterance: "Hey Echo, take me to Hospital"]
                     |
                     v
       [VoiceAssistantService (STT)]
                     |
            (Acoustic Filter)
   [Checks TTSService.isSpeaking -> Not Speaking]
                     |
                     v
         [VoiceAssistantNotifier]
                     |
                     +---------------------------------------+
                     |                                       |
           (If GEMINI_API_KEY set)                (If Offline / Key Empty)
                     v                                       v
         [GeminiAssistantService]                [_offlineSemanticClassify]
          - Model: gemini-1.5-flash               - Regex & token parser
          - Generates Action JSON                 - Detects "navigate to"
                     |                                       |
                     +-------------------+-------------------+
                                         |
                                         v
                         [Intent: openNavigation]
                         [Argument: "Hospital"]
                                         |
                                         v
              [TTSService: "Navigating to Hospital."]
                                         |
                                         v
              [Navigator pushes NavigateModeScreen]
                                         |
                                         v
            [NavigationService geocodes via Nominatim]
                                         |
                                         v
            [NavigationService routes via OSRM Walking]
                                         |
                                         v
            [Live Visual Map + Turn-by-Turn Spoken Steps]
```

---

### 4.2 Security & Credential Handling Best Practices

| Secret / Config Item | Config Location | Ingestion Method | Git Committed? | Fallback Behavior |
|---|---|---|---|---|
| **Google Gemini API Key** | `AppConstants.geminiApiKey` | `--dart-define=GEMINI_API_KEY=xxx` | **No** (empty default) | Degrades to offline phonetic classifier |
| **Google Maps API Key** | `AppConstants.googleMapsApiKey` | Hardcoded constant | Placeholder string | Degrades to free OSRM walking router |
| **Nominatim OpenStreetMap** | Inline URL in `navigation_service.dart` | Keyless public HTTP | Public API | Uses device coordinates directly |
| **OSRM Routing Engine** | Inline URL in `navigation_service.dart` | Keyless public HTTP | Public API | Direct Haversine straight-line step |

#### Security Recommendations:
1. When generating release APKs / AABs, pass `--dart-define=GEMINI_API_KEY=<PROD_KEY>` in CI/CD pipeline.
2. If Google Directions API is needed in production, migrate `googleMapsApiKey` from static constant to `String.fromEnvironment('GOOGLE_MAPS_API_KEY')` to prevent key exposure in source control.
3. OpenStreetMap tile requests and Nominatim reverse geocoding include compliant `User-Agent` headers (`SmartGlassesAssistiveApp/1.0`) to honor OSM Usage Policies.
