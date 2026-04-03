import 'dart:convert';

import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';

class OperationJournalRepository {
  OperationJournalRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _logsKey = 'operation_logs_json';
  static const _retryQueueKey = 'operation_retry_queue_json';
  static const _classifyTransactionsKey = 'classify_transactions_json';

  List<ClassifyOperationLog> loadLogs() {
    final encoded = _prefs.getString(_logsKey);
    if (encoded == null || encoded.isEmpty) {
      return const [];
    }
    final raw = jsonDecode(encoded) as List<dynamic>;
    return raw
        .map(
          (item) => ClassifyOperationLog.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> saveLogs(List<ClassifyOperationLog> logs) {
    final encoded = jsonEncode(
      logs.map((item) => item.toJson()).toList(growable: false),
    );
    return _prefs.setString(_logsKey, encoded);
  }

  List<RetryQueueItem> loadRetryQueue() {
    final encoded = _prefs.getString(_retryQueueKey);
    if (encoded == null || encoded.isEmpty) {
      return const [];
    }
    final raw = jsonDecode(encoded) as List<dynamic>;
    return raw
        .map((item) => RetryQueueItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveRetryQueue(List<RetryQueueItem> items) {
    final encoded = jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
    );
    return _prefs.setString(_retryQueueKey, encoded);
  }

  List<ClassifyTransactionEntry> loadClassifyTransactions() {
    final encoded = _prefs.getString(_classifyTransactionsKey);
    if (encoded == null || encoded.isEmpty) {
      return const [];
    }
    final raw = jsonDecode(encoded) as List<dynamic>;
    return raw
        .map(
          (item) =>
              ClassifyTransactionEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> saveClassifyTransactions(List<ClassifyTransactionEntry> items) {
    final encoded = jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
    );
    return _prefs.setString(_classifyTransactionsKey, encoded);
  }

  Future<void> upsertClassifyTransaction(ClassifyTransactionEntry entry) async {
    final items = loadClassifyTransactions().toList(growable: true);
    final index = items.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      items.add(entry);
    } else {
      items[index] = entry;
    }
    await saveClassifyTransactions(items);
  }

  Future<void> removeClassifyTransaction(String id) async {
    final next = loadClassifyTransactions()
        .where((item) => item.id != id)
        .toList(growable: false);
    await saveClassifyTransactions(next);
  }
}
