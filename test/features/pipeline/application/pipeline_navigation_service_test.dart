import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test(
    'showNext moves current index and exposes next cached message',
    () async {
      final state = PipelineRuntimeState();
      final service = PipelineNavigationService(state: state);
      final first = fakePipelineMessage(id: 101);
      final second = fakePipelineMessage(id: 102);

      service.replaceMessages(<PipelineMessage>[first, second]);

      expect(state.currentMessage.value?.id, 101);
      await service.showNext();
      expect(state.currentMessage.value?.id, 102);
      expect(state.canShowPrevious.value, isTrue);
    },
  );
}

PipelineMessage fakePipelineMessage({required int id}) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: '$id'),
  );
}
