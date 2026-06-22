import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/models/tutorial.dart';

void main() {
  group('TutorialStep.fromJson', () {
    test('should parse all fields correctly', () {
      final json = {
        'step': 1,
        'title': '打开电话应用',
        'description': '在主屏幕找到电话图标并点击',
      };

      final step = TutorialStep.fromJson(json);

      expect(step.step, 1);
      expect(step.title, '打开电话应用');
      expect(step.description, '在主屏幕找到电话图标并点击');
    });
  });

  group('Tutorial.fromJson', () {
    test('should parse all fields correctly', () {
      final json = {
        'id': 1,
        'title': '如何打电话',
        'description': '学习拨打电话',
        'category': 'basic',
        'difficulty_level': 'beginner',
        'steps': [
          {'step': 1, 'title': '步骤1', 'description': '说明1'},
          {'step': 2, 'title': '步骤2', 'description': '说明2'},
        ],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.id, 1);
      expect(tutorial.title, '如何打电话');
      expect(tutorial.description, '学习拨打电话');
      expect(tutorial.category, 'basic');
      expect(tutorial.difficultyLevel, 'beginner');
      expect(tutorial.steps, hasLength(2));
      expect(tutorial.steps[0].title, '步骤1');
      expect(tutorial.steps[1].step, 2);
    });

    test('should use default description when not provided', () {
      final json = {
        'id': 1,
        'title': '测试',
        'category': 'basic',
        'steps': [],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.description, '');
    });

    test('should use default difficulty_level when not provided', () {
      final json = {
        'id': 1,
        'title': '测试',
        'category': 'basic',
        'steps': [],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.difficultyLevel, 'beginner');
    });

    test('should parse steps list correctly', () {
      final json = {
        'id': 1,
        'title': '测试',
        'category': 'communication',
        'difficulty_level': 'intermediate',
        'steps': [
          {'step': 1, 'title': '打开微信', 'description': '点击微信图标'},
          {'step': 2, 'title': '选择联系人', 'description': '从通讯录选择'},
          {'step': 3, 'title': '发送消息', 'description': '输入文字并发送'},
        ],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.steps, hasLength(3));
      expect(tutorial.steps[0].step, 1);
      expect(tutorial.steps[1].step, 2);
      expect(tutorial.steps[2].step, 3);
      expect(tutorial.steps[2].title, '发送消息');
    });

    test('should handle empty steps list', () {
      final json = {
        'id': 1,
        'title': '空教程',
        'category': 'basic',
        'steps': [],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.steps, isEmpty);
    });

    test('should handle different categories', () {
      for (final cat in ['basic', 'communication', 'payment', 'entertainment', 'utility']) {
        final tutorial = Tutorial.fromJson({
          'id': 1, 'title': 'T', 'category': cat, 'steps': []
        });
        expect(tutorial.category, cat);
      }
    });

    test('should handle different difficulty levels', () {
      for (final level in ['beginner', 'intermediate', 'advanced']) {
        final tutorial = Tutorial.fromJson({
          'id': 1, 'title': 'T', 'category': 'basic',
          'difficulty_level': level, 'steps': []
        });
        expect(tutorial.difficultyLevel, level);
      }
    });
  });
}
