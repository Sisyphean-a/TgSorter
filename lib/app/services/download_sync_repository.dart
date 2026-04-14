import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';

class DownloadSyncRecord {
  const DownloadSyncRecord({
    required this.id,
    required this.jobKey,
    required this.sourceChatId,
    required this.messageId,
    required this.kind,
    required this.outputPath,
    required this.updatedAtMs,
  });

  final String id;
  final String jobKey;
  final int sourceChatId;
  final int messageId;
  final MediaItemKind kind;
  final String outputPath;
  final int updatedAtMs;

  DownloadSyncRecord copyWith({
    String? id,
    String? jobKey,
    int? sourceChatId,
    int? messageId,
    MediaItemKind? kind,
    String? outputPath,
    int? updatedAtMs,
  }) {
    return DownloadSyncRecord(
      id: id ?? this.id,
      jobKey: jobKey ?? this.jobKey,
      sourceChatId: sourceChatId ?? this.sourceChatId,
      messageId: messageId ?? this.messageId,
      kind: kind ?? this.kind,
      outputPath: outputPath ?? this.outputPath,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_key': jobKey,
      'source_chat_id': sourceChatId,
      'message_id': messageId,
      'kind': kind.name,
      'output_path': outputPath,
      'updated_at_ms': updatedAtMs,
    };
  }

  factory DownloadSyncRecord.fromJson(Map<String, dynamic> json) {
    return DownloadSyncRecord(
      id: json['id'] as String,
      jobKey: json['job_key'] as String,
      sourceChatId: json['source_chat_id'] as int,
      messageId: json['message_id'] as int,
      kind: MediaItemKind.values.firstWhere(
        (value) => value.name == json['kind'],
      ),
      outputPath: json['output_path'] as String,
      updatedAtMs: json['updated_at_ms'] as int,
    );
  }
}

class DownloadSyncRepository {
  DownloadSyncRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _recordsKey = 'download_sync_records_json';

  List<DownloadSyncRecord> loadRecords() {
    final encoded = _prefs.getString(_recordsKey);
    if (encoded == null || encoded.isEmpty) {
      return const <DownloadSyncRecord>[];
    }
    final raw = jsonDecode(encoded) as List<dynamic>;
    return raw
        .map((item) => DownloadSyncRecord.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveRecords(List<DownloadSyncRecord> records) {
    final encoded = jsonEncode(
      records.map((item) => item.toJson()).toList(growable: false),
    );
    return _prefs.setString(_recordsKey, encoded);
  }
}
