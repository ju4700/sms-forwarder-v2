import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/message_store.dart';
import '../../core/services/sms_capture_service.dart';
import '../../core/services/transaction_parser.dart';
import 'compose_screen.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.thread,
    required this.store,
    required this.captureService,
  });

  final MessageThread thread;
  final MessageStore store;
  final SmsCaptureService captureService;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _ink = Color(0xFF0B2B4B);
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  Future<void> _markRead() async {
    await widget.store.markThreadRead(widget.thread.id);
    await widget.captureService.markThreadRead(widget.thread.address);
  }

  Future<void> _deleteThread() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('All messages with ${widget.thread.address} will be permanently removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.store.deleteThread(widget.thread.id);
      await widget.captureService.deleteThread(widget.thread.address);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = (widget.thread.displayName ?? '').trim().isEmpty
        ? widget.thread.address
        : widget.thread.displayName!.trim();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                title.characters.first.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.thread.displayName != null &&
                      widget.thread.displayName!.isNotEmpty &&
                      widget.thread.displayName != widget.thread.address)
                    Text(
                      widget.thread.address,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<ComposeScreen>(
                  builder: (_) => ComposeScreen(
                    store: widget.store,
                    captureService: widget.captureService,
                    initialRecipient: widget.thread.address,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'New Message',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'delete') {
                _deleteThread();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Conversation', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
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
          stream: widget.store.watchMessagesForThread(widget.thread.id),
          builder: (BuildContext context, AsyncSnapshot<List<Message>> snapshot) {
            final List<Message> messages = snapshot.data ?? <Message>[];

            if (snapshot.hasData && _lastMessageCount != 0 && messages.length > _lastMessageCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _markRead();
                }
              });
            }
            _lastMessageCount = messages.length;

            if (messages.isEmpty) {
              return Center(
                child: Text(
                  'No messages in this thread yet.',
                  style: GoogleFonts.spaceGrotesk(color: _ink.withValues(alpha: 0.7)),
                ),
              );
            }

            final List<Message> displayMessages = messages.reversed.toList(growable: false);

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: displayMessages.length,
              itemBuilder: (BuildContext context, int index) {
                final Message message = displayMessages[index];
                // In reversed view, index 0 is at the bottom (newest message).
                // Chronologically previous (older) message is at index + 1:
                final Message? prevMessage =
                    index < displayMessages.length - 1 ? displayMessages[index + 1] : null;
                // Chronologically next (newer) message is at index - 1:
                final Message? nextMessage = index > 0 ? displayMessages[index - 1] : null;

                final bool showDateDivider = prevMessage == null ||
                    !_isSameDay(message.timestamp, prevMessage.timestamp);

                final bool isFirstInGroup = prevMessage == null ||
                    prevMessage.isIncoming != message.isIncoming ||
                    (message.timestamp - prevMessage.timestamp).abs() > 120000;

                final bool isLastInGroup = nextMessage == null ||
                    nextMessage.isIncoming != message.isIncoming ||
                    (nextMessage.timestamp - message.timestamp).abs() > 120000;

                return Column(
                  children: <Widget>[
                    if (showDateDivider) _buildDateDivider(message.timestamp),
                    _buildMessageBubble(
                      message: message,
                      isFirstInGroup: isFirstInGroup,
                      isLastInGroup: isLastInGroup,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomSheet: _ComposerWidget(
        thread: widget.thread,
        store: widget.store,
        captureService: widget.captureService,
      ),
    );
  }

  Widget _buildDateDivider(int epochMs) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCEBFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatDateHeader(epochMs),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _ink.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required Message message,
    required bool isFirstInGroup,
    required bool isLastInGroup,
  }) {
    final bool incoming = message.isIncoming;
    final Color bubbleColor = incoming ? Colors.white : _electricBlue;
    final Color textColor = incoming ? _ink : Colors.white;
    final Alignment alignment = incoming ? Alignment.centerLeft : Alignment.centerRight;

    final String? otp = _extractOtp(message.body);
    final String? trxId = _extractTrxId(message.body);

    final BorderRadius radius = incoming
        ? BorderRadius.only(
            topLeft: Radius.circular(isFirstInGroup ? 18 : 4),
            bottomLeft: Radius.circular(isLastInGroup ? 18 : 4),
            topRight: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          )
        : BorderRadius.only(
            topLeft: const Radius.circular(18),
            bottomLeft: const Radius.circular(18),
            topRight: Radius.circular(isFirstInGroup ? 18 : 4),
            bottomRight: Radius.circular(isLastInGroup ? 18 : 4),
          );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        margin: EdgeInsets.only(bottom: isLastInGroup ? 10 : 3),
        child: Column(
          crossAxisAlignment: incoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: radius,
                border: incoming ? Border.all(color: const Color(0xFFD8ECFF)) : null,
                boxShadow: incoming
                    ? <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]
                    : <BoxShadow>[],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectableText(
                    message.body,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    style: GoogleFonts.spaceGrotesk(
                      color: textColor,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _formatBubbleTime(message.timestamp),
                        style: GoogleFonts.spaceGrotesk(
                          color: textColor.withValues(alpha: 0.65),
                          fontSize: 10,
                        ),
                      ),
                      if (!incoming) ...<Widget>[
                        const SizedBox(width: 4),
                        if (message.status == 'sending')
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70),
                          )
                        else if (message.status == 'send_failed')
                          const Icon(Icons.error_outline, size: 12, color: Colors.redAccent)
                        else
                          const Icon(Icons.check, size: 12, color: Colors.white70),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (incoming && (otp != null || trxId != null)) ...<Widget>[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: <Widget>[
                  if (otp != null)
                    ActionChip(
                      avatar: const Icon(Icons.copy, size: 13, color: _electricBlue),
                      label: Text('Copy Code: $otp', style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFB7DFFF)),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: otp));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied code $otp')),
                        );
                      },
                    ),
                  if (trxId != null)
                    ActionChip(
                      avatar: const Icon(Icons.receipt_long, size: 13, color: _electricBlue),
                      label: Text('Copy TrxID: $trxId', style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFB7DFFF)),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: trxId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied TrxID $trxId')),
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _extractOtp(String body) {
    if (!TransactionParser.isSecurityOrOtp(body)) return null;
    final RegExp regex = RegExp(r'\b([0-9]{4,8})\b');
    return regex.firstMatch(body)?.group(1);
  }

  String? _extractTrxId(String body) {
    final RegExp regex = RegExp(
      r'(?:TrxID|TxnID|Txn\s*ID|Transaction\s*ID)[\s:]*([A-Z0-9]+)',
      caseSensitive: false,
    );
    return regex.firstMatch(body)?.group(1);
  }

  bool _isSameDay(int timeA, int timeB) {
    final DateTime a = DateTime.fromMillisecondsSinceEpoch(timeA);
    final DateTime b = DateTime.fromMillisecondsSinceEpoch(timeB);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(int epochMs) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final DateTime now = DateTime.now();
    if (_isSameDay(epochMs, now.millisecondsSinceEpoch)) {
      return 'Today';
    }
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(epochMs, yesterday.millisecondsSinceEpoch)) {
      return 'Yesterday';
    }
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatBubbleTime(int epochMs) {
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ComposerWidget extends StatefulWidget {
  const _ComposerWidget({
    required this.thread,
    required this.store,
    required this.captureService,
  });

  final MessageThread thread;
  final MessageStore store;
  final SmsCaptureService captureService;

  @override
  State<_ComposerWidget> createState() => _ComposerWidgetState();
}

class _ComposerWidgetState extends State<_ComposerWidget> {
  late final TextEditingController _controller;
  static const Color _electricBlue = Color(0xFF009BFF);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_syncTextState);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTextState);
    _controller.dispose();
    super.dispose();
  }

  void _syncTextState() {
    final bool next = _controller.text.trim().isNotEmpty;
    if (next != _hasText) {
      setState(() {
        _hasText = next;
      });
    }
  }

  Future<void> _send() async {
    final String body = _controller.text.trim();
    if (body.isEmpty) {
      return;
    }
    _controller.clear();

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final int messageId = await widget.store.insertOutgoingMessage(
      address: widget.thread.address,
      body: body,
      timestamp: timestamp,
      status: 'sending',
    );

    final bool sent = await widget.captureService.sendSms(
      address: widget.thread.address,
      body: body,
    );

    await widget.store.updateMessageStatus(
      messageId,
      sent ? 'sent' : 'send_failed',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6FB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD6E6F5)),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Text message',
                    hintStyle: GoogleFonts.spaceGrotesk(color: Colors.black45),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _hasText ? _send : null,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _hasText ? _electricBlue : const Color(0xFFCDE4F7),
                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
