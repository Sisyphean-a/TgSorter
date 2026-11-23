import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';

import '../../support/fake_dedup_media_gateway.dart';

void main() {
  late FakeDedupMediaGateway gateway;
  late MediaDedupWorkbench workbench;

  setUp(() {
    gateway = FakeDedupMediaGateway();
    workbench = MediaDedupWorkbench(gateway);
  });

  Future<DedupScanResult> scan() =>
      workbench.scan(-1001, stop: DedupScanStop(), onProgress: (_) {});

  test('只按同类媒体的稳定标识分组，不用大小、时长或本地文件 ID 推测重复', () async {
    gateway.history.addAll([
      dedupMedia(10, 1, identity: 'same-photo'),
      dedupMedia(9, 3),
      dedupMedia(8, 5, kind: DedupMediaKind.video, durationSeconds: 500),
      dedupMedia(7, 7, kind: DedupMediaKind.video, durationSeconds: 500),
      dedupMedia(6, 8, unidentified: true),
      dedupMedia(5, 2, identity: 'same-photo', size: null),
      dedupMedia(4, 4, identity: 'same-photo', kind: DedupMediaKind.video),
      dedupMedia(3, 5, kind: DedupMediaKind.video),
      dedupMedia(2, 8, unidentified: true),
      dedupMedia(1, 1, identity: 'same-photo', chatId: -2000),
    ]);

    final result = await scan();
    expect(result.unidentified, 2);
    expect(
      result.groups.map((group) => group.copies.map((copy) => copy.messageId)),
      [
        [10, 5],
        [8, 3],
      ],
    );
    expect(gateway.deleted, isEmpty);

    await workbench.removeDuplicates(result.groups.first, 5);
    await workbench.removeDuplicates(result.groups.last, 8);
    expect(gateway.verified, [(10, true), (5, false), (3, true), (8, false)]);
    expect(gateway.deleted.map((request) => request.$1), [-1001, -1001]);
    expect(gateway.deleted.map((request) => request.$2), [
      [10],
      [3],
    ]);
  });

  test('复核保留项失败不发出删除请求', () async {
    gateway.history.addAll([dedupMedia(2, 1), dedupMedia(1, 1)]);
    final result = await scan();
    gateway.staleId = 2;

    await expectLater(
      workbench.removeDuplicates(result.groups.single, 2),
      throwsStateError,
    );
    expect(gateway.verified, [(1, true), (2, false)]);
    expect(gateway.deleted, isEmpty);
  });

  test('删除结果不明时不重试', () async {
    gateway.history.addAll([dedupMedia(2, 1), dedupMedia(1, 1)]);
    final result = await scan();
    gateway.deletionError = TimeoutException('TDLib response timeout');
    await expectLater(
      workbench.removeDuplicates(result.groups.single, 2),
      throwsA(isA<DedupDeletionUncertain>()),
    );
    expect(gateway.deleted.single.$1, -1001);
    expect(gateway.deleted.single.$2, [1]);
  });

  test('可以停止等待会话历史', () async {
    final pending = Completer<DedupMedia>();
    gateway.historyStream = Stream.fromFuture(pending.future);
    final stop = DedupScanStop();
    final result = workbench.scan(-1001, stop: stop, onProgress: (_) {});
    final cancelled = expectLater(result, throwsA(isA<DedupScanCancelled>()));
    stop.cancel();
    await cancelled;
    pending.complete(dedupMedia(2, 1));
  });

  test('10 分钟和 1 小时均为四张，时间点不含首尾', () {
    for (final (seconds, count) in [
      (1, 2),
      (599, 2),
      (600, 4),
      (3600, 4),
      (3601, 6),
    ]) {
      final points = videoThumbnailPositions(seconds);
      expect(points, hasLength(count));
      expect(points.first, greaterThan(Duration.zero));
      expect(points.last, lessThan(Duration(seconds: seconds)));
    }
    expect(videoThumbnailPositions(300), [
      const Duration(seconds: 100),
      const Duration(seconds: 200),
    ]);
  });
}
