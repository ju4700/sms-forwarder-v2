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
  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _cardBorder = Color(0xFFD8ECFF);

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    widget.controller.addListener(_syncControllerText);
    _syncControllerText();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllerText);
    _endpointController.dispose();
    super.dispose();
  }

  void _syncControllerText() {
    final String endpoint = widget.controller.settings.apiEndpoint;
    if (_endpointController.text != endpoint) {
      _endpointController.text = endpoint;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Forwarder'),
        centerTitle: false,
      ),
      body: ListView(
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
      ),
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
            style: TextStyle(
              color: _electricBlue,
              fontWeight: FontWeight.w700,
            ),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => controller.saveEndpoint(_endpointController.text),
              child: const Text('Save Endpoint'),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.settings.foregroundReliabilityMode,
            title: const Text('Foreground reliability mode'),
            subtitle: const Text('Improves Android 13+ reliability with persistent notification.'),
            onChanged: controller.setForegroundMode,
          ),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: controller.retryFailed,
                child: const Text('Retry Failed and Sync Now'),
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
    final int failed = controller.history.where((QueuedSms x) => x.status == 'dead_letter').length;

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
          return ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            title: Text('Tk ${item.amount.toStringAsFixed(2)} - ${item.reference}'),
            subtitle: Text(
              '${item.sender} | TrxID ${item.transactionId}\n${item.transactionLocalTime}',
            ),
            isThreeLine: true,
            trailing: Chip(
              label: Text(item.status),
              backgroundColor: const Color(0xFFEAF6FF),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
