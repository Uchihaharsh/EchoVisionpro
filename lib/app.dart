import 'package:flutter/material.dart';
import 'package:smart_glasses/core/theme.dart';
import 'package:smart_glasses/ui/home_screen.dart';

/// Global navigator key allowing voice commands to navigate from anywhere in the app
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Root application widget for VisionAssist Smart Glasses.
/// Configures the high-contrast accessible theme and sets HomeScreen as entry point.
class SmartGlassesApp extends StatelessWidget {
  const SmartGlassesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'VisionAssist - Smart Glasses',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(),
      home: const HomeScreen(),
    );
  }
}
