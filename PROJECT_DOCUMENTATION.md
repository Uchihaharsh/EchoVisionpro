# EchoVisionPro (VisionAssist Smart Glasses) — Complete Master Project Documentation

**Project Name:** EchoVisionPro (`smart_glasses`)  
**Target Users:** Visually Impaired & Blind Individuals  
**Repository:** `https://github.com/Uchihaharsh/EchoVisionpro.git`  
**Platform:** Android (Mobile + Wearable Sony IMX378 USB-C UVC Smart Glasses)  
**Framework & SDK:** Flutter `^3.7.0` / Dart `^3.7.0`  
**State Management:** Flutter Riverpod `^2.6.1`  

---

## Table of Contents

1. [Executive Summary & Project Vision](#1-executive-summary--project-vision)
2. [What We Have Done in This Project (End-to-End Engineering History)](#2-what-we-have-done-in-this-project-end-to-end-engineering-history)
3. [What AI Agents & Machine Learning Models We Used (Runtime & Development)](#3-what-ai-agents--machine-learning-models-we-used-runtime--development)
   - 3.1 [Runtime AI Agents & ML Engines Inside the App](#31-runtime-ai-agents--ml-engines-inside-the-app)
   - 3.2 [Development & Engineering AI Agents Used to Build the Project](#32-development--engineering-ai-agents-used-to-build-the-project)
4. [System Architecture & Layered Design (Why & How)](#4-system-architecture--layered-design-why--how)
5. [Complete Codebase Reference (Where Everything Is & What Code We Used)](#5-complete-codebase-reference-where-everything-is--what-code-we-used)
   - 5.1 [Application Entry Points (`lib/main.dart`, `lib/app.dart`)](#51-application-entry-points-libmaindart-libappdart)
   - 5.2 [Core Utilities & Theme (`lib/core/`)](#52-core-utilities--theme-libcore)
   - 5.3 [Domain Data Models (`lib/models/`)](#53-domain-data-models-libmodels)
   - 5.4 [Hardware, AI, & Cloud Services (`lib/services/`)](#54-hardware-ai--cloud-services-libservices)
   - 5.5 [Reactive State Management Providers (`lib/providers/`)](#55-reactive-state-management-providers-libproviders)
   - 5.6 [Accessible User Interface & Widgets (`lib/ui/`)](#56-accessible-user-interface--widgets-libui)
6. [Deep-Dive Technical Workflows (How Everything Works Under the Hood)](#6-deep-dive-technical-workflows-how-everything-works-under-the-hood)
   - 6.1 [Continuous "Hey Echo" / Direct-Command Voice Assistant Engine](#61-continuous-hey-echo--direct-command-voice-assistant-engine)
   - 6.2 [Dual-Tier Intent Routing: 0ms Fast-Path vs. Gemini 1.5 Flash Cloud AI](#62-dual-tier-intent-routing-0ms-fast-path-vs-gemini-15-flash-cloud-ai)
   - 6.3 [Real-Time Object Detection Pipeline & Semantic Filtering](#63-real-time-object-detection-pipeline--semantic-filtering)
   - 6.4 [Indian Rupee Banknote (Currency) Recognition Pipeline](#64-indian-rupee-banknote-currency-recognition-pipeline)
   - 6.5 [Optical Character Recognition (OCR) & Jaccard Deduplication](#65-optical-character-recognition-ocr--jaccard-deduplication)
   - 6.6 [Pedestrian Turn-by-Turn GPS Navigation & Reverse Geocoding](#66-pedestrian-turn-by-turn-gps-navigation--reverse-geocoding)
   - 6.7 [Dual-Camera Hardware Strategy (Sony IMX378 USB-C Glasses vs. Phone Camera)](#67-dual-camera-hardware-strategy-sony-imx378-usb-c-glasses-vs-phone-camera)
7. [Critical Engineering Bugs We Solved & How We Solved Them](#7-critical-engineering-bugs-we-solved--how-we-solved-them)
8. [Complete Voice Command Matrix](#8-complete-voice-command-matrix)
9. [Technology Stack & Dependencies (`pubspec.yaml` Rationale)](#9-technology-stack--dependencies-pubspecyaml-rationale)
10. [Build, Deployment, & GitHub Synchronization Guide](#10-build-deployment--github-synchronization-guide)

---

## 1. Executive Summary & Project Vision

**EchoVisionPro (VisionAssist)** is an assistive technology application engineered for blind and visually impaired users. It transforms an Android smartphone—and optionally a pair of **Sony IMX378 USB-C UVC Smart Glasses**—into an intelligent, hands-free visual and spatial companion.

### Core Objectives
1. **100% Hands-Free Operation:** A blind user should never have to visually hunt for buttons on a touchscreen. Every feature in the app can be launched, switched, queried, or stopped by speaking naturally (either using the **"Hey Echo"** wake word or direct commands like *"Open currency"*, *"Read text"*, *"Where am I?"*, *"What time is it?"*, or *"Go home"*).
2. **Dual-Hardware Camera Flexibility:** The app works out-of-the-box using the phone's built-in rear camera (`NativeCameraSource`) and automatically detects or switches to an external wearable **Sony IMX378 12MP USB-C Smart Glasses camera** (`UvcCameraSource`) over USB OTG.
3. **Hybrid Edge + Cloud AI Architecture:**
   - **On-Device Edge AI (0ms network latency, 100% offline capable):** Real-time object detection, obstacle spatial positioning (`left`, `ahead`, `right`), Indian Rupee currency recognition (`₹10` to `₹500`), and printed text reading (OCR) run locally on the phone using Google ML Kit and TensorFlow Lite.
   - **Cloud Multimodal Generative AI (Gemini 1.5 Flash):** Complex visual scene descriptions (*"What am I looking at?"*) and open-ended conversational queries are routed to Google's `gemini-1.5-flash` vision-language model, with an automatic offline fallback to local object detection if the user has no internet connection.
4. **High-Contrast, Screen-Reader-First UI:** For users with low vision (partial sight), the interface adheres to strict accessibility standards: pure dark backgrounds (`#121212`), high-luminance neon accents (`#6C63FF`, `#00E5FF`, `#76FF03`), massive touch targets (`80dp+`), haptic feedback on every state transition, and full Android TalkBack `Semantics` annotations.

---

## 2. What We Have Done in This Project (End-to-End Engineering History)

Over the course of developing, auditing, debugging, and enhancing **EchoVisionPro**, we executed the following major engineering milestones:

### Phase 1: Comprehensive Codebase Mapping & Architectural Audit
- Deployed four parallel **GSD Codebase Mapper Subagents** (`gsd-codebase-mapper`) to analyze the entire repository across four dimensions:
  1. **Tech Stack & Integrations** (`.planning/codebase/STACK.md`, `.planning/codebase/INTEGRATIONS.md`)
  2. **System Architecture & File Structure** (`.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`)
  3. **Coding Conventions & Patterns** (`.planning/codebase/CONVENTIONS.md`)
  4. **Technical Debt, Bugs, & Concerns** (`.planning/codebase/CONCERNS.md`, `.planning/codebase/TESTING.md`)

### Phase 2: Fixing Real-Time Object Detection & Camera Stream Crashes
- **Implemented Missing Live Stream Detection:** Previously, `ObjectDetectionService.detectObjects(CameraImage)` was a stub returning an empty list `[]`, and `DetectModeScreen` relied only on a slow 2.5-second JPEG snapshot timer. We implemented full NV21/YUV420 `CameraImage` to `InputImage` conversion in `lib/services/object_detection_service.dart` and wired `cameraFrameStreamProvider` in `lib/ui/detect_mode_screen.dart` with a **350ms (3 FPS) throttle** so object detection runs smoothly in real time without freezing the UI thread.
- **Fixed `RangeError` Crash in YUV420 Image Conversion:** Fixed `ImageUtils.convertYUV420ToRGB()` in `lib/core/utils/image_utils.dart` to safely handle 1-plane (concatenated NV21), 2-plane (biplanar NV21/NV12), and 3-plane (standard YUV_420_888) camera buffers with strict bounds clamping (`clamp(0, length - 1)`).
- **Physical Object Rule Engine:** Filtered out noisy abstract ML Kit labels (`monochrome`, `font`, `parallel`, `rectangle`, `ceiling`) and mapped over 90 synonyms into **18 concrete physical object categories** (Laptop, Mobile phone, Bottle, Cup, Chair, Table, Person, Book, Backpack, Door, Shoes, Bed, Couch, Television, Vehicle, Glasses, Clock, Plate).

### Phase 3: Re-Engineering the Voice Assistant ("Hey Echo" & Google Assistant-Style Direct Commands)
- **Solved the "Listens to Only One Command" Bug:** Android's native `SpeechRecognizer` automatically terminates a listening session after a single utterance (`status == 'done'`) or throws `error_busy` / `error_speech_timeout` if restarted too rapidly. We built a self-healing **Liveness Watchdog** (`_startLivenessWatchdog`, running every 4 seconds) and a debounced auto-restart state machine (`_restartContinuousListeningIfNeeded`) in `lib/services/voice_assistant_service.dart` that keeps the microphone alive indefinitely across the entire app.
- **Solved Premature Wake-Word Cutoff:** Previously, saying *"Hey Echo open currency"* caused the partial speech recognizer callback to see *"Hey Echo"* in the first 200ms, immediately stop the microphone, and say *"Yes, I'm listening"*—cutting off *"open currency"*. We fixed `VoiceAssistantService` so standalone `wakeWordPrompt` only fires when `result.finalResult == true`, while actionable commands fire immediately.
- **Added Indian English Phonetic & Natural Language Support:** Added `en_IN` locale discovery and phonetic wake-word matching (`hey echo`, `ok echo`, `hey eco`, `eko`, `eco`, `ekho`, `aiko`, `ok google`, `hey google`) plus natural-language polite prefix stripping (`can you please`, `i want to`, `show me`, `help me`) and word-boundary regex matching (`\b...\b`) so words like *"already"* never falsely trigger *"read"* and *"background"* never falsely triggers *"back"*.
- **Solved Feature-to-Feature Jumping & Camera Disposal Collisions:** Previously, when jumping from `DetectModeScreen` to `CurrencyModeScreen`, `deactivate()` called `stopDetection()`, which disposed the shared `CameraController` while the new screen was simultaneously trying to initialize it—causing camera blackouts and microphone lockups. Furthermore, calling `popUntil` + `push` caused route transition collisions. We fixed this by:
  1. Keeping the camera hot across mode switches (`Keep camera initialized for fast mode switching` in `lib/providers/detection_providers.dart`).
  2. Implementing **Atomic Screen Replacement** (`nav.pushReplacement`) in `VoiceAssistantNotifier._globalNavigate()` (`lib/providers/voice_assistant_providers.dart`) with `currentScreen` tracking (`home`, `detect`, `currency`, `read`, `navigate`).
- **Added Full Barge-In & Utility Commands:** Allowed users to interrupt TTS speech at any time (`pauseForTts()` keeps the mic open using acoustic echo string filtering `_isAcousticEcho()`), and added instant voice commands for **Stop Speaking** (*"stop"*, *"quiet"*), **Tell Time** (*"what time is it"*), **Tell Date** (*"what is today's date"*), **App Status** (*"what mode am I in"*), and **Offline Scene Description Fallback**.

### Phase 4: Git Repository Setup & Automated GitHub Synchronization
- Initialized Git repository on `main`, created `.gitignore`, linked remote `https://github.com/Uchihaharsh/EchoVisionpro.git`, and created `sync_to_github.ps1` so every future update is committed and pushed to GitHub.

---

## 3. What AI Agents & Machine Learning Models We Used (Runtime & Development)

A critical question for understanding **EchoVisionPro** is: **What AI agents and machine learning models are used, why were they chosen, where do they live in the code, and how do they work together?**

We used **two distinct categories** of AI Agents/Models:
1. **Runtime AI Agents & On-Device ML Models (5 Engines)** that run inside the Flutter app to serve the blind user.
2. **Development & Architectural AI Agents (5 Specialized Agents)** used during software engineering to map, audit, debug, and build the project.

---

### 3.1 Runtime AI Agents & ML Engines Inside the App

```
┌────────────────────────────────────────────────────────────────────────────┐
│                   RUNTIME AI & ML ENGINES IN ECHOVISIONPRO                 │
├──────────────────────────┬────────────────────────┬────────────────────────┤
│ Agent / Model Name       │ Execution Environment  │ Primary Responsibility │
├──────────────────────────┼────────────────────────┼────────────────────────┤
│ 1. Echo Local Voice      │ On-Device (0ms)        │ Continuous wake-word   │
│    Agent                 │ Android SpeechToText   │ & 14-intent NLU router │
├──────────────────────────┼────────────────────────┼────────────────────────┤
│ 2. Gemini 1.5 Flash      │ Cloud Multimodal LLM   │ Visual scene narration │
│    Multimodal Agent      │ (Google Generative AI) │ & open Q&A assistant   │
├──────────────────────────┼────────────────────────┼────────────────────────┤
│ 3. Google ML Kit         │ On-Device Edge NPU/GPU │ Real-time physical     │
│    ImageLabeler Engine   │ (Threshold: 0.28)      │ object & obstacle ID   │
├──────────────────────────┼────────────────────────┼────────────────────────┤
│ 4. Google ML Kit Latin   │ On-Device Edge NPU/GPU │ Book/Sign OCR reading  │
│    TextRecognizer Engine │ (Latin Script v2)      │ & Indian Rupee OCR     │
├──────────────────────────┼────────────────────────┼────────────────────────┤
│ 5. TensorFlow Lite       │ On-Device Interpreter  │ Bounding-box tensor    │
│    Edge Inference Engine │ (SSD MobileNet v1)     │ object localization    │
└──────────────────────────┴────────────────────────┴────────────────────────┘
```

#### Runtime Agent 1: Echo Local Voice Agent (`VoiceAssistantService` + `VoiceAssistantNotifier`)
- **What It Is:** A deterministic, zero-latency Natural Language Understanding (NLU) and state-machine agent that listens continuously to the user's microphone, filters out speaker echo, strips conversational filler words, and maps spoken phrases into 15 structured `VoiceCommandType` intents.
- **Why We Used It:** Cloud LLMs take 800ms–2500ms over cellular networks and fail completely when offline. A blind user walking down a street needs **0ms instant response** when they say *"Stop"*, *"Open currency"*, *"Read text"*, or *"Go home"*.
- **Where It Is Used:**
  - `lib/services/voice_assistant_service.dart` (Lines 7–533)
  - `lib/providers/voice_assistant_providers.dart` (Lines 71–429)
- **How It Works:** Uses `speech_to_text` (`^7.4.0`) with partial and final result streaming, a 4-second periodic liveness watchdog timer, acoustic echo comparison against `TTSState.currentText`, and word-boundary regular expressions (`\b...\b`) across 180+ domain keywords.

#### Runtime Agent 2: Gemini 1.5 Flash Multimodal Cloud Agent (`GeminiAssistantService`)
- **What It Is:** Google's `gemini-1.5-flash` multimodal Large Language Model integrated via the `google_generative_ai` (`^0.4.7`) SDK. It operates in two modes:
  1. **Structured JSON Intent Agent (`_intentModel`):** Configured with `responseMimeType: 'application/json'`, `temperature: 0.1`, and a strict `Schema.object` (`intent`, `argument`, `speechResponse`, `isMultimodalSceneDescription`).
  2. **Multimodal Vision Agent (`_visionModel`):** Accepts live camera JPEG bytes (`DataPart('image/jpeg', imageBytes)`) alongside the user's spoken question (`TextPart`) to describe the room, objects, colors, hazards, and text in 1–2 empathetic sentences.
- **Why We Used It:** On-device models can only classify fixed categories (e.g., "chair", "bottle"). When a blind user asks *"What am I looking at?"*, *"Is this shirt blue or black?"*, or *"Describe the room in front of me"*, a multimodal vision-language model is required to reason about the entire scene holistically. We chose `gemini-1.5-flash` over `gemini-1.5-pro` because Flash delivers sub-second time-to-first-token latency ideal for real-time audio feedback.
- **Where It Is Used:**
  - `lib/services/gemini_assistant_service.dart` (Lines 1–258)
  - `lib/providers/voice_assistant_providers.dart` (Lines 142–225)
  - `lib/ui/widgets/gemini_wave_overlay.dart` (Lines 1–201)
- **How It Works:** When the user says *"What am I looking at?"* or speaks a conversational query not matched by the fast-path parser, `VoiceAssistantNotifier` snapshots a JPEG frame via `CameraService.extractFrame()` and sends it to `GeminiAssistantService.describeCameraScene()`. If the Gemini API key is not passed via `--dart-define=GEMINI_API_KEY=...` or the device is offline, it gracefully falls back to `_describeSceneOfflineFallback()` using live on-device object detections.

#### Runtime Engine 3: Google ML Kit Image Labeling Engine (`ObjectDetectionService`)
- **What It Is:** Google ML Kit's on-device `ImageLabeler` (`google_mlkit_image_labeling: ^0.14.2`) configured with a base `confidenceThreshold: 0.28` and paired with a custom **18-Category Physical Object Semantic Rule Engine**.
- **Why We Used It:** Standard bounding-box detectors often fail on motion-blurred frames from wearable smart glasses or return unhelpful abstract classes. By combining ML Kit's hardware-accelerated `ImageLabeler` with a custom synonym-matching dictionary (`_physicalObjectRules`) and a banned-label filter (`_bannedLabels`), the app reliably identifies 18 everyday indoor/outdoor objects with high accuracy and zero internet dependency.
- **Where It Is Used:**
  - `lib/services/object_detection_service.dart` (Lines 1–304)
  - `lib/providers/detection_providers.dart` (Lines 1–215)
  - `lib/ui/detect_mode_screen.dart` (Lines 1–285)

#### Runtime Engine 4: Google ML Kit Latin Text Recognizer (`OcrService` & `CurrencyService`)
- **What It Is:** Google ML Kit's on-device `TextRecognizer(script: TextRecognitionScript.latin)` (`google_mlkit_text_recognition: ^0.15.1`).
- **Why We Used It:** Blind users need two distinct text-based capabilities:
  1. **Reading documents, books, menus, and street signs** (`OcrService`).
  2. **Identifying Indian Rupee banknotes (`₹10`, `₹20`, `₹50`, `₹100`, `₹200`, `₹500`)** (`CurrencyService`). Because Indian banknotes print large, high-contrast numerals (`10`, `20`, `50`, `100`, `200`, `500`), OCR regex matching (`\b(500|200|100|50|20|10)\b`) is significantly faster and less prone to color/lighting false positives than a small custom image classifier.
- **Where It Is Used:**
  - `lib/services/ocr_service.dart` (Lines 1–137)
  - `lib/services/currency_service.dart` (Lines 1–127)
  - `lib/providers/ocr_providers.dart` & `lib/providers/currency_providers.dart`
  - `lib/ui/read_mode_screen.dart` & `lib/ui/currency_mode_screen.dart`

#### Runtime Engine 5: TensorFlow Lite Edge Interpreter (`TFLiteService`)
- **What It Is:** An on-device TensorFlow Lite (`tflite_flutter: ^0.12.1`) multi-threaded interpreter (`InterpreterOptions()..threads = 4`) supporting SSD MobileNet (`assets/models/object_detection.tflite`, 300×300×3 input tensor, 4 output tensors: boxes, classes, scores, count) and currency classification (`assets/models/currency_classifier.tflite`, 224×224×3 input tensor).
- **Why We Used It:** Provides low-level tensor inference infrastructure for custom `.tflite` models alongside ML Kit.
- **Where It Is Used:**
  - `lib/services/tflite_service.dart` (Lines 1–145)
  - `assets/models/object_detection.tflite` & `assets/labels/object_labels.txt`

---

### 3.2 Development & Engineering AI Agents Used to Build the Project

During our development sessions, we also utilized specialized **AI Software Engineering Agents** to analyze, architect, debug, and verify the project:

| Development Agent | Role / Type | Why We Used It | What Output It Produced |
|---|---|---|---|
| **Antigravity Primary Agent** | Lead Full-Stack & AI Systems Architect | End-to-end debugging, writing Flutter/Dart services, fixing camera/voice race conditions, ADB testing, and Git automation. | All production code fixes across `lib/`, Gradle builds, live device testing, and GitHub setup. |
| **GSD Codebase Mapper #1 (`tech`)** | Technology & Integrations Analyst | Audited `pubspec.yaml`, Android manifests, native FFI bindings, and external REST APIs. | `.planning/codebase/STACK.md` & `.planning/codebase/INTEGRATIONS.md` |
| **GSD Codebase Mapper #2 (`arch`)** | System Architecture & Structure Analyst | Mapped the 4-layer Riverpod architecture, dual-camera strategy pattern, and directory tree. | `.planning/codebase/ARCHITECTURE.md` & `.planning/codebase/STRUCTURE.md` |
| **GSD Codebase Mapper #3 (`quality`)** | Coding Conventions & Style Auditor | Analyzed naming conventions, state immutability (`copyWith`), error handling, and accessibility rules. | `.planning/codebase/CONVENTIONS.md` & `.planning/codebase/TESTING.md` |
| **GSD Codebase Mapper #4 (`concerns`)** | Bug, Security & Performance Auditor | Identified memory leaks, camera buffer bugs, race conditions, and edge cases across the codebase. | `.planning/codebase/CONCERNS.md` |

---

## 4. System Architecture & Layered Design (Why & How)

### Why We Chose Layered Clean Architecture + Riverpod
In an assistive app for blind users, **hardware resources (Camera, Microphone, Speaker, GPS) are shared globally across screens**:
- The **Microphone** (`VoiceAssistantService`) must stay active even while the user navigates from the Home Screen to Object Detection, Currency, or Navigation.
- The **Speaker / TTS** (`TTSService`) must coordinate with the Microphone so the app doesn't hear its own voice and trigger false commands, while still allowing the user to barge in ("Stop!").
- The **Camera** (`CameraService`) must stream frames to whichever vision mode is currently active without crashing when switching modes.

If hardware services were owned inside individual StatefulWidgets, switching screens would destroy and recreate the microphone and camera on every transition. Instead, **Riverpod `Provider` and `StateNotifierProvider` singletons** own the hardware lifecycles at the root `ProviderScope` (`lib/main.dart`), while UI screens simply observe immutable state slices.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        1. PRESENTATION LAYER (UI)                       │
│  Screens: HomeScreen, DetectModeScreen, CurrencyModeScreen,             │
│           ReadModeScreen, NavigateModeScreen                            │
│  Widgets: VoiceAssistantBar, GeminiWaveOverlay, CameraPreviewWidget,    │
│           AccessibleButton, StatusBanner                                │
└────────────────────────────────────▲────────────────────────────────────┘
                                     │ ref.watch() / ref.read()
┌────────────────────────────────────▼────────────────────────────────────┐
│                 2. APPLICATION STATE LAYER (RIVERPOD)                   │
│  • VoiceAssistantNotifier  • CameraStateNotifier   • TTSStateNotifier   │
│  • DetectionStateNotifier  • CurrencyStateNotifier • OcrStateNotifier   │
│  • NavigationStateNotifier                                              │
└────────────────────────────────────▲────────────────────────────────────┘
                                     │ Calls async methods & listens to streams
┌────────────────────────────────────▼────────────────────────────────────┐
│                   3. SERVICES & INFRASTRUCTURE LAYER                    │
│  • VoiceAssistantService   • GeminiAssistantService • CameraService     │
│  • ObjectDetectionService  • CurrencyService        • OcrService        │
│  • NavigationService       • LocationService        • TTSService        │
│  • TFLiteService                                                        │
└────────────────────────────────────▲────────────────────────────────────┘
                                     │ Instantiates & transforms
┌────────────────────────────────────▼────────────────────────────────────┐
│                    4. DOMAIN MODELS & CORE UTILITIES                    │
│  Models: DetectionResult, BoundingBox, CurrencyResult, OcrResult,       │
│          NavigationStep, RouteInfo                                      │
│  Core:   AppConstants, AppTheme, AudioFeedback, ImageUtils              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Complete Codebase Reference (Where Everything Is & What Code We Used)

Below is the complete, file-by-file breakdown of every file in the repository (`c:\Users\admin\OneDrive\Desktop\Glasses for blind by anity`).

### Directory Tree Overview
```
EchoVisionpro/
├── android/                                  # Android native project (Kotlin, Gradle, Manifest)
│   └── app/src/main/AndroidManifest.xml      # Permissions (Camera, Record Audio, Fine Location, USB)
├── assets/
│   ├── labels/
│   │   ├── currency_labels.txt               # Indian Rupee labels (10, 20, 50, 100, 200, 500)
│   │   └── object_labels.txt                 # 80 COCO object detection class names
│   └── models/
│       └── object_detection.tflite           # Quantized SSD MobileNet v1 TFLite model
├── lib/
│   ├── main.dart                             # App bootstrap, portrait lock, ProviderScope
│   ├── app.dart                              # MaterialApp, appNavigatorKey, GeminiWaveOverlay host
│   ├── core/
│   │   ├── constants/app_constants.dart      # Thresholds, timeouts, dimensions, TTS settings
│   │   ├── theme/app_theme.dart              # High-contrast dark theme & neon palette
│   │   └── utils/
│   │       ├── audio_feedback.dart           # Haptic feedback patterns (light, medium, heavy, error)
│   │       └── image_utils.dart              # YUV420/NV21 to RGB conversion, resizing, normalization
│   ├── models/
│   │   ├── currency_result.dart              # CurrencyResult model & spokenOutput formatter
│   │   ├── detection_result.dart             # DetectionResult & BoundingBox spatial math
│   │   ├── navigation_step.dart              # NavigationStep & RouteInfo models
│   │   └── ocr_result.dart                   # OcrResult, TextBlockInfo, TextLineInfo models
│   ├── providers/
│   │   ├── camera_providers.dart             # CameraStateNotifier & cameraFrameStreamProvider
│   │   ├── currency_providers.dart           # CurrencyStateNotifier
│   │   ├── detection_providers.dart          # DetectionStateNotifier (anti-spam speech logic)
│   │   ├── navigation_providers.dart         # NavigationStateNotifier (GPS tracking & turn prompts)
│   │   ├── ocr_providers.dart                # OcrStateNotifier
│   │   ├── tts_providers.dart                # TTSStateNotifier
│   │   └── voice_assistant_providers.dart    # VoiceAssistantNotifier (Global router & Gemini bridge)
│   ├── services/
│   │   ├── camera_service.dart               # CameraSource strategy (NativeCameraSource & UvcCameraSource)
│   │   ├── currency_service.dart             # ML Kit OCR banknote recognizer
│   │   ├── gemini_assistant_service.dart     # Gemini 1.5 Flash Intent & Multimodal Vision service
│   │   ├── location_service.dart             # Geolocator high-accuracy GPS stream service
│   │   ├── navigation_service.dart           # OSRM foot routing, Nominatim geocoding, Haversine fallback
│   │   ├── object_detection_service.dart     # ML Kit ImageLabeler + 18-category semantic rule engine
│   │   ├── ocr_service.dart                  # ML Kit TextRecognizer document & sign reader
│   │   ├── tflite_service.dart               # TensorFlow Lite interpreter wrapper
│   │   ├── tts_service.dart                  # FlutterTts priority queue & 8s watchdog timer
│   │   └── voice_assistant_service.dart      # Continuous SpeechToText, wake-word & 14-intent parser
│   └── ui/
│       ├── home_screen.dart                  # 2x2 accessible mode grid + permission request + voice bar
│       ├── detect_mode_screen.dart           # Live 3 FPS object detection + bounding box overlay
│       ├── currency_mode_screen.dart         # Live 1.5s auto-scanning Indian Rupee detector
│       ├── read_mode_screen.dart             # Continuous OCR reader with 75% overlap suppression
│       ├── navigate_mode_screen.dart         # OpenStreetMap live view + voice/quick-chip destinations
│       └── widgets/
│           ├── accessible_button.dart        # Semantics-annotated high-contrast button with haptics
│           ├── camera_preview_widget.dart    # Dual-renderer (Native CameraPreview vs USB Texture)
│           ├── gemini_wave_overlay.dart      # Animated 4-color glowing AI wave bar at top of screen
│           ├── status_banner.dart            # Top status bar with animated activity dot
│           └── voice_assistant_bar.dart      # Interactive mic control bar with pulsing animations
├── test/
│   └── widget_test.dart                      # Unit tests for models, spatial positions, & voice parser
├── pubspec.yaml                              # Dependencies and asset declarations
└── sync_to_github.ps1                        # One-command PowerShell script to commit & push to GitHub
```

---

### 5.1 Application Entry Points (`lib/main.dart`, `lib/app.dart`)

#### 1. `lib/main.dart` (36 lines)
- **Purpose:** Initializes Flutter bindings, locks orientation to Portrait (`DeviceOrientation.portraitUp`, `DeviceOrientation.portraitDown`) so spatial left/right camera coordinates remain consistent relative to the user's body, styles the Android system navigation/status bars in dark mode, and wraps the app in Riverpod's `ProviderScope`.

#### 2. `lib/app.dart` (34 lines)
- **Purpose:** Defines the global navigator key:
  ```dart
  final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
  ```
  and configures `MaterialApp` with `navigatorKey: appNavigatorKey`, `AppTheme.darkTheme`, and a global `builder` that overlays `GeminiWaveOverlay` at the top of every screen in the application while clamping `TextScaler.linear` between `1.0` and `1.3` so OS font scaling never breaks high-contrast button layouts.

---

### 5.2 Core Utilities & Theme (`lib/core/`)

#### 1. `lib/core/constants/app_constants.dart` (61 lines)
- **Purpose:** Centralizes all numeric tuning parameters:
  - `objectDetectionConfidenceThreshold = 0.5` (and `0.28` in `ObjectDetectionService` for broad recall before rule filtering)
  - `currencyConfidenceThreshold = 0.7`
  - `objectDetectionInputSize = 300`, `currencyInputSize = 224`
  - `defaultSpeechRate = 0.5`, `defaultPitch = 1.0`, `defaultVolume = 1.0`, `defaultLanguage = 'en-US'`
  - `frameSkipCount = 5`
  - `locationUpdateIntervalMeters = 5.0`, `turnPromptDistanceMeters = 15.0`
  - `currencyLabels = ['₹10', '₹20', '₹50', '₹100', '₹200', '₹500']`

#### 2. `lib/core/theme/app_theme.dart` (141 lines)
- **Purpose:** Defines the WCAG AAA high-contrast dark theme (`#121212` background, `#1E1E2E` surface, `#2A2A3C` card) and feature-coded neon colors:
  - **Detect Objects:** Purple (`#6C63FF`)
  - **Currency Reader:** Cyan (`#00E5FF`)
  - **Read Text (OCR):** Green (`#76FF03`)
  - **Navigation:** Orange (`#FF9100`)

#### 3. `lib/core/utils/audio_feedback.dart` (54 lines)
- **Purpose:** Provides tactile confirmation for blind users via `HapticFeedback` and `SystemSound`:
  - `lightHaptic()` -> button hover/minor state change
  - `mediumHaptic()` -> mode change
  - `heavyHaptic()` -> major confirmation / voice command recognized
  - `doubleVibrate()` -> important alert (2 pulses separated by 100ms)
  - `errorFeedback()` -> 3 rapid pulses separated by 80ms

#### 4. `lib/core/utils/image_utils.dart` (167 lines)
- **Purpose:** Low-level pixel manipulation for camera frames:
  - `convertYUV420ToRGB(CameraImage)` (Lines 10–94): Converts 1-plane, 2-plane (NV21/NV12), and 3-plane (YUV_420_888) camera buffers into `img.Image` RGB format using ITU-R BT.601 integer math:
    $$R = \text{clamp}\left(\frac{298(Y - 16) + 409(V - 128) + 128}{256}, 0, 255\right)$$
    $$G = \text{clamp}\left(\frac{298(Y - 16) - 100(U - 128) - 208(V - 128) + 128}{256}, 0, 255\right)$$
    $$B = \text{clamp}\left(\frac{298(Y - 16) + 516(U - 128) + 128}{256}, 0, 255\right)$$
  - `resizeImage()` (Lines 97–104): Bilinear interpolation resize for TFLite tensors (`300x300` or `224x224`).
  - `normalizePixels()` & `imageToUint8List()` (Lines 107–156): Converts RGB pixels into 4D `[1, H, W, 3]` tensors.

---

### 5.3 Domain Data Models (`lib/models/`)

1. **`lib/models/detection_result.dart` (95 lines):**
   - `DetectionResult`: Holds `label`, `confidence`, and `BoundingBox`.
   - `positionDescription`: Divides normalized X center (`centerX` in `[0.0, 1.0]`) into 3 spatial zones:
     - `centerX < 0.33` $\rightarrow$ `"to the left"`
     - `centerX > 0.66` $\rightarrow$ `"to the right"`
     - `0.33 <= centerX <= 0.66` $\rightarrow$ `"ahead"`
   - `spokenSummary`: Formats `"$label $positionDescription"` (e.g., `"Chair ahead"`, `"Bottle to the left"`).
2. **`lib/models/currency_result.dart` (36 lines):**
   - `CurrencyResult`: Holds `denomination` (e.g., `"₹500"`), `confidence`, and `timestamp`.
   - `spokenOutput`: Converts `"₹500"` into `"500 Rupees detected"`.
3. **`lib/models/ocr_result.dart` (72 lines):**
   - `OcrResult`, `TextBlockInfo`, `TextLineInfo`: Stores full recognized text, individual bounding boxes, and `summary` (truncates text over 500 characters for comfortable listening).
4. **`lib/models/navigation_step.dart` (92 lines):**
   - `NavigationStep`: Holds `instruction`, `distanceMeters`, `durationSeconds`, `startLat`, `startLng`, `endLat`, `endLng`, `maneuver`.
   - `spokenInstruction`: Formats `"In 25 meters, turn left onto Main Street"` or `"Now, turn left"` when `< 10` meters.
   - `RouteInfo`: Aggregates `destination`, `totalDistanceMeters`, `totalDurationSeconds`, `steps`, and `polylinePoints` (`List<LatLng>`).

---

### 5.4 Hardware, AI, & Cloud Services (`lib/services/`)

#### 1. `lib/services/voice_assistant_service.dart` (534 lines)
- **What Code We Used:** `stt.SpeechToText` from `speech_to_text: ^7.4.0`, Dart `StreamController.broadcast()`, `Timer.periodic` watchdog, and a multi-stage regex NLU parser.
- **Key Methods:**
  - `initialize()` (Lines 78–125): Initializes Android SpeechRecognizer, attaches `onStatus` and `onError` handlers, and caches the `en_IN` locale for accurate recognition of Indian English accents.
  - `_startLivenessWatchdog()` (Lines 128–136): Runs every 4 seconds to check if `_continuousMode && !_speech.isListening && !_isRestarting` and automatically restarts listening.
  - `_isAcousticEcho(String words)` (Lines 174–190): Checks if recognized words match `_lastTtsPhrase` spoken within the last 4 seconds—unless the user spoke an actionable command keyword (enabling real-time barge-in).
  - `startListening()` (Lines 193–288): Listens with `partialResults: true`, `listenFor: 30s`, `pauseFor: 5s`, `listenMode: stt.ListenMode.confirmation`.
  - `parseCommand(String input)` (Lines 326–511): Strips wake words (`hey echo`, `ok echo`, `eko`, `eco`, `ok google`, etc.), strips conversational prefixes (`can you please`, `i want to`, `show me`), and matches 14 command categories using word-boundary regexes (`_containsAny`).

#### 2. `lib/services/gemini_assistant_service.dart` (258 lines)
- **What Code We Used:** `GenerativeModel` from `google_generative_ai: ^0.4.7`.
- **Key Methods:**
  - `initialize()` (Lines 45–107): Configures `_intentModel` (`gemini-1.5-flash` with JSON schema output) and `_visionModel` (`gemini-1.5-flash` multimodal).
  - `processUserSpeech(String rawText)` (Lines 110–159): Sends unrecognized speech to Gemini with a **4-second timeout** so slow networks never stall the app, falling back to `_offlineSmartFallback()`.
  - `describeCameraScene(Uint8List imageBytes, String userPrompt)` (Lines 163–191): Sends live camera JPEG bytes + prompt to `_visionModel` with an **8-second timeout** to narrate the scene for the blind user.

#### 3. `lib/services/camera_service.dart` (372 lines)
- **What Code We Used:** `camera: ^0.11.3+1` (`CameraController`) and `flutter_ffi_uvc: ^0.11.0` (`UvcCamera`).
- **Key Classes & Methods:**
  - `CameraSource` (Abstract Strategy Interface, Lines 11–26): Defines `initialize()`, `startStream()`, `stopStream()`, `extractFrame()`, `dispose()`, `frameStream`, `textureId`, `aspectRatio`, and `cameraName`.
  - `NativeCameraSource` (Lines 31–167): Manages the built-in phone camera (`ResolutionPreset.medium`, `enableAudio: false` so it never conflicts with the voice assistant microphone, `ImageFormatGroup.nv21` on Android). Streams frames throttled to ~8 FPS (`125ms`) and supports `extractFrame()` via `takePicture()` or NV21 conversion fallback.
  - `UvcCameraSource` (Lines 172–255): Connects to external **Sony IMX378 Smart Glasses** via USB-C OTG, allocates a native Flutter hardware texture (`createPreviewTexture()`), starts auto-negotiated quality preview (`startPreviewAuto`), and captures JPEG frames via `takePicture()`.
  - `CameraService` (Lines 260–371): Facade that auto-detects attached USB UVC cameras (`hasUsbCameraAttached()`) or toggles between phone camera and smart glasses via `toggleCameraSource()`.

#### 4. `lib/services/object_detection_service.dart` (304 lines)
- **What Code We Used:** `google_mlkit_image_labeling: ^0.14.2` (`ImageLabeler`, `InputImage`).
- **Key Data Structures & Methods:**
  - `_bannedLabels` (Lines 16–28): 60+ banned abstract concepts (`font`, `monochrome`, `parallel`, `symmetry`, `ceiling`, `floor`, `darkness`, etc.).
  - `_physicalObjectRules` (Lines 32–52): Maps 18 tangible object categories to synonym lists.
  - `detectFromFile(String imagePath)` (Lines 66–81): Runs ML Kit labeling on a captured JPEG file.
  - `detectObjects(CameraImage image, int sensorOrientation)` (Lines 160–177): Converts live `CameraImage` frames into `InputImage` via `_convertCameraImage()` (handling both 1-plane NV21 and 3-plane YUV420 buffers into NV21 byte layout) and runs `_processInputImage()`.

#### 5. `lib/services/currency_service.dart` (127 lines)
- **What Code We Used:** `google_mlkit_text_recognition: ^0.15.1` (`TextRecognizer`).
- **Key Methods:**
  - `detectFromFile(String imagePath)` (Lines 29–68): Scans captured frame for regex `\b(500|200|100|50|20|10)\b`, maps matched value to `'₹$val'`, and returns `CurrencyResult(denomination: matchedNote, confidence: 0.92)`.

#### 6. `lib/services/ocr_service.dart` (137 lines)
- **What Code We Used:** `google_mlkit_text_recognition: ^0.15.1` (`TextRecognizer(script: TextRecognitionScript.latin)`).
- **Key Methods:**
  - `recognizeFromFile(String imagePath)` (Lines 26–83): Extracts `RecognizedText`, sorts blocks top-to-bottom (`a.boundingBox.top.compareTo(b.boundingBox.top)`), and builds structured `OcrResult` blocks and lines for natural reading order.

#### 7. `lib/services/navigation_service.dart` (373 lines) & `lib/services/location_service.dart` (115 lines)
- **What Code We Used:** `geolocator: ^14.0.3`, `http: ^1.3.0`, `latlong2: ^0.10.1`.
- **Key Methods in `NavigationService`:**
  - `getWalkingDirections()` (Lines 23–41): Tries **OSRM Foot Routing** first (`_getOSRMDirections` at `https://router.project-osrm.org/route/v1/foot/`), falls back to Google Directions API if configured, and falls back to offline Haversine vector routing (`_generateOfflineRoute`) if offline.
  - `getCurrentAddress(double lat, double lng)` (Lines 202–228): Queries OpenStreetMap **Nominatim Reverse Geocoding API** (`https://nominatim.openstreetmap.org/reverse?format=json&lat=...&lon=...`) to speak the user's current street, neighborhood, and city when they ask *"Where am I?"*.
  - `searchPlace(String query, ...)` (Lines 231–273): Resolves spoken destination names (e.g., *"Central Park"*, *"Hospital"*) into GPS coordinates via Nominatim search.

#### 8. `lib/services/tts_service.dart` (194 lines)
- **What Code We Used:** `flutter_tts: ^4.2.5`.
- **Key Features:**
  - **Queue & Interrupt Priority:** Supports immediate speech interruption (`interrupt: true`) for urgent alerts or sequential queuing (`_speechQueue`, max 5 items) for non-urgent updates.
  - **8-Second Stuck-Callback Watchdog (`_resetSpeakWatchdog`, Lines 95–104):** On some Android OEMs, `FlutterTts.onComplete` occasionally fails to fire, which would permanently lock `isSpeaking = true`. The 8-second watchdog timer automatically resets `_isSpeaking = false` and drains the queue.

---

### 5.5 Reactive State Management Providers (`lib/providers/`)

1. **`lib/providers/voice_assistant_providers.dart` (444 lines):**
   - `VoiceAssistantNotifier`: Subscribes to `VoiceAssistantService` streams (`listeningStatusStream`, `partialWordsStream`, `commandStream`), coordinates with `ttsStateProvider` for acoustic echo tracking, routes known commands on the **0ms Fast Path** (`_executeCommandGlobally`), routes unknown/conversational queries to **Gemini 1.5 Flash** (`_processCommandWithGemini`), and executes **Atomic Screen Swaps** (`nav.pushReplacement`) via `appNavigatorKey`.
2. **`lib/providers/detection_providers.dart` (215 lines):**
   - `DetectionStateNotifier`: Runs `detectInFile()` and `processFrame(CameraImage)`, maintains `DetectionState`, and implements the **Anti-Audio-Spam Gate**:
     - Manual tap (`forceSpeak: true`) speaks immediately (even if `"No objects clearly visible"`).
     - Automatic background stream only speaks when the top object label changes OR 10 seconds have passed since the last announcement, and never speaks while TTS is currently active.
3. **`lib/providers/camera_providers.dart` (146 lines):**
   - `CameraStateNotifier`: Manages camera initialization, frame streaming, source toggling (Phone vs. IMX378 USB Glasses), and exposes `cameraFrameStreamProvider`.
4. **`lib/providers/currency_providers.dart` (104 lines):**
   - `CurrencyStateNotifier`: Captures frames via `cameraService.extractFrame()`, runs `CurrencyService.detectFromFile()`, and speaks the detected Rupee denomination.
5. **`lib/providers/ocr_providers.dart` (129 lines):**
   - `OcrStateNotifier`: Captures frames, runs `OcrService.recognizeFromFile()`, and manages continuous vs. single-shot reading state.
6. **`lib/providers/navigation_providers.dart` (258 lines):**
   - `NavigationStateNotifier`: Streams live GPS updates from `LocationService`, computes distance to the next waypoint, advances steps within 15 meters, and announces turn-by-turn directions.
7. **`lib/providers/tts_providers.dart` (94 lines):**
   - `TTSStateNotifier`: Exposes `TTSState(isSpeaking, currentText, speechRate, language)` reactively to the UI and voice assistant.

---

### 5.6 Accessible User Interface & Widgets (`lib/ui/`)

1. **`lib/ui/home_screen.dart` (340 lines):**
   - Requests runtime permissions (`camera`, `microphone`, `locationWhenInUse`).
   - Starts continuous `"Hey Echo"` listening (`startContinuousListening()`) and speaks the welcome greeting (`AppConstants.welcomeMessage`).
   - Displays hardware connection banner (`Phone Camera` vs. `IMX378 Smart Glasses` with a 1-tap `Switch` button).
   - Renders a 2×2 high-contrast grid of `AccessibleButton` cards (**Detect Objects**, **Currency**, **Read Text**, **Navigate**) plus the bottom `VoiceAssistantBar`.
2. **`lib/ui/detect_mode_screen.dart` (285 lines):**
   - Streams live camera frames at 3 FPS (`350ms` throttle) into `DetectionStateNotifier.processFrame(frame)` and runs a backup high-res snapshot timer every 2.5s.
   - Draws real-time neon bounding boxes and confidence badges via `_BoundingBoxPainter` (`CustomPainter`).
   - Full-screen tap triggers immediate manual scan & voice announcement; double-tap toggles continuous detection.
3. **`lib/ui/currency_mode_screen.dart` (225 lines):**
   - Runs a periodic 1.5-second auto-scanner (`_autoScanTimer`) when continuous scanning is active.
   - Displays a centered cyan targeting reticle and large denomination readout (`₹500`, `₹200`, etc.).
4. **`lib/ui/read_mode_screen.dart` (266 lines):**
   - Runs a 4-second periodic OCR scanner with **Jaccard word-overlap deduplication (`_isSimilarText`, threshold `0.75`)** so holding the camera over the same page does not repeat the same paragraph endlessly.
5. **`lib/ui/navigate_mode_screen.dart` (453 lines):**
   - Renders a live interactive dark-tinted **OpenStreetMap** (`FlutterMap` + `TileLayer` + `PolylineLayer` + `MarkerLayer` showing user GPS dot and destination pin).
   - Provides quick-destination chips (`Hospital`, `Pharmacy`, `Bus Stop`, `Train Station`, `Park`, `Restaurant`, `ATM`), a voice mic search button, a text search bar, and a high-contrast orange Turn Instruction Card.
6. **Reusable Widgets (`lib/ui/widgets/`):**
   - `gemini_wave_overlay.dart`: Renders a 4-color (`#4285F4`, `#EA4335`, `#FBBC05`, `#34A853`) animated sinusoidal wave bar at the very top of the screen whenever the voice assistant is listening or thinking.
   - `voice_assistant_bar.dart`: Pulsing microphone control bar showing live partial transcripts and AI responses.
   - `camera_preview_widget.dart`: Automatically switches between `Texture(textureId: ...)` for USB-C Smart Glasses and `CameraPreview(controller)` for the built-in phone camera.
   - `accessible_button.dart` & `status_banner.dart`: High-contrast, TalkBack-annotated UI components.

---

## 6. Deep-Dive Technical Workflows (How Everything Works Under the Hood)

### 6.1 Continuous "Hey Echo" / Direct-Command Voice Assistant Engine

Android's `SpeechRecognizer` is designed for short single-shot dictation—not continuous wake-word listening. To make it behave like **OK Google / Alexa** inside our app, we engineered a 4-part state machine in `VoiceAssistantService` (`lib/services/voice_assistant_service.dart`):

```
                    ┌──────────────────────────────────────┐
                    │       App Launch (HomeScreen)        │
                    │  enableContinuousListening() called  │
                    └──────────────────┬───────────────────┘
                                       ▼
                    ┌──────────────────────────────────────┐
                    │     _speech.listen(30s, en_IN)       │◄──────────────┐
                    │   partialResults: true, pauseFor: 5s │               │
                    └──────────────────┬───────────────────┘               │
                                       │                                   │
          ┌────────────────────────────┼────────────────────────────┐      │
          ▼                            ▼                            ▼      │
┌───────────────────┐      ┌───────────────────────┐      ┌──────────────┐ │
│ Partial Callback  │      │    Final Callback     │      │ Status: done │ │
│ (Every ~150ms)    │      │ (result.finalResult)  │      │ or onError   │ │
└─────────┬─────────┘      └───────────┬───────────┘      └──────┬───────┘ │
          │                            │                         │         │
          ▼                            ▼                         │         │
  Is it an Actionable          Did user say ONLY                 │         │
  Command? (e.g.               "Hey Echo" (wakeWord)             │         │
  "open currency")             or open question?                 │         │
          │                            │                         │         │
          ├─► YES: Dispatch            ├─► YES: Dispatch         │         │
          │   Immediately (0ms)!       │   to TTS / Gemini!      │         │
          └────────────────────────────┴────────────┬────────────┘         │
                                                    ▼                      │
                                     ┌─────────────────────────────┐       │
                                     │ _restartContinuousListening │───────┘
                                     │ (350ms–950ms smart delay +  │
                                     │  4s Liveness Watchdog)      │
                                     └─────────────────────────────┘
```

### 6.2 Dual-Tier Intent Routing: 0ms Fast-Path vs. Gemini 1.5 Flash Cloud AI

When `VoiceAssistantService` emits a `VoiceCommand` on `commandStream`, `VoiceAssistantNotifier` (`lib/providers/voice_assistant_providers.dart`, Lines 110–131) evaluates:
1. **Barge-In Interruption:** If `cmd.type != VoiceCommandType.wakeWordPrompt`, it immediately calls `_ref.read(ttsStateProvider.notifier).stop()` so whatever the app was saying is silenced immediately.
2. **Tier 1 — Local Fast Path (`cmd.type != VoiceCommandType.unknown`):**
   - Executes `_executeCommandGlobally(cmd)` in **0 milliseconds** with zero network calls.
   - Handles all 14 core intents (`openCurrency`, `openObjectDetection`, `openReadText`, `openNavigation`, `whereAmI`, `switchCamera`, `describeScene`, `goHome`, `wakeWordPrompt`, `stopSpeaking`, `tellTime`, `tellDate`, `tellStatus`, `help`).
3. **Tier 2 — Cloud AI Path (`cmd.type == VoiceCommandType.unknown`):**
   - Triggered when the user wakes Echo (*"Hey Echo"*) and asks an open-ended question (e.g., *"What should I wear if it's raining?"* or unusual phrasing like *"I need to pay the shopkeeper"*).
   - Calls `GeminiAssistantService.processUserSpeech(cmd.rawText)` which returns structured JSON (`GeminiAssistantResponse`) to either trigger the right app screen or speak a helpful conversational answer.

### 6.3 Real-Time Object Detection Pipeline & Semantic Filtering

In `DetectModeScreen` (`lib/ui/detect_mode_screen.dart`), frames flow through two complementary pathways:
1. **High-Frequency Stream Pathway (Every 350ms / ~3 FPS):**
   - `ref.listen<AsyncValue<CameraImage>>(cameraFrameStreamProvider, ...)` receives raw YUV420/NV21 frames from the camera sensor.
   - `ObjectDetectionService.detectObjects(image, sensorOrientation)` packs the Y, U, and V planes into a contiguous NV21 byte buffer (`_convertCameraImage`), constructs an ML Kit `InputImage`, and runs `ImageLabeler.processImage()`.
2. **Semantic Rule Engine (`_processInputImage`):**
   - Raw ML Kit labels with confidence $\ge 0.28$ are checked against `_bannedLabels` (filtering out useless abstract words like `"monochrome"`, `"font"`, `"rectangle"`).
   - Remaining labels are matched against `_physicalObjectRules` (18 physical object categories) and boosted by `+0.15` confidence when a specific rule matches.
   - Up to 3 distinct physical objects per frame are emitted with spatial coordinates (`left`, `ahead`, `right`) and spoken via the anti-spam TTS gate.

### 6.4 Indian Rupee Banknote (Currency) Recognition Pipeline

In `CurrencyModeScreen` (`lib/ui/currency_mode_screen.dart`):
1. Every **1.5 seconds**, `_autoScanTimer` calls `CurrencyStateNotifier.detectCurrentFrame()`.
2. `CameraService.extractFrame()` captures a JPEG image from the active camera source (Phone or IMX378 Smart Glasses) and writes a temporary file `temp_currency_frame.jpg`.
3. `CurrencyService.detectFromFile()` runs `TextRecognizer` on the frame and searches all recognized text blocks for the regex `\b(500|200|100|50|20|10)\b`.
4. When a valid Indian Rupee denomination (`₹10`, `₹20`, `₹50`, `₹100`, `₹200`, `₹500`) is matched, TTS immediately interrupts and announces: **"500 Rupees detected"**.

### 6.5 Optical Character Recognition (OCR) & Jaccard Deduplication

In `ReadModeScreen` (`lib/ui/read_mode_screen.dart`):
1. Every **4 seconds** (in continuous mode) or on manual tap, `OcrStateNotifier.captureAndRead()` captures a high-resolution frame and runs `OcrService.recognizeFromFile()`.
2. Text blocks are sorted vertically by `boundingBox.top` so paragraphs are read from top to bottom.
3. To prevent the app from re-reading the exact same page over and over while the user holds a book, `_isSimilarText(String a, String b)` computes the **word-level Jaccard overlap**:
   $$\text{Overlap}(A, B) = \frac{|W_A \cap W_B|}{\max(|W_A|, |W_B|)}$$
   If $\text{Overlap}(A, B) > 0.75$, automatic re-announcement is suppressed until the user turns the page or taps the screen manually.

### 6.6 Pedestrian Turn-by-Turn GPS Navigation & Reverse Geocoding

In `NavigateModeScreen` (`lib/ui/navigate_mode_screen.dart`) and `NavigationStateNotifier` (`lib/providers/navigation_providers.dart`):
1. **"Where Am I?" Reverse Geocoding:** Queries `LocationService.getCurrentPosition()`, sends `(lat, lng)` to OpenStreetMap Nominatim (`NavigationService.getCurrentAddress()`), and speaks the exact street, neighborhood, and city name.
2. **Voice Destination Routing:** Saying *"Navigate to Apollo Hospital"* extracts `argument: "apollo hospital"`, opens `NavigateModeScreen(initialDestination: "apollo hospital")`, resolves the coordinates via Nominatim `searchPlace()`, and fetches foot-walking geometry from **OSRM (`router.project-osrm.org/route/v1/foot/`)**.
3. **Live Waypoint Tracking:** `LocationService.getPositionStream()` emits GPS updates every 2 meters. When the Haversine distance to the current step's end coordinate drops below `15.0` meters (`AppConstants.turnPromptDistanceMeters`), `NavigationStateNotifier` advances `currentStepIndex` and speaks the next turn instruction aloud.

### 6.7 Dual-Camera Hardware Strategy (Sony IMX378 USB-C Glasses vs. Phone Camera)

`CameraService` (`lib/services/camera_service.dart`) implements the **Strategy Design Pattern**:
- On startup, `hasUsbCameraAttached()` queries `UvcCamera().listUsbDevices()` via `flutter_ffi_uvc`.
- If the external **Sony IMX378 USB-C camera** on the smart glasses is plugged in, `UvcCameraSource` is instantiated and bound to a Flutter hardware `Texture(textureId: ...)`.
- Otherwise, `NativeCameraSource` initializes the smartphone's rear camera.
- At any time, the user can say **"Switch camera"** or tap the top hardware banner on the Home Screen to hot-swap between the Phone Camera and the Smart Glasses Camera.

---

## 7. Critical Engineering Bugs We Solved & How We Solved Them

| # | Bug / Symptom | Root Cause | How We Solved It (File & Mechanism) |
|---|---|---|---|
| **1** | Voice assistant listened to only one command and then stopped responding forever. | Android's `SpeechRecognizer` ends its session after a single utterance (`status == 'done'`) or drops out on `error_speech_timeout` / `error_busy`. | Added a 4-second periodic `_startLivenessWatchdog()` and smart backoff `_restartContinuousListeningIfNeeded()` (`350ms` normal, `950ms` on native busy) in `lib/services/voice_assistant_service.dart`. |
| **2** | Saying *"Hey Echo open currency"* caused the app to say *"Yes, I'm listening"* and ignore *"open currency"*. | Partial speech results (`partialResults: true`) matched `wakeWordPrompt` (`"Hey Echo"`) in the first 200ms and immediately stopped the recognizer before the user finished speaking the rest of the sentence. | Updated `onResult` in `lib/services/voice_assistant_service.dart` (Lines 250–256) so `VoiceCommandType.wakeWordPrompt` **only** dispatches when `result.finalResult == true`, while actionable commands dispatch immediately. |
| **3** | Jumping directly from Object Detection to Currency Detection via voice failed or froze the camera. | 1) `DetectModeScreen.deactivate()` called `stopDetection()`, which disposed the shared `CameraController` while the new screen was opening.<br>2) `popUntil` + `push` caused simultaneous route lifecycle collisions. | 1) Removed `cameraService.dispose()` from `stopDetection()` in `lib/providers/detection_providers.dart` so the camera stays hot across mode switches.<br>2) Used `nav.pushReplacement()` in `VoiceAssistantNotifier._globalNavigate()` (`lib/providers/voice_assistant_providers.dart`, Line 360) for atomic screen swapping. |
| **4** | TTS audio output was picked up by the microphone, causing self-triggering loops or blocking user barge-in. | Either the mic was completely killed during TTS (preventing user barge-in) or left raw (hearing its own voice). | Implemented `_isAcousticEcho()` in `lib/services/voice_assistant_service.dart` (Lines 174–190) which filters out phrases matching `_lastTtsPhrase` within 4 seconds **unless** the spoken phrase contains an actionable command keyword (allowing instant user barge-in!). |
| **5** | Words like *"already"* triggered Read Text mode, and *"background"* triggered Go Home. | Substring `.contains('read')` and `.contains('back')` matched inside longer unrelated words. | Replaced substring checks with strict word-boundary regular expressions `RegExp(r'\b' + RegExp.escape(p) + r'\b')` in `_containsAny()` (`lib/services/voice_assistant_service.dart`, Lines 513–523). |
| **6** | Real-time Object Detection threw `RangeError` on certain Android camera image formats. | `ImageUtils.convertYUV420ToRGB()` assumed all frames had 3 separate planes (`planes[0]`, `planes[1]`, `planes[2]`), crashing on 1-plane or 2-plane NV21 frames. | Rewrote `ImageUtils.convertYUV420ToRGB()` (`lib/core/utils/image_utils.dart`, Lines 10–94) to support 1-plane, 2-plane, and 3-plane formats with `.clamp()` index protection. |

---

## 8. Complete Voice Command Matrix

Users can say any of these commands **with or without** `"Hey Echo"` (or `"OK Echo"`, `"Hey Eco"`, `"OK Google"`) from **any screen in the app**:

| Intent (`VoiceCommandType`) | Example Natural Phrases | Action Executed |
|---|---|---|
| `openObjectDetection` | *"Detect objects"*, *"Open object detection"*, *"Are there any obstacles?"*, *"What is around me?"* | Atomically navigates to `DetectModeScreen` and starts 3 FPS live object & obstacle detection. |
| `openCurrency` | *"Open currency"*, *"Count money"*, *"Check rupees"*, *"How much cash is this?"*, *"Currency mode"* | Atomically navigates to `CurrencyModeScreen` and starts 1.5s auto-scanning for Indian Rupee notes (`₹10`–`₹500`). |
| `openReadText` | *"Read text"*, *"Read this book"*, *"What is written here?"*, *"Scan document"*, *"Open OCR"* | Atomically navigates to `ReadModeScreen` and reads printed text aloud with duplicate suppression. |
| `openNavigation` | *"Open navigation"*, *"Navigate to Central Hospital"*, *"Take me to Bus Stop"*, *"Walking directions to pharmacy"* | Atomically navigates to `NavigateModeScreen` and automatically calculates a walking route if a destination was spoken. |
| `describeScene` | *"What am I looking at?"*, *"Describe the scene"*, *"What is in front of me?"*, *"Look around"* | Captures a live frame and uses **Gemini 1.5 Flash Vision** (or offline detection fallback) to narrate the scene. |
| `whereAmI` | *"Where am I?"*, *"What is my current location?"*, *"Which street am I on?"*, *"My address"* | Fetches GPS coordinates and reverse-geocodes the street and city name via OpenStreetMap Nominatim. |
| `tellTime` | *"What time is it?"*, *"Tell me the time"*, *"Current time"* | Speaks the current 12-hour formatted time (e.g., *"The time is 10:15 PM"*). |
| `tellDate` | *"What is today's date?"*, *"What day is today?"*, *"Current date"* | Speaks the current weekday, month, and day (e.g., *"Today is Thursday, October 8"*). |
| `tellStatus` | *"What mode am I in?"*, *"Current screen"*, *"App status"* | Announces the active screen and active camera hardware (Phone Camera vs. IMX378 Smart Glasses). |
| `switchCamera` | *"Switch camera"*, *"Use smart glasses"*, *"Switch to phone camera"* | Toggles hardware feed between built-in Phone Camera and USB-C IMX378 Smart Glasses. |
| `stopSpeaking` | *"Stop"*, *"Quiet"*, *"Be quiet"*, *"Mute"*, *"Stop talking"* | Immediately halts ongoing TTS speech output. |
| `goHome` | *"Go home"*, *"Home screen"*, *"Main menu"*, *"Go back"*, *"Exit"* | Pops back to `HomeScreen` cleanly from any feature mode. |
| `help` | *"Help"*, *"What can you do?"*, *"Commands"* | Speaks the full list of available voice commands aloud. |
| `wakeWordPrompt` | *"Hey Echo"*, *"OK Echo"* (spoken alone) | Responds *"Yes, I'm listening"* and opens a 10-second active conversational window. |

---

## 9. Technology Stack & Dependencies (`pubspec.yaml` Rationale)

| Package | Version | Why We Used It |
|---|---|---|
| `flutter_riverpod` | `^2.6.1` | Compile-safe, context-free reactive state management that allows background voice/hardware services to survive screen navigation. |
| `speech_to_text` | `^7.4.0` | Native Android speech recognition binding supporting partial results, locale selection (`en_IN`), and low-latency streaming. |
| `flutter_tts` | `^4.2.5` | Offline native Text-to-Speech synthesis with completion handlers, rate/pitch control, and immediate interrupt capability. |
| `google_generative_ai` | `^0.4.7` | Official Google Dart SDK for `gemini-1.5-flash` structured JSON intent classification and multimodal camera scene narration. |
| `google_mlkit_image_labeling` | `^0.14.2` | Hardware-accelerated on-device edge classification used by our 18-category physical object rule engine. |
| `google_mlkit_text_recognition` | `^0.15.1` | Fast on-device Latin script OCR engine powering both `ReadModeScreen` and `CurrencyService` (`₹10`–`₹500` note detection). |
| `google_mlkit_object_detection` | `^0.15.1` | On-device object bounding-box tracking support. |
| `tflite_flutter` | `^0.12.1` | Direct C++ TensorFlow Lite interpreter binding for custom `.tflite` models (`object_detection.tflite`). |
| `camera` | `^0.11.3+1` | Official Flutter camera plugin for streaming NV21/YUV420 frames and capturing JPEGs from the built-in phone camera. |
| `flutter_ffi_uvc` | `^0.11.0` | Native C/FFI USB Video Class (UVC) driver enabling plug-and-play video streaming from **Sony IMX378 USB-C Smart Glasses**. |
| `geolocator` | `^14.0.3` | High-accuracy GPS position streaming (`LocationAccuracy.high`, `distanceFilter: 2m`) for pedestrian navigation. |
| `flutter_map` & `latlong2` | `^8.3.1` / `^0.10.1` | Keyless OpenStreetMap vector/tile rendering and Haversine geodesic distance math. |
| `http` | `^1.3.0` | REST client for OSRM walking directions (`router.project-osrm.org`) and Nominatim reverse geocoding (`nominatim.openstreetmap.org`). |
| `permission_handler` | `^11.3.1` | Runtime Android permission requests for Camera, Microphone, and Fine Location. |
| `wakelock_plus` | `^1.1.4` | Prevents the phone screen and CPU from sleeping while a blind user is actively using the smart glasses. |

---

## 10. Build, Deployment, & GitHub Synchronization Guide

### 10.1 Building & Running the App in PowerShell
```powershell
# 1. Fetch Flutter packages
flutter pub get

# 2. Clean and rebuild Android Gradle project (if needed)
cd android
.\gradlew clean
.\gradlew assembleDebug
cd ..

# 3. Install and run on connected Android device (with optional Gemini API Key)
flutter run -d <DEVICE_ID> --dart-define=GEMINI_API_KEY=your_api_key_here
```

### 10.2 Running Unit Tests
```powershell
flutter test
```

### 10.3 Syncing Updates to GitHub (`https://github.com/Uchihaharsh/EchoVisionpro.git`)
Whenever any file is added or modified in the workspace, run the included helper script:
```powershell
.\sync_to_github.ps1 "Describe your update here"
```
Or manually via Git:
```powershell
git add -A
git commit -m "Update project"
git push origin main
```
