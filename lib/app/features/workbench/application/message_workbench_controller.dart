import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_feed_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/workbench/application/message_workbench_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class MessageWorkbenchController {
  MessageWorkbenchController({
    required this.state,
    required MessageReadGateway messages,
    required MediaGateway media,
    required PipelineSettingsReader settings,
    required void Function(Object error) reportError,
    PipelineNavigationService? navigation,
    PipelineFeedController? feed,
    RemainingCountService? remainingCount,
  }) {
    this.navigation = navigation ?? PipelineNavigationService(state: state);
    feedController =
        feed ??
        PipelineFeedController(
          state: state,
          navigation: this.navigation,
          messages: messages,
          media: media,
          settings: settings,
          remainingCount: remainingCount ?? RemainingCountService(),
          reportGeneralError: reportError,
        );
  }

  final MessageWorkbenchState state;
  late final PipelineNavigationService navigation;
  late final PipelineFeedController feedController;

  Rxn<PipelineMessage> get currentMessage => state.currentMessage;
  RxBool get loading => state.loading;
  RxBool get processing => state.processing;
  RxBool get isOnline => state.isOnline;
  RxBool get canShowPrevious => state.canShowPrevious;
  RxBool get canShowNext => state.canShowNext;

  PipelineScreenVm get screenVm => PipelineScreenVm(
    message: MessagePreviewVm(
      content: state.currentMessage.value,
      media: MediaSessionVm.fromState(state.mediaSession.value),
    ),
    navigation: NavigationVm(
      canShowPrevious: state.navigation.value.canShowPrevious,
      canShowNext: state.navigation.value.canShowNext,
    ),
    workflow: WorkflowVm(
      processingOverlay: state.loading.value || state.processing.value,
      online: state.isOnline.value,
    ),
  );

  Future<void> fetchNext() async {
    loading.value = true;
    try {
      await feedController.loadInitialMessages();
    } finally {
      loading.value = false;
    }
  }

  Future<void> showPreviousMessage() async {
    if (processing.value || state.currentIndex <= 0) {
      return;
    }
    await navigation.showPrevious();
    await feedController.prefetchIfNeeded();
  }

  Future<void> showNextMessage() async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    if (state.currentIndex + 1 >= state.cache.length) {
      await feedController.appendMoreMessages();
    }
    if (state.currentIndex + 1 < state.cache.length) {
      await navigation.showNext();
      await feedController.prefetchIfNeeded();
    }
  }

  Future<void> skipCurrent() async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    processing.value = true;
    try {
      navigation.removeCurrentAndSync();
      await feedController.ensureVisibleMessage();
    } finally {
      processing.value = false;
    }
  }

  void replaceCurrent(PipelineMessage message) {
    if (state.currentIndex < 0 || state.currentIndex >= state.cache.length) {
      return;
    }
    state.cache[state.currentIndex] = message;
    navigation.syncCurrentMessage();
  }
}
