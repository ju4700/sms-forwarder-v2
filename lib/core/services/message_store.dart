import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'message_store.g.dart';

class MessageThreads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get address => text()();
  TextColumn get displayName => text().nullable()();
  IntColumn get lastMessageAt => integer()();
  TextColumn get lastSnippet => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

}

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get threadId => integer().references(MessageThreads, #id)();
  TextColumn get address => text()();
  TextColumn get body => text()();
  IntColumn get timestamp => integer()();
  BoolColumn get isIncoming => boolean()();
  TextColumn get status => text()();
  TextColumn get rawSms => text().nullable()();
  TextColumn get parsedJson => text().nullable()();
  TextColumn get apiEndpoint => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().nullable()();

}

class CaptureRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get senderPattern => text().nullable()();
  TextColumn get bodyPattern => text().nullable()();
  TextColumn get templateKey => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

@DriftDatabase(tables: <Type>[MessageThreads, Messages, CaptureRules])
class MessageStore extends _$MessageStore {
  MessageStore() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> ensureThread({
    required String address,
    String? displayName,
    required int lastMessageAt,
    String? lastSnippet,
  }) async {
    final MessageThread? existing = await (select(messageThreads)
          ..where((MessageThreads tbl) => tbl.address.equals(address)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(messageThreads)
            ..where((MessageThreads tbl) => tbl.id.equals(existing.id)))
          .write(MessageThreadsCompanion(
        displayName: Value<String?>(displayName ?? existing.displayName),
        lastMessageAt: Value<int>(lastMessageAt),
        lastSnippet: Value<String?>(lastSnippet ?? existing.lastSnippet),
      ));
      return existing.id;
    }

    return into(messageThreads).insert(MessageThreadsCompanion.insert(
      address: address,
      displayName: Value<String?>(displayName),
      lastMessageAt: lastMessageAt,
      lastSnippet: Value<String?>(lastSnippet),
    ));
  }

  Future<int> insertIncomingMessage({
    required String address,
    required String body,
    required int timestamp,
    String? rawSms,
    String? parsedJson,
    String status = 'received',
  }) async {
    final int threadId = await ensureThread(
      address: address,
      lastMessageAt: timestamp,
      lastSnippet: body.isEmpty ? null : body.substring(0, body.length.clamp(0, 120)),
    );

    return into(messages).insert(MessagesCompanion.insert(
      threadId: threadId,
      address: address,
      body: body,
      timestamp: timestamp,
      isIncoming: true,
      status: status,
      rawSms: Value<String?>(rawSms),
      parsedJson: Value<String?>(parsedJson),
      apiEndpoint: const Value<String?>(null),
      retryCount: const Value<int>(0),
      nextRetryAt: const Value<int?>(null),
    ));
  }

  Future<void> insertIncomingIfMissing({
    required String address,
    required String body,
    required int timestamp,
    required String status,
  }) async {
    final Message? existing = await (select(messages)
          ..where((Messages tbl) => tbl.address.equals(address))
          ..where((Messages tbl) => tbl.timestamp.equals(timestamp))
          ..where((Messages tbl) => tbl.body.equals(body)))
        .getSingleOrNull();

    if (existing != null) {
      if (existing.status != status) {
        await (update(messages)..where((Messages tbl) => tbl.id.equals(existing.id)))
            .write(MessagesCompanion(status: Value<String>(status)));
      }
      return;
    }

    await insertIncomingMessage(
      address: address,
      body: body,
      timestamp: timestamp,
      rawSms: body,
      parsedJson: null,
      status: status,
    );
  }

  Future<int> insertOutgoingMessage({
    required String address,
    required String body,
    required int timestamp,
    String status = 'local_only',
  }) async {
    final int threadId = await ensureThread(
      address: address,
      lastMessageAt: timestamp,
      lastSnippet: body.isEmpty ? null : body.substring(0, body.length.clamp(0, 120)),
    );

    return into(messages).insert(MessagesCompanion.insert(
      threadId: threadId,
      address: address,
      body: body,
      timestamp: timestamp,
      isIncoming: false,
      status: status,
      rawSms: const Value<String?>(null),
      parsedJson: const Value<String?>(null),
      apiEndpoint: const Value<String?>(null),
      retryCount: const Value<int>(0),
      nextRetryAt: const Value<int?>(null),
    ));
  }

  Stream<List<MessageThread>> watchThreads() {
    return (select(messageThreads)
          ..orderBy(<OrderingTerm Function(MessageThreads)>[
            (MessageThreads t) => OrderingTerm.desc(t.lastMessageAt),
          ]))
        .watch();
  }

  Stream<List<Message>> watchMessagesForThread(int threadId) {
    return (select(messages)
          ..where((Messages t) => t.threadId.equals(threadId))
          ..orderBy(<OrderingTerm Function(Messages)>[
            (Messages t) => OrderingTerm.asc(t.timestamp),
          ]))
        .watch();
  }

  Stream<List<CaptureRule>> watchRules() {
    return (select(captureRules)
          ..orderBy(<OrderingTerm Function(CaptureRules)>[
            (CaptureRules t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<int> insertRule({
    required String name,
    required String type,
    String? senderPattern,
    String? bodyPattern,
    String? templateKey,
    bool enabled = true,
    String? notes,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return into(captureRules).insert(CaptureRulesCompanion.insert(
      name: name,
      type: type,
      senderPattern: Value<String?>(senderPattern),
      bodyPattern: Value<String?>(bodyPattern),
      templateKey: Value<String?>(templateKey),
      enabled: Value<bool>(enabled),
      notes: Value<String?>(notes),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> updateRule({
    required int id,
    required String name,
    required String type,
    String? senderPattern,
    String? bodyPattern,
    String? templateKey,
    required bool enabled,
    String? notes,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await (update(captureRules)..where((CaptureRules t) => t.id.equals(id)))
        .write(CaptureRulesCompanion(
      name: Value<String>(name),
      type: Value<String>(type),
      senderPattern: Value<String?>(senderPattern),
      bodyPattern: Value<String?>(bodyPattern),
      templateKey: Value<String?>(templateKey),
      enabled: Value<bool>(enabled),
      notes: Value<String?>(notes),
      updatedAt: Value<int>(now),
    ));
  }

  Future<void> deleteRule(int id) async {
    await (delete(captureRules)..where((CaptureRules t) => t.id.equals(id))).go();
  }

  Future<String> exportRulesJson() async {
    final List<CaptureRule> rules = await select(captureRules).get();
    final List<Map<String, dynamic>> payload = rules.map((CaptureRule rule) {
      return <String, dynamic>{
        'id': rule.id,
        'name': rule.name,
        'type': rule.type,
        'senderPattern': rule.senderPattern,
        'bodyPattern': rule.bodyPattern,
        'templateKey': rule.templateKey,
        'enabled': rule.enabled,
      };
    }).toList(growable: false);

    return const JsonEncoder().convert(payload);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'sms_forwarder.db'));
    return NativeDatabase(file);
  });
}
