import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_refresh_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test(
    'prepareCurrentMedia merges prepared video payload into current message',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = PipelineMessage(
        id: 21,
        messageIds: const <int>[21],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.video,
          title: 'video',
        ),
      );
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: _FakeMediaRefreshService(),
      );

      await controller.prepareCurrentMedia();

      expect(
        state.currentMessage.value?.preview.localVideoPath,
        'C:/video.mp4',
      );
    },
  );

  test(
    'prepareCurrentMedia tracks preparing state for target message only',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = PipelineMessage(
        id: 21,
        messageIds: const <int>[21, 22],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.video,
          title: 'album',
          mediaItems: [
            MediaItemPreview(
              messageId: 21,
              kind: MediaItemKind.video,
              previewPath: null,
              fullPath: null,
            ),
            MediaItemPreview(
              messageId: 22,
              kind: MediaItemKind.video,
              previewPath: null,
              fullPath: null,
            ),
          ],
        ),
      );
      final completer = Completer<PipelineMessage>();
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: _BlockingMediaRefreshService(completer),
      );

      final future = controller.prepareCurrentMedia(22);

      expect(controller.isPreparingMessageId(22), isTrue);
      expect(controller.isPreparingMessageId(21), isFalse);

      completer.complete(
        PipelineMessage(
          id: 22,
          messageIds: const <int>[22],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'video-2',
            localVideoPath: 'C:/video-2.mp4',
            mediaItems: [
              MediaItemPreview(
                messageId: 22,
                kind: MediaItemKind.video,
                previewPath: 'C:/thumb-2.jpg',
                fullPath: 'C:/video-2.mp4',
              ),
            ],
          ),
        ),
      );
      await future;

      expect(controller.isPreparingMessageId(22), isFalse);
    },
  );

  test(
    'refreshCurrentMediaIfNeeded refreshes missing grouped item previews',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = PipelineMessage(
        id: 21,
        messageIds: const <int>[21, 22],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.video,
          title: 'album',
          mediaItems: [
            MediaItemPreview(
              messageId: 21,
              kind: MediaItemKind.video,
              previewPath: 'C:/thumb-1.jpg',
              fullPath: null,
            ),
            MediaItemPreview(
              messageId: 22,
              kind: MediaItemKind.video,
              previewPath: null,
              fullPath: null,
            ),
          ],
        ),
      );
      final mediaRefresh = _RecordingRefreshMediaService();
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: mediaRefresh,
        videoRefreshInterval: const Duration(milliseconds: 5),
      );

      await controller.refreshCurrentMediaIfNeeded();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mediaRefresh.refreshCalls, contains(22));
    },
  );

  test(
    'refreshCurrentMediaIfNeeded refreshes missing photo previews',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = PipelineMessage(
        id: 31,
        messageIds: const <int>[31, 32],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.photo,
          title: 'photos',
          mediaItems: [
            MediaItemPreview(messageId: 31, kind: MediaItemKind.photo),
            MediaItemPreview(
              messageId: 32,
              kind: MediaItemKind.photo,
              previewPath: 'C:/photo-32.jpg',
            ),
          ],
        ),
      );
      final mediaRefresh = _PhotoRefreshMediaService();
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: mediaRefresh,
        videoRefreshInterval: const Duration(milliseconds: 5),
      );

      await controller.refreshCurrentMediaIfNeeded();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mediaRefresh.refreshCalls, contains(31));
      expect(
        state.currentMessage.value?.preview.mediaItems.first.previewPath,
        'C:/photo-31.jpg',
      );
    },
  );

  test(
    'refreshCurrentMediaIfNeeded starts current photo preview warmup before refresh',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = PipelineMessage(
        id: 31,
        messageIds: const <int>[31],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.photo,
          title: 'photo',
        ),
      );
      final mediaRefresh = _PhotoPrepareRefreshMediaService();
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: mediaRefresh,
        videoRefreshInterval: const Duration(milliseconds: 5),
      );

      await controller.refreshCurrentMediaIfNeeded();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mediaRefresh.preparePreviewCalls, <int>[31]);
      expect(mediaRefresh.refreshCalls, contains(31));
    },
  );

  test(
    'prepareCurrentMedia stops preparing after grouped audio track becomes ready',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = PipelineMessage(
        id: 21,
        messageIds: const <int>[21, 22],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.audio,
          title: 'album',
          audioTracks: [
            AudioTrackPreview(messageId: 21, title: 'track-1'),
            AudioTrackPreview(messageId: 22, title: 'track-2'),
          ],
        ),
      );
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: _GroupedAudioRefreshService(),
        videoRefreshInterval: const Duration(milliseconds: 5),
      );

      await controller.prepareCurrentMedia(22);

      expect(controller.isPreparingMessageId(22), isFalse);
      expect(state.videoPreparing.value, isFalse);
      expect(
        state.currentMessage.value?.preview.audioTracks.last.localAudioPath,
        'C:/track-22.mp3',
      );
    },
  );

  test(
    'prepareCurrentMedia keeps prepared payload when navigating away and back',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      navigation.replaceMessages(<PipelineMessage>[
        PipelineMessage(
          id: 21,
          messageIds: const <int>[21],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'video-1',
          ),
        ),
        PipelineMessage(
          id: 22,
          messageIds: const <int>[22],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.text,
            title: 'text-2',
          ),
        ),
      ]);
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: _FakeMediaRefreshService(),
      );

      await controller.prepareCurrentMedia();
      await navigation.showNext();
      await navigation.showPrevious();

      expect(state.currentMessage.value?.id, 21);
      expect(
        state.currentMessage.value?.preview.localVideoPath,
        'C:/video.mp4',
      );
    },
  );

  test(
    'prepareCurrentMedia does not overwrite a newer current message after async prepare',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      navigation.replaceMessages(<PipelineMessage>[
        PipelineMessage(
          id: 21,
          messageIds: const <int>[21],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'video-1',
          ),
        ),
        PipelineMessage(
          id: 22,
          messageIds: const <int>[22],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.text,
            title: 'text-2',
          ),
        ),
      ]);
      final prepareCompleter = Completer<PipelineMessage>();
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: _BlockingMediaRefreshService(prepareCompleter),
      );

      final preparing = controller.prepareCurrentMedia();
      await navigation.showNext();
      prepareCompleter.complete(
        PipelineMessage(
          id: 21,
          messageIds: const <int>[21],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'video-1',
            localVideoPath: 'C:/video.mp4',
          ),
        ),
      );
      await preparing;

      expect(state.currentMessage.value?.id, 22);
      expect(state.currentMessage.value?.preview.title, 'text-2');
      await navigation.showPrevious();
      expect(state.currentMessage.value?.id, 21);
      expect(
        state.currentMessage.value?.preview.localVideoPath,
        'C:/video.mp4',
      );
    },
  );

  test(
    'prepareCurrentMedia stops stale follow-up refresh when current message changed',
    () async {
      final state = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: state);
      navigation.replaceMessages(<PipelineMessage>[
        PipelineMessage(
          id: 21,
          messageIds: const <int>[21],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'video-1',
          ),
        ),
        PipelineMessage(
          id: 22,
          messageIds: const <int>[22],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'video-2',
          ),
        ),
      ]);
      final prepareCompleter = Completer<PipelineMessage>();
      final mediaRefresh = _BlockingMediaRefreshService(prepareCompleter);
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: mediaRefresh,
        videoRefreshInterval: const Duration(milliseconds: 5),
      );

      final preparing = controller.prepareCurrentMedia();
      await navigation.showNext();
      prepareCompleter.complete(
        PipelineMessage(
          id: 21,
          messageIds: const <int>[21],
          sourceChatId: 8888,
          preview: const MessagePreview(
            kind: MessagePreviewKind.video,
            title: 'video-1',
            localVideoPath: 'C:/video.mp4',
          ),
        ),
      );
      await preparing;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(state.currentMessage.value?.id, 22);
      expect(mediaRefresh.refreshCalls, isEmpty);
      expect(state.videoPreparing.value, isFalse);
    },
  );

  test(
    'refreshCurrentMediaIfNeeded reports refresh failure and stops retry timer',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = PipelineMessage(
        id: 21,
        messageIds: const <int>[21],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.video,
          title: 'video-1',
        ),
      );
      final errors = <Object>[];
      final uncaughtErrors = <Object>[];
      final mediaRefresh = _FailingRefreshMediaService();
      final controller = PipelineMediaController(
        state: state,
        mediaRefresh: mediaRefresh,
        reportGeneralError: errors.add,
        videoRefreshInterval: const Duration(milliseconds: 5),
      );

      await runZonedGuarded(
        () async {
          await controller.refreshCurrentMediaIfNeeded();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
        (error, _) {
          uncaughtErrors.add(error);
        },
      );

      expect(errors, hasLength(1));
      expect(uncaughtErrors, isEmpty);
      expect(mediaRefresh.refreshCalls, [21]);
      expect(state.videoPreparing.value, isFalse);
    },
  );
}

class _FakeMediaRefreshService extends PipelineMediaRefreshService {
  _FakeMediaRefreshService()
    : super.legacy(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
        localVideoPath: 'C:/video.mp4',
      ),
    );
  }
}

class _BlockingMediaRefreshService extends PipelineMediaRefreshService {
  _BlockingMediaRefreshService(this.prepareCompleter)
    : super.legacy(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  final Completer<PipelineMessage> prepareCompleter;
  final List<int> refreshCalls = <int>[];

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) {
    return prepareCompleter.future;
  }

  @override
  Future<PipelineMessage> refreshCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    refreshCalls.add(messageId);
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'refreshed',
      ),
    );
  }
}

class _FailingRefreshMediaService extends PipelineMediaRefreshService {
  _FailingRefreshMediaService()
    : super.legacy(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  final List<int> refreshCalls = <int>[];

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> refreshCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    refreshCalls.add(messageId);
    throw StateError('refresh failed');
  }
}

class _RecordingRefreshMediaService extends PipelineMediaRefreshService {
  _RecordingRefreshMediaService()
    : super.legacy(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  final List<int> refreshCalls = <int>[];

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> refreshCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    refreshCalls.add(messageId);
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'refreshed-$messageId',
        mediaItems: <MediaItemPreview>[
          MediaItemPreview(
            messageId: messageId,
            kind: MediaItemKind.video,
            previewPath: 'C:/thumb-$messageId.jpg',
            fullPath: null,
          ),
        ],
      ),
    );
  }
}

class _PhotoRefreshMediaService extends PipelineMediaRefreshService {
  _PhotoRefreshMediaService()
    : super.legacy(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  final List<int> refreshCalls = <int>[];

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> refreshCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    refreshCalls.add(messageId);
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: MessagePreview(
        kind: MessagePreviewKind.photo,
        title: 'photo-$messageId',
        mediaItems: <MediaItemPreview>[
          MediaItemPreview(
            messageId: messageId,
            kind: MediaItemKind.photo,
            previewPath: 'C:/photo-$messageId.jpg',
          ),
        ],
      ),
    );
  }
}

class _PhotoPrepareRefreshMediaService extends PipelineMediaRefreshService {
  _PhotoPrepareRefreshMediaService()
    : super.legacy(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  final List<int> preparePreviewCalls = <int>[];
  final List<int> refreshCalls = <int>[];

  @override
  Future<void> prepareCurrentPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    preparePreviewCalls.add(messageId);
  }

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> refreshCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    refreshCalls.add(messageId);
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: MessagePreview(
        kind: MessagePreviewKind.photo,
        title: 'photo-$messageId',
        mediaItems: <MediaItemPreview>[
          MediaItemPreview(
            messageId: messageId,
            kind: MediaItemKind.photo,
            previewPath: 'C:/photo-$messageId.jpg',
          ),
        ],
      ),
    );
  }
}

class _GroupedAudioRefreshService extends PipelineMediaRefreshService {
  _GroupedAudioRefreshService()
    : super.legacy(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  @override
  Future<PipelineMessage> prepareCurrentMedia({
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
        localAudioPath: 'C:/track-$messageId.mp3',
      ),
    );
  }

  @override
  Future<PipelineMessage> refreshCurrentMedia({
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
        localAudioPath: 'C:/track-$messageId.mp3',
      ),
    );
  }
}

class _NoopMediaGateway implements MediaGateway {
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

class _NoopMessageReadGateway implements MessageReadGateway {
  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 0;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    return const <PipelineMessage>[];
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
