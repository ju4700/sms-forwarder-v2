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
        title: const Text('Capture Rules'),
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
            'Capture rules decide which SMS are forwarded.',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Messages are still stored locally even if no rules match or the API is empty.',
            style: GoogleFonts.spaceGrotesk(color: _ink.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        color: Colors.white,
      ),
      child: Text(
        'No rules yet. Add one to start forwarding transactions.',
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
            style: GoogleFonts.spaceGrotesk(fontSize: 12.5, color: _ink.withOpacity(0.7)),
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
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ruleSummary(CaptureRule rule) {
    if (rule.type == 'template' && rule.templateKey != null) {
      return 'Template: ${rule.templateKey}';
    }
    final List<String> parts = <String>[];
    if (rule.senderPattern != null && rule.senderPattern!.isNotEmpty) {
      parts.add('Sender: ${rule.senderPattern}');
    }
    if (rule.bodyPattern != null && rule.bodyPattern!.isNotEmpty) {
      parts.add('Body: ${rule.bodyPattern}');
    }
    return parts.isEmpty ? 'Custom rule' : parts.join(' • ');
  }

  Future<void> _openEditor(BuildContext context, CaptureRule? rule) async {
    final TextEditingController nameController = TextEditingController(text: rule?.name ?? '');
    final TextEditingController senderController =
        TextEditingController(text: rule?.senderPattern ?? '');
    final TextEditingController bodyController = TextEditingController(text: rule?.bodyPattern ?? '');
    String type = rule?.type ?? 'template';
    String templateKey = rule?.templateKey ?? 'bkash';

    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                rule == null ? 'Add Rule' : 'Edit Rule',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Rule name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Rule type'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'template', child: Text('Template')),
                  DropdownMenuItem(value: 'regex', child: Text('Regex')),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    type = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              if (type == 'template')
                DropdownButtonFormField<String>(
                  initialValue: templateKey,
                  decoration: const InputDecoration(labelText: 'Template'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                    DropdownMenuItem(value: 'rocket', child: Text('Rocket')),
                    DropdownMenuItem(value: 'dbbl', child: Text('DBBL')),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      templateKey = value;
                    }
                  },
                ),
              if (type == 'regex') ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: senderController,
                  decoration: const InputDecoration(labelText: 'Sender pattern (regex)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(labelText: 'Body pattern (regex)'),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

    if (rule == null) {
      await controller.messageStore.insertRule(
        name: name,
        type: type,
        senderPattern: senderPattern,
        bodyPattern: bodyPattern,
        templateKey: template,
        enabled: true,
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
      );
    }

    await _syncRules();
  }

  Future<void> _syncRules() async {
    await controller.refreshRulesSync();
  }
}
