import 'package:flutter/services.dart';

class AppSettings {
  const AppSettings({
    this.apiEndpoint = '',
    this.deviceId = '',
    this.receivingAccount = '',
    this.secretConfigured = false,
    this.foregroundReliabilityMode = false,
  });
  final String apiEndpoint;
  final String deviceId;
  final String receivingAccount;
  final bool secretConfigured;
  final bool foregroundReliabilityMode;
}

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();
  static const MethodChannel channel = MethodChannel(
    'sms_forwarder_v2/sms_bridge',
  );

  Future<AppSettings> load() async {
    final Map<dynamic, dynamic> data =
        await channel.invokeMethod<Map<dynamic, dynamic>>('loadSettings') ?? {};
    return AppSettings(
      apiEndpoint: data['apiEndpoint'] as String? ?? '',
      deviceId: data['deviceId'] as String? ?? '',
      receivingAccount: data['receivingAccount'] as String? ?? '',
      secretConfigured: data['secretConfigured'] == true,
      foregroundReliabilityMode: data['foregroundReliabilityMode'] == true,
    );
  }

  Future<void> save({
    required String endpoint,
    required String deviceId,
    required String receivingAccount,
    required String secret,
  }) async {
    await channel.invokeMethod<bool>('saveSettings', {
      'apiEndpoint': endpoint.trim(),
      'deviceId': deviceId.trim(),
      'receivingAccount': receivingAccount.trim(),
      'secret': secret.trim(),
    });
  }

  Future<void> setForegroundMode(bool enabled) async {
    await channel.invokeMethod<bool>('setForegroundMode', {'enabled': enabled});
  }
}
