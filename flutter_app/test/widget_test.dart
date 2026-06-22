import 'package:flutter_test/flutter_test.dart';
import 'package:elder_smart_helper/main.dart';

void main() {
  testWidgets('App should render without errors', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
