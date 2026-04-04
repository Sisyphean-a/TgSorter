import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_feed_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

void main() {
  test('loadInitialMessages replaces cache and records tail message id', () async {
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
  });
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
