import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF4A90E2);
}

class AppTheme {
  static const double _fontSizeSmall = 16;
  static const double _fontSizeMedium = 18;
  static const double _fontSizeLarge = 20;
  static const double _fontSizeXLarge = 24;

  static double getFontSize(String size) {
    switch (size) {
      case 'small': return _fontSizeSmall;
      case 'medium': return _fontSizeMedium;
      case 'large': return _fontSizeLarge;
      case 'xlarge': return _fontSizeXLarge;
      default: return _fontSizeLarge;
    }
  }

  static ThemeData lightTheme({double scaleFactor = 1.0}) {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: const Color(0xFF4A90E2),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22 * scaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          textStyle: TextStyle(fontSize: 20 * scaleFactor, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(fontSize: 18 * scaleFactor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedLabelStyle: TextStyle(fontSize: 14 * scaleFactor),
        unselectedLabelStyle: TextStyle(fontSize: 12 * scaleFactor),
      ),
    );
  }
}