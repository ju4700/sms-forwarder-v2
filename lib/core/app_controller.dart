import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models/queued_sms.dart';
import 'services/foreground_service_controller.dart';
import 'services/settings_service.dart';
import 'services/sms_capture_service.dart';

class AppController extends ChangeNotifier {
  final SmsCaptureService _sms = SmsCaptureService();
  AppSettings _settings = const AppSettings();
  List<QueuedSms> _history = [];
  String _status = 'Configure the receiving wallet and server';
  bool _permissionsGranted = false;
  bool _ready = false;
  bool _refreshing = false;
  bool _disposed = false;
  Timer? _timer;
  AppSettings get settings => _settings;
  List<QueuedSms> get history => _history;
  String get status => _status;
  bool get permissionsGranted => _permissionsGranted;
  bool get ready => _ready;

  Future<void> initialize() async {
    try {
      _settings = await SettingsService.instance.load();
      _permissionsGranted = await _sms.requestPermissions();
      await refresh();
      if (_permissionsGranted && _settings.secretConfigured) {
        await _sms.triggerNativeSync();
      }
      // Recovery is explicit: historical inbox messages are never imported automatically.
      _timer = Timer.periodic(const Duration(seconds: 10), (_) {
        unawaited(refresh());
      });
      _status = _permissionsGranted
          ? (_settings.secretConfigured
                ? 'Monitoring incoming bKash receipts'
                : 'Configure the receiving wallet and server')
          : 'SMS permission denied';
    } catch (_) {
      _status = 'Payment storage unavailable. Check permissions and restart.';
    }
    _ready = true;
    _notify();
  }

  Future<void> saveDelivery({
    required String endpoint,
    required String deviceId,
    required String receivingAccount,
    required String secret,
  }) async {
    await SettingsService.instance.save(
      endpoint: endpoint,
      deviceId: deviceId,
      receivingAccount: receivingAccount,
      secret: secret,
    );
    _settings = await SettingsService.instance.load();
    _status = 'Signed delivery configured';
    _notify();
  }

  Future<void> setForegroundMode(bool value) async {
    try {
      await SettingsService.instance.setForegroundMode(value);
      await ForegroundServiceController.instance.apply(value);
      _settings = await SettingsService.instance.load();
      _status = value
          ? 'Foreground monitoring enabled'
          : 'Background SMS monitoring active';
    } catch (_) {
      _status = 'Could not change foreground monitoring';
    }
    _notify();
  }

  Future<void> recoverReceipts() async {
    try {
      final int count = await _sms.recoverReceipts();
      _status = 'Recovered $count new receipts from the last 48 hours';
      await refresh();
    } catch (e) {
      _status = _message(e);
    }
    _notify();
  }

  Future<void> disableBatteryOptimization() async {
    await _sms.requestIgnoreBatteryOptimizations();
  }

  Future<void> retryFailed() async {
    try {
      await _sms.retryDeadLetters();
      await refresh();
      _status = 'Retry requested';
    } catch (e) {
      _status = _message(e);
    }
    _notify();
  }

  Future<void> markHandled(QueuedSms item) async {
    await SettingsService.channel.invokeMethod<bool>('markHandled', {
      'id': item.id,
    });
    await refresh();
  }

  Future<void> retrySingle(QueuedSms item) async {
    try {
      await _sms.retrySingle(
        sender: item.sender,
        body: item.messageBody,
        timestamp: item.createdAt,
      );
      await refresh();
    } catch (e) {
      _status = _message(e);
    }
    _notify();
  }

  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    try {
      _history = (await _sms.fetchQueueSnapshot()).map((row) {
        final int createdAt = (row['timestamp'] as num).toInt();
        final DateTime paidAt = DateTime.fromMillisecondsSinceEpoch(
          (row['paidAt'] as num).toInt(),
          isUtc: true,
        );
        return QueuedSms(
          id: row['id'] as String,
          sender: row['payerAccount'] as String,
          messageBody: row['body'] as String,
          amount: (row['amountMinor'] as num).toInt() / 100,
          transactionId: row['transactionId'] as String,
          reference: row['reference'] as String,
          transactionLocalTime: paidAt
              .add(const Duration(hours: 6))
              .toIso8601String()
              .replaceFirst('Z', '+06:00'),
          transactionUtcTime: paidAt.toIso8601String(),
          fee: 0,
          balance: 0,
          status: row['status'] as String,
          attemptCount: (row['attemptCount'] as num).toInt(),
          createdAt: createdAt,
          updatedAt: createdAt,
          nextRetryAt: (row['nextRetryAt'] as num?)?.toInt(),
          lastEvent: row['lastEvent'] as String?,
        );
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      _status = 'Could not read encrypted payment queue';
    } finally {
      _refreshing = false;
    }
    _notify();
  }

  String _message(Object e) => e is PlatformException
      ? e.message ?? 'Payment operation failed'
      : 'Payment operation failed';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
