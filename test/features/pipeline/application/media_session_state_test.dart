import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test('fromMessage tracks active item and per-item availability', () {
    final message = PipelineMessage(
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
          ),
          MediaItemPreview(messageId: 22, kind: MediaItemKind.video),
        ],
      ),
    );

    final session = MediaSessionState.fromMessage(message);

    expect(session.groupMessageId, 21);
    expect(session.activeItemMessageId, 21);
    expect(session.requestState, MediaRequestState.idle);
    expect(session.items[21]?.previewAvailability, MediaAvailability.ready);
    expect(session.items[22]?.previewAvailability, MediaAvailability.missing);
  });

  test('fromMessage falls back to first item when active item is invalid', () {
    final message = PipelineMessage(
      id: 21,
      messageIds: const <int>[21, 22],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'album',
        mediaItems: [
          MediaItemPreview(messageId: 21, kind: MediaItemKind.video),
          MediaItemPreview(messageId: 22, kind: MediaItemKind.video),
        ],
      ),
    );

    final session = MediaSessionState.fromMessage(
      message,
      activeItemMessageId: 999,
    );

    expect(session.activeItemMessageId, 21);
  });

  test('fromMessage creates standalone session item for single video', () {
    final message = PipelineMessage(
      id: 31,
      messageIds: const <int>[31],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'single-video',
        localVideoThumbnailPath: 'C:/thumb.jpg',
      ),
    );

    final session = MediaSessionState.fromMessage(message);

    expect(session.activeItemMessageId, 31);
    expect(session.items[31]?.kind, MediaItemKind.video);
    expect(session.items[31]?.previewAvailability, MediaAvailability.ready);
    expect(session.items[31]?.playbackAvailability, MediaAvailability.missing);
  });

  test('fromMessage creates standalone session item for single audio', () {
    final message = PipelineMessage(
      id: 41,
      messageIds: const <int>[41],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.audio,
        title: 'single-audio',
        audioTracks: [
          AudioTrackPreview(
            messageId: 41,
            title: 'single-audio',
          ),
        ],
      ),
    );

    final session = MediaSessionState.fromMessage(message);

    expect(session.activeItemMessageId, 41);
    expect(session.items[41]?.kind, MediaItemKind.audio);
    expect(session.items[41]?.playbackAvailability, MediaAvailability.missing);
  });
}
