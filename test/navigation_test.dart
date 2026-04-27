import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sms_forwarder_v2/core/app_controller.dart';
import 'package:sms_forwarder_v2/ui/app_shell.dart';

void main() {
  testWidgets('shows home logs and policy tabs', (WidgetTester tester) async {
    final AppController controller = AppController();

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(controller: controller),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Policy'), findsOneWidget);
    expect(find.text('SMS Forwarder'), findsOneWidget);

    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();

    expect(find.text('Logs'), findsWidgets);
    expect(find.text('No log entries yet.'), findsOneWidget);

    await tester.tap(find.text('Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Policy'), findsWidgets);
    expect(find.textContaining('monitors incoming transaction SMS'), findsOneWidget);
  });
}
