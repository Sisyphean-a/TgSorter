import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';
import 'package:tgsorter/app/features/dedup/presentation/media_dedup_screen.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

import '../support/fake_dedup_media_gateway.dart';

void main() {
  testWidgets('切回会话恢复选择，访问第四个会话只淘汰最久未打开的结果', (tester) async {
    final gateway = _gateway()
      ..chats.addAll([
        const SelectableChat(id: -3, title: '会话 C'),
        const SelectableChat(id: -4, title: '会话 D'),
      ]);
    await _open(tester, gateway);
    await _selectChat(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('照片 · 2 份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('消息 10'));
    await tester.pumpAndSettle();
    for (final (from, to) in [
      ('个人资料群', '资料频道'),
      ('资料频道', '会话 C'),
      ('会话 C', '个人资料群'),
    ]) {
      await _selectChat(tester, current: from, title: to);
      await tester.pumpAndSettle();
    }
    expect(find.text('保留消息 10'), findsOneWidget);
    expect(find.textContaining('已恢复上次扫描结果'), findsOneWidget);
    expect(gateway.historyRequests.map((item) => item.$1), [-1001, -2000, -3]);

    for (final (from, to) in [
      ('个人资料群', '会话 D'),
      ('会话 D', '会话 C'),
      ('会话 C', '资料频道'),
    ]) {
      await _selectChat(tester, current: from, title: to);
      await tester.pumpAndSettle();
    }
    expect(gateway.historyRequests.map((item) => item.$1), [
      -1001,
      -2000,
      -3,
      -4,
      -2000,
    ]);
    expect(gateway.deleted, isEmpty);
  });

  for (final wide in [false, true]) {
    testWidgets('照片对比按消息加载，可选择保留；宽屏=$wide', (tester) async {
      await tester.binding.setSurfaceSize(Size(wide ? 1280 : 390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _gateway()
        ..history.insertAll(0, [
          dedupMedia(
            30,
            90,
            identity: 'photo',
            photoPreviewFileId: 91,
            caption: '第一份说明',
          ),
          dedupMedia(
            29,
            80,
            identity: 'photo',
            photoPreviewFileId: 81,
            caption: '第二份说明',
          ),
        ])
        ..photoLoader = (_) async => throw StateError('模拟图片请求失败');
      await _open(tester, gateway);
      await _selectChat(tester);
      await tester.pumpAndSettle();
      expect(gateway.photoRequests, isEmpty);
      await tester.tap(find.widgetWithText(ListTile, '照片 · 2 份').first);
      await tester.pumpAndSettle();
      expect(gateway.photoRequests, isEmpty);
      await tester.tap(find.text('对比照片'));
      await tester.pumpAndSettle();
      final first = find.text('保留消息 30');
      final second = find.text('保留消息 29');
      if (!wide) {
        await tester.scrollUntilVisible(
          second,
          150,
          scrollable: find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      final a = tester.getCenter(first);
      final b = tester.getCenter(second);
      expect(wide ? a.dy : a.dx, closeTo(wide ? b.dy : b.dx, 12));
      expect(gateway.photoRequests, unorderedEquals([91, 81]));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('第二份说明'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(second);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      final large = find.text('查看大图').last;
      await tester.ensureVisible(large);
      await tester.tap(large);
      await tester.pumpAndSettle();
      expect(find.text('大图 · 消息 29'), findsOneWidget);
      expect(gateway.photoRequests, unorderedEquals([91, 81, 80]));
      await tester.tap(find.text('关闭大图'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭对比'));
      await tester.pumpAndSettle();
      expect(find.text('保留消息 29'), findsOneWidget);
      expect(gateway.deleted, isEmpty);
    });
  }

  testWidgets('音频去重预览只展示信息，不播放或请求缩略图', (tester) async {
    final gateway = _gateway()
      ..history.insertAll(0, [
        dedupMedia(30, 99, kind: DedupMediaKind.audio, durationSeconds: 90),
        dedupMedia(29, 99, kind: DedupMediaKind.audio, durationSeconds: 90),
      ]);
    final thumbnails = _ThumbnailPreview();
    await _open(tester, gateway, thumbnails: thumbnails);
    await _selectChat(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('音频 · 2 份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预览音频'));
    await tester.pumpAndSettle();
    expect(find.text('时长：01:30'), findsOneWidget);
    expect(find.text('仅显示音频信息，不下载或播放'), findsOneWidget);
    expect(find.text('生成时间缩略图'), findsNothing);
    expect(thumbnails.requests, isEmpty);
    expect(gateway.deleted, isEmpty);
    unawaited(thumbnails.frames.close());
  });

  testWidgets('只在主动点击后抽帧，达到上限保留已生成的图片', (tester) async {
    final preview = _ThumbnailPreview();
    await _open(tester, _gateway(), thumbnails: preview);
    await _selectChat(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频 · 2 份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预览视频'));
    await tester.pumpAndSettle();
    expect(preview.requests, isEmpty);
    expect(find.text('计划 4 张 · 分段读取上限 12 MiB'), findsOneWidget);

    await tester.tap(find.text('生成时间缩略图'));
    await tester.pump();
    expect(preview.requests, [(6, 900)]);
    preview.frames.add(
      VideoThumbnail(
        const Duration(minutes: 3),
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1sAAAAASUVORK5CYII=',
        ),
      ),
    );
    preview.frames.addError(StateError('已达读取上限'));
    await tester.pumpAndSettle();
    expect(find.text('03:00'), findsOneWidget);
    expect(find.textContaining('已达读取上限'), findsOneWidget);
    unawaited(preview.frames.close());
    await tester.pump();
  });

  testWidgets(
    'chooses a copy at phone width and warns before deleting a caption',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _gateway();
      await _open(tester, gateway);
      expect(find.text('未选择会话'), findsOneWidget);
      await _selectChat(tester);
      await tester.pumpAndSettle();
      expect(find.text('照片 · 2 份'), findsOneWidget);
      expect(find.text('视频 · 2 份'), findsOneWidget);
      expect(gateway.deleted, isEmpty);

      await tester.tap(find.text('照片 · 2 份'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '删除其余副本'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('消息 10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除其余副本'));
      await tester.pumpAndSettle();
      expect(find.textContaining('其中 1 条附有说明'), findsOneWidget);
      expect(
        find.textContaining('保留：2025-09-05 12:10:00 · 消息 10'),
        findsOneWidget,
      );
      expect(gateway.deleted, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(gateway.deleted, isEmpty);

      await tester.tap(find.text('删除其余副本'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除 1 条消息'));
      await tester.pumpAndSettle();
      expect(gateway.deleted.single.$1, -1001);
      expect(gateway.deleted.single.$2, [7]);
      expect(find.text('照片 · 2 份'), findsNothing);
      expect(find.text('视频 · 2 份'), findsOneWidget);
      expect(find.textContaining('已删除 1 条重复消息'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retains a visible failure and offers rescan when deletion outcome is unknown',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _gateway(chatId: -2000)
        ..deletionError = TimeoutException('未收到回复');
      await _open(tester, gateway, dark: true);
      await _selectChat(tester, title: '资料频道');
      await tester.pumpAndSettle();
      await tester.tap(find.text('视频 · 2 份'));
      await tester.pumpAndSettle();
      expect(find.text('照片 · 2 份'), findsOneWidget);
      await tester.tap(find.text('消息 5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除其余副本'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除 1 条消息'));
      await tester.pumpAndSettle();
      expect(find.textContaining('未能确认删除结果'), findsOneWidget);
      expect(find.text('照片 · 2 份'), findsNothing);
      expect(find.text('扫描会话'), findsOneWidget);
      expect(gateway.deleted.single.$1, -2000);
      expect(gateway.deleted.single.$2, [9]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('历史超时后保留媒体计数，继续扫描时合并此前已有的副本', (tester) async {
    final gateway = _gateway();
    gateway.historyStream = (() async* {
      yield gateway.history.first;
      throw TimeoutException('getChatHistory');
    })();
    await _open(tester, gateway);
    await _selectChat(tester);
    await tester.pumpAndSettle();
    expect(find.text('继续扫描'), findsOneWidget);
    expect(find.textContaining('已检查 1 个媒体'), findsOneWidget);
    expect(find.text('照片 · 2 份'), findsNothing);

    gateway.historyStream = null;
    await _selectChat(tester, current: '个人资料群', title: '资料频道');
    await tester.pumpAndSettle();
    await _selectChat(tester, current: '资料频道');
    await tester.pumpAndSettle();
    expect(gateway.historyRequests, [(-1001, 0), (-2000, 0)]);
    expect(find.textContaining('已检查 1 个媒体'), findsOneWidget);
    await tester.tap(find.text('继续扫描'));
    await tester.pumpAndSettle();
    expect(find.text('照片 · 2 份'), findsOneWidget);
    expect(find.text('视频 · 2 份'), findsOneWidget);
    expect(gateway.historyRequests.last, (-1001, 10));
    expect(gateway.deleted, isEmpty);
  });

  testWidgets(
    'canceling a slow scan restores the chat scope at large text size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _gateway();
      final pending = Completer<DedupMedia>();
      gateway.historyStream = Stream.fromFuture(pending.future);
      await _open(tester, gateway, textScale: 2);
      await _selectChat(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('正在读取会话历史'), findsOneWidget);
      await tester.tap(find.text('停止扫描'));
      await tester.pumpAndSettle();
      expect(find.text('扫描已停止'), findsOneWidget);
      expect(find.text('扫描会话'), findsOneWidget);
      expect(gateway.deleted, isEmpty);
      expect(tester.takeException(), isNull);
      pending.complete(dedupMedia(30, 5));
      await tester.pump();
    },
  );
}

FakeDedupMediaGateway _gateway({int chatId = -1001}) => FakeDedupMediaGateway()
  ..chats.addAll([
    const SelectableChat(id: -1001, title: '个人资料群'),
    const SelectableChat(id: -2000, title: '资料频道'),
  ])
  ..history.addAll([
    dedupMedia(10, 5, chatId: chatId),
    dedupMedia(
      9,
      6,
      chatId: chatId,
      kind: DedupMediaKind.video,
      durationSeconds: 900,
    ),
    dedupMedia(7, 5, chatId: chatId, caption: '需要单独查看的消息说明'),
    dedupMedia(5, 6, chatId: chatId, kind: DedupMediaKind.video),
  ]);

Future<void> _open(
  WidgetTester tester,
  FakeDedupMediaGateway gateway, {
  bool dark = false,
  double textScale = 1,
  VideoThumbnailPreview? thumbnails,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: MediaDedupScreen(
          workbench: MediaDedupWorkbench(gateway, videoThumbnails: thumbnails),
        ),
      ),
    ),
  );
}

Future<void> _selectChat(
  WidgetTester tester, {
  String title = '个人资料群',
  String current = '选择会话',
}) async {
  await tester.tap(find.text(current));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(title));
  await tester.pump();
}

class _ThumbnailPreview implements VideoThumbnailPreview {
  final requests = <(int, int)>[];
  final frames = StreamController<VideoThumbnail>();

  @override
  Stream<VideoThumbnail> generate(int fileId, int durationSeconds) {
    requests.add((fileId, durationSeconds));
    return frames.stream;
  }
}
