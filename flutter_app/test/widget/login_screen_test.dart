import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elder_smart_helper/providers/font_size_provider.dart';
import 'package:elder_smart_helper/screens/login_screen.dart';

void main() {
  group('LoginScreen Widget', () {
    Widget createLoginScreen() {
      return ChangeNotifierProvider(
        create: (_) => FontSizeProvider(),
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      );
    }

    testWidgets('should display app title and subtitle', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      expect(find.text('智能助手'), findsOneWidget);
      expect(find.text('中老年人智能手机助手'), findsOneWidget);
    });

    testWidgets('should display phone and password fields', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('手机号'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
    });

    testWidgets('should display login button', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      expect(find.text('登录'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should display register link', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      expect(find.text('没有账号？立即注册'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('should display phone icon', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });

    testWidgets('should allow text input in phone field', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, '13800000001');
      await tester.pump();

      expect(find.text('13800000001'), findsOneWidget);
    });

    testWidgets('should allow text input in password field', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, '123456');
      await tester.pump();

      // Password field should obscure text, but the text is still there
      expect(find.text('123456'), findsOneWidget);
    });
  });
}
