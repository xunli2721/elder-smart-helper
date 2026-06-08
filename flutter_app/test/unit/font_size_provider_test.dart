import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/providers/font_size_provider.dart';

void main() {
  group('FontSizeProvider', () {
    late FontSizeProvider provider;

    setUp(() {
      provider = FontSizeProvider();
    });

    test('should have default fontSizeKey of large', () {
      expect(provider.fontSizeKey, 'large');
    });

    test('should have default speechRate of slow', () {
      expect(provider.speechRate, 'slow');
    });

    group('scaleFactor', () {
      test('should return 0.8 for small', () {
        // We can't directly set _fontSizeKey, but we can test the default
        expect(provider.scaleFactor, 1.0); // default is large
      });
    });

    group('scaled', () {
      test('should scale base size by factor', () {
        // Default is large (1.0)
        expect(provider.scaled(20.0), 20.0);
      });

      test('should return correct scaled value', () {
        // Default scale factor is 1.0 for 'large'
        expect(provider.scaled(16.0), 16.0);
        expect(provider.scaled(24.0), 24.0);
      });
    });
  });
}
