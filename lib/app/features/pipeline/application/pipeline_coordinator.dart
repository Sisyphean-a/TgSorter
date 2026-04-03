import 'package:get/get.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

import 'pipeline_navigation_service.dart';
import 'pipeline_runtime_state.dart';

class PipelineCoordinator extends GetxController {
  PipelineCoordinator({required this.navigation, required this.runtimeState});

  final PipelineNavigationService navigation;
  final PipelineRuntimeState runtimeState;

  Rxn<PipelineMessage> get currentMessage => runtimeState.currentMessage;
  RxBool get canShowPrevious => runtimeState.canShowPrevious;
  RxBool get canShowNext => runtimeState.canShowNext;
}
