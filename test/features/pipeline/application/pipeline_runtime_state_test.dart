import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test('currentMessage updates mediaSession automatically', () async {
    final state = PipelineRuntimeState();
    state.currentMessage.value = PipelineMessage(
      id: 301,
      messageIds: const <int>[301, 302],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'album',
        mediaItems: [
          MediaItemPreview(messageId: 301, kind: MediaItemKind.video),
          MediaItemPreview(messageId: 302, kind: MediaItemKind.video),
        ],
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(state.mediaSession.value?.groupMessageId, 301);
    expect(state.mediaSession.value?.activeItemMessageId, 301);
  });
}
