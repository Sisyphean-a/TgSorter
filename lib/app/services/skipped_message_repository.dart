import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/skipped_message_record.dart';

export 'package:tgsorter/app/models/skipped_message_record.dart';

class SkippedMessageRepository {
  SkippedMessageRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _skippedMessagesKey = 'skipped_messages_json';

  List<SkippedMessageRecord> loadSkippedMessages() {
    final encoded = _prefs.getString(_skippedMessagesKey);
    if (encoded == null || encoded.isEmpty) {
      return const <SkippedMessageRecord>[];
    }
    final raw = jsonDecode(encoded) as List<dynamic>;
    return raw
        .map(
          (item) => SkippedMessageRecord.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> saveSkippedMessages(List<SkippedMessageRecord> records) {
    final encoded = jsonEncode(
      records.map((item) => item.toJson()).toList(growable: false),
    );
    return _prefs.setString(_skippedMessagesKey, encoded);
  }

  Future<void> upsertSkippedMessage(SkippedMessageRecord record) async {
    final items = loadSkippedMessages().toList(growable: true);
    final index = items.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      items.add(record);
    } else {
      items[index] = record;
    }
    await saveSkippedMessages(items);
  }

  bool containsMessage({
    required SkippedMessageWorkflow workflow,
    required int sourceChatId,
    required Iterable<int> messageIds,
  }) {
    final targetIds = messageIds.toSet();
    return loadSkippedMessages().any(
      (item) =>
          item.workflow == workflow &&
          item.sourceChatId == sourceChatId &&
          item.messageIds.any(targetIds.contains),
    );
  }

  int countSkippedMessages({
    required SkippedMessageWorkflow workflow,
    int? sourceChatId,
  }) {
    return loadSkippedMessages().where((item) {
      return item.workflow == workflow &&
          (sourceChatId == null || item.sourceChatId == sourceChatId);
    }).length;
  }

  Future<int> restoreSkippedMessages({
    SkippedMessageWorkflow? workflow,
    int? sourceChatId,
  }) async {
    final current = loadSkippedMessages();
    final next = current.where((item) {
      if (workflow != null && item.workflow != workflow) {
        return true;
      }
      if (sourceChatId != null && item.sourceChatId != sourceChatId) {
        return true;
      }
      return false;
    }).toList(growable: false);
    await saveSkippedMessages(next);
    return current.length - next.length;
  }

  Future<void> clearAll() async {
    await _prefs.remove(_skippedMessagesKey);
  }
}

class NoopSkippedMessageRepository extends SkippedMessageRepository {
  NoopSkippedMessageRepository._() : super(_NoopPreferences.instance);

  static final NoopSkippedMessageRepository instance =
      NoopSkippedMessageRepository._();

  @override
  bool containsMessage({
    required SkippedMessageWorkflow workflow,
    required int sourceChatId,
    required Iterable<int> messageIds,
  }) {
    return false;
  }

  @override
  int countSkippedMessages({
    required SkippedMessageWorkflow workflow,
    int? sourceChatId,
  }) {
    return 0;
  }

  @override
  List<SkippedMessageRecord> loadSkippedMessages() {
    return const <SkippedMessageRecord>[];
  }

  @override
  Future<int> restoreSkippedMessages({
    SkippedMessageWorkflow? workflow,
    int? sourceChatId,
  }) async {
    return 0;
  }

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> saveSkippedMessages(List<SkippedMessageRecord> records) async {}

  @override
  Future<void> upsertSkippedMessage(SkippedMessageRecord record) async {}
}

class _NoopPreferences implements SharedPreferences {
  _NoopPreferences._();

  static final _NoopPreferences instance = _NoopPreferences._();

  @override
  Future<bool> clear() async => true;

  @override
  Future<bool> commit() async => true;

  @override
  bool containsKey(String key) => false;

  @override
  Object? get(String key) => null;

  @override
  bool? getBool(String key) => null;

  @override
  double? getDouble(String key) => null;

  @override
  int? getInt(String key) => null;

  @override
  Set<String> getKeys() => const <String>{};

  @override
  String? getString(String key) => null;

  @override
  List<String>? getStringList(String key) => null;

  @override
  Future<bool> reload() async => true;

  @override
  Future<bool> remove(String key) async => true;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> setDouble(String key, double value) async => true;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  Future<bool> setString(String key, String value) async => true;

  @override
  Future<bool> setStringList(String key, List<String> value) async => true;
}
