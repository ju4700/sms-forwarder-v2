import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../core/models/queued_sms.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _endpointController;
  late final TextEditingController _deviceController;
  late final TextEditingController _walletController;
  final TextEditingController _secretController = TextEditingController();
  bool _saving = false;
  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _cardBorder = Color(0xFFD8ECFF);
  bool _retrying = false;
  final Set<String> _retryingItems = <String>{};
  int _retryCooldownUntil = 0;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(
      text: widget.controller.settings.apiEndpoint,
    );
    _deviceController = TextEditingController(
      text: widget.controller.settings.deviceId,
    );
    _walletController = TextEditingController(
      text: widget.controller.settings.receivingAccount,
    );
    widget.controller.addListener(_syncControllerText);
    _syncControllerText();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllerText);
    _endpointController.dispose();
    _deviceController.dispose();
    _walletController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _syncControllerText() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildStatusCard(controller),
        const SizedBox(height: 12),
        _buildSettingsCard(controller),
        const SizedBox(height: 12),
        _buildQueueStats(controller),
        const SizedBox(height: 12),
        _buildHistory(controller.history),
      ],
    );
  }

  Widget _buildStatusCard(AppController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Status',
            style: TextStyle(
              color: _electricBlue,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(controller.status),
          const SizedBox(height: 8),
          Text(
            controller.permissionsGranted
                ? 'SMS permission: granted'
                : 'SMS permission: not granted',
          ),
          const SizedBox(height: 8),
          const Text('Receives bKash credit receipts from bKash / 16247 only.'),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(AppController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Delivery Settings',
            style: TextStyle(color: _electricBlue, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _endpointController,
            decoration: const InputDecoration(
              labelText: 'API Endpoint',
              hintText: 'https://example.com/api/transactions',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _deviceController,
            decoration: const InputDecoration(
              labelText: 'Device ID',
              hintText: 'payment-phone-1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _walletController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Receiving bKash number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _secretController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Device secret (64 hex characters)',
              helperText: controller.settings.secretConfigured
                  ? 'Saved securely. Leave empty to keep it.'
                  : 'Use the secret configured on your server.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await controller.saveDelivery(
                          endpoint: _endpointController.text,
                          deviceId: _deviceController.text,
                          receivingAccount: _walletController.text,
                          secret: _secretController.text,
                        );
                        _secretController.clear();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Delivery settings saved'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e is PlatformException
                                    ? e.message ??
                                          'Could not save delivery settings'
                                    : 'Could not save delivery settings',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: const Text('Save Delivery Settings'),
            ),
          ),
          const SizedBox(height: 6),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.settings.foregroundReliabilityMode,
              title: const Text('Foreground reliability mode'),
              subtitle: const Text(
                'Shows a monitoring notification. Android may limit its duration.',
              ),
              onChanged: controller.setForegroundMode,
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: controller.settings.secretConfigured
                ? controller.recoverReceipts
                : null,
            child: const Text('Recover recent payment receipts'),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: () async {
              try {
                await controller.disableBatteryOptimization();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open Android battery settings for this app.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Battery settings'),
          ),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed:
                    _retrying ||
                        DateTime.now().millisecondsSinceEpoch <
                            _retryCooldownUntil
                    ? null
                    : () async {
                        setState(() => _retrying = true);
                        _retryCooldownUntil =
                            DateTime.now().millisecondsSinceEpoch + 3000;
                        try {
                          await controller.retryFailed();
                        } catch (_) {
                          // controller.retryFailed is guarded, but protect UI anyway
                        } finally {
                          if (mounted) setState(() => _retrying = false);
                        }
                      },
                child: _retrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Retry Failed and Sync Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueStats(AppController controller) {
    final int pending = controller.history
        .where(
          (QueuedSms x) =>
              x.status == 'pending' || x.status == 'retry_scheduled',
        )
        .length;
    final int sent = controller.history
        .where((QueuedSms x) => x.status == 'delivered')
        .length;
    final int failed = controller.history
        .where(
          (QueuedSms x) => x.status == 'failed' || x.status == 'dead_letter',
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _statItem('Pending', pending),
          _statItem('Sent', sent),
          _statItem('Failed', failed),
        ],
      ),
    );
  }

  Widget _statItem(String label, int value) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: TextStyle(
            color: _electricBlue,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildHistory(List<QueuedSms> history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: const Text('No transaction SMS captured yet.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: history.take(20).map((QueuedSms item) {
          final bool isFailed =
              item.status == 'failed' || item.status == 'dead_letter';
          final bool isPending =
              item.status == 'pending' || item.status == 'retry_scheduled';
          final bool isRetrying = _retryingItems.contains(item.id);
          return Material(
            type: MaterialType.transparency,
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              title: Text(
                'Tk ${item.amount.toStringAsFixed(2)} - ${item.reference}',
              ),
              subtitle: Text(
                '${item.sender} | TrxID ${item.transactionId}\n${item.transactionLocalTime}',
              ),
              isThreeLine: true,
              onLongPress: !isFailed
                  ? null
                  : () async {
                      final bool confirmed =
                          await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Handled manually?'),
                              content: const Text(
                                'Confirm you reviewed this transaction in the wallet and resolved it in the store. This stops delivery retries for this receipt.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Mark handled'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirmed) {
                        try {
                          await widget.controller.markHandled(item);
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not mark the receipt handled.',
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Chip(
                    label: Text(item.status),
                    backgroundColor: const Color(0xFFEAF6FF),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  if (isFailed || isPending) ...<Widget>[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: isRetrying
                          ? null
                          : () async {
                              setState(() => _retryingItems.add(item.id));
                              try {
                                await widget.controller.retrySingle(item);
                              } catch (_) {
                                // controller.retrySingle is guarded
                              } finally {
                                if (mounted) {
                                  setState(
                                    () => _retryingItems.remove(item.id),
                                  );
                                }
                              }
                            },
                      child: isRetrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
