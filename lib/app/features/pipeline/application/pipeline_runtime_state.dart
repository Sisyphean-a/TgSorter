import 'package:get/get.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class PipelineRuntimeState {
  final currentMessage = Rxn<PipelineMessage>();
  final canShowPrevious = false.obs;
  final canShowNext = false.obs;
  final loading = false.obs;
  final processing = false.obs;
  final videoPreparing = false.obs;
  final preparingMessageIds = <int>{}.obs;
  final isOnline = false.obs;
  final remainingCount = RxnInt();
  final remainingCountLoading = false.obs;

  final List<PipelineMessage> cache = <PipelineMessage>[];
  int currentIndex = -1;
}
