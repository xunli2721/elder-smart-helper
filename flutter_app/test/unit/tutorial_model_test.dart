import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/models/tutorial.dart';

void main() {
  group('Tutorial Model', () {
    test('should create Tutorial from JSON', () {
      final json = {
        'id': 1,
        'title': '如何拨打电话',
        'description': '学习使用手机拨打电话',
        'category': 'basic',
        'difficulty_level': 'beginner',
        'steps': [
          {'step': 1, 'title': '找到电话图标', 'description': '在主屏幕找到绿色图标'},
          {'step': 2, 'title': '点击图标', 'description': '用手指点击'},
        ],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.id, 1);
      expect(tutorial.title, '如何拨打电话');
      expect(tutorial.description, '学习使用手机拨打电话');
      expect(tutorial.category, 'basic');
      expect(tutorial.difficultyLevel, 'beginner');
      expect(tutorial.steps, hasLength(2));
    });

    test('should default description to empty string', () {
      final json = {
        'id': 1,
        'title': '测试',
        'category': 'basic',
        'steps': [],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.description, '');
    });

    test('should default difficulty_level to beginner', () {
      final json = {
        'id': 1,
        'title': '测试',
        'category': 'basic',
        'steps': [],
      };

      final tutorial = Tutorial.fromJson(json);

      expect(tutorial.difficultyLevel, 'beginner');
    });
  });

  group('TutorialStep Model', () {
    test('should create TutorialStep from JSON', () {
      final json = {
        'step': 1,
        'title': '找到电话图标',
        'description': '在主屏幕上找到绿色的电话图标',
      };

      final step = TutorialStep.fromJson(json);

      expect(step.step, 1);
      expect(step.title, '找到电话图标');
      expect(step.description, '在主屏幕上找到绿色的电话图标');
    });
  });
}
