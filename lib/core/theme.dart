import 'package:flutter/material.dart';

class AppTheme {
  // Returns the app's accessible theme tailored for visual impairments
  static ThemeData getTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212), // Very dark background
      primaryColor: const Color(0xFFFFD600), // High-contrast bright yellow
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFD600),
        secondary: Colors.amber, // Secondary orange-amber
        surface: Color(0xFF1E1E1E), // Dark grey for surfaces
        error: Colors.redAccent, // Bright red for errors
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Color(0xFFFFD600), size: 32),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(200, 80), // Large touch targets >= 48dp
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFFFFD600),
          foregroundColor: Colors.black, // High contrast text on yellow background
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontSize: 20),
        bodyMedium: TextStyle(color: Colors.white, fontSize: 18),
        headlineLarge: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFFFD600),
        size: 32, // Large icons for accessibility
      ),
    );
  }
}
