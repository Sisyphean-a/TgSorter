import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';

import 'classify_gateway.dart';
import 'media_gateway.dart';
import 'message_read_gateway.dart';
import 'pipeline_action_service.dart';
import 'pipeline_media_refresh_service.dart';
import 'pipeline_recovery_service.dart';
import 'remaining_count_service.dart';
import 'pipeline_settings_reader.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_runtime_state.dart';
import 'recovery_gateway.dart';

class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required this.runtimeState,
    required this.navigation,
    required this.actions,
    required this.recovery,
    required this.mediaRefresh,
    required this.remainingCount,
    required this.messages,
    required this.media,
    required this.classify,
    required this.settings,
    required this.journalRepository,
    required this.errorController,
  });

  final PipelineRuntimeState runtimeState;
  final PipelineNavigationService navigation;
  final PipelineActionService actions;
  final PipelineRecoveryService recovery;
  final PipelineMediaRefreshService mediaRefresh;
  final RemainingCountService remainingCount;

  final MessageReadGateway messages;
  final MediaGateway media;
  final ClassifyGateway classify;
  final PipelineSettingsReader settings;
  final OperationJournalRepository journalRepository;
  final AppErrorController errorController;

  Future<bool> classifyMessage(String key) => actions.classifyCurrent(key);
  Future<void> showNextMessage() => navigation.showNext();
  Future<void> showPreviousMessage() => navigation.showPrevious();
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) => mediaRefresh.prepareCurrentMedia(
    sourceChatId: sourceChatId,
    messageId: messageId,
  );

  Rxn<PipelineMessage> get currentMessage => runtimeState.currentMessage;
  RxBool get canShowPrevious => runtimeState.canShowPrevious;
  RxBool get canShowNext => runtimeState.canShowNext;
}
