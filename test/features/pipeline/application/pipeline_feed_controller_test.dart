import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_feed_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

void main() {
  test(
    'loadInitialMessages replaces cache and records tail message id',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final controller = PipelineFeedController(
        state: state,
        navigation: navigation,
        messages: _FakeMessageReadGateway(),
        media: _FakeMediaGateway(),
        settings: _FakeSettingsReader(),
        remainingCount: _FakeRemainingCountService(),
        reportGeneralError: (_) {},
      );

      await controller.loadInitialMessages();

      expect(state.currentMessage.value?.id, 1);
      expect(controller.tailMessageId, 2);
    },
  );

  test(
    'loadInitialMessages recomputes next navigation after remaining count arrives later',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final messages = _DelayedRemainingMessageReadGateway(
        messages: <PipelineMessage>[_singleMessage(1, 'first')],
        remainingCount: 8,
      );
      final controller = PipelineFeedController(
        state: state,
        navigation: navigation,
        messages: messages,
        media: _FakeMediaGateway(),
        settings: _FakeSettingsReader(),
        remainingCount: RemainingCountService(),
        reportGeneralError: (_) {},
      );

      final loadTask = controller.loadInitialMessages();
      await Future<void>.delayed(Duration.zero);

      expect(state.currentMessage.value?.id, 1);
      expect(state.canShowNext.value, isFalse);

      messages.completeRemainingCount();
      await loadTask;
      await Future<void>.delayed(Duration.zero);

      expect(state.remainingCount.value, 8);
      expect(state.canShowNext.value, isTrue);
    },
  );

  test(
    'prepareUpcomingPreviews retries message after previous preview warmup failure',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final media = _RetryMediaGateway();
      final controller = PipelineFeedController(
        state: state,
        navigation: navigation,
        messages: _FakeMessageReadGateway(),
        media: media,
        settings: _FakeSettingsReader(),
        remainingCount: _FakeRemainingCountService(),
        reportGeneralError: (_) {},
      );
      navigation.replaceMessages(<PipelineMessage>[
        PipelineMessage(
          id: 1,
          messageIds: const <int>[1],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.text,
            title: 'first',
          ),
        ),
        PipelineMessage(
          id: 2,
          messageIds: const <int>[2],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'second',
          ),
        ),
      ]);

      await expectLater(
        controller.prepareUpcomingPreviews(),
        throwsA(isA<StateError>()),
      );
      await controller.prepareUpcomingPreviews();

      expect(media.prepareCalls, [2, 2]);
    },
  );

  test(
    'ensureVisibleMessage waits for current refresh but leaves upcoming prefetch in background',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final media = _BlockingMediaGateway();
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      final controller = PipelineFeedController(
        state: state,
        navigation: navigation,
        messages: _FakeMessageReadGateway(),
        media: media,
        settings: _FakeSettingsReader(),
        remainingCount: _FakeRemainingCountService(),
        reportGeneralError: (_) {},
        refreshCurrentMediaIfNeeded: () async {
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
          await releaseRefresh.future;
        },
      );
      navigation.replaceMessages(<PipelineMessage>[
        _message(1, 'first'),
        _message(2, 'second'),
        _message(3, 'third'),
      ]);

      final ensureTask = controller.ensureVisibleMessage();
      await refreshStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(media.prepareCalls, isEmpty);

      releaseRefresh.complete();
      await media.firstPrepareStarted.future;
      await expectLater(ensureTask, completes);

      expect(media.prepareCalls, [2, 3]);
      media.releaseFirstPrepare();
    },
  );

  test(
    'prepareUpcomingPreviews respects background concurrency and stops stale work after reset',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final media = _ConcurrentBlockingMediaGateway();
      final controller = PipelineFeedController(
        state: state,
        navigation: navigation,
        messages: _FakeMessageReadGateway(),
        media: media,
        settings: _FakeSettingsReader(),
        remainingCount: _FakeRemainingCountService(),
        reportGeneralError: (_) {},
      );
      navigation.replaceMessages(<PipelineMessage>[
        _message(1, 'first'),
        _message(2, 'second'),
        _message(3, 'third'),
      ]);

      final preparing = controller.prepareUpcomingPreviews();
      await Future<void>.delayed(Duration.zero);
      expect(media.prepareCalls, [2, 3]);
      expect(media.maxActive, 2);
      controller.reset();
      media.releaseAll();

      await expectLater(preparing, completes);
      expect(media.prepareCalls, [2, 3]);
    },
  );

  test(
    'prepareUpcomingPreviews refreshes cached message after preview download completes',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final messages = _RefreshableMessageReadGateway();
      final media = _PreparedPreviewMediaGateway();
      final controller = PipelineFeedController(
        state: state,
        navigation: navigation,
        messages: messages,
        media: media,
        settings: _FakeSettingsReader(),
        remainingCount: _FakeRemainingCountService(),
        reportGeneralError: (_) {},
      );
      navigation.replaceMessages(<PipelineMessage>[
        _message(1, 'first'),
        _message(2, 'second'),
      ]);

      await controller.prepareUpcomingPreviews();

      expect(state.cache[1].preview.localImagePath, 'C:/preview-2.jpg');
      expect(state.cache[1].preview.mediaItems.first.previewPath, 'C:/preview-2.jpg');
    },
  );

  test(
    'prepareUpcomingPreviews preserves grouped audio items while refreshing tracks',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final messages = _GroupedAudioRefreshMessageReadGateway();
      final media = _PreparedPreviewMediaGateway();
      final controller = PipelineFeedController(
        state: state,
        navigation: navigation,
        messages: messages,
        media: media,
        settings: _FakeSettingsReader(),
        remainingCount: _FakeRemainingCountService(),
        reportGeneralError: (_) {},
      );
      navigation.replaceMessages(<PipelineMessage>[
        _message(1, 'first'),
        PipelineMessage(
          id: 21,
          messageIds: const <int>[21, 22, 23],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.audio,
            title: '音频组 (3 条)',
            audioTracks: <AudioTrackPreview>[
              AudioTrackPreview(messageId: 21, title: 'track-21'),
              AudioTrackPreview(messageId: 22, title: 'track-22'),
              AudioTrackPreview(messageId: 23, title: 'track-23'),
            ],
          ),
        ),
      ]);

      await controller.prepareUpcomingPreviews();

      expect(state.cache[1].messageIds, const <int>[21, 22, 23]);
      expect(state.cache[1].preview.audioTracks, hasLength(3));
      expect(
        state.cache[1].preview.audioTracks.map((item) => item.localAudioPath),
        <String?>['C:/audio-21.mp3', 'C:/audio-22.mp3', 'C:/audio-23.mp3'],
      );
    },
  );
}

PipelineMessage _message(int id, String title) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.video, title: title),
  );
}

PipelineMessage _singleMessage(int id, String title) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}

class _FakeMessageReadGateway implements MessageReadGateway {
  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 8;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    if (fromMessageId != null) {
      return const <PipelineMessage>[];
    }
    return <PipelineMessage>[
      PipelineMessage(
        id: 1,
        messageIds: const <int>[1],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.text,
          title: 'first',
        ),
      ),
      PipelineMessage(
        id: 2,
        messageIds: const <int>[2],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.text,
          title: 'second',
        ),
      ),
    ];
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => null;

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'refreshed-$messageId',
      ),
    );
  }
}

class _RefreshableMessageReadGateway extends _FakeMessageReadGateway {
  _RefreshableMessageReadGateway();

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: MessagePreview(
        kind: MessagePreviewKind.photo,
        title: 'prepared',
        localImagePath: 'C:/preview-$messageId.jpg',
        mediaItems: <MediaItemPreview>[
          MediaItemPreview(
            messageId: messageId,
            kind: MediaItemKind.photo,
            previewPath: 'C:/preview-$messageId.jpg',
            fullPath: 'C:/full-$messageId.jpg',
          ),
        ],
      ),
    );
  }
}

class _GroupedAudioRefreshMessageReadGateway extends _FakeMessageReadGateway {
  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: MessagePreview(
        kind: MessagePreviewKind.audio,
        title: 'track-$messageId',
        subtitle: 'artist-$messageId',
        localAudioPath: 'C:/audio-$messageId.mp3',
        audioDurationSeconds: 180,
        audioTracks: <AudioTrackPreview>[
          AudioTrackPreview(
            messageId: messageId,
            title: 'track-$messageId',
            subtitle: 'artist-$messageId',
            localAudioPath: 'C:/audio-$messageId.mp3',
            audioDurationSeconds: 180,
          ),
        ],
      ),
    );
  }
}

class _DelayedRemainingMessageReadGateway implements MessageReadGateway {
  _DelayedRemainingMessageReadGateway({
    required this.messages,
    required this.remainingCount,
  });

  final List<PipelineMessage> messages;
  final int remainingCount;
  final Completer<int> _remainingCountCompleter = Completer<int>();

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) {
    return _remainingCountCompleter.future;
  }

  void completeRemainingCount() {
    if (!_remainingCountCompleter.isCompleted) {
      _remainingCountCompleter.complete(remainingCount);
    }
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    if (fromMessageId != null) {
      return const <PipelineMessage>[];
    }
    return messages;
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => null;

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}

class _FakeMediaGateway implements MediaGateway {
  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}

class _PreparedPreviewMediaGateway extends _FakeMediaGateway {}

class _RetryMediaGateway extends _FakeMediaGateway {
  final List<int> prepareCalls = <int>[];
  bool _failed = false;

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    prepareCalls.add(messageId);
    if (!_failed) {
      _failed = true;
      throw StateError('preview failed once');
    }
  }
}

class _BlockingMediaGateway extends _FakeMediaGateway {
  final List<int> prepareCalls = <int>[];
  final Completer<void> firstPrepareStarted = Completer<void>();
  final Completer<void> _releaseFirstPrepare = Completer<void>();

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    prepareCalls.add(messageId);
    if (messageId != 2) {
      return;
    }
    if (!firstPrepareStarted.isCompleted) {
      firstPrepareStarted.complete();
    }
    await _releaseFirstPrepare.future;
  }

  void releaseFirstPrepare() {
    if (!_releaseFirstPrepare.isCompleted) {
      _releaseFirstPrepare.complete();
    }
  }
}

class _ConcurrentBlockingMediaGateway extends _FakeMediaGateway {
  final List<int> prepareCalls = <int>[];
  final Map<int, Completer<void>> _releases = <int, Completer<void>>{};
  int _activeCount = 0;
  int maxActive = 0;

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    prepareCalls.add(messageId);
    _activeCount++;
    if (_activeCount > maxActive) {
      maxActive = _activeCount;
    }
    final release = _releases.putIfAbsent(messageId, Completer<void>.new);
    await release.future;
    _activeCount--;
  }

  void releaseAll() {
    for (final completer in _releases.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }
}

class _FakeSettingsReader implements PipelineSettingsReader {
  @override
  final settingsStream = const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: 8888,
    fetchDirection: MessageFetchDirection.latestFirst,
    forwardAsCopy: false,
    batchSize: 2,
    throttleMs: 0,
    proxy: ProxySettings.empty,
  ).obs;

  @override
  AppSettings get currentSettings => settingsStream.value;

  @override
  CategoryConfig getCategory(String key) {
    throw UnimplementedError();
  }
}

class _FakeRemainingCountService extends RemainingCountService {}
