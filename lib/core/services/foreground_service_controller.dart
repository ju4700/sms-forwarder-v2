import 'package:flutter/services.dart';

class ForegroundServiceController {
  ForegroundServiceController._();

  static final ForegroundServiceController instance = ForegroundServiceController._();

  static const MethodChannel _channel = MethodChannel(
    'sms_forwarder_v2/foreground_service',
  );

  Future<void> apply(bool enabled) async {
    if (enabled) {
      await start();
      return;
    }
    await stop();
  }

  Future<void> start() async {
    await _channel.invokeMethod<bool>('start');
  }

  Future<void> stop() async {
    await _channel.invokeMethod<bool>('stop');
  }
}
