import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_glasses/app.dart';

void main() {
  // Ensure Flutter binding is initialized before any plugins or UI
  WidgetsFlutterBinding.ensureInitialized();
  
  // Run the app wrapped in ProviderScope for Riverpod state management
  runApp(const ProviderScope(child: SmartGlassesApp()));
}
