import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_session_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class PipelineRuntimeState {
  PipelineRuntimeState() {
    currentMessage.listen((message) {
      mediaSession.value = message == null
          ? const MediaSessionState.empty()
          : MediaSessionState.fromMessage(message);
    });
  }

  final currentMessage = Rxn<PipelineMessage>();
  final navigation = Rx<NavigationAvailability>(
    const NavigationAvailability(
      canShowPrevious: false,
      next: NextAvailability.none,
    ),
  );
  final canShowPrevious = false.obs;
  final canShowNext = false.obs;
  final loading = false.obs;
  final processing = false.obs;
  final mediaSession = Rxn<MediaSessionState>();
  final videoPreparing = false.obs;
  final preparingMessageIds = <int>{}.obs;
  final mediaFailureMessages = <int, String>{}.obs;
  final mediaRetryAttempts = <int, int>{}.obs;
  final isOnline = false.obs;
  final remainingCount = RxnInt();
  final remainingCountLoading = false.obs;

  final List<PipelineMessage> cache = <PipelineMessage>[];
  int currentIndex = -1;
}
