import 'package:permission_handler/permission_handler.dart';
import 'settings_service.dart';

class SmsCaptureService {
  Future<bool> requestPermissions() async {
    final bool granted = (await Permission.sms.request()).isGranted;
    await Permission.notification.request();
    return granted;
  }

  Future<List<Map<String, dynamic>>> fetchQueueSnapshot() async {
    final List<dynamic> rows =
        await SettingsService.channel.invokeMethod<List<dynamic>>(
          'getQueueSnapshot',
        ) ??
        [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> retryDeadLetters() async {
    await SettingsService.channel.invokeMethod<int>('retryDeadLetters');
  }

  Future<bool> retrySingle({
    required String sender,
    required String body,
    required int timestamp,
  }) async {
    return await SettingsService.channel.invokeMethod<bool>('retrySingle', {
          'body': body,
          'timestamp': timestamp,
        }) ??
        false;
  }

  Future<void> triggerNativeSync() async {
    await SettingsService.channel.invokeMethod<bool>('triggerNativeSync');
  }

  Future<int> recoverReceipts() async {
    return await SettingsService.channel.invokeMethod<int>('recoverReceipts') ??
        0;
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    await SettingsService.channel.invokeMethod<bool>(
      'requestIgnoreBatteryOptimizations',
    );
  }
}
