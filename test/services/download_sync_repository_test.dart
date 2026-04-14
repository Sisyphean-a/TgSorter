import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/services/download_sync_repository.dart';

void main() {
  test('clearRecords removes persisted sync index', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = DownloadSyncRepository(prefs);

    await repository.saveRecords(const <DownloadSyncRecord>[
      DownloadSyncRecord(
        id: '777|/tmp:11:audio',
        jobKey: '777|/tmp',
        sourceChatId: 777,
        messageId: 11,
        kind: MediaItemKind.audio,
        outputPath: '/tmp/source-audio.mp3',
        updatedAtMs: 1700000000000,
      ),
    ]);

    await repository.clearRecords();

    expect(repository.loadRecords(), isEmpty);
  });
}
