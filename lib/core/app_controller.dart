import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'models/queued_sms.dart';
import 'services/bkash_parser.dart';
import 'services/foreground_service_controller.dart';
import 'services/settings_service.dart';
import 'services/sms_capture_service.dart';

class AppController extends ChangeNotifier {
  AppController() : _smsCaptureService = SmsCaptureService();

  final SmsCaptureService _smsCaptureService;

  AppSettings _settings = const AppSettings(
    apiEndpoint: '',
    foregroundReliabilityMode: false,
    maxAttempts: 12,
  );
  bool _ready = false;
  bool _permissionsGranted = false;
  String _status = 'Starting...';
  List<QueuedSms> _history = <QueuedSms>[];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _nativeDrainTimer;

  AppSettings get settings => _settings;
  bool get ready => _ready;
  bool get permissionsGranted => _permissionsGranted;
  String get status => _status;
  List<QueuedSms> get history => _history;

  Future<void> initialize() async {
    _status = 'Initializing services';
    notifyListeners();

    _settings = await SettingsService.instance.load();
    await ForegroundServiceController.instance.apply(
      _settings.foregroundReliabilityMode,
    );

    _permissionsGranted = await _smsCaptureService.requestPermissions();
    if (_permissionsGranted) {
      await _smsCaptureService.startListening();
      await _smsCaptureService.triggerNativeSync();
      await _refreshHistoryFromNative();
      _nativeDrainTimer = Timer.periodic(const Duration(seconds: 10), (
        Timer _,
      ) async {
        await _smsCaptureService.triggerNativeSync();
        await _refreshHistoryFromNative();
      });
      _status = 'Monitoring SMS';
    } else {
      _status = 'SMS permission denied';
    }

    await _refreshHistoryFromNative();
    _listenConnectivity();

    _ready = true;
    notifyListeners();
  }

  Future<void> saveEndpoint(String endpoint) async {
    _settings = _settings.copyWith(apiEndpoint: endpoint.trim());
    await SettingsService.instance.save(_settings);
    await _smsCaptureService.triggerNativeSync();
    await _refreshHistoryFromNative();
    _status = 'API endpoint saved';
    notifyListeners();
  }

  Future<void> setForegroundMode(bool value) async {
    _settings = _settings.copyWith(foregroundReliabilityMode: value);
    await SettingsService.instance.save(_settings);
    await ForegroundServiceController.instance.apply(value);
    _status = value
        ? 'Foreground reliability mode enabled'
        : 'Foreground reliability mode disabled';
    notifyListeners();
  }

  Future<void> retryFailed() async {
    _status = 'Retrying queued messages';
    notifyListeners();
    await _smsCaptureService.retryDeadLetters();
    await _smsCaptureService.triggerNativeSync();
    await _refreshHistoryFromNative();
    _status = 'Retry completed';
    notifyListeners();
  }

  Future<void> _refreshHistoryFromNative() async {
    final List<Map<String, dynamic>> snapshot = await _smsCaptureService.fetchQueueSnapshot();
    _history = snapshot
        .map(_mapNativeRowToQueuedSms)
        .toList(growable: false)
      ..sort((QueuedSms a, QueuedSms b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  QueuedSms _mapNativeRowToQueuedSms(Map<String, dynamic> row) {
    final String body = (row['body'] as String? ?? '').trim();
    final ParsedBkashTransaction? parsed = BkashParser.parse(body);
    final int createdAt = _asEpochMs(row['timestamp']);
    final int nextRetryAt = _asEpochMs(row['nextRetryAt']);
    final int attemptCount = _asInt(row['attemptCount']);
    final String sender = parsed?.sender ?? (row['sender'] as String? ?? '');
    final String status = (row['status'] as String? ?? 'pending').trim();

    final DateTime fallbackLocal = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return QueuedSms(
      id: _buildNativeRowId(row),
      sender: sender,
      messageBody: body,
      amount: parsed?.amount ?? 0,
      transactionId: parsed?.transactionId ?? 'UNKNOWN',
      reference: parsed?.reference ?? 'UNKNOWN',
      transactionLocalTime: parsed?.localIso ?? fallbackLocal.toIso8601String(),
      transactionUtcTime: parsed?.utcIso ?? fallbackLocal.toUtc().toIso8601String(),
      fee: parsed?.fee ?? 0,
      balance: parsed?.balance ?? 0,
      status: status,
      attemptCount: attemptCount,
      nextRetryAt: nextRetryAt == 0 ? null : nextRetryAt,
      lastError: (row['lastError'] as String?)?.trim().isEmpty == true
          ? null
          : (row['lastError'] as String?),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  int _asEpochMs(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  String _buildNativeRowId(Map<String, dynamic> row) {
    final String sender = row['sender'] as String? ?? '';
    final String body = row['body'] as String? ?? '';
    final int timestamp = _asEpochMs(row['timestamp']);
    final String seed = '$sender|$body|$timestamp';
    return 'native-${seed.hashCode.abs()}';
  }

  void _listenConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) async {
      if (result.any((ConnectivityResult item) => item != ConnectivityResult.none)) {
        await _smsCaptureService.triggerNativeSync();
        await _refreshHistoryFromNative();
        _status = 'Internet available: queue sync triggered';
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _nativeDrainTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
