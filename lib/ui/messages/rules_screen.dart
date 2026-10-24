import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_controller.dart';
import '../../core/services/message_store.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.controller});

  final AppController controller;

  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _ink = Color(0xFF0B2B4B);
  static const Color _cardBorder = Color(0xFFD8ECFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture & Forward Rules'),
      ),
      body: StreamBuilder<List<CaptureRule>>(
        stream: controller.messageStore.watchRules(),
        builder: (BuildContext context, AsyncSnapshot<List<CaptureRule>> snapshot) {
          final List<CaptureRule> rules = snapshot.data ?? <CaptureRule>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _buildIntro(context),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                _emptyState(context)
              else
                ...rules.map((CaptureRule rule) => _ruleCard(context, rule)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _openEditor(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Add Rule'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Smart Capture & Forwarding Rules',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rules filter which SMS are forwarded to your webhook. Automatic protection blocks OTPs and promotional spam.',
            style: GoogleFonts.spaceGrotesk(color: _ink.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        color: Colors.white,
      ),
      child: Text(
        'No rules yet. Add one to start forwarding MFS or bank transactions.',
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceGrotesk(color: _ink),
      ),
    );
  }

  Widget _ruleCard(BuildContext context, CaptureRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  rule.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
              ),
              Switch(
                value: rule.enabled,
                activeThumbColor: _electricBlue,
                onChanged: (bool value) async {
                  await controller.messageStore.updateRule(
                    id: rule.id,
                    name: rule.name,
                    type: rule.type,
                    senderPattern: rule.senderPattern,
                    bodyPattern: rule.bodyPattern,
                    templateKey: rule.templateKey,
                    enabled: value,
                    notes: rule.notes,
                  );
                  await _syncRules();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _ruleSummary(rule),
            style: GoogleFonts.spaceGrotesk(fontSize: 12.5, color: _ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: () => _openEditor(context, rule),
                child: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await controller.messageStore.deleteRule(rule.id);
                  await _syncRules();
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ruleSummary(CaptureRule rule) {
    final List<String> parts = <String>[];
    if (rule.type == 'template' && rule.templateKey != null) {
      parts.add('Provider: ${rule.templateKey!.toUpperCase()}');
    }
    if (rule.senderPattern != null && rule.senderPattern!.isNotEmpty) {
      parts.add('Sender: ${rule.senderPattern}');
    }
    if (rule.bodyPattern != null && rule.bodyPattern!.isNotEmpty) {
      parts.add('Body: ${rule.bodyPattern}');
    }

    if (rule.notes != null && rule.notes!.isNotEmpty) {
      try {
        final Map<String, dynamic> notes = jsonDecode(rule.notes!) as Map<String, dynamic>;
        final String direction = notes['direction']?.toString() ?? 'credit';
        parts.add(direction == 'credit' ? 'Money In Only' : (direction == 'debit' ? 'Money Out Only' : 'All'));
        final double min = (notes['minAmount'] as num?)?.toDouble() ?? 0.0;
        if (min > 0) parts.add('Min: BDT $min');
      } catch (_) {}
    }

    return parts.isEmpty ? 'Custom filter' : parts.join(' - ');
  }

  Future<void> _openEditor(BuildContext context, CaptureRule? rule) async {
    final TextEditingController nameController = TextEditingController(text: rule?.name ?? '');
    final TextEditingController senderController = TextEditingController(text: rule?.senderPattern ?? '');
    final TextEditingController bodyController = TextEditingController(text: rule?.bodyPattern ?? '');
    final TextEditingController minAmountController = TextEditingController();

    String type = rule?.type ?? 'template';
    String templateKey = rule?.templateKey ?? 'all';
    String direction = 'credit';
    bool filterSpam = true;
    bool filterOtp = true;

    if (rule?.notes != null && rule!.notes!.isNotEmpty) {
      try {
        final Map<String, dynamic> extra = jsonDecode(rule.notes!) as Map<String, dynamic>;
        direction = extra['direction']?.toString() ?? 'credit';
        final double? min = (extra['minAmount'] as num?)?.toDouble();
        if (min != null && min > 0) minAmountController.text = min.toStringAsFixed(0);
        filterSpam = extra['filterSpam'] as bool? ?? true;
        filterOtp = extra['filterOtp'] as bool? ?? true;
      } catch (_) {}
    }

    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      rule == null ? 'Add Forwarding Rule' : 'Edit Forwarding Rule',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Rule Name',
                        hintText: 'e.g. bKash Merchant Payments',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Rule Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'template', child: Text('Pre-configured Template')),
                        DropdownMenuItem(value: 'regex', child: Text('Custom Regex Pattern')),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setModalState(() => type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (type == 'template')
                      DropdownButtonFormField<String>(
                        initialValue: templateKey,
                        decoration: const InputDecoration(
                          labelText: 'Provider Template',
                          border: OutlineInputBorder(),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'all', child: Text('All Providers (bKash, Nagad, Rocket, Banks)')),
                          DropdownMenuItem(value: 'bkash', child: Text('bKash Only')),
                          DropdownMenuItem(value: 'nagad', child: Text('Nagad Only')),
                          DropdownMenuItem(value: 'rocket', child: Text('Rocket Only')),
                          DropdownMenuItem(value: 'bank', child: Text('Commercial Banks (City, DBBL, BRAC, etc.)')),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            setModalState(() => templateKey = value);
                          }
                        },
                      ),
                    if (type == 'regex') ...<Widget>[
                      TextField(
                        controller: senderController,
                        decoration: const InputDecoration(
                          labelText: 'Sender Pattern (Regex / Number)',
                          hintText: 'e.g. ^01[3-9]\\d{8}\$ or bKash|NAGAD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyController,
                        decoration: const InputDecoration(
                          labelText: 'Body Pattern (Regex)',
                          hintText: 'e.g. Received|credited',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: direction,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Direction',
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'credit', child: Text('Money In / Received (Credit only - Recommended)')),
                        DropdownMenuItem(value: 'debit', child: Text('Money Out / Sent (Debit only)')),
                        DropdownMenuItem(value: 'all', child: Text('Both (Credit and Debit)')),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setModalState(() => direction = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Amount (BDT) (Optional)',
                        hintText: 'e.g. 50 (Ignores transactions below this)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: filterOtp,
                      title: const Text('Block OTPs & Verification Codes'),
                      subtitle: const Text('Prevents security codes from leaking to webhook'),
                      onChanged: (bool v) => setModalState(() => filterOtp = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: filterSpam,
                      title: const Text('Block Promotional & Marketing Spam'),
                      subtitle: const Text('Blocks carrier cashback and marketing alerts'),
                      onChanged: (bool v) => setModalState(() => filterSpam = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Save Rule'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final String name = nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final String? senderPattern = type == 'regex' ? senderController.text.trim() : null;
    final String? bodyPattern = type == 'regex' ? bodyController.text.trim() : null;
    final String? template = type == 'template' ? templateKey : null;

    final double? minAmount = double.tryParse(minAmountController.text.trim());
    final Map<String, dynamic> notesMap = <String, dynamic>{
      'direction': direction,
      'minAmount': minAmount ?? 0.0,
      'filterSpam': filterSpam,
      'filterOtp': filterOtp,
    };
    final String notesJson = jsonEncode(notesMap);

    if (rule == null) {
      await controller.messageStore.insertRule(
        name: name,
        type: type,
        senderPattern: senderPattern,
        bodyPattern: bodyPattern,
        templateKey: template,
        enabled: true,
        notes: notesJson,
      );
    } else {
      await controller.messageStore.updateRule(
        id: rule.id,
        name: name,
        type: type,
        senderPattern: senderPattern,
        bodyPattern: bodyPattern,
        templateKey: template,
        enabled: rule.enabled,
        notes: notesJson,
      );
    }

    await _syncRules();
  }

  Future<void> _syncRules() async {
    await controller.refreshRulesSync();
  }
}
