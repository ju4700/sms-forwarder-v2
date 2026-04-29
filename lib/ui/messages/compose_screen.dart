import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/message_store.dart';
import '../../core/services/sms_capture_service.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.store,
    required this.captureService,
    this.initialRecipient,
  });

  final MessageStore store;
  final SmsCaptureService captureService;
  final String? initialRecipient;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _ink = Color(0xFF0B2B4B);

  late final TextEditingController _recipientController;
  late final TextEditingController _bodyController;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _recipientController = TextEditingController(text: widget.initialRecipient ?? '');
    _bodyController = TextEditingController();
    _recipientController.addListener(_syncCanSend);
    _bodyController.addListener(_syncCanSend);
    _syncCanSend();
  }

  @override
  void dispose() {
    _recipientController.removeListener(_syncCanSend);
    _bodyController.removeListener(_syncCanSend);
    _recipientController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _syncCanSend() {
    final bool next = _recipientController.text.trim().isNotEmpty &&
        _bodyController.text.trim().isNotEmpty;
    if (next != _canSend) {
      setState(() {
        _canSend = next;
      });
    }
  }

  Future<void> _sendMessage() async {
    final String recipient = _recipientController.text.trim();
    final String body = _bodyController.text.trim();
    if (recipient.isEmpty || body.isEmpty) {
      return;
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    await widget.store.insertOutgoingMessage(
      address: recipient,
      body: body,
      timestamp: timestamp,
      status: 'sending',
    );

    final bool sent = await widget.captureService.sendSms(
      address: recipient,
      body: body,
    );

    await widget.store.insertOutgoingMessage(
      address: recipient,
      body: body,
      timestamp: timestamp + 1,
      status: sent ? 'sent' : 'send_failed',
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
        actions: <Widget>[
          TextButton(
            onPressed: _canSend ? _sendMessage : null,
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Recipient',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recipientController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+8801xxxxxxxxx',
                hintStyle: GoogleFonts.spaceGrotesk(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Message',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: 'Type SMS content',
                  hintStyle: GoogleFonts.spaceGrotesk(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canSend ? _sendMessage : null,
                icon: const Icon(Icons.send),
                label: const Text('Send Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _electricBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
