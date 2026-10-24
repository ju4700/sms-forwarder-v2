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
    final List<QueuedSms> displayItems = items.take(40).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _summaryRow(items),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cardBorder),
          ),
          child: displayItems.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No log entries yet.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayItems.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: _cardBorder.withValues(alpha: 0.6)),
                  itemBuilder: (BuildContext context, int index) {
                    final QueuedSms item = displayItems[index];
                    final bool isDelivered = item.status == 'delivered';
                    final bool isFailed = item.status == 'failed' || item.status == 'dead_letter';

                    final Color statusColor = isDelivered
                        ? Colors.green.shade800
                        : (isFailed ? Colors.red.shade800 : Colors.blue.shade800);
                    final Color statusBg = isDelivered
                        ? Colors.green.shade50
                        : (isFailed ? Colors.red.shade50 : const Color(0xFFEAF6FF));

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '${item.reference} - Tk ${item.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
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
                                  borderRadius: BorderRadius.circular(10),
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
                          const SizedBox(height: 5),
                          Text(
                            item.sender,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  item.lastEvent ?? item.status,
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                item.transactionLocalTime,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
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
        borderRadius: BorderRadius.circular(8),
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
