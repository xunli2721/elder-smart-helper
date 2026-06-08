import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/main.dart';
import 'package:elder_smart_helper/config/theme.dart';

void main() {
  group('MainScreen', () {
    testWidgets('should display 4 bottom navigation items', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ));

      expect(find.text('首页'), findsOneWidget);
      expect(find.text('教程'), findsOneWidget);
      expect(find.text('远程协助'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('should display correct icons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ));

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should start on first tab (home)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ));

      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, 0);
    });

    testWidgets('should switch tabs on tap', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ));

      await tester.tap(find.text('教程'));
      await tester.pump();

      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, 1);
    });

    testWidgets('should use fixed type for bottom navigation', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ));

      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.type, BottomNavigationBarType.fixed);
    });
  });

  group('MyApp', () {
    testWidgets('should render without errors', (tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('should have correct title', (tester) async {
      await tester.pumpWidget(const MyApp());

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, '智能助手');
    });

    testWidgets('should not show debug banner', (tester) async {
      await tester.pumpWidget(const MyApp());

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, false);
    });
  });
}
