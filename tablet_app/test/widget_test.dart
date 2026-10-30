import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_app/main.dart';

void main() {
  testWidgets('Tablet Kiosk App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GymTabletKioskApp());
    expect(find.byType(GymTabletKioskApp), findsOneWidget);
  });
}
