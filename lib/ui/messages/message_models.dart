class MessageThreadPreview {
  MessageThreadPreview({
    required this.id,
    required this.title,
    required this.snippet,
    required this.timeLabel,
    required this.unreadCount,
  });

  final int id;
  final String title;
  final String snippet;
  final String timeLabel;
  final int unreadCount;
}

final List<MessageThreadPreview> demoThreads = <MessageThreadPreview>[
  MessageThreadPreview(
    id: 1,
    title: 'bKash · 01818882237',
    snippet: 'Received Tk 1.00 · TrxID DDSOLRNUG8 · Balance Tk 363.15',
    timeLabel: 'Just now',
    unreadCount: 1,
  ),
  MessageThreadPreview(
    id: 2,
    title: 'Rocket · 01700xxxxxx',
    snippet: 'Cash in Tk 500.00 · Ref Grocery · Bal Tk 8,250.50',
    timeLabel: '5m',
    unreadCount: 0,
  ),
  MessageThreadPreview(
    id: 3,
    title: 'DBBL · 017xx',
    snippet: 'Transaction alert · Tk 2,200.00 · Merchant POS 0453',
    timeLabel: '42m',
    unreadCount: 0,
  ),
];
