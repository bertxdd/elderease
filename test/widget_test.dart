import 'package:flutter_test/flutter_test.dart';
import 'package:elderease/main.dart';

void main() {
  testWidgets('ElderEase app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ElderEaseApp());
  });
}
