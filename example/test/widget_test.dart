import 'package:flutter_test/flutter_test.dart';

import 'package:thunder_thermal_print_example/main.dart';

void main() {
  testWidgets('App displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ThermalPrintDemoApp());

    expect(find.text('🖨️ Thermal Print Demo'), findsOneWidget);
  });
}
