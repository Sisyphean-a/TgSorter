import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/features/tagging/presentation/tagging_page.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  testWidgets('tagging page shows tag buttons and applies selected tag', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tagging = _TaggingPageGateway();
    final controller = _buildController(tagging: tagging);
    controller.isOnline.value = true;
    await controller.fetchNext();

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark(),
        home: TaggingPage(controller: controller, errors: AppErrorController()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#摄影'), findsOneWidget);
    expect(find.text('撤销上一步'), findsNothing);
    expect(find.text('重试下一条'), findsNothing);

    await tester.tap(find.text('#摄影'));
    await tester.pumpAndSettle();

    expect(tagging.lastTagName, '摄影');
    expect(find.text('待打标 #摄影'), findsOneWidget);
  });

  testWidgets('tagging page narrow layout does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _buildController();
    controller.isOnline.value = true;
    await controller.fetchNext();

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark(),
        home: TaggingPage(controller: controller, errors: AppErrorController()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tagging-workbench-mobile')), findsOneWidget);
    expect(find.text('#摄影'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TaggingCoordinator _buildController({_TaggingPageGateway? tagging}) {
  return TaggingCoordinator(
    messageReadGateway: _TaggingPageMessages(),
    mediaGateway: _TaggingPageMedia(),
    taggingGateway: tagging ?? _TaggingPageGateway(),
    settingsReader: _TaggingPageSettings(),
    errorController: AppErrorController(),
  );
}

class _TaggingPageGateway implements TaggingGateway {
  String? lastTagName;

  @override
  Future<ApplyTagResult> applyTag({
    required int sourceChatId,
    required List<int> messageIds,
    required String tagName,
  }) async {
    lastTagName = tagName;
    return ApplyTagResult(message: _message('待打标 #$tagName'), changed: true);
  }
}

class _TaggingPageMessages implements MessageReadGateway {
  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 1;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async => [_message('待打标')];

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => _message('待打标');

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async => _message('待打标');
}

class _TaggingPageMedia implements MediaGateway {
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

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }
}

class _TaggingPageSettings implements PipelineSettingsReader {
  final _settings = AppSettings.defaults().copyWith(
    tagSourceChatId: -1001,
    tagGroups: const [
      TagGroupConfig(
        key: TagGroupConfig.defaultGroupKey,
        title: TagGroupConfig.defaultGroupTitle,
        tags: [TagConfig(name: '摄影')],
      ),
    ],
  );

  @override
  AppSettings get currentSettings => _settings;

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();

  @override
  Rx<AppSettings> get settingsStream => _settings.obs;
}

PipelineMessage _message(String title) {
  return PipelineMessage(
    id: 1,
    messageIds: const [1],
    sourceChatId: -1001,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}
