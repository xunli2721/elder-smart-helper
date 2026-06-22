import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/models/user.dart';

void main() {
  group('User Model', () {
    test('should create User from JSON', () {
      final json = {
        'id': 1,
        'phone': '13800000001',
        'name': '张爷爷',
        'user_type': 'elderly',
        'font_size': 'large',
      };

      final user = User.fromJson(json);

      expect(user.id, 1);
      expect(user.phone, '13800000001');
      expect(user.name, '张爷爷');
      expect(user.userType, 'elderly');
      expect(user.fontSize, 'large');
    });

    test('should default font_size to large when null', () {
      final json = {
        'id': 2,
        'phone': '13800000002',
        'name': '小张',
        'user_type': 'family',
      };

      final user = User.fromJson(json);

      expect(user.fontSize, 'large');
    });

    test('should handle all user types', () {
      for (final type in ['elderly', 'family', 'admin']) {
        final user = User.fromJson({
          'id': 1,
          'phone': '13800000001',
          'name': '测试',
          'user_type': type,
        });
        expect(user.userType, type);
      }
    });
  });
}
