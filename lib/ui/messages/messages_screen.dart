import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_controller.dart';
import '../../core/services/message_store.dart';
import '../../core/services/transaction_parser.dart';
import 'compose_screen.dart';
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

  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: <Widget>[
          _buildHero(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildQuickFilters(),
          const SizedBox(height: 16),
          _buildThreadList(context),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _electricBlue,
        foregroundColor: Colors.white,
        tooltip: 'New Message',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ComposeScreen(
                store: widget.controller.messageStore,
                captureService: widget.controller.smsCaptureService,
              ),
            ),
          );
        },
        child: const Icon(Icons.edit_outlined),
      ),
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
            child: const Icon(Icons.forum_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Messages',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Smart categories & forwarding active.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: _ink.withValues(alpha: 0.7),
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
            tooltip: 'Forwarding rules',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: _electricBlue),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          hintText: 'Search sender, keyword, or TrxID',
          hintStyle: GoogleFonts.spaceGrotesk(
            color: _ink.withValues(alpha: 0.45),
            fontSize: 13.5,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _pill('All', 'all'),
          const SizedBox(width: 8),
          _pill('Personal', 'personal'),
          const SizedBox(width: 8),
          _pill('Transactions', 'transactions'),
          const SizedBox(width: 8),
          _pill('OTPs', 'otp'),
          const SizedBox(width: 8),
          _pill('Offers', 'offers'),
        ],
      ),
    );
  }

  Widget _pill(String label, String key) {
    final bool selected = _selectedCategory == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _electricBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _electricBlue : _cardBorder),
          boxShadow: <BoxShadow>[
            if (selected)
              BoxShadow(
                color: _electricBlue.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }

  bool _matchesCategory(MessageThread thread) {
    final String snippet = thread.lastSnippet ?? '';
    final String address = thread.address;

    switch (_selectedCategory) {
      case 'personal':
        final String cleanAddress = address.replaceAll(RegExp(r'[\s-]'), '');
        final bool isPhone = RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleanAddress);
        final bool isShortCode = address == '16247' || address == '16167' || address == '16216';
        final bool isTrx = TransactionParser.detectProvider(address, snippet) != 'generic' ||
            snippet.toLowerCase().contains('trxid') ||
            snippet.toLowerCase().contains('txnid');
        return isPhone && !isShortCode && !isTrx && !TransactionParser.isSecurityOrOtp(snippet);

      case 'transactions':
        return TransactionParser.detectProvider(address, snippet) != 'generic' ||
            snippet.toLowerCase().contains('trxid') ||
            snippet.toLowerCase().contains('txnid') ||
            snippet.toLowerCase().contains('credited') ||
            snippet.toLowerCase().contains('debited');

      case 'otp':
        return TransactionParser.isSecurityOrOtp(snippet);

      case 'offers':
        return TransactionParser.isPromotionalOrSpam(snippet);

      case 'all':
      default:
        return true;
    }
  }

  bool _matchesSearch(MessageThread thread) {
    if (_searchQuery.isEmpty) return true;
    final String address = thread.address.toLowerCase();
    final String name = (thread.displayName ?? '').toLowerCase();
    final String snippet = (thread.lastSnippet ?? '').toLowerCase();
    return address.contains(_searchQuery) ||
        name.contains(_searchQuery) ||
        snippet.contains(_searchQuery);
  }

  Widget _buildThreadList(BuildContext context) {
    return StreamBuilder<List<MessageThread>>(
      stream: widget.controller.messageStore.watchThreads(),
      builder: (BuildContext context, AsyncSnapshot<List<MessageThread>> snapshot) {
        final List<MessageThread> allThreads = snapshot.data ?? <MessageThread>[];
        final List<MessageThread> filtered = allThreads
            .where(_matchesCategory)
            .where(_matchesSearch)
            .toList(growable: false);

        if (filtered.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
              color: Colors.white,
            ),
            child: Column(
              children: <Widget>[
                Icon(Icons.inbox_outlined, size: 40, color: _ink.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No conversations matching "$_searchQuery"'
                      : _selectedCategory != 'all'
                          ? 'No messages in this category'
                          : 'No conversations yet. Messages will appear here.',
                  style: GoogleFonts.spaceGrotesk(
                    color: _ink.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: filtered.map((MessageThread thread) {
            return Dismissible(
              key: ValueKey<int>(thread.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    title: const Text('Delete conversation?'),
                    content: Text('Delete conversation with ${thread.address}?'),
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
              },
              onDismissed: (_) async {
                await widget.controller.messageStore.deleteThread(thread.id);
                await widget.controller.smsCaptureService.deleteThread(thread.address);
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
    final Color avatarColor = _avatarColorFor(thread.address);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: thread.unreadCount > 0 ? _electricBlue.withValues(alpha: 0.4) : _cardBorder,
        ),
        color: thread.unreadCount > 0 ? const Color(0xFFF9FCFF) : Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<ConversationScreen>(
              builder: (_) => ConversationScreen(
                thread: thread,
                store: widget.controller.messageStore,
                captureService: widget.controller.smsCaptureService,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: avatarColor.withValues(alpha: 0.15),
          child: Text(
            title.characters.first.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              color: avatarColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                  color: _ink,
                  fontSize: 14.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              timeLabel,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: thread.unreadCount > 0 ? _electricBlue : _ink.withValues(alpha: 0.55),
                fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  snippet,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12.5,
                    color: thread.unreadCount > 0 ? _ink : _ink.withValues(alpha: 0.65),
                    fontWeight: thread.unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (thread.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
      ),
    );
  }

  Color _avatarColorFor(String address) {
    final String lower = address.toLowerCase();
    if (lower.contains('bkash')) return const Color(0xFFE2136E);
    if (lower.contains('nagad')) return const Color(0xFFF7941D);
    if (lower.contains('rocket') || lower.contains('dbbl')) return const Color(0xFF8C3494);
    if (lower.contains('bank') || lower.contains('city') || lower.contains('brac')) return const Color(0xFF005BAC);

    const List<Color> palette = <Color>[
      Color(0xFF009BFF),
      Color(0xFF00B074),
      Color(0xFF5856D6),
      Color(0xFFFF9500),
      Color(0xFFFF2D55),
      Color(0xFF34AADC),
      Color(0xFF4CD964),
    ];
    return palette[address.hashCode.abs() % palette.length];
  }

  String _formatTimeLabel(int epochMs) {
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final DateTime now = DateTime.now();
    if (now.difference(time).inHours < 24 && now.day == time.day) {
      final String hour = time.hour.toString().padLeft(2, '0');
      final String minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == time.year && yesterday.month == time.month && yesterday.day == time.day) {
      return 'Yesterday';
    }
    if (now.year == time.year) {
      const List<String> months = <String>[
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[time.month - 1]} ${time.day}';
    }
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}
