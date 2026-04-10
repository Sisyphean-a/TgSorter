import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/features/workbench/application/message_workbench_controller.dart';
import 'package:tgsorter/app/features/workbench/application/message_workbench_state.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

class TaggingCoordinator extends GetxController {
  TaggingCoordinator({
    required MessageReadGateway messageReadGateway,
    required MediaGateway mediaGateway,
    required TaggingGateway taggingGateway,
    required PipelineSettingsReader settingsReader,
    required AppErrorController errorController,
    MessageWorkbenchController? workbench,
  }) : _taggingGateway = taggingGateway,
       _settingsReader = settingsReader,
       _errorController = errorController,
       workbench =
           workbench ??
           MessageWorkbenchController(
             state: MessageWorkbenchState(),
             messages: messageReadGateway,
             media: mediaGateway,
             settings: _TaggingSourceSettingsReader(settingsReader),
             reportError: (error) => _reportError(errorController, error),
           );

  final TaggingGateway _taggingGateway;
  final PipelineSettingsReader _settingsReader;
  final AppErrorController _errorController;
  final MessageWorkbenchController workbench;

  Rxn<PipelineMessage> get currentMessage => workbench.currentMessage;
  RxBool get loading => workbench.loading;
  RxBool get processing => workbench.processing;
  RxBool get isOnline => workbench.isOnline;
  RxBool get canShowPrevious => workbench.canShowPrevious;
  RxBool get canShowNext => workbench.canShowNext;
  List<TagGroupConfig> get tagGroups =>
      _settingsReader.currentSettings.tagGroups;
  PipelineScreenVm get screenVm => workbench.screenVm;

  Future<void> fetchNext() => workbench.fetchNext();

  Future<void> showPreviousMessage() => workbench.showPreviousMessage();

  Future<void> showNextMessage() => workbench.showNextMessage();

  Future<void> skipCurrent() => workbench.skipCurrent();

  Future<bool> applyTag(String tagName) async {
    final message = currentMessage.value;
    if (processing.value || !isOnline.value || message == null) {
      return false;
    }
    processing.value = true;
    try {
      final result = await _taggingGateway.applyTag(
        sourceChatId: message.sourceChatId,
        messageIds: message.messageIds,
        tagName: tagName,
      );
      workbench.replaceCurrent(result.message);
      return result.changed;
    } catch (error) {
      _reportError(_errorController, error, title: '打标失败');
      return false;
    } finally {
      processing.value = false;
    }
  }

  static void _reportError(
    AppErrorController errors,
    Object error, {
    String title = '标签工作台错误',
  }) {
    errors.report(
      title: title,
      message: '$error',
      scope: AppErrorScope.pipeline,
    );
  }
}

class _TaggingSourceSettingsReader implements PipelineSettingsReader {
  _TaggingSourceSettingsReader(this._inner);

  final PipelineSettingsReader _inner;

  @override
  AppSettings get currentSettings => _useTagSource(_inner.currentSettings);

  @override
  CategoryConfig getCategory(String key) => _inner.getCategory(key);

  @override
  Rx<AppSettings> get settingsStream => _inner.settingsStream;

  AppSettings _useTagSource(AppSettings settings) {
    return settings.copyWith(
      sourceChatId: settings.tagSourceChatId,
      clearSourceChatId: settings.tagSourceChatId == null,
    );
  }
}
