import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/config/theme.dart';

void main() {
  group('AppTheme.getFontSize', () {
    test('should return 16 for small', () {
      expect(AppTheme.getFontSize('small'), 16);
    });

    test('should return 18 for medium', () {
      expect(AppTheme.getFontSize('medium'), 18);
    });

    test('should return 20 for large', () {
      expect(AppTheme.getFontSize('large'), 20);
    });

    test('should return 24 for xlarge', () {
      expect(AppTheme.getFontSize('xlarge'), 24);
    });

    test('should return 20 (large) as default for unknown size', () {
      expect(AppTheme.getFontSize('unknown'), 20);
    });

    test('should return 20 (large) as default for empty string', () {
      expect(AppTheme.getFontSize(''), 20);
    });
  });

  group('AppTheme.lightTheme', () {
    test('should return a valid ThemeData', () {
      final theme = AppTheme.lightTheme;
      expect(theme, isA<ThemeData>());
    });

    test('should have correct primary color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.primaryColor, const Color(0xFF4A90E2));
    });

    test('should have correct scaffold background color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F5F5));
    });

    test('should have correct app bar background color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF4A90E2));
    });

    test('should have white app bar foreground color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('should center app bar title', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.centerTitle, true);
    });

    test('should have elevated button with full width', () {
      final theme = AppTheme.lightTheme;
      final style = theme.elevatedButtonTheme.style;
      expect(style, isNotNull);
    });

    test('should have card with rounded corners', () {
      final theme = AppTheme.lightTheme;
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(cardShape, isNotNull);
      expect(cardShape!.borderRadius, BorderRadius.circular(12));
    });

    test('should have input decoration with rounded border', () {
      final theme = AppTheme.lightTheme;
      final inputTheme = theme.inputDecorationTheme;
      expect(inputTheme.border, isA<OutlineInputBorder>());
    });
  });
}
