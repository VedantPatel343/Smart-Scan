import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scanner/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartScannerApp());
    await tester.pumpAndSettle();
    expect(find.text('SmartScan'), findsOneWidget);
  });
}
