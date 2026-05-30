import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_controller.dart';
import '../core/services/portal_config.dart';
import '../core/services/portal_service.dart';
import '../core/services/sms_capture_service.dart';

class PortalScreen extends StatefulWidget {
  const PortalScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  final PortalService _portalService = PortalService();
  final SmsCaptureService _smsCaptureService = SmsCaptureService();

  bool _busy = false;
  bool _batteryIgnored = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadBatteryStatus();
  }

  Future<void> _loadBatteryStatus() async {
    try {
      final bool ignored = await _smsCaptureService.isIgnoringBatteryOptimizations();
      if (mounted) {
        setState(() => _batteryIgnored = ignored);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _scanAndPair() async {
    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      final String? pairingId = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => const _PortalScannerScreen(),
        ),
      );

      if (pairingId == null || pairingId.trim().isEmpty) {
        return;
      }

      final PortalPairingResult result = await _portalService.claimPairing(pairingId.trim());
      if (result.deviceId.isEmpty || result.deviceSecret.isEmpty || result.pin.isEmpty) {
        throw Exception('Invalid pairing payload');
      }

      await widget.controller.savePortalPairing(
        deviceId: result.deviceId,
        deviceSecret: result.deviceSecret,
        pin: result.pin,
      );

      await _loadBatteryStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Pairing failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _syncInbox() async {
    final String deviceId = widget.controller.settings.portalDeviceId;
    final String secret = widget.controller.settings.portalDeviceSecret;
    if (deviceId.isEmpty || secret.isEmpty) {
      setState(() => _error = 'Pair the portal before syncing.');
      return;
    }

    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      final List<Map<String, dynamic>> rows =
          await _smsCaptureService.importSmsInbox(limit: 500);
      if (rows.isEmpty) {
        setState(() => _error = 'No inbox messages found to upload.');
        return;
      }

      final List<PortalMessage> messages = rows.map((Map<String, dynamic> row) {
        final String address = (row['address'] as String? ?? '').trim();
        final String body = (row['body'] as String? ?? '').trim();
        final dynamic rawTimestamp = row['timestamp'];
        final int timestamp = rawTimestamp is num
            ? rawTimestamp.toInt()
            : DateTime.now().millisecondsSinceEpoch;
        final bool incoming = (row['isIncoming'] as bool?) ?? true;
        return PortalMessage(
          address: address,
          body: body,
          timestamp: timestamp,
          direction: incoming ? 'incoming' : 'outgoing',
        );
      }).where((PortalMessage message) {
        return message.address.isNotEmpty && message.body.isNotEmpty;
      }).toList(growable: false);

      await _portalService.uploadMessagesBulk(
        deviceId: deviceId,
        deviceSecret: secret,
        messages: messages,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Inbox sync failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetPairing() async {
    await widget.controller.clearPortalPairing();
    if (mounted) {
      setState(() => _error = '');
    }
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      await _smsCaptureService.requestIgnoreBatteryOptimizations();
      await _loadBatteryStatus();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to open battery settings.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool paired = widget.controller.portalPaired;
    final String deviceId = widget.controller.portalDeviceId;
    final String pin = widget.controller.portalPin;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildCard(
          title: 'Portal Pairing',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                paired
                    ? 'Paired with device $deviceId'
                    : 'Scan the QR code from the web portal to pair.',
              ),
              const SizedBox(height: 12),
              if (paired) ...<Widget>[
                Text('PIN: $pin', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Portal URL: ${PortalConfig.baseUrl}'),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _busy ? null : _scanAndPair,
                    child: Text(paired ? 'Re-pair device' : 'Scan QR'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || !paired ? null : _resetPairing,
                    child: const Text('Reset pairing'),
                  ),
                  OutlinedButton(
                    onPressed: _busy || !paired ? null : _syncInbox,
                    child: const Text('Sync inbox now'),
                  ),
                ],
              ),
              if (_busy) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCard(
          title: 'Battery & Reliability',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _batteryIgnored
                    ? 'Battery optimizations are disabled for this app.'
                    : 'Disable battery optimizations to keep uploads running.',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _requestBatteryOptimization,
                child: const Text('Disable battery optimization'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep foreground mode enabled for maximum reliability.',
              ),
            ],
          ),
        ),
        if (_error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
      ],
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD8ECFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF009BFF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PortalScannerScreen extends StatefulWidget {
  const _PortalScannerScreen();

  @override
  State<_PortalScannerScreen> createState() => _PortalScannerScreenState();
}

class _PortalScannerScreenState extends State<_PortalScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    final Barcode? barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final String rawValue = barcode?.rawValue ?? '';
    if (rawValue.isEmpty) {
      return;
    }

    String pairingId = rawValue.trim();
    try {
      final Map<String, dynamic> payload =
          jsonDecode(rawValue) as Map<String, dynamic>;
      if (payload['pairingId'] is String) {
        pairingId = payload['pairingId'] as String;
      }
    } catch (_) {
      // keep raw value
    }

    _handled = true;
    Navigator.of(context).pop(pairingId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Portal QR')),
      body: MobileScanner(
        onDetect: _onDetect,
      ),
    );
  }
}
