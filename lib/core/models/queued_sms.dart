class QueuedSms {
  QueuedSms({
    required this.id,
    required this.sender,
    required this.messageBody,
    required this.amount,
    required this.transactionId,
    required this.reference,
    required this.transactionLocalTime,
    required this.transactionUtcTime,
    required this.fee,
    required this.balance,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.nextRetryAt,
    this.lastError,
  });

  final String id;
  final String sender;
  final String messageBody;
  final double amount;
  final String transactionId;
  final String reference;
  final String transactionLocalTime;
  final String transactionUtcTime;
  final double fee;
  final double balance;
  final String status;
  final int attemptCount;
  final int createdAt;
  final int updatedAt;
  final int? nextRetryAt;
  final String? lastError;

  bool get isDelivered => status == 'delivered';

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'sender': sender,
      'message_body': messageBody,
      'amount': amount,
      'transaction_id': transactionId,
      'reference': reference,
      'transaction_local_time': transactionLocalTime,
      'transaction_utc_time': transactionUtcTime,
      'fee': fee,
      'balance': balance,
      'status': status,
      'attempt_count': attemptCount,
      'next_retry_at': nextRetryAt,
      'last_error': lastError,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory QueuedSms.fromMap(Map<String, Object?> map) {
    return QueuedSms(
      id: map['id']! as String,
      sender: map['sender']! as String,
      messageBody: map['message_body']! as String,
      amount: (map['amount']! as num).toDouble(),
      transactionId: map['transaction_id']! as String,
      reference: map['reference']! as String,
      transactionLocalTime: map['transaction_local_time']! as String,
      transactionUtcTime: map['transaction_utc_time']! as String,
      fee: (map['fee']! as num).toDouble(),
      balance: (map['balance']! as num).toDouble(),
      status: map['status']! as String,
      attemptCount: map['attempt_count']! as int,
      nextRetryAt: map['next_retry_at'] as int?,
      lastError: map['last_error'] as String?,
      createdAt: map['created_at']! as int,
      updatedAt: map['updated_at']! as int,
    );
  }

  QueuedSms copyWith({
    String? status,
    int? attemptCount,
    int? nextRetryAt,
    String? lastError,
    int? updatedAt,
  }) {
    return QueuedSms(
      id: id,
      sender: sender,
      messageBody: messageBody,
      amount: amount,
      transactionId: transactionId,
      reference: reference,
      transactionLocalTime: transactionLocalTime,
      transactionUtcTime: transactionUtcTime,
      fee: fee,
      balance: balance,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
