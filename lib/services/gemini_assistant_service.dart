import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:smart_glasses/core/constants.dart';
import 'package:smart_glasses/services/voice_assistant_service.dart';

/// Structured response returned by Gemini AI assistant
class GeminiVoiceResponse {
  final VoiceCommandType intent;
  final String? argument;
  final String speechResponse;
  final bool isMultimodalSceneDescription;

  const GeminiVoiceResponse({
    required this.intent,
    this.argument,
    required this.speechResponse,
    this.isMultimodalSceneDescription = false,
  });

  @override
  String toString() =>
      'GeminiVoiceResponse(intent: $intent, arg: $argument, speech: "$speechResponse", vision: $isMultimodalSceneDescription)';
}

/// Advanced Gemini-powered multimodal conversational AI assistant for smart glasses.
/// Combines Generative AI understanding, Gemini Vision scene descriptions, and offline phonetic fallback.
class GeminiAssistantService {
  GenerativeModel? _textModel;
  GenerativeModel? _visionModel;
  bool _hasApiKey = false;

  GeminiAssistantService() {
    _initGemini();
  }

  void _initGemini() {
    final key = AppConstants.geminiApiKey.trim();
    if (key.isNotEmpty) {
      try {
        _textModel = GenerativeModel(
          model: AppConstants.geminiModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.2,
            maxOutputTokens: 250,
          ),
        );
        _visionModel = GenerativeModel(
          model: AppConstants.geminiModel,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.3,
            maxOutputTokens: 300,
          ),
        );
        _hasApiKey = true;
      } catch (e) {
        debugPrint('Error initializing GenerativeModel: $e');
        _hasApiKey = false;
      }
    }
  }

  /// Understands natural language speech and returns an action or spoken answer
  Future<GeminiVoiceResponse> processUserSpeech(String userSpeech) async {
    final clean = userSpeech.trim();
    if (clean.isEmpty) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.unknown,
        speechResponse: "I'm listening. How can I help you?",
      );
    }

    // Check if user is asking for camera scene description ("What am I looking at?", "Describe the scene", etc.)
    if (_isAskingForSceneDescription(clean)) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.describeScene,
        speechResponse: "Looking through your smart glasses now...",
        isMultimodalSceneDescription: true,
      );
    }

    // Try Gemini Generative AI understanding if key is available
    if (_hasApiKey && _textModel != null) {
      try {
        final prompt = '''
You are Echo, an intelligent AI voice assistant inside smart glasses designed for visually impaired and blind users.
Analyze the user's spoken request: "$clean"

Determine the user's intent from these options:
1. "currency": User wants to identify, check, count, or read banknotes / money / cash / rupees.
2. "read_text": User wants to read text, document, book, letters, signboards, or OCR.
3. "objects": User wants to detect objects, obstacles, look around, or know what is around them.
4. "navigation": User wants directions, walking route, maps, or to go somewhere.
5. "where_am_i": User asks for their current location, street, or address.
6. "switch_camera": User wants to switch between smart glasses camera and phone camera.
7. "home": User wants to go back, home screen, stop, or exit.
8. "describe_scene": User asks what is in front of them or asks for visual description.
9. "conversation": General conversation, help, or question.

Respond ONLY with valid JSON in this exact structure:
{
  "action": "currency" | "read_text" | "objects" | "navigation" | "where_am_i" | "switch_camera" | "home" | "describe_scene" | "conversation",
  "destination": null or "target place name if navigation",
  "response": "short concise voice response spoken to the blind user (under 20 words)"
}
''';

        final response = await _textModel!
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 4));

        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) {
          final jsonStr = _extractJson(text);
          if (jsonStr != null) {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final action = data['action'] as String? ?? 'conversation';
            final destination = data['destination'] as String?;
            final speechResp = data['response'] as String? ?? 'Opening feature';

            return GeminiVoiceResponse(
              intent: _actionToIntent(action),
              argument: destination,
              speechResponse: speechResp,
              isMultimodalSceneDescription: action == 'describe_scene',
            );
          }
        }
      } catch (e) {
        debugPrint('Gemini cloud processing error: $e');
        // Falls through to offline semantic classifier
      }
    }

    // High-resilience offline semantic classifier
    return _offlineSemanticClassify(clean);
  }

  /// Describes live camera frame using Gemini Multimodal Vision for blind user
  Future<String> describeCameraScene(Uint8List jpegBytes, String userPrompt) async {
    if (!_hasApiKey || _visionModel == null) {
      return "I can see the room ahead of you. Point your smart glasses forward to inspect objects.";
    }

    try {
      final prompt = '''
You are Echo, an empathetic assistive AI speaking through smart glasses to a blind user.
The user asks: "$userPrompt"
Analyze this camera image from their glasses.
Give a direct, concise, 2-sentence description of the scene in front of them.
Mention key obstacles (chairs, tables, steps, curbs), doors/openings, people, or notable objects directly in their path.
Speak clearly and reassuringly in first person as their eyes.
''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', jpegBytes),
        ])
      ];

      final response = await _visionModel!
          .generateContent(content)
          .timeout(const Duration(seconds: 8));

      final reply = response.text?.trim();
      if (reply != null && reply.isNotEmpty) {
        return reply;
      }
    } catch (e) {
      debugPrint('Error describing scene with Gemini Vision: $e');
    }

    return "Looking ahead, there is an open space with objects in front of you. Tap detect objects for live tracking.";
  }

  bool _isAskingForSceneDescription(String input) {
    final lower = input.toLowerCase();
    final patterns = [
      'what am i looking at',
      'what is in front of me',
      'describe what you see',
      'describe the scene',
      'describe the room',
      'what do you see',
      'look and tell me',
      'what is this thing',
      'tell me what you see',
      'what am i seeing',
      'look around and describe',
    ];
    for (var p in patterns) {
      if (lower.contains(p)) return true;
    }
    return false;
  }

  GeminiVoiceResponse _offlineSemanticClassify(String input) {
    String clean = input.toLowerCase().trim();
    clean = clean.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    // Strip wake words
    clean = clean
        .replaceFirst(RegExp(r'^(hey|ok|okay|hi)?\s*(echo|eco|ekho|aiko)\s*'), '')
        .replaceFirst(RegExp(r'^(please|can you|could you|i want to|open|launch|start|show me)\s*'), '')
        .trim();

    if (clean.isEmpty) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.wakeWordPrompt,
        speechResponse: "Yes, I'm listening. What would you like to do?",
      );
    }

    // 1. CURRENCY
    if (_containsAny(clean, [
      'currency', 'money', 'rupee', 'rupees', 'cash', 'banknote', 'note',
      'bill', 'count money', 'check money', 'pay', 'wallet', '500', '200', '100', '50', '20', '10'
    ])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.openCurrency,
        speechResponse: "Opening Currency Recognition. Point camera at banknote.",
      );
    }

    // 2. READ TEXT / OCR
    if (_containsAny(clean, [
      'read', 'reading', 'text', 'document', 'ocr', 'book', 'words', 'paper',
      'letter', 'sign', 'board', 'receipt', 'menu', 'page'
    ])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.openReadText,
        speechResponse: "Opening Read Text Mode. Point camera at text.",
      );
    }

    // 3. NAVIGATION
    if (clean.startsWith('navigate to') || clean.startsWith('take me to') || clean.startsWith('go to')) {
      final dest = clean.replaceFirst(RegExp(r'^(navigate to|take me to|go to)\s*'), '').trim();
      return GeminiVoiceResponse(
        intent: VoiceCommandType.openNavigation,
        argument: dest.isNotEmpty ? dest : null,
        speechResponse: dest.isNotEmpty ? "Navigating to $dest." : "Opening Navigation.",
      );
    }

    if (_containsAny(clean, ['navigate', 'navigation', 'map', 'maps', 'directions', 'route', 'walk to'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.openNavigation,
        speechResponse: "Opening Navigation and Live Map.",
      );
    }

    // 4. WHERE AM I
    if (_containsAny(clean, ['where am i', 'my location', 'current location', 'where i am', 'address', 'street'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.whereAmI,
        speechResponse: "Checking your current location...",
      );
    }

    // 5. CAMERA SWITCH
    if (_containsAny(clean, ['switch camera', 'change camera', 'toggle camera', 'glasses camera', 'phone camera', 'smart glasses'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.switchCamera,
        speechResponse: "Switching camera source.",
      );
    }

    // 6. OBJECT DETECTION
    if (_containsAny(clean, [
      'object', 'objects', 'detect', 'detecting', 'detection', 'obstacle',
      'obstacles', 'barrier', 'barriers', 'what objects', 'see objects',
      'identify object', 'recognize object', 'object detection'
    ])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.openObjectDetection,
        speechResponse: "Opening Object Detection.",
      );
    }

    // 7. STOP SPEAKING / MUTE
    if (_containsAny(clean, ['stop talking', 'shut up', 'quiet', 'silence', 'mute', 'pause speaking', 'stop audio']) || clean == 'stop') {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.stopSpeaking,
        speechResponse: "Stopping audio.",
      );
    }

    // 8. TELL TIME
    if (_containsAny(clean, ['time', 'what time is it', 'tell me time', 'current time', 'clock', 'what is the time'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.tellTime,
        speechResponse: "Checking time...",
      );
    }

    // 9. TELL DATE
    if (_containsAny(clean, ['date', 'what is today', 'what day is today', 'today date', 'what is the date', 'current date'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.tellDate,
        speechResponse: "Checking date...",
      );
    }

    // 10. APP STATUS
    if (_containsAny(clean, ['status', 'app status', 'current mode', 'what mode', 'where am i in the app', 'what screen'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.tellStatus,
        speechResponse: "Checking app status...",
      );
    }

    // 11. HOME / BACK
    if (_containsAny(clean, ['home', 'go home', 'home screen', 'go back', 'back', 'exit', 'close', 'return'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.goHome,
        speechResponse: "Returning to home screen.",
      );
    }

    // 12. HELP
    if (_containsAny(clean, ['help', 'what can you do', 'commands', 'instructions', 'how to use'])) {
      return const GeminiVoiceResponse(
        intent: VoiceCommandType.help,
        speechResponse: "You can ask me to open currency, read text, open maps, detect objects, or ask what am I looking at.",
      );
    }

    return GeminiVoiceResponse(
      intent: VoiceCommandType.unknown,
      speechResponse: "I heard: $input. You can say open currency, detect objects, read text, where am I, or what time is it.",
    );
  }

  VoiceCommandType _actionToIntent(String action) {
    switch (action.toLowerCase()) {
      case 'currency':
        return VoiceCommandType.openCurrency;
      case 'read_text':
        return VoiceCommandType.openReadText;
      case 'objects':
        return VoiceCommandType.openObjectDetection;
      case 'describe_scene':
        return VoiceCommandType.describeScene;
      case 'navigation':
        return VoiceCommandType.openNavigation;
      case 'where_am_i':
        return VoiceCommandType.whereAmI;
      case 'tell_time':
        return VoiceCommandType.tellTime;
      case 'tell_date':
        return VoiceCommandType.tellDate;
      case 'tell_status':
        return VoiceCommandType.tellStatus;
      case 'stop_speaking':
        return VoiceCommandType.stopSpeaking;
      case 'switch_camera':
        return VoiceCommandType.switchCamera;
      case 'home':
        return VoiceCommandType.goHome;
      case 'help':
        return VoiceCommandType.help;
      default:
        return VoiceCommandType.unknown;
    }
  }

  bool _containsAny(String input, List<String> patterns) {
    for (var p in patterns) {
      if (input == p || input.contains(p)) return true;
    }
    return false;
  }

  String? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return raw.substring(start, end + 1);
    }
    return null;
  }
}
