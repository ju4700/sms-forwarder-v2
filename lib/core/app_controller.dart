import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/queued_sms.dart';
import 'services/foreground_service_controller.dart';
import 'services/message_store.dart';
import 'services/settings_service.dart';
import 'services/sms_capture_service.dart';
import 'services/transaction_parser.dart';

class AppController extends ChangeNotifier {
  AppController()
      : _smsCaptureService = SmsCaptureService(),
        _messageStore = MessageStore();

  final SmsCaptureService _smsCaptureService;
  final MessageStore _messageStore;

  AppSettings _settings = const AppSettings(
    apiEndpoint: '',
    apiSecret: '',
    foregroundReliabilityMode: false,
    maxAttempts: 12,
  );
  bool _ready = false;
  bool _permissionsGranted = false;
  bool _isDefaultSmsApp = false;
  String _status = 'Starting...';
  List<QueuedSms> _history = <QueuedSms>[];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _nativeDrainTimer;
  Timer? _inboxRefreshTimer;

  AppSettings get settings => _settings;
  bool get ready => _ready;
  bool get permissionsGranted => _permissionsGranted;
  bool get isDefaultSmsApp => _isDefaultSmsApp;
  String get status => _status;
  List<QueuedSms> get history => _history;
  MessageStore get messageStore => _messageStore;
  SmsCaptureService get smsCaptureService => _smsCaptureService;

  Future<void> initialize() async {
    _status = 'Initializing services';
    notifyListeners();

    try {
      // Load settings with fallback to defaults if load fails
      try {
        _settings = await SettingsService.instance.load();
      } catch (e) {
        _settings = const AppSettings(
          apiEndpoint: '',
          apiSecret: '',
          foregroundReliabilityMode: false,
          maxAttempts: 12,
        );
      }

      // Apply foreground mode with error handling
      try {
        await ForegroundServiceController.instance.apply(
          _settings.foregroundReliabilityMode,
        );
      } catch (_) {}

      // Request permissions with timeout to prevent hanging
      try {
        _permissionsGranted = await Future.any(<Future<bool>>[
          _smsCaptureService.requestPermissions(),
          Future<bool>.delayed(const Duration(seconds: 10), () => false),
        ]);
      } catch (_) {
        _permissionsGranted = false;
      }

      // Check default SMS role status
      try {
        _isDefaultSmsApp = await _smsCaptureService.isDefaultSmsApp();
      } catch (_) {
        _isDefaultSmsApp = false;
      }

      if (_permissionsGranted) {
        try {
          await _smsCaptureService.startListening();
        } catch (_) {}

        // Initial sync
        try {
          await _smsCaptureService.triggerNativeSync();
          await _refreshHistoryFromNative();
        } catch (_) {}

        // Start periodic drain timer
        _nativeDrainTimer = Timer.periodic(const Duration(seconds: 15), (Timer _) async {
          try {
            await _smsCaptureService.triggerNativeSync();
            await _refreshHistoryFromNative();
          } catch (_) {}
        });

        _status = 'Monitoring SMS';
      } else {
        _status = 'SMS permission denied';
      }

      // Always ensure default rules exist and sync to native
      try {
        await _messageStore.ensureDefaultRules();
        await _syncRulesToNative();
      } catch (_) {}

      // Import inbox once after permissions granted
      if (_permissionsGranted) {
        await _importInboxOnce();
        _startInboxRefreshTimer();
      }

      // Refresh history with error handling
      try {
        await _refreshHistoryFromNative();
      } catch (_) {}

      // Start connectivity listening
      _listenConnectivity();

      _ready = true;
      _status = 'Ready';
    } catch (_) {
      _status = 'Initialization failed';
      _ready = true;
    }
    notifyListeners();
  }

  Future<void> requestDefaultSmsRole() async {
    _status = 'Requesting default SMS role';
    notifyListeners();

    try {
      await _smsCaptureService.requestDefaultSmsRole();
      await Future<void>.delayed(const Duration(seconds: 2));
      _isDefaultSmsApp = await _smsCaptureService.isDefaultSmsApp();
      _status = _isDefaultSmsApp
          ? 'Default SMS role enabled'
          : 'Default SMS role not granted';
    } catch (_) {
      _status = 'Default SMS role request failed';
    }

    notifyListeners();
  }

  Future<void> saveSettings({required String endpoint, String secret = ''}) async {
    _settings = _settings.copyWith(
      apiEndpoint: endpoint.trim(),
      apiSecret: secret.trim(),
    );
    await SettingsService.instance.save(_settings);
    await _smsCaptureService.triggerNativeSync();
    await _refreshHistoryFromNative();
    _status = 'Settings saved';
    notifyListeners();
  }

  Future<void> saveEndpoint(String endpoint, {String? secret}) async {
    await saveSettings(
      endpoint: endpoint,
      secret: secret ?? _settings.apiSecret,
    );
  }

  Future<Map<String, dynamic>> testWebhookDelivery({String? customEndpoint, String? customSecret}) async {
    final String endpoint = (customEndpoint ?? _settings.apiEndpoint).trim();
    final String secret = (customSecret ?? _settings.apiSecret).trim();

    if (endpoint.isEmpty) {
      return <String, dynamic>{
        'success': false,
        'message': 'API Endpoint URL is empty. Please enter an endpoint first.',
      };
    }

    _status = 'Testing webhook delivery...';
    notifyListeners();

    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final String nowIso = DateTime.now().toIso8601String();
      final String nowUtc = DateTime.now().toUtc().toIso8601String();
      final String testTrxId = 'TEST${now % 1000000}';

      final Map<String, dynamic> testPayload = <String, dynamic>{
        'schemaVersion': '2.0',
        'idempotencyKey': 'test-webhook-$now',
        'provider': 'bkash',
        'direction': 'credit',
        'number': '01700000000',
        'sender': '01700000000',
        'amount': 500.0,
        'fee': 0.0,
        'balance': 1500.0,
        'transactionId': testTrxId,
        'reference': 'TEST_WEBHOOK',
        'datetimeLocal': nowIso,
        'datetimeUtc': nowUtc,
        'isParsed': true,
        'rawSms': 'You have received Tk 500.00 from 01700000000. Ref TEST_WEBHOOK. Fee Tk 0.00. Balance Tk 1,500.00. TrxID $testTrxId at $nowIso',
        'metadata': <String, dynamic>{
          'rawSms': 'You have received Tk 500.00 from 01700000000. Ref TEST_WEBHOOK. Fee Tk 0.00. Balance Tk 1,500.00. TrxID $testTrxId at $nowIso',
          'parserVersion': '2.0.0-multi',
          'isTestDelivery': true,
        },
      };

      final Uri uri = Uri.parse(endpoint);
      final Map<String, String> headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'X-Idempotency-Key': 'test-webhook-$now',
      };
      if (secret.isNotEmpty) {
        headers['Authorization'] = 'Bearer $secret';
      }

      final http.Response response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(testPayload),
          )
          .timeout(const Duration(seconds: 15));

      final bool success = response.statusCode >= 200 && response.statusCode < 300;

      // Also enqueue test SMS into native queue so it shows in delivery queue and history
      try {
        await _smsCaptureService.enqueueTestSms(
          sender: 'bKash',
          body: testPayload['rawSms'] as String,
        );
        await _refreshHistoryFromNative();
      } catch (_) {}

      _status = success
          ? 'Webhook test succeeded (HTTP ${response.statusCode})'
          : 'Webhook test failed (HTTP ${response.statusCode})';
      notifyListeners();

      return <String, dynamic>{
        'success': success,
        'statusCode': response.statusCode,
        'responseBody': response.body,
        'message': success
            ? 'Success: Webhook responded with HTTP ${response.statusCode}'
            : 'Server returned HTTP ${response.statusCode}: ${response.body}',
      };
    } catch (e) {
      _status = 'Webhook test error: $e';
      notifyListeners();
      return <String, dynamic>{
        'success': false,
        'message': 'Connection error: $e',
      };
    }
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
    try {
      await _syncRulesToNative();
      await _smsCaptureService.retryDeadLetters();
      await _smsCaptureService.triggerNativeSync();
      await _refreshHistoryFromNative();
      _status = 'Retry completed';
    } catch (e) {
      _status = 'Retry failed: ${e.toString()}';
    }
    notifyListeners();
  }

  Future<void> retrySingle(QueuedSms item) async {
    _status = 'Retrying message';
    notifyListeners();
    try {
      await _syncRulesToNative();
      await _smsCaptureService.retrySingle(
        sender: item.rawSender ?? item.sender,
        body: item.messageBody,
        timestamp: item.createdAt,
      );
      await _smsCaptureService.triggerNativeSync();
      await _refreshHistoryFromNative();
      _status = 'Retry triggered';
    } catch (e) {
      _status = 'Retry failed: ${e.toString()}';
    }
    notifyListeners();
  }

  Future<void> _refreshHistoryFromNative() async {
    try {
      final List<Map<String, dynamic>> snapshot = await _smsCaptureService.fetchQueueSnapshot();
      await _persistSnapshotToMessageStore(snapshot);
      _history = snapshot
          .where((Map<String, dynamic> row) => row['forward'] == true)
          .map(_mapNativeRowToQueuedSms)
          .toList(growable: false)
        ..sort((QueuedSms a, QueuedSms b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistSnapshotToMessageStore(List<Map<String, dynamic>> snapshot) async {
    if (snapshot.isEmpty) {
      return;
    }

    await _messageStore.transaction(() async {
      for (final Map<String, dynamic> row in snapshot) {
        final String sender = (row['sender'] as String? ?? '').trim();
        final String body = (row['body'] as String? ?? '').trim();
        final int timestamp = _asEpochMs(row['timestamp']);
        final String status = (row['status'] as String? ?? 'pending').trim();

        if (sender.isEmpty || body.isEmpty) {
          continue;
        }

        await _messageStore.insertIncomingIfMissing(
          address: sender,
          body: body,
          timestamp: timestamp,
          status: status,
        );
      }
    });
  }

  Future<void> _importInboxOnce() async {
    try {
      final bool imported = await SettingsService.instance.hasImportedInbox();
      if (imported) {
        return;
      }

      final List<Map<String, dynamic>> rows = await _smsCaptureService.importSmsInbox(limit: 500);
      if (rows.isEmpty) {
        await SettingsService.instance.markInboxImported();
        return;
      }

      await _messageStore.transaction(() async {
        for (final Map<String, dynamic> row in rows) {
          final String sender = (row['address'] as String? ?? '').trim();
          final String body = (row['body'] as String? ?? '').trim();
          final int timestamp = _asEpochMs(row['timestamp']);
          final bool incoming = (row['isIncoming'] as bool?) ?? true;

          if (sender.isEmpty || body.isEmpty) {
            continue;
          }

          if (incoming) {
            await _messageStore.insertIncomingIfMissing(
              address: sender,
              body: body,
              timestamp: timestamp,
              status: 'received',
            );
          } else {
            await _messageStore.insertOutgoingIfMissing(
              address: sender,
              body: body,
              timestamp: timestamp,
              status: 'sent',
            );
          }
        }
      });

      await SettingsService.instance.markInboxImported();
    } catch (_) {}
  }

  void _startInboxRefreshTimer() {
    _inboxRefreshTimer?.cancel();
    _inboxRefreshTimer = Timer.periodic(const Duration(seconds: 60), (Timer _) async {
      await _refreshInbox();
    });
  }

  Future<void> _refreshInbox() async {
    try {
      if (!_permissionsGranted) {
        return;
      }

      final List<Map<String, dynamic>> rows = await _smsCaptureService.importSmsInbox(limit: 200);
      if (rows.isEmpty) {
        return;
      }

      await _messageStore.transaction(() async {
        for (final Map<String, dynamic> row in rows) {
          final String sender = (row['address'] as String? ?? '').trim();
          final String body = (row['body'] as String? ?? '').trim();
          final int timestamp = _asEpochMs(row['timestamp']);
          final bool incoming = (row['isIncoming'] as bool?) ?? true;

          if (sender.isEmpty || body.isEmpty) {
            continue;
          }

          if (incoming) {
            await _messageStore.insertIncomingIfMissing(
              address: sender,
              body: body,
              timestamp: timestamp,
              status: 'received',
            );
          } else {
            await _messageStore.insertOutgoingIfMissing(
              address: sender,
              body: body,
              timestamp: timestamp,
              status: 'sent',
            );
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _syncRulesToNative() async {
    try {
      final String json = await _messageStore.exportRulesJson();
      await _smsCaptureService.setCaptureRules(json);
    } catch (_) {}
  }

  Future<void> refreshRulesSync() async {
    await _syncRulesToNative();
  }

  Future<void> handleAppResumed() async {
    try {
      await _refreshInbox();
      await _refreshHistoryFromNative();
      _isDefaultSmsApp = await _smsCaptureService.isDefaultSmsApp();
      notifyListeners();
    } catch (_) {}
  }

  QueuedSms _mapNativeRowToQueuedSms(Map<String, dynamic> row) {
    final String body = (row['body'] as String? ?? '').trim();
    final String rawSender = (row['sender'] as String? ?? '').trim();
    final ParsedTransaction parsed = TransactionParser.parse(
      body,
      fallbackSender: rawSender,
    );
    final int createdAt = _asEpochMs(row['timestamp']);
    final int nextRetryAt = _asEpochMs(row['nextRetryAt']);
    final int attemptCount = _asInt(row['attemptCount']);
    final String sender = parsed.sender.isNotEmpty ? parsed.sender : rawSender;
    final String status = (row['status'] as String? ?? 'pending').trim();

    return QueuedSms(
      id: _buildNativeRowId(row),
      sender: sender,
      rawSender: rawSender,
      messageBody: body,
      createdAt: createdAt,
      updatedAt: createdAt,
      amount: parsed.amount,
      transactionId: parsed.transactionId,
      reference: parsed.reference,
      transactionLocalTime: parsed.localIso,
      transactionUtcTime: parsed.utcIso,
      fee: parsed.fee,
      balance: parsed.balance,
      status: status,
      attemptCount: attemptCount,
      nextRetryAt: nextRetryAt == 0 ? null : nextRetryAt,
      lastError: (row['lastError'] as String?)?.trim().isEmpty == true
          ? null
          : (row['lastError'] as String?),
      lastEvent: (row['lastEvent'] as String?)?.trim().isEmpty == true
          ? null
          : (row['lastEvent'] as String?),
    );
  }

  String _buildNativeRowId(Map<String, dynamic> row) {
    final String sender = (row['sender'] as String? ?? '').trim();
    final String body = (row['body'] as String? ?? '').trim();
    final int timestamp = _asEpochMs(row['timestamp']);
    return '$sender|$timestamp|${body.hashCode}';
  }

  int _asEpochMs(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  void _listenConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final bool hasNet = results.any(
        (ConnectivityResult r) => r != ConnectivityResult.none,
      );
      if (hasNet) {
        try {
          await _smsCaptureService.triggerNativeSync();
          await _refreshHistoryFromNative();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _nativeDrainTimer?.cancel();
    _inboxRefreshTimer?.cancel();
    super.dispose();
  }
}
