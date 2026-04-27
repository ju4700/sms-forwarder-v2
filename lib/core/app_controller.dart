import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'models/queued_sms.dart';
import 'services/database_service.dart';
import 'services/delivery_service.dart';
import 'services/foreground_service_controller.dart';
import 'services/settings_service.dart';
import 'services/sms_capture_service.dart';
import 'services/work_scheduler.dart';

class AppController extends ChangeNotifier {
  AppController()
      : _deliveryService = DeliveryService(
          databaseService: DatabaseService.instance,
          settingsService: SettingsService.instance,
        ),
        _smsCaptureService = SmsCaptureService(
          deliveryService: DeliveryService(
            databaseService: DatabaseService.instance,
            settingsService: SettingsService.instance,
          ),
        );

  final DeliveryService _deliveryService;
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
    await WorkScheduler.instance.initialize();
    await ForegroundServiceController.instance.apply(
      _settings.foregroundReliabilityMode,
    );

    _permissionsGranted = await _smsCaptureService.requestPermissions();
    if (_permissionsGranted) {
      await _smsCaptureService.startListening();
      await _smsCaptureService.drainCapturedFromNative();
      _nativeDrainTimer = Timer.periodic(const Duration(seconds: 10), (
        Timer _,
      ) async {
        await _smsCaptureService.drainCapturedFromNative();
        await _refreshHistory();
      });
      _status = 'Monitoring SMS';
    } else {
      _status = 'SMS permission denied';
    }

    await _refreshHistory();
    await _deliveryService.drainQueue();
    _listenConnectivity();

    _ready = true;
    notifyListeners();
  }

  Future<void> saveEndpoint(String endpoint) async {
    _settings = _settings.copyWith(apiEndpoint: endpoint.trim());
    await SettingsService.instance.save(_settings);
    await _deliveryService.drainQueue();
    await _refreshHistory();
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
    await DatabaseService.instance.rescheduleDeadLetters();
    await _deliveryService.drainQueue();
    await _refreshHistory();
    _status = 'Retry completed';
    notifyListeners();
  }

  Future<void> _refreshHistory() async {
    _history = await DatabaseService.instance.fetchAll();
    notifyListeners();
  }

  void _listenConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) async {
      if (result.any((ConnectivityResult item) => item != ConnectivityResult.none)) {
        await _smsCaptureService.drainCapturedFromNative();
        await _deliveryService.drainQueue();
        await _refreshHistory();
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
