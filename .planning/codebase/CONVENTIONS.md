# VisionAssist Codebase Conventions & Quality Guidelines

This document details the architectural conventions, coding style, accessibility patterns, state management rules, and error handling strategies enforced across the **VisionAssist Smart Glasses** codebase.

---

## 1. Coding Standards & Static Analysis

### 1.1 Analyzer Configuration
The static analyzer is configured via [analysis_options.yaml](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/analysis_options.yaml) and includes Flutter's official recommended lints:

```yaml
include: package:flutter_lints/flutter.yaml
```

The dependency is declared in [pubspec.yaml](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/pubspec.yaml#L35):
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

### 1.2 Enforced & Recommended Lint Rules
While the default `flutter_lints` ruleset is active, the codebase adheres to the following conventions:

| Rule | Enforcement Level | Rationale |
|------|-------------------|-----------|
| `avoid_print` | **Mandatory** | `print()` outputs in production release APKs without metadata. Use `debugPrint()` which throttles and integrates cleanly with Flutter DevTools. |
| `prefer_const_constructors` | **Mandatory** | Reduces widget rebuild overhead and garbage collection pressure, critical for 30fps camera and ML loops. |
| `prefer_final_fields` | **Mandatory** | Enforces immutability for service internals and model classes. |
| `unawaited_futures` | **Recommended** | Prevents unhandled asynchronous exceptions in fire-and-forget hardware operations. |
| `use_super_parameters` | **Standard** | Utilizes Dart 3 constructor parameter shortening (e.g. `super.key`). |
| `withValues(alpha:)` | **Modern Flutter Standard** | Codebase standardizes on `color.withValues(alpha: 0.3)` rather than deprecated `withOpacity(0.3)`. |

> [!WARNING]
> **Audit Note: Raw `print()` instances**
> Three legacy `print()` calls exist in [lib/providers/detection_providers.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/providers/detection_providers.dart#L64) (lines 64, 150, 178). These must be replaced with `debugPrint()` to maintain 100% compliance with `avoid_print`.

---

## 2. Naming Conventions

The codebase follows standard Dart/Flutter naming conventions systematically applied across all layers:

### 2.1 File & Directory Names
- **Files**: `lower_snake_case.dart` (e.g., [accessible_button.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/ui/widgets/accessible_button.dart), [gemini_assistant_service.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/gemini_assistant_service.dart)).
- **Directories**: `lower_snake_case` (e.g., `lib/core/utils/`, `lib/providers/`, `lib/services/`, `lib/ui/widgets/`).

### 2.2 Classes & Types
- **Classes**: `UpperCamelCase` describing role and domain:
  - **Widgets**: `HomeScreen`, `ReadModeScreen`, `AccessibleButton`, `StatusBanner`, `CameraPreviewWidget`, `GeminiWaveOverlay`.
  - **Services**: Suffix `Service` (e.g., `CameraService`, `TTSService`, `OcrService`, `VoiceAssistantService`).
  - **Models**: Suffix `Result` or descriptive noun (e.g., `DetectionResult`, `CurrencyResult`, `OcrResult`, `NavigationStep`).
  - **State Classes**: Suffix `State` (e.g., `CameraState`, `TTSState`, `OcrState`, `CurrencyState`, `DetectionState`, `NavigationState`, `VoiceAssistantState`).
  - **StateNotifiers**: Suffix `Notifier` or `StateNotifier` (e.g., `CameraStateNotifier`, `TTSStateNotifier`, `VoiceAssistantNotifier`).

### 2.3 Riverpod Provider Naming Conventions
All providers are declared as top-level `final` variables in `lowerCamelCase` with specific suffix patterns:

| Provider Type | Suffix | Example | File Location |
|---------------|--------|---------|---------------|
| Service Singleton | `...ServiceProvider` | `cameraServiceProvider`, `ttsServiceProvider` | [tts_providers.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/providers/tts_providers.dart#L6) |
| State Notifier | `...StateProvider` | `cameraStateProvider`, `ocrStateProvider` | [ocr_providers.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/providers/ocr_providers.dart#L101) |
| Event / Stream | `...StreamProvider` | `cameraFrameStreamProvider`, `voiceCommandStreamProvider` | [camera_providers.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/providers/camera_providers.dart#L139) |

---

## 3. Accessibility Conventions (Assistive Technology Focus)

Because VisionAssist is an assistive technology application for blind and visually impaired users, accessibility is **the primary design driver**, not an afterthought.

### 3.1 High-Contrast Visual Palette
Defined in [lib/core/theme.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/core/theme.dart) and applied uniformly:

```dart
// Theme Foundations
Scaffold Background: Color(0xFF121212) or Colors.black  // Extreme dark
Primary Accent:      Color(0xFFFFD600) / Colors.yellowAccent // High-contrast bright yellow
Text on Dark:        Colors.white (100% opacity for primary, white70 for secondary)
Text on Accent:      Colors.black (Bold, minimum 22sp)
```

#### Color Meaning & Mode Differentiation
Vibrant, distinct neon-spectrum accents are assigned to features so low-vision users can immediately distinguish modes:
- **Yellow / Amber (`0xFFFFD600`)**: Primary brand, OCR / Read Text mode, Voice Assistant idle.
- **Cyan (`Colors.cyanAccent`)**: IMX378 USB Smart Glasses active, Voice Assistant active listening.
- **Blue (`Colors.blueAccent`)**: Object Detection mode, GPS location / "Where Am I?".
- **Green (`Colors.greenAccent`)**: Currency Recognition mode (Rupees), high-confidence matches.
- **Orange (`Colors.orangeAccent`)**: Navigation mode, turn-by-turn alerts.
- **Purple (`Colors.purpleAccent`)**: Gemini AI thinking / reasoning orb overlay.
- **Red (`Colors.redAccent`)**: Errors, stop actions, low confidence warnings.

### 3.2 Touch Targets & Geometry
- **Global Rule**: Minimum touch target height must be **at least 60dp**, with primary action buttons sized at **80dp**.
- In [lib/core/theme.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/core/theme.dart#L28):
  ```dart
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(200, 80), // Exceeds WCAG 48dp guideline
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  )
  ```
- In [lib/ui/widgets/accessible_button.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/ui/widgets/accessible_button.dart#L45):
  ```dart
  Container(
    constraints: const BoxConstraints(minHeight: 80.0),
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
    child: Row(
      children: [
        Icon(icon, size: 40.0, color: textCol),
        const SizedBox(width: 16.0),
        Expanded(child: Text(label, style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold))),
      ],
    ),
  )
  ```
- Floating action buttons must have explicit constraints: `SizedBox(width: 80.0, height: 80.0)`.

### 3.3 Screen Reader Semantics
All interactive, informational, and dynamic elements must supply explicit semantics for Android TalkBack and iOS VoiceOver:

1. **`button: true` and `label`**:
   Every clickable surface (buttons, cards, banners) declares `button: true` and a clear descriptive sentence.
   ```dart
   Semantics(
     button: true,
     label: isListening ? 'Voice assistant listening. Speak now.' : 'Voice Assistant. Tap to activate.',
     child: ...
   )
   ```
2. **`liveRegion: true`**:
   Crucial for asynchronous assistive tech. Applied to [StatusBanner](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/ui/widgets/status_banner.dart#L42) and live navigation cards:
   ```dart
   Semantics(
     label: 'Status: ${widget.statusText}',
     liveRegion: true, // Forces TalkBack to announce state changes automatically
     child: ...
   )
   ```
3. **`header: true`**:
   Applied to all screen titles so screen reader users can navigate quickly by headings.

### 3.4 Multi-Modal Gestures & Touch Freedom
To accommodate totally blind users who cannot see button boundaries:
- **Double Tap Anywhere**: [lib/ui/home_screen.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/ui/home_screen.dart#L81) binds `onDoubleTap` on the root `GestureDetector` to immediately wake up voice listening.
- **Tap Screen Anywhere to Scan**: In `ReadModeScreen`, `DetectModeScreen`, and `CurrencyModeScreen`, tapping anywhere triggers an immediate snapshot and ML inspection.

### 3.5 Auditory Feedback & Anti-Repetition Rules
Every user interaction and mode change announces itself via Text-To-Speech:
```dart
ref.read(ttsStateProvider.notifier).speak('Read Mode Active. Point camera at text.');
```

#### Anti-Repetition Speech Thresholds
To prevent repetitive audio loops when the camera stays pointed at the same text or object:
1. **OCR Word Overlap**: In [lib/ui/read_mode_screen.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/ui/read_mode_screen.dart#L25-L42), `_isNewText` checks word intersection. If similarity > 75%, speech readout is suppressed.
2. **Object Detection Cooldown**: In [lib/providers/detection_providers.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/providers/detection_providers.dart#L96-L107), repeated detections of the same object are suppressed for at least 10 seconds unless the user forces a re-scan.
3. **TTS Speaking Interlock**: If `ttsState.isSpeaking == true`, background ML scans skip speech triggers to avoid overlapping speech.

### 3.6 Haptic Cues
Haptics provide non-auditory physical confirmation of touch. Standardized in [lib/core/utils/audio_feedback.dart](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/core/utils/audio_feedback.dart):
- `HapticFeedback.heavyImpact()`: Button presses, screen navigation, voice assistant activation, error alerts.
- `HapticFeedback.mediumImpact()`: Camera source toggle, stopping voice commands.
- `SystemSound.play(SystemSoundType.click)`: Audio click confirmation on microphone opening.

---

## 4. Riverpod State Management Patterns

The codebase uses **Flutter Riverpod ^2.6.1** with strict immutability and separation of concerns.

```
┌────────────────────────────────────────────────────────┐
│                        UI LAYER                        │
│   HomeScreen, ReadModeScreen, AccessibleButton, etc.   │
└───────────────────────────▲────────────────────────────┘
                            │ ref.watch / ref.listen
┌───────────────────────────┴────────────────────────────┐
│                    PROVIDER LAYER                      │
│     CameraStateNotifier, VoiceAssistantNotifier,       │
│           TTSStateNotifier, NavigationStateNotifier     │
└───────────────────────────▲────────────────────────────┘
                            │ ref.read / callbacks
┌───────────────────────────┴────────────────────────────┐
│                    SERVICE LAYER                       │
│    CameraService, TTSService, VoiceAssistantService,   │
│   GeminiAssistantService, NavigationService, OcrService│
└────────────────────────────────────────────────────────┘
```

### 4.1 State Immutability
Every state class MUST be immutable and provide a `copyWith` method:
```dart
class CameraState {
  final bool isInitialized;
  final bool isStreaming;
  final String? errorMessage;
  // ...
  CameraState copyWith({bool? isInitialized, ...}) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      // ...
    );
  }
}
```

### 4.2 Safe Ref Usage Rules
1. **`ref.watch()`**: Used **only** inside `build()` methods to subscribe the widget to reactive changes.
2. **`ref.read()`**: Used inside event handlers (`onPressed`, `onTap`) and `StateNotifier` constructors/methods.
3. **`ref.listen()`**: Used for reactive side-effects (e.g. triggering TTS when OCR state changes, muting microphone when TTS is active).
4. **`ref.onDispose()`**: Registered on service providers to guarantee hardware release:
   ```dart
   final cameraServiceProvider = Provider<CameraService>((ref) {
     final service = CameraService();
     ref.onDispose(() => service.dispose());
     return service;
   });
   ```

### 4.3 Cross-Provider Interlocking Pattern
Hardware components must coordinate without circular dependencies. Example from [VoiceAssistantNotifier](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/providers/voice_assistant_providers.dart#L85-L93):
```dart
// Mute microphone when TTS is speaking to prevent hearing itself
_ref.listen<TTSState>(ttsStateProvider, (previous, next) {
  if (next.isSpeaking) {
    _voiceService.pauseForTts();
  } else if (previous?.isSpeaking == true && !next.isSpeaking) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _voiceService.resumeAfterTts();
    });
  }
});
```

---

## 5. Error Handling & Hardware Resilience Conventions

### 5.1 Three-Tier Fallback Architecture

The app interfaces with unreliable hardware (USB-C UVC cameras, GPS signals, cloud APIs, network routers). Every critical subsystem implements a tiered fallback:

```
┌────────────────────────────────────────────────────────┐
│ 1. Primary Hardware / Cloud Engine                     │
│    (IMX378 USB Camera, Gemini Cloud AI, OSRM Routing)  │
└───────────────────────────┬────────────────────────────┘
                            │ Failure / Disconnection
┌───────────────────────────▼────────────────────────────┐
│ 2. Secondary Local Fallback                            │
│    (Phone Camera, Offline Semantic Rules, Google Maps) │
└───────────────────────────┬────────────────────────────┘
                            │ Complete Network/Sensor Drop
┌───────────────────────────▼────────────────────────────┐
│ 3. Safe Degradation / Spoken TTS Error Notice          │
│    ("Direct distance 50m", "Camera fallback active")   │
└────────────────────────────────────────────────────────┘
```

#### Concrete Fallback Implementations:
1. **Camera Stream ([CameraService](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/camera_service.dart#L235-L250))**:
   Checks for USB-C connected IMX378 glasses via `uvcCamera.listUsbDevices()`. If absent or on error, seamlessly defaults to `NativeCameraSource` (smartphone back camera).
2. **AI Voice Assistant ([GeminiAssistantService](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/gemini_assistant_service.dart#L85-L140))**:
   Sends user query to Google Gemini 1.5 Flash. If network timeout (4s) or API error occurs, immediately falls back to `_offlineSemanticClassify()` keyword rules without failing the user's request.
3. **Walking Directions ([NavigationService](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/navigation_service.dart#L84-L198))**:
   - Tier 1: Free keyless OSRM walking route engine.
   - Tier 2: Google Directions API walking query.
   - Tier 3: Direct Haversine geographic line distance step.
4. **TTS Engine Hangs ([TTSService](file:///c:/Users/admin/OneDrive/Desktop/Glasses%20for%20blind%20by%20anity/lib/services/tts_service.dart#L69-L83))**:
   Native TTS engines (especially on low-end Android) occasionally hang without invoking the completion callback. A dynamic `_speechWatchdogTimer` calculates expected speech duration based on word count + 3s buffer, auto-resetting `isSpeaking = false` if the engine hangs.

### 5.2 Exception Catching & Logging Rules
- **Rule 1**: Never swallow exceptions silently. Log with `debugPrint('Descriptive context: $e')`.
- **Rule 2**: When catching in a provider, store the error in state (e.g. `state.copyWith(errorMessage: e.toString())`) and communicate failure to the user via TTS.
- **Rule 3**: Protect image processing pipelines with an `_isProcessing` guard flag in `finally` blocks to guarantee against deadlocks:
  ```dart
  if (_isProcessing) return null;
  try {
    _isProcessing = true;
    // Process frame...
  } catch (e) {
    debugPrint('Error: $e');
    return null;
  } finally {
    _isProcessing = false;
  }
  ```

---

## 6. Conventions Summary Checklist

When authoring or modifying code in this repository, ensure:

- [ ] File name is `lower_snake_case.dart` matching its primary class.
- [ ] No raw `print()` statements; all logs use `debugPrint()`.
- [ ] All interactive touch targets have at least 60dp height (preferred 80dp).
- [ ] All interactive widgets are wrapped with `Semantics(button: true, label: '...')`.
- [ ] Dynamic status displays declare `Semantics(liveRegion: true)`.
- [ ] High-contrast color palette strictly respected (Yellow/Cyan on Black).
- [ ] Haptic feedback triggered on taps via `HapticFeedback.heavyImpact()`.
- [ ] State objects are immutable with complete `copyWith()` implementation.
- [ ] Hardware allocations have matching `ref.onDispose()` and `dispose()` cleanup.
- [ ] Async hardware calls are wrapped in `try-catch` with fallbacks and TTS announcements.
