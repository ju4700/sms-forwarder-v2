import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models/queued_sms.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.controller});

  final AppController controller;

  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _cardBorder = Color(0xFFD8ECFF);

  @override
  Widget build(BuildContext context) {
    final List<QueuedSms> items = controller.history;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _summaryRow(items),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _cardBorder),
          ),
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No log entries yet.'),
                )
              : Column(
                  children: items.take(40).map((QueuedSms item) {
                    return ListTile(
                      title: Text('${item.reference} · Tk ${item.amount.toStringAsFixed(2)}'),
                      subtitle: Text(
                        '${item.sender}\n${item.transactionLocalTime}\n${item.lastEvent ?? item.status}',
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
        ),
      ],
    );
  }

  Widget _summaryRow(List<QueuedSms> items) {
    final int captured = items.length;
    final int sent = items.where((QueuedSms item) => item.status == 'delivered').length;
    final int retrying = items.where((QueuedSms item) => item.status == 'retry_scheduled').length;
    final int dead = items
      .where((QueuedSms item) => item.status == 'failed' || item.status == 'dead_letter')
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
          _stat('Captured', captured),
          _stat('Sent', sent),
          _stat('Retry', retrying),
          _stat('Failed', dead),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: const TextStyle(
            color: _electricBlue,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label),
      ],
    );
  }
}
