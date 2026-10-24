import 'package:flutter/material.dart';

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
  late final TextEditingController _secretController;
  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _cardBorder = Color(0xFFD8ECFF);
  bool _retrying = false;
  final Set<String> _retryingItems = <String>{};
  int _retryCooldownUntil = 0;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    _secretController = TextEditingController();
    widget.controller.addListener(_syncControllerText);
    _syncControllerText();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllerText);
    _endpointController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _syncControllerText() {
    final String endpoint = widget.controller.settings.apiEndpoint;
    final String secret = widget.controller.settings.apiSecret;
    if (_endpointController.text != endpoint) {
      _endpointController.text = endpoint;
    }
    if (_secretController.text != secret) {
      _secretController.text = secret;
    }
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'System Status',
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
                ? 'SMS permission: Granted'
                : 'SMS permission: Denied',
          ),
          const SizedBox(height: 8),
          Text(
            controller.isDefaultSmsApp
                ? 'Default SMS app: Enabled (Full Capture & Delivery)'
                : 'Default SMS app: Not set (May miss some background SMS)',
          ),
          const SizedBox(height: 8),
          if (!controller.isDefaultSmsApp)
            ElevatedButton.icon(
              onPressed: controller.requestDefaultSmsRole,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Set as Default SMS App'),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(AppController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Delivery Webhook Settings',
            style: TextStyle(
              color: _electricBlue,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _endpointController,
            decoration: const InputDecoration(
              labelText: 'API Endpoint URL',
              hintText: 'https://your-server.com/api/sms-webhook',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _secretController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Secret / Bearer Token (Optional)',
              hintText: 'Used for Authorization header & HMAC signature',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.saveSettings(
                endpoint: _endpointController.text,
                secret: _secretController.text,
              ),
              child: const Text('Save Settings'),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.settings.foregroundReliabilityMode,
            title: const Text('Foreground reliability mode'),
            subtitle: const Text('Keeps monitor service alive with persistent notification.'),
            onChanged: controller.setForegroundMode,
          ),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: 240,
              child: OutlinedButton(
                onPressed: _retrying || DateTime.now().millisecondsSinceEpoch < _retryCooldownUntil
                    ? null
                    : () async {
                        setState(() => _retrying = true);
                        _retryCooldownUntil =
                            DateTime.now().millisecondsSinceEpoch + 3000;
                        try {
                          await controller.retryFailed();
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
                    : const Text('Retry Failed & Sync Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueStats(AppController controller) {
    final int pending = controller.history.where((QueuedSms x) => x.status == 'pending' || x.status == 'retry_scheduled').length;
    final int sent = controller.history.where((QueuedSms x) => x.status == 'delivered').length;
    final int failed = controller.history
      .where((QueuedSms x) => x.status == 'failed' || x.status == 'dead_letter')
      .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _statItem('Pending', pending, Colors.orange),
          _statItem('Sent', sent, Colors.green),
          _statItem('Failed', failed, Colors.red),
        ],
      ),
    );
  }

  Widget _statItem(String label, int value, Color color) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: TextStyle(
            color: color,
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
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cardBorder),
        ),
        child: const Text('No transaction SMS captured yet.'),
      );
    }

    final List<QueuedSms> displayItems = history.take(25).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayItems.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: _cardBorder.withValues(alpha: 0.6)),
        itemBuilder: (BuildContext context, int index) {
          final QueuedSms item = displayItems[index];
          final bool isFailed = item.status == 'failed' || item.status == 'dead_letter';
          final bool isPending = item.status == 'pending' || item.status == 'retry_scheduled';
          final bool isRetrying = _retryingItems.contains(item.id);

          final Color statusColor = item.status == 'delivered'
              ? Colors.green.shade800
              : (isFailed ? Colors.red.shade800 : Colors.blue.shade800);
          final Color statusBg = item.status == 'delivered'
              ? Colors.green.shade50
              : (isFailed ? Colors.red.shade50 : const Color(0xFFEAF6FF));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Tk ${item.amount.toStringAsFixed(2)} - ${item.reference}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0B2B4B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${item.sender} | TrxID: ${item.transactionId}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.transactionLocalTime,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isFailed || isPending) ...<Widget>[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: isRetrying
                              ? null
                              : () async {
                                  setState(() => _retryingItems.add(item.id));
                                  try {
                                    await widget.controller.retrySingle(item);
                                  } finally {
                                    if (mounted) {
                                      setState(() => _retryingItems.remove(item.id));
                                    }
                                  }
                                },
                          child: isRetrying
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Send', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
