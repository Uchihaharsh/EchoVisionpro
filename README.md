# EchoVisionpro 👓

**EchoVisionpro** is an assistive technology application and smart glasses interface designed to empower blind and visually impaired users with real-time computer vision, continuous AI voice guidance, and spatial awareness.

Powered by **Flutter**, **Google ML Kit**, **Google Generative AI (Gemini)**, and continuous background speech recognition.

---

## 🌟 Key Features

### 🎙️ 1. Hands-Free Voice Assistant ("Hey Echo")
- **Always Listening**: Functions like Google Assistant / Gemini, listening continuously in the background across all features without dropping.
- **Natural Phrasing & Accent Robustness**: Understands conversational requests with or without polite fillers (*"Can you please open currency"*, *"Hey Echo what time is it"*).
- **0ms Instant Local Execution**: Mode jumps, time announcements, GPS location, and app control execute in 0ms locally, reserving cloud Gemini only for open-ended scene descriptions.
- **Voice Skills**:
  - *"Hey Echo, open currency"*
  - *"Hey Echo, detect objects"*
  - *"Hey Echo, read text"*
  - *"Hey Echo, where am I"*
  - *"Hey Echo, what time is it"*
  - *"Hey Echo, what is today's date"*
  - *"Stop talking"* / *"Quiet"*

### 🔍 2. Real-Time Object & Obstacle Detection
- Continuous real-time detection of everyday physical objects (Laptop, Phone, Bottle, Cup, Chair, Table, Person, Doors, etc.).
- Bounding box visualization and haptic + speech feedback for nearest obstacles.

### 💵 3. Currency Recognition
- Rapid banknote identification for Indian Rupee denominations (₹10, ₹20, ₹50, ₹100, ₹200, ₹500).
- High-contrast visual cards and voice announcements.

### 📖 4. Read Text (Live OCR)
- Instant and continuous document, sign, and book text reader.
- Intelligent deduplication prevents repetitive speech loops while reading paragraphs.

### 🧭 5. Turn-by-Turn Navigation & GPS
- Precise GPS geolocation and reverse geocoding to announce current street address.
- Interactive map interface with route guidance for walking.

### 📷 6. Dual-Camera Architecture
- Supports switching seamlessly between:
  1. Built-in smartphone camera.
  2. External USB-C Smart Glasses camera (Sony IMX378 sensor).

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.7+)
- Android Studio / Android SDK (API 34+)
- An Android device with USB debugging enabled

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/Uchihaharsh/EchoVisionpro.git
   cd EchoVisionpro
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run on connected device:
   ```bash
   flutter run
   ```

---

## 🛠️ Tech Stack
- **Framework**: Flutter / Dart
- **State Management**: Flutter Riverpod
- **Speech Engine**: SpeechToText (Continuous Confirmation Mode) & FlutterTTS
- **Vision & ML**: Google ML Kit (Text Recognition, Image Labeling, Object Detection)
- **AI**: Google Generative AI (Gemini 1.5 Flash)
- **Mapping & Location**: Geolocator, Flutter Map, OpenStreetMap

---

## 📄 License
This project is open-source and intended to advance accessible assistive technology.
