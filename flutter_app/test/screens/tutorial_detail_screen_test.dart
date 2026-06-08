import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/models/tutorial.dart';
import 'package:elder_smart_helper/screens/tutorial_detail_screen.dart';

Tutorial _createTestTutorial({int stepCount = 3}) {
  return Tutorial(
    id: 1,
    title: '如何打电话',
    description: '学习拨打电话',
    category: 'basic',
    difficultyLevel: 'beginner',
    steps: List.generate(
      stepCount,
      (i) => TutorialStep(
        step: i + 1,
        title: '步骤${i + 1}',
        description: '这是步骤${i + 1}的说明',
      ),
    ),
  );
}

void main() {
  group('TutorialDetailScreen', () {
    testWidgets('should display tutorial title in app bar', (tester) async {
      final tutorial = _createTestTutorial();

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      expect(find.text('如何打电话'), findsOneWidget);
    });

    testWidgets('should display first step by default', (tester) async {
      final tutorial = _createTestTutorial();

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('步骤1'), findsOneWidget);
      expect(find.text('这是步骤1的说明'), findsOneWidget);
    });

    testWidgets('should show next button', (tester) async {
      final tutorial = _createTestTutorial();

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      expect(find.text('下一步'), findsOneWidget);
    });

    testWidgets('should not show previous button on first step', (tester) async {
      final tutorial = _createTestTutorial();

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      expect(find.text('上一步'), findsNothing);
    });

    testWidgets('should navigate to next step', (tester) async {
      final tutorial = _createTestTutorial();

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('步骤2'), findsOneWidget);
      expect(find.text('上一步'), findsOneWidget);
    });

    testWidgets('should navigate back to previous step', (tester) async {
      final tutorial = _createTestTutorial();

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      // Go to step 2
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // Go back to step 1
      await tester.tap(find.text('上一步'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('步骤1'), findsOneWidget);
    });

    testWidgets('should show complete button on last step', (tester) async {
      final tutorial = _createTestTutorial(stepCount: 2);

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      // Go to last step
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('完成'), findsOneWidget);
      expect(find.text('下一步'), findsNothing);
    });

    testWidgets('should show completion dialog on last step', (tester) async {
      final tutorial = _createTestTutorial(stepCount: 1);

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('恭喜！'), findsOneWidget);
      expect(find.textContaining('如何打电话'), findsWidgets);
      expect(find.text('返回'), findsOneWidget);
    });

    testWidgets('should display correct progress indicators', (tester) async {
      final tutorial = _createTestTutorial(stepCount: 3);

      await tester.pumpWidget(MaterialApp(
        home: TutorialDetailScreen(tutorial: tutorial),
      ));

      // Should have 3 progress indicator containers
      final containers = find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration != null,
      );
      expect(containers, findsWidgets);
    });
  });
}
