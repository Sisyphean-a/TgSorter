import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_feed_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';

void main() {
  test('loadInitialMessages skips persisted forwarding records by default', () async {
    final state = PipelineRuntimeState();
    final navigation = PipelineNavigationService(state: state);
    final skipped = _MemorySkippedMessageRepository(
      records: <SkippedMessageRecord>[
        SkippedMessageRecord(
          id: 'forwarding:8888:1',
          workflow: SkippedMessageWorkflow.forwarding,
          sourceChatId: 8888,
          primaryMessageId: 1,
          messageIds: const <int>[1],
          createdAtMs: 1,
        ),
      ],
    );
    final controller = PipelineFeedController(
      state: state,
      navigation: navigation,
      messages: _PagedMessageReadGateway(),
      media: _NoopMediaGateway(),
      settings: _SettingsReader(),
      remainingCount: RemainingCountService(),
      reportGeneralError: (_) {},
      skippedMessageRepository: skipped,
      workflow: SkippedMessageWorkflow.forwarding,
    );

    await controller.loadInitialMessages();

    expect(state.currentMessage.value?.id, 2);
    expect(state.remainingCount.value, 1);
  });
}

class _PagedMessageReadGateway implements MessageReadGateway {
  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 2;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    if (fromMessageId == null) {
      return <PipelineMessage>[_message(1, 'first'), _message(2, 'second')];
    }
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
  }) async {
    return _message(messageId, 'message-$messageId');
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
  }) async {
    throw UnimplementedError();
  }
}

class _SettingsReader implements PipelineSettingsReader {
  @override
  AppSettings get currentSettings =>
      AppSettings.defaults().updateSourceChatId(8888);

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();

  @override
  Rx<AppSettings> get settingsStream => currentSettings.obs;
}

class _MemorySkippedMessageRepository implements SkippedMessageRepository {
  _MemorySkippedMessageRepository({required this.records});

  final List<SkippedMessageRecord> records;

  @override
  bool containsMessage({
    required SkippedMessageWorkflow workflow,
    required int sourceChatId,
    required Iterable<int> messageIds,
  }) {
    final targetIds = messageIds.toSet();
    return records.any(
      (item) =>
          item.workflow == workflow &&
          item.sourceChatId == sourceChatId &&
          item.messageIds.any(targetIds.contains),
    );
  }

  @override
  int countSkippedMessages({
    required SkippedMessageWorkflow workflow,
    int? sourceChatId,
  }) {
    return records.where((item) {
      return item.workflow == workflow &&
          (sourceChatId == null || item.sourceChatId == sourceChatId);
    }).length;
  }

  @override
  List<SkippedMessageRecord> loadSkippedMessages() =>
      List<SkippedMessageRecord>.from(records);

  @override
  Future<int> restoreSkippedMessages({
    SkippedMessageWorkflow? workflow,
    int? sourceChatId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSkippedMessages(List<SkippedMessageRecord> records) async {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertSkippedMessage(SkippedMessageRecord record) async {
    throw UnimplementedError();
  }
}

PipelineMessage _message(int id, String title) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}
