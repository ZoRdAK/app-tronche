import 'package:flutter_test/flutter_test.dart';

import 'package:tronche/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TroncheApp());
    expect(find.text('Tronche!'), findsOneWidget);
  });
}
