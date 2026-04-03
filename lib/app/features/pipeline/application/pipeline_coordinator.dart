import 'package:get/get.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

import 'pipeline_action_service.dart';
import 'pipeline_media_refresh_service.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_recovery_service.dart';
import 'pipeline_runtime_state.dart';
import 'remaining_count_service.dart';

class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required this.runtimeState,
    required this.navigation,
    required this.actions,
    required this.recovery,
    required this.mediaRefresh,
    required this.remainingCount,
  });

  final PipelineRuntimeState runtimeState;
  final PipelineNavigationService navigation;
  final PipelineActionService actions;
  final PipelineRecoveryService recovery;
  final PipelineMediaRefreshService mediaRefresh;
  final RemainingCountService remainingCount;

  Future<bool> classify(String key) async {
    final receipt = await actions.classifyCurrent(key);
    return receipt != null;
  }
  Future<void> showNextMessage() => navigation.showNext();
  Future<void> showPreviousMessage() => navigation.showPrevious();
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) => mediaRefresh.prepareCurrentMedia(
    sourceChatId: sourceChatId,
    messageId: messageId,
  );
  Future<void> recoverPendingTransactionsIfNeeded() =>
      recovery.recoverPendingTransactionsIfNeeded();

  Rxn<PipelineMessage> get currentMessage => runtimeState.currentMessage;
  RxBool get canShowPrevious => runtimeState.canShowPrevious;
  RxBool get canShowNext => runtimeState.canShowNext;
}
