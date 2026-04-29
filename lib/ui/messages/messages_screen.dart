import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_controller.dart';
import '../../core/services/message_store.dart';
import '../../core/services/sms_capture_service.dart';
import 'conversation_screen.dart';
import 'rules_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const Color _electricBlue = Color(0xFF009BFF);
  static const Color _ink = Color(0xFF0B2B4B);
  static const Color _cardBorder = Color(0xFFD8ECFF);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _buildHero(),
        const SizedBox(height: 16),
        _buildSearchBar(),
        const SizedBox(height: 12),
        _buildQuickFilters(),
        const SizedBox(height: 16),
        _buildThreadList(context),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFE9F6FF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _electricBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.message_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Conversations',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Default SMS inbox with smart capture rules.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: _ink.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<RulesScreen>(
                  builder: (_) => RulesScreen(controller: widget.controller),
                ),
              );
            },
            icon: const Icon(Icons.tune, color: _electricBlue),
            tooltip: 'Capture rules',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search sender, keyword, or TrxID',
        hintStyle: GoogleFonts.spaceGrotesk(
          color: _ink.withOpacity(0.55),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Row(
      children: <Widget>[
        _pill('All', true),
        const SizedBox(width: 8),
        _pill('Unread', false),
        const SizedBox(width: 8),
        _pill('Transactions', false),
      ],
    );
  }

  Widget _pill(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _electricBlue : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? _electricBlue : _cardBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _ink,
        ),
      ),
    );
  }

  Widget _buildThreadList(BuildContext context) {
    return StreamBuilder<List<MessageThread>>(
      stream: widget.controller.messageStore.watchThreads(),
      builder: (BuildContext context, AsyncSnapshot<List<MessageThread>> snapshot) {
        final List<MessageThread> threads = snapshot.data ?? <MessageThread>[];

        if (threads.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
              color: Colors.white,
            ),
            child: Text(
              'No messages yet. Set this app as default SMS and send a test message.',
              style: GoogleFonts.spaceGrotesk(color: _ink),
            ),
          );
        }

        return Column(
          children: threads.map((MessageThread thread) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (BuildContext context, double value, Widget? child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: _threadTile(context, thread),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _threadTile(BuildContext context, MessageThread thread) {
    final String title = (thread.displayName ?? '').trim().isEmpty
        ? thread.address
        : thread.displayName!.trim();
    final String snippet = (thread.lastSnippet ?? '').trim().isEmpty
        ? 'No preview yet'
        : thread.lastSnippet!.trim();
    final String timeLabel = _formatTimeLabel(thread.lastMessageAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        color: Colors.white,
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<ConversationScreen>(
              builder: (_) => ConversationScreen(
                thread: thread,
                store: widget.controller.messageStore,
                captureService: SmsCaptureService(),
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: _electricBlue.withOpacity(0.1),
          child: Text(
            title.characters.first,
            style: GoogleFonts.spaceGrotesk(
              color: _electricBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
            color: _ink,
          ),
        ),
        subtitle: Text(
          snippet,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12.5,
            color: _ink.withOpacity(0.7),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              timeLabel,
              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _ink.withOpacity(0.6)),
            ),
            const SizedBox(height: 6),
            if (thread.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _electricBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${thread.unreadCount}',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimeLabel(int epochMs) {
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final DateTime now = DateTime.now();
    if (now.difference(time).inHours < 24 && now.day == time.day) {
      final String hour = time.hour.toString().padLeft(2, '0');
      final String minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (now.year == time.year) {
      const List<String> months = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[time.month - 1]} ${time.day}';
    }
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}
