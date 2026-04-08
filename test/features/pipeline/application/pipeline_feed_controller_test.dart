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
    'prepareUpcomingPreviews stops stale work after pipeline reset',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      final media = _BlockingMediaGateway();
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
      await media.firstPrepareStarted.future;
      controller.reset();
      media.releaseFirstPrepare();

      await expectLater(preparing, completes);
      expect(media.prepareCalls, [2]);
    },
  );
}

PipelineMessage _message(int id, String title) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(
      kind: MessagePreviewKind.video,
      title: title,
    ),
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
  }) {
    throw UnimplementedError();
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
