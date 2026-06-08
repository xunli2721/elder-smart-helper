import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('should parse all fields correctly', () {
      final json = {
        'id': 1,
        'phone': '13800138000',
        'name': '张爷爷',
        'user_type': 'elderly',
        'font_size': 'large',
      };

      final user = User.fromJson(json);

      expect(user.id, 1);
      expect(user.phone, '13800138000');
      expect(user.name, '张爷爷');
      expect(user.userType, 'elderly');
      expect(user.fontSize, 'large');
    });

    test('should use default font_size when not provided', () {
      final json = {
        'id': 2,
        'phone': '13900000000',
        'name': '小张',
        'user_type': 'family',
      };

      final user = User.fromJson(json);

      expect(user.fontSize, 'large');
    });

    test('should use default font_size when null', () {
      final json = {
        'id': 3,
        'phone': '13800138001',
        'name': '李奶奶',
        'user_type': 'elderly',
        'font_size': null,
      };

      final user = User.fromJson(json);

      expect(user.fontSize, 'large');
    });

    test('should handle different user types', () {
      final elderly = User.fromJson({
        'id': 1, 'phone': '111', 'name': 'A', 'user_type': 'elderly'
      });
      final family = User.fromJson({
        'id': 2, 'phone': '222', 'name': 'B', 'user_type': 'family'
      });
      final admin = User.fromJson({
        'id': 3, 'phone': '333', 'name': 'C', 'user_type': 'admin'
      });

      expect(elderly.userType, 'elderly');
      expect(family.userType, 'family');
      expect(admin.userType, 'admin');
    });

    test('should handle different font sizes', () {
      for (final size in ['small', 'medium', 'large', 'xlarge']) {
        final user = User.fromJson({
          'id': 1, 'phone': '111', 'name': 'A',
          'user_type': 'elderly', 'font_size': size
        });
        expect(user.fontSize, size);
      }
    });
  });

  group('User constructor', () {
    test('should create user with required fields', () {
      final user = User(
        id: 1,
        phone: '13800138000',
        name: '张爷爷',
        userType: 'elderly',
      );

      expect(user.id, 1);
      expect(user.phone, '13800138000');
      expect(user.name, '张爷爷');
      expect(user.userType, 'elderly');
      expect(user.fontSize, 'large');
    });

    test('should create user with custom font size', () {
      final user = User(
        id: 1,
        phone: '13800138000',
        name: '张爷爷',
        userType: 'elderly',
        fontSize: 'xlarge',
      );

      expect(user.fontSize, 'xlarge');
    });
  });
}
