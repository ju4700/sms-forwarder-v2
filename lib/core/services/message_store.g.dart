// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_store.dart';

// ignore_for_file: type=lint
class $MessageThreadsTable extends MessageThreads
    with TableInfo<$MessageThreadsTable, MessageThread> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageThreadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<int> lastMessageAt = GeneratedColumn<int>(
    'last_message_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSnippetMeta = const VerificationMeta(
    'lastSnippet',
  );
  @override
  late final GeneratedColumn<String> lastSnippet = GeneratedColumn<String>(
    'last_snippet',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    address,
    displayName,
    lastMessageAt,
    lastSnippet,
    unreadCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_threads';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageThread> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastMessageAtMeta);
    }
    if (data.containsKey('last_snippet')) {
      context.handle(
        _lastSnippetMeta,
        lastSnippet.isAcceptableOrUnknown(
          data['last_snippet']!,
          _lastSnippetMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageThread map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageThread(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_at'],
      )!,
      lastSnippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_snippet'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
    );
  }

  @override
  $MessageThreadsTable createAlias(String alias) {
    return $MessageThreadsTable(attachedDatabase, alias);
  }
}

class MessageThread extends DataClass implements Insertable<MessageThread> {
  final int id;
  final String address;
  final String? displayName;
  final int lastMessageAt;
  final String? lastSnippet;
  final int unreadCount;
  const MessageThread({
    required this.id,
    required this.address,
    this.displayName,
    required this.lastMessageAt,
    this.lastSnippet,
    required this.unreadCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['last_message_at'] = Variable<int>(lastMessageAt);
    if (!nullToAbsent || lastSnippet != null) {
      map['last_snippet'] = Variable<String>(lastSnippet);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    return map;
  }

  MessageThreadsCompanion toCompanion(bool nullToAbsent) {
    return MessageThreadsCompanion(
      id: Value(id),
      address: Value(address),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      lastMessageAt: Value(lastMessageAt),
      lastSnippet: lastSnippet == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSnippet),
      unreadCount: Value(unreadCount),
    );
  }

  factory MessageThread.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageThread(
      id: serializer.fromJson<int>(json['id']),
      address: serializer.fromJson<String>(json['address']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      lastMessageAt: serializer.fromJson<int>(json['lastMessageAt']),
      lastSnippet: serializer.fromJson<String?>(json['lastSnippet']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'address': serializer.toJson<String>(address),
      'displayName': serializer.toJson<String?>(displayName),
      'lastMessageAt': serializer.toJson<int>(lastMessageAt),
      'lastSnippet': serializer.toJson<String?>(lastSnippet),
      'unreadCount': serializer.toJson<int>(unreadCount),
    };
  }

  MessageThread copyWith({
    int? id,
    String? address,
    Value<String?> displayName = const Value.absent(),
    int? lastMessageAt,
    Value<String?> lastSnippet = const Value.absent(),
    int? unreadCount,
  }) => MessageThread(
    id: id ?? this.id,
    address: address ?? this.address,
    displayName: displayName.present ? displayName.value : this.displayName,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    lastSnippet: lastSnippet.present ? lastSnippet.value : this.lastSnippet,
    unreadCount: unreadCount ?? this.unreadCount,
  );
  MessageThread copyWithCompanion(MessageThreadsCompanion data) {
    return MessageThread(
      id: data.id.present ? data.id.value : this.id,
      address: data.address.present ? data.address.value : this.address,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      lastSnippet: data.lastSnippet.present
          ? data.lastSnippet.value
          : this.lastSnippet,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageThread(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('displayName: $displayName, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastSnippet: $lastSnippet, ')
          ..write('unreadCount: $unreadCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    address,
    displayName,
    lastMessageAt,
    lastSnippet,
    unreadCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageThread &&
          other.id == this.id &&
          other.address == this.address &&
          other.displayName == this.displayName &&
          other.lastMessageAt == this.lastMessageAt &&
          other.lastSnippet == this.lastSnippet &&
          other.unreadCount == this.unreadCount);
}

class MessageThreadsCompanion extends UpdateCompanion<MessageThread> {
  final Value<int> id;
  final Value<String> address;
  final Value<String?> displayName;
  final Value<int> lastMessageAt;
  final Value<String?> lastSnippet;
  final Value<int> unreadCount;
  const MessageThreadsCompanion({
    this.id = const Value.absent(),
    this.address = const Value.absent(),
    this.displayName = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastSnippet = const Value.absent(),
    this.unreadCount = const Value.absent(),
  });
  MessageThreadsCompanion.insert({
    this.id = const Value.absent(),
    required String address,
    this.displayName = const Value.absent(),
    required int lastMessageAt,
    this.lastSnippet = const Value.absent(),
    this.unreadCount = const Value.absent(),
  }) : address = Value(address),
       lastMessageAt = Value(lastMessageAt);
  static Insertable<MessageThread> custom({
    Expression<int>? id,
    Expression<String>? address,
    Expression<String>? displayName,
    Expression<int>? lastMessageAt,
    Expression<String>? lastSnippet,
    Expression<int>? unreadCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (address != null) 'address': address,
      if (displayName != null) 'display_name': displayName,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (lastSnippet != null) 'last_snippet': lastSnippet,
      if (unreadCount != null) 'unread_count': unreadCount,
    });
  }

  MessageThreadsCompanion copyWith({
    Value<int>? id,
    Value<String>? address,
    Value<String?>? displayName,
    Value<int>? lastMessageAt,
    Value<String?>? lastSnippet,
    Value<int>? unreadCount,
  }) {
    return MessageThreadsCompanion(
      id: id ?? this.id,
      address: address ?? this.address,
      displayName: displayName ?? this.displayName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastSnippet: lastSnippet ?? this.lastSnippet,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<int>(lastMessageAt.value);
    }
    if (lastSnippet.present) {
      map['last_snippet'] = Variable<String>(lastSnippet.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageThreadsCompanion(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('displayName: $displayName, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastSnippet: $lastSnippet, ')
          ..write('unreadCount: $unreadCount')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<int> threadId = GeneratedColumn<int>(
    'thread_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES message_threads (id)',
    ),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isIncomingMeta = const VerificationMeta(
    'isIncoming',
  );
  @override
  late final GeneratedColumn<bool> isIncoming = GeneratedColumn<bool>(
    'is_incoming',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_incoming" IN (0, 1))',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawSmsMeta = const VerificationMeta('rawSms');
  @override
  late final GeneratedColumn<String> rawSms = GeneratedColumn<String>(
    'raw_sms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parsedJsonMeta = const VerificationMeta(
    'parsedJson',
  );
  @override
  late final GeneratedColumn<String> parsedJson = GeneratedColumn<String>(
    'parsed_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apiEndpointMeta = const VerificationMeta(
    'apiEndpoint',
  );
  @override
  late final GeneratedColumn<String> apiEndpoint = GeneratedColumn<String>(
    'api_endpoint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    threadId,
    address,
    body,
    timestamp,
    isIncoming,
    status,
    rawSms,
    parsedJson,
    apiEndpoint,
    retryCount,
    nextRetryAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_incoming')) {
      context.handle(
        _isIncomingMeta,
        isIncoming.isAcceptableOrUnknown(data['is_incoming']!, _isIncomingMeta),
      );
    } else if (isInserting) {
      context.missing(_isIncomingMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('raw_sms')) {
      context.handle(
        _rawSmsMeta,
        rawSms.isAcceptableOrUnknown(data['raw_sms']!, _rawSmsMeta),
      );
    }
    if (data.containsKey('parsed_json')) {
      context.handle(
        _parsedJsonMeta,
        parsedJson.isAcceptableOrUnknown(data['parsed_json']!, _parsedJsonMeta),
      );
    }
    if (data.containsKey('api_endpoint')) {
      context.handle(
        _apiEndpointMeta,
        apiEndpoint.isAcceptableOrUnknown(
          data['api_endpoint']!,
          _apiEndpointMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thread_id'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      isIncoming: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_incoming'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rawSms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_sms'],
      ),
      parsedJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parsed_json'],
      ),
      apiEndpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_endpoint'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final int threadId;
  final String address;
  final String body;
  final int timestamp;
  final bool isIncoming;
  final String status;
  final String? rawSms;
  final String? parsedJson;
  final String? apiEndpoint;
  final int retryCount;
  final int? nextRetryAt;
  const Message({
    required this.id,
    required this.threadId,
    required this.address,
    required this.body,
    required this.timestamp,
    required this.isIncoming,
    required this.status,
    this.rawSms,
    this.parsedJson,
    this.apiEndpoint,
    required this.retryCount,
    this.nextRetryAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['thread_id'] = Variable<int>(threadId);
    map['address'] = Variable<String>(address);
    map['body'] = Variable<String>(body);
    map['timestamp'] = Variable<int>(timestamp);
    map['is_incoming'] = Variable<bool>(isIncoming);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || rawSms != null) {
      map['raw_sms'] = Variable<String>(rawSms);
    }
    if (!nullToAbsent || parsedJson != null) {
      map['parsed_json'] = Variable<String>(parsedJson);
    }
    if (!nullToAbsent || apiEndpoint != null) {
      map['api_endpoint'] = Variable<String>(apiEndpoint);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<int>(nextRetryAt);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      threadId: Value(threadId),
      address: Value(address),
      body: Value(body),
      timestamp: Value(timestamp),
      isIncoming: Value(isIncoming),
      status: Value(status),
      rawSms: rawSms == null && nullToAbsent
          ? const Value.absent()
          : Value(rawSms),
      parsedJson: parsedJson == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedJson),
      apiEndpoint: apiEndpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(apiEndpoint),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      threadId: serializer.fromJson<int>(json['threadId']),
      address: serializer.fromJson<String>(json['address']),
      body: serializer.fromJson<String>(json['body']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      isIncoming: serializer.fromJson<bool>(json['isIncoming']),
      status: serializer.fromJson<String>(json['status']),
      rawSms: serializer.fromJson<String?>(json['rawSms']),
      parsedJson: serializer.fromJson<String?>(json['parsedJson']),
      apiEndpoint: serializer.fromJson<String?>(json['apiEndpoint']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<int?>(json['nextRetryAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'threadId': serializer.toJson<int>(threadId),
      'address': serializer.toJson<String>(address),
      'body': serializer.toJson<String>(body),
      'timestamp': serializer.toJson<int>(timestamp),
      'isIncoming': serializer.toJson<bool>(isIncoming),
      'status': serializer.toJson<String>(status),
      'rawSms': serializer.toJson<String?>(rawSms),
      'parsedJson': serializer.toJson<String?>(parsedJson),
      'apiEndpoint': serializer.toJson<String?>(apiEndpoint),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<int?>(nextRetryAt),
    };
  }

  Message copyWith({
    int? id,
    int? threadId,
    String? address,
    String? body,
    int? timestamp,
    bool? isIncoming,
    String? status,
    Value<String?> rawSms = const Value.absent(),
    Value<String?> parsedJson = const Value.absent(),
    Value<String?> apiEndpoint = const Value.absent(),
    int? retryCount,
    Value<int?> nextRetryAt = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    address: address ?? this.address,
    body: body ?? this.body,
    timestamp: timestamp ?? this.timestamp,
    isIncoming: isIncoming ?? this.isIncoming,
    status: status ?? this.status,
    rawSms: rawSms.present ? rawSms.value : this.rawSms,
    parsedJson: parsedJson.present ? parsedJson.value : this.parsedJson,
    apiEndpoint: apiEndpoint.present ? apiEndpoint.value : this.apiEndpoint,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      address: data.address.present ? data.address.value : this.address,
      body: data.body.present ? data.body.value : this.body,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isIncoming: data.isIncoming.present
          ? data.isIncoming.value
          : this.isIncoming,
      status: data.status.present ? data.status.value : this.status,
      rawSms: data.rawSms.present ? data.rawSms.value : this.rawSms,
      parsedJson: data.parsedJson.present
          ? data.parsedJson.value
          : this.parsedJson,
      apiEndpoint: data.apiEndpoint.present
          ? data.apiEndpoint.value
          : this.apiEndpoint,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('address: $address, ')
          ..write('body: $body, ')
          ..write('timestamp: $timestamp, ')
          ..write('isIncoming: $isIncoming, ')
          ..write('status: $status, ')
          ..write('rawSms: $rawSms, ')
          ..write('parsedJson: $parsedJson, ')
          ..write('apiEndpoint: $apiEndpoint, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    threadId,
    address,
    body,
    timestamp,
    isIncoming,
    status,
    rawSms,
    parsedJson,
    apiEndpoint,
    retryCount,
    nextRetryAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.threadId == this.threadId &&
          other.address == this.address &&
          other.body == this.body &&
          other.timestamp == this.timestamp &&
          other.isIncoming == this.isIncoming &&
          other.status == this.status &&
          other.rawSms == this.rawSms &&
          other.parsedJson == this.parsedJson &&
          other.apiEndpoint == this.apiEndpoint &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<int> threadId;
  final Value<String> address;
  final Value<String> body;
  final Value<int> timestamp;
  final Value<bool> isIncoming;
  final Value<String> status;
  final Value<String?> rawSms;
  final Value<String?> parsedJson;
  final Value<String?> apiEndpoint;
  final Value<int> retryCount;
  final Value<int?> nextRetryAt;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.threadId = const Value.absent(),
    this.address = const Value.absent(),
    this.body = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isIncoming = const Value.absent(),
    this.status = const Value.absent(),
    this.rawSms = const Value.absent(),
    this.parsedJson = const Value.absent(),
    this.apiEndpoint = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int threadId,
    required String address,
    required String body,
    required int timestamp,
    required bool isIncoming,
    required String status,
    this.rawSms = const Value.absent(),
    this.parsedJson = const Value.absent(),
    this.apiEndpoint = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
  }) : threadId = Value(threadId),
       address = Value(address),
       body = Value(body),
       timestamp = Value(timestamp),
       isIncoming = Value(isIncoming),
       status = Value(status);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<int>? threadId,
    Expression<String>? address,
    Expression<String>? body,
    Expression<int>? timestamp,
    Expression<bool>? isIncoming,
    Expression<String>? status,
    Expression<String>? rawSms,
    Expression<String>? parsedJson,
    Expression<String>? apiEndpoint,
    Expression<int>? retryCount,
    Expression<int>? nextRetryAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (threadId != null) 'thread_id': threadId,
      if (address != null) 'address': address,
      if (body != null) 'body': body,
      if (timestamp != null) 'timestamp': timestamp,
      if (isIncoming != null) 'is_incoming': isIncoming,
      if (status != null) 'status': status,
      if (rawSms != null) 'raw_sms': rawSms,
      if (parsedJson != null) 'parsed_json': parsedJson,
      if (apiEndpoint != null) 'api_endpoint': apiEndpoint,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? threadId,
    Value<String>? address,
    Value<String>? body,
    Value<int>? timestamp,
    Value<bool>? isIncoming,
    Value<String>? status,
    Value<String?>? rawSms,
    Value<String?>? parsedJson,
    Value<String?>? apiEndpoint,
    Value<int>? retryCount,
    Value<int?>? nextRetryAt,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      address: address ?? this.address,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isIncoming: isIncoming ?? this.isIncoming,
      status: status ?? this.status,
      rawSms: rawSms ?? this.rawSms,
      parsedJson: parsedJson ?? this.parsedJson,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<int>(threadId.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (isIncoming.present) {
      map['is_incoming'] = Variable<bool>(isIncoming.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rawSms.present) {
      map['raw_sms'] = Variable<String>(rawSms.value);
    }
    if (parsedJson.present) {
      map['parsed_json'] = Variable<String>(parsedJson.value);
    }
    if (apiEndpoint.present) {
      map['api_endpoint'] = Variable<String>(apiEndpoint.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('address: $address, ')
          ..write('body: $body, ')
          ..write('timestamp: $timestamp, ')
          ..write('isIncoming: $isIncoming, ')
          ..write('status: $status, ')
          ..write('rawSms: $rawSms, ')
          ..write('parsedJson: $parsedJson, ')
          ..write('apiEndpoint: $apiEndpoint, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt')
          ..write(')'))
        .toString();
  }
}

class $CaptureRulesTable extends CaptureRules
    with TableInfo<$CaptureRulesTable, CaptureRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderPatternMeta = const VerificationMeta(
    'senderPattern',
  );
  @override
  late final GeneratedColumn<String> senderPattern = GeneratedColumn<String>(
    'sender_pattern',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyPatternMeta = const VerificationMeta(
    'bodyPattern',
  );
  @override
  late final GeneratedColumn<String> bodyPattern = GeneratedColumn<String>(
    'body_pattern',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateKeyMeta = const VerificationMeta(
    'templateKey',
  );
  @override
  late final GeneratedColumn<String> templateKey = GeneratedColumn<String>(
    'template_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    senderPattern,
    bodyPattern,
    templateKey,
    enabled,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaptureRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('sender_pattern')) {
      context.handle(
        _senderPatternMeta,
        senderPattern.isAcceptableOrUnknown(
          data['sender_pattern']!,
          _senderPatternMeta,
        ),
      );
    }
    if (data.containsKey('body_pattern')) {
      context.handle(
        _bodyPatternMeta,
        bodyPattern.isAcceptableOrUnknown(
          data['body_pattern']!,
          _bodyPatternMeta,
        ),
      );
    }
    if (data.containsKey('template_key')) {
      context.handle(
        _templateKeyMeta,
        templateKey.isAcceptableOrUnknown(
          data['template_key']!,
          _templateKeyMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaptureRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      senderPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_pattern'],
      ),
      bodyPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_pattern'],
      ),
      templateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_key'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CaptureRulesTable createAlias(String alias) {
    return $CaptureRulesTable(attachedDatabase, alias);
  }
}

class CaptureRule extends DataClass implements Insertable<CaptureRule> {
  final int id;
  final String name;
  final String type;
  final String? senderPattern;
  final String? bodyPattern;
  final String? templateKey;
  final bool enabled;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  const CaptureRule({
    required this.id,
    required this.name,
    required this.type,
    this.senderPattern,
    this.bodyPattern,
    this.templateKey,
    required this.enabled,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || senderPattern != null) {
      map['sender_pattern'] = Variable<String>(senderPattern);
    }
    if (!nullToAbsent || bodyPattern != null) {
      map['body_pattern'] = Variable<String>(bodyPattern);
    }
    if (!nullToAbsent || templateKey != null) {
      map['template_key'] = Variable<String>(templateKey);
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CaptureRulesCompanion toCompanion(bool nullToAbsent) {
    return CaptureRulesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      senderPattern: senderPattern == null && nullToAbsent
          ? const Value.absent()
          : Value(senderPattern),
      bodyPattern: bodyPattern == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyPattern),
      templateKey: templateKey == null && nullToAbsent
          ? const Value.absent()
          : Value(templateKey),
      enabled: Value(enabled),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CaptureRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureRule(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      senderPattern: serializer.fromJson<String?>(json['senderPattern']),
      bodyPattern: serializer.fromJson<String?>(json['bodyPattern']),
      templateKey: serializer.fromJson<String?>(json['templateKey']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'senderPattern': serializer.toJson<String?>(senderPattern),
      'bodyPattern': serializer.toJson<String?>(bodyPattern),
      'templateKey': serializer.toJson<String?>(templateKey),
      'enabled': serializer.toJson<bool>(enabled),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CaptureRule copyWith({
    int? id,
    String? name,
    String? type,
    Value<String?> senderPattern = const Value.absent(),
    Value<String?> bodyPattern = const Value.absent(),
    Value<String?> templateKey = const Value.absent(),
    bool? enabled,
    Value<String?> notes = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => CaptureRule(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    senderPattern: senderPattern.present
        ? senderPattern.value
        : this.senderPattern,
    bodyPattern: bodyPattern.present ? bodyPattern.value : this.bodyPattern,
    templateKey: templateKey.present ? templateKey.value : this.templateKey,
    enabled: enabled ?? this.enabled,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CaptureRule copyWithCompanion(CaptureRulesCompanion data) {
    return CaptureRule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      senderPattern: data.senderPattern.present
          ? data.senderPattern.value
          : this.senderPattern,
      bodyPattern: data.bodyPattern.present
          ? data.bodyPattern.value
          : this.bodyPattern,
      templateKey: data.templateKey.present
          ? data.templateKey.value
          : this.templateKey,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaptureRule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('senderPattern: $senderPattern, ')
          ..write('bodyPattern: $bodyPattern, ')
          ..write('templateKey: $templateKey, ')
          ..write('enabled: $enabled, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    senderPattern,
    bodyPattern,
    templateKey,
    enabled,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureRule &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.senderPattern == this.senderPattern &&
          other.bodyPattern == this.bodyPattern &&
          other.templateKey == this.templateKey &&
          other.enabled == this.enabled &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CaptureRulesCompanion extends UpdateCompanion<CaptureRule> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> senderPattern;
  final Value<String?> bodyPattern;
  final Value<String?> templateKey;
  final Value<bool> enabled;
  final Value<String?> notes;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const CaptureRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.senderPattern = const Value.absent(),
    this.bodyPattern = const Value.absent(),
    this.templateKey = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CaptureRulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    this.senderPattern = const Value.absent(),
    this.bodyPattern = const Value.absent(),
    this.templateKey = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notes = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : name = Value(name),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CaptureRule> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? senderPattern,
    Expression<String>? bodyPattern,
    Expression<String>? templateKey,
    Expression<bool>? enabled,
    Expression<String>? notes,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (senderPattern != null) 'sender_pattern': senderPattern,
      if (bodyPattern != null) 'body_pattern': bodyPattern,
      if (templateKey != null) 'template_key': templateKey,
      if (enabled != null) 'enabled': enabled,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CaptureRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? senderPattern,
    Value<String?>? bodyPattern,
    Value<String?>? templateKey,
    Value<bool>? enabled,
    Value<String?>? notes,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return CaptureRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      senderPattern: senderPattern ?? this.senderPattern,
      bodyPattern: bodyPattern ?? this.bodyPattern,
      templateKey: templateKey ?? this.templateKey,
      enabled: enabled ?? this.enabled,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (senderPattern.present) {
      map['sender_pattern'] = Variable<String>(senderPattern.value);
    }
    if (bodyPattern.present) {
      map['body_pattern'] = Variable<String>(bodyPattern.value);
    }
    if (templateKey.present) {
      map['template_key'] = Variable<String>(templateKey.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaptureRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('senderPattern: $senderPattern, ')
          ..write('bodyPattern: $bodyPattern, ')
          ..write('templateKey: $templateKey, ')
          ..write('enabled: $enabled, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$MessageStore extends GeneratedDatabase {
  _$MessageStore(QueryExecutor e) : super(e);
  $MessageStoreManager get managers => $MessageStoreManager(this);
  late final $MessageThreadsTable messageThreads = $MessageThreadsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $CaptureRulesTable captureRules = $CaptureRulesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messageThreads,
    messages,
    captureRules,
  ];
}

typedef $$MessageThreadsTableCreateCompanionBuilder =
    MessageThreadsCompanion Function({
      Value<int> id,
      required String address,
      Value<String?> displayName,
      required int lastMessageAt,
      Value<String?> lastSnippet,
      Value<int> unreadCount,
    });
typedef $$MessageThreadsTableUpdateCompanionBuilder =
    MessageThreadsCompanion Function({
      Value<int> id,
      Value<String> address,
      Value<String?> displayName,
      Value<int> lastMessageAt,
      Value<String?> lastSnippet,
      Value<int> unreadCount,
    });

final class $$MessageThreadsTableReferences
    extends
        BaseReferences<_$MessageStore, $MessageThreadsTable, MessageThread> {
  $$MessageThreadsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$MessageStore db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: $_aliasNameGenerator(db.messageThreads.id, db.messages.threadId),
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.threadId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MessageThreadsTableFilterComposer
    extends Composer<_$MessageStore, $MessageThreadsTable> {
  $$MessageThreadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSnippet => $composableBuilder(
    column: $table.lastSnippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.threadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MessageThreadsTableOrderingComposer
    extends Composer<_$MessageStore, $MessageThreadsTable> {
  $$MessageThreadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSnippet => $composableBuilder(
    column: $table.lastSnippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageThreadsTableAnnotationComposer
    extends Composer<_$MessageStore, $MessageThreadsTable> {
  $$MessageThreadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSnippet => $composableBuilder(
    column: $table.lastSnippet,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.threadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MessageThreadsTableTableManager
    extends
        RootTableManager<
          _$MessageStore,
          $MessageThreadsTable,
          MessageThread,
          $$MessageThreadsTableFilterComposer,
          $$MessageThreadsTableOrderingComposer,
          $$MessageThreadsTableAnnotationComposer,
          $$MessageThreadsTableCreateCompanionBuilder,
          $$MessageThreadsTableUpdateCompanionBuilder,
          (MessageThread, $$MessageThreadsTableReferences),
          MessageThread,
          PrefetchHooks Function({bool messagesRefs})
        > {
  $$MessageThreadsTableTableManager(
    _$MessageStore db,
    $MessageThreadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageThreadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageThreadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageThreadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int> lastMessageAt = const Value.absent(),
                Value<String?> lastSnippet = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
              }) => MessageThreadsCompanion(
                id: id,
                address: address,
                displayName: displayName,
                lastMessageAt: lastMessageAt,
                lastSnippet: lastSnippet,
                unreadCount: unreadCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String address,
                Value<String?> displayName = const Value.absent(),
                required int lastMessageAt,
                Value<String?> lastSnippet = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
              }) => MessageThreadsCompanion.insert(
                id: id,
                address: address,
                displayName: displayName,
                lastMessageAt: lastMessageAt,
                lastSnippet: lastSnippet,
                unreadCount: unreadCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessageThreadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedData<
                      MessageThread,
                      $MessageThreadsTable,
                      Message
                    >(
                      currentTable: table,
                      referencedTable: $$MessageThreadsTableReferences
                          ._messagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MessageThreadsTableReferences(
                            db,
                            table,
                            p0,
                          ).messagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.threadId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MessageThreadsTableProcessedTableManager =
    ProcessedTableManager<
      _$MessageStore,
      $MessageThreadsTable,
      MessageThread,
      $$MessageThreadsTableFilterComposer,
      $$MessageThreadsTableOrderingComposer,
      $$MessageThreadsTableAnnotationComposer,
      $$MessageThreadsTableCreateCompanionBuilder,
      $$MessageThreadsTableUpdateCompanionBuilder,
      (MessageThread, $$MessageThreadsTableReferences),
      MessageThread,
      PrefetchHooks Function({bool messagesRefs})
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      required int threadId,
      required String address,
      required String body,
      required int timestamp,
      required bool isIncoming,
      required String status,
      Value<String?> rawSms,
      Value<String?> parsedJson,
      Value<String?> apiEndpoint,
      Value<int> retryCount,
      Value<int?> nextRetryAt,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      Value<int> threadId,
      Value<String> address,
      Value<String> body,
      Value<int> timestamp,
      Value<bool> isIncoming,
      Value<String> status,
      Value<String?> rawSms,
      Value<String?> parsedJson,
      Value<String?> apiEndpoint,
      Value<int> retryCount,
      Value<int?> nextRetryAt,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$MessageStore, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MessageThreadsTable _threadIdTable(_$MessageStore db) =>
      db.messageThreads.createAlias(
        $_aliasNameGenerator(db.messages.threadId, db.messageThreads.id),
      );

  $$MessageThreadsTableProcessedTableManager get threadId {
    final $_column = $_itemColumn<int>('thread_id')!;

    final manager = $$MessageThreadsTableTableManager(
      $_db,
      $_db.messageThreads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_threadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$MessageStore, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isIncoming => $composableBuilder(
    column: $table.isIncoming,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawSms => $composableBuilder(
    column: $table.rawSms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parsedJson => $composableBuilder(
    column: $table.parsedJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiEndpoint => $composableBuilder(
    column: $table.apiEndpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MessageThreadsTableFilterComposer get threadId {
    final $$MessageThreadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.messageThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageThreadsTableFilterComposer(
            $db: $db,
            $table: $db.messageThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$MessageStore, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isIncoming => $composableBuilder(
    column: $table.isIncoming,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawSms => $composableBuilder(
    column: $table.rawSms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parsedJson => $composableBuilder(
    column: $table.parsedJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiEndpoint => $composableBuilder(
    column: $table.apiEndpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessageThreadsTableOrderingComposer get threadId {
    final $$MessageThreadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.messageThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageThreadsTableOrderingComposer(
            $db: $db,
            $table: $db.messageThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$MessageStore, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isIncoming => $composableBuilder(
    column: $table.isIncoming,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get rawSms =>
      $composableBuilder(column: $table.rawSms, builder: (column) => column);

  GeneratedColumn<String> get parsedJson => $composableBuilder(
    column: $table.parsedJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get apiEndpoint => $composableBuilder(
    column: $table.apiEndpoint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  $$MessageThreadsTableAnnotationComposer get threadId {
    final $$MessageThreadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.threadId,
      referencedTable: $db.messageThreads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageThreadsTableAnnotationComposer(
            $db: $db,
            $table: $db.messageThreads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$MessageStore,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool threadId})
        > {
  $$MessagesTableTableManager(_$MessageStore db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> threadId = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<bool> isIncoming = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> rawSms = const Value.absent(),
                Value<String?> parsedJson = const Value.absent(),
                Value<String?> apiEndpoint = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                threadId: threadId,
                address: address,
                body: body,
                timestamp: timestamp,
                isIncoming: isIncoming,
                status: status,
                rawSms: rawSms,
                parsedJson: parsedJson,
                apiEndpoint: apiEndpoint,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int threadId,
                required String address,
                required String body,
                required int timestamp,
                required bool isIncoming,
                required String status,
                Value<String?> rawSms = const Value.absent(),
                Value<String?> parsedJson = const Value.absent(),
                Value<String?> apiEndpoint = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                threadId: threadId,
                address: address,
                body: body,
                timestamp: timestamp,
                isIncoming: isIncoming,
                status: status,
                rawSms: rawSms,
                parsedJson: parsedJson,
                apiEndpoint: apiEndpoint,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({threadId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (threadId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.threadId,
                                referencedTable: $$MessagesTableReferences
                                    ._threadIdTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._threadIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$MessageStore,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool threadId})
    >;
typedef $$CaptureRulesTableCreateCompanionBuilder =
    CaptureRulesCompanion Function({
      Value<int> id,
      required String name,
      required String type,
      Value<String?> senderPattern,
      Value<String?> bodyPattern,
      Value<String?> templateKey,
      Value<bool> enabled,
      Value<String?> notes,
      required int createdAt,
      required int updatedAt,
    });
typedef $$CaptureRulesTableUpdateCompanionBuilder =
    CaptureRulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String?> senderPattern,
      Value<String?> bodyPattern,
      Value<String?> templateKey,
      Value<bool> enabled,
      Value<String?> notes,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

class $$CaptureRulesTableFilterComposer
    extends Composer<_$MessageStore, $CaptureRulesTable> {
  $$CaptureRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPattern => $composableBuilder(
    column: $table.senderPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyPattern => $composableBuilder(
    column: $table.bodyPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaptureRulesTableOrderingComposer
    extends Composer<_$MessageStore, $CaptureRulesTable> {
  $$CaptureRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPattern => $composableBuilder(
    column: $table.senderPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyPattern => $composableBuilder(
    column: $table.bodyPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaptureRulesTableAnnotationComposer
    extends Composer<_$MessageStore, $CaptureRulesTable> {
  $$CaptureRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get senderPattern => $composableBuilder(
    column: $table.senderPattern,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyPattern => $composableBuilder(
    column: $table.bodyPattern,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CaptureRulesTableTableManager
    extends
        RootTableManager<
          _$MessageStore,
          $CaptureRulesTable,
          CaptureRule,
          $$CaptureRulesTableFilterComposer,
          $$CaptureRulesTableOrderingComposer,
          $$CaptureRulesTableAnnotationComposer,
          $$CaptureRulesTableCreateCompanionBuilder,
          $$CaptureRulesTableUpdateCompanionBuilder,
          (
            CaptureRule,
            BaseReferences<_$MessageStore, $CaptureRulesTable, CaptureRule>,
          ),
          CaptureRule,
          PrefetchHooks Function()
        > {
  $$CaptureRulesTableTableManager(_$MessageStore db, $CaptureRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaptureRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaptureRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaptureRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> senderPattern = const Value.absent(),
                Value<String?> bodyPattern = const Value.absent(),
                Value<String?> templateKey = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => CaptureRulesCompanion(
                id: id,
                name: name,
                type: type,
                senderPattern: senderPattern,
                bodyPattern: bodyPattern,
                templateKey: templateKey,
                enabled: enabled,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String type,
                Value<String?> senderPattern = const Value.absent(),
                Value<String?> bodyPattern = const Value.absent(),
                Value<String?> templateKey = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => CaptureRulesCompanion.insert(
                id: id,
                name: name,
                type: type,
                senderPattern: senderPattern,
                bodyPattern: bodyPattern,
                templateKey: templateKey,
                enabled: enabled,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CaptureRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$MessageStore,
      $CaptureRulesTable,
      CaptureRule,
      $$CaptureRulesTableFilterComposer,
      $$CaptureRulesTableOrderingComposer,
      $$CaptureRulesTableAnnotationComposer,
      $$CaptureRulesTableCreateCompanionBuilder,
      $$CaptureRulesTableUpdateCompanionBuilder,
      (
        CaptureRule,
        BaseReferences<_$MessageStore, $CaptureRulesTable, CaptureRule>,
      ),
      CaptureRule,
      PrefetchHooks Function()
    >;

class $MessageStoreManager {
  final _$MessageStore _db;
  $MessageStoreManager(this._db);
  $$MessageThreadsTableTableManager get messageThreads =>
      $$MessageThreadsTableTableManager(_db, _db.messageThreads);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$CaptureRulesTableTableManager get captureRules =>
      $$CaptureRulesTableTableManager(_db, _db.captureRules);
}
