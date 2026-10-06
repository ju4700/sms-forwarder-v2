import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_forwarder_v2/core/app_controller.dart';
import 'package:sms_forwarder_v2/core/services/settings_service.dart';
import 'package:sms_forwarder_v2/ui/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> stored;
  late List<MethodCall> calls;
  setUp(() {
    stored = {
      'apiEndpoint': 'https://qabasic.test/api/payments/sms',
      'deviceId': 'phone-1',
      'receivingAccount': '01799999999',
      'secretConfigured': true,
      'foregroundReliabilityMode': false,
    };
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SettingsService.channel, (call) async {
          calls.add(call);
          if (call.method == 'loadSettings') return stored;
          if (call.method == 'getQueueSnapshot') return [];
          if (call.method == 'saveSettings') return true;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SettingsService.channel, null);
  });

  testWidgets('keeps credentials obscured and clears the secret after saving', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(controller: controller)),
      ),
    );
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(3)).obscureText, isTrue);
    await tester.enterText(fields.at(0), stored['apiEndpoint'] as String);
    await tester.enterText(fields.at(1), 'phone-1');
    await tester.enterText(fields.at(2), '01799999999');
    await tester.enterText(fields.at(3), 'f' * 64);
    final save = find.text('Save Delivery Settings');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(3)).controller!.text, isEmpty);
    expect(calls.where((call) => call.method == 'saveSettings'), hasLength(1));
    expect(controller.settings.secretConfigured, isTrue);
    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('queue refresh does not overwrite an endpoint being edited', (
    tester,
  ) async {
    final controller = AppController();
    await controller.saveDelivery(
      endpoint: stored['apiEndpoint'] as String,
      deviceId: 'phone-1',
      receivingAccount: '01799999999',
      secret: 'f' * 64,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(controller: controller)),
      ),
    );
    final endpoint = find.byType(TextField).first;
    await tester.enterText(endpoint, '');
    await controller.refresh();
    await tester.pump();
    expect(tester.widget<TextField>(endpoint).controller!.text, isEmpty);
    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
