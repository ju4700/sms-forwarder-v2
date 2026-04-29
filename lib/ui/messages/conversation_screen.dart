import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/message_store.dart';
import '../../core/services/sms_capture_service.dart';
import 'compose_screen.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({
    super.key,
    required this.thread,
    required this.store,
    required this.captureService,
  });

  final MessageThread thread;
  final MessageStore store;
  final SmsCaptureService captureService;

  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _ink = Color(0xFF0B2B4B);

  @override
  Widget build(BuildContext context) {
    final String title = (thread.displayName ?? '').trim().isEmpty
        ? thread.address
        : thread.displayName!.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<ComposeScreen>(
                  builder: (_) => ComposeScreen(
                    store: store,
                    captureService: captureService,
                    initialRecipient: thread.address,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF7FBFF), Color(0xFFEFF7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<List<Message>>(
          stream: store.watchMessagesForThread(thread.id),
          builder: (BuildContext context, AsyncSnapshot<List<Message>> snapshot) {
            final List<Message> messages = snapshot.data ?? <Message>[];

            if (messages.isEmpty) {
              return Center(
                child: Text(
                  'No messages in this thread yet.',
                  style: GoogleFonts.spaceGrotesk(color: _ink.withOpacity(0.7)),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: messages.map((Message message) {
                return _bubble(
                  text: message.body,
                  incoming: message.isIncoming,
                  time: _formatBubbleTime(message.timestamp),
                );
              }).toList(),
            );
          },
        ),
      ),
      bottomSheet: _composer(context),
    );
  }

  Widget _bubble({
    required String text,
    required bool incoming,
    required String time,
  }) {
    final Color bubbleColor = incoming ? Colors.white : _electricBlue;
    final Color textColor = incoming ? _ink : Colors.white;
    final Alignment alignment = incoming ? Alignment.centerLeft : Alignment.centerRight;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: incoming
              ? Border.all(color: const Color(0xFFD8ECFF))
              : null,
          boxShadow: incoming
              ? <BoxShadow>[BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]
              : <BoxShadow>[],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text,
              style: GoogleFonts.spaceGrotesk(color: textColor, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: GoogleFonts.spaceGrotesk(
                color: textColor.withOpacity(0.65),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type a message',
                hintStyle: GoogleFonts.spaceGrotesk(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              final String body = controller.text.trim();
              if (body.isEmpty) {
                return;
              }
              final int timestamp = DateTime.now().millisecondsSinceEpoch;
              await store.insertOutgoingMessage(
                address: thread.address,
                body: body,
                timestamp: timestamp,
                status: 'sending',
              );

              final bool sent = await captureService.sendSms(
                address: thread.address,
                body: body,
              );

              await store.insertOutgoingMessage(
                address: thread.address,
                body: body,
                timestamp: timestamp + 1,
                status: sent ? 'sent' : 'send_failed',
              );

              controller.clear();
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: _electricBlue,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBubbleTime(int epochMs) {
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
