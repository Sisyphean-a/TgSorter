import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';

import 'classify_gateway.dart';
import 'media_gateway.dart';
import 'message_read_gateway.dart';
import 'pipeline_settings_reader.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_runtime_state.dart';
import 'recovery_gateway.dart';

class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required MessageReadGateway messages,
    required MediaGateway media,
    required ClassifyGateway classify,
    required RecoveryGateway recovery,
    required PipelineSettingsReader settings,
    required OperationJournalRepository journalRepository,
    required AppErrorController errorController,
    required this.navigation,
    required this.runtimeState,
  }) : _messages = messages,
       _media = media,
       _classify = classify,
       _recovery = recovery,
       _settings = settings,
       _journalRepository = journalRepository,
       _errorController = errorController;

  final MessageReadGateway _messages;
  final MediaGateway _media;
  final ClassifyGateway _classify;
  final RecoveryGateway _recovery;
  final PipelineSettingsReader _settings;
  final OperationJournalRepository _journalRepository;
  final AppErrorController _errorController;
  final PipelineNavigationService navigation;
  final PipelineRuntimeState runtimeState;

  MessageReadGateway get messages => _messages;
  MediaGateway get media => _media;
  ClassifyGateway get classify => _classify;
  RecoveryGateway get recovery => _recovery;
  PipelineSettingsReader get settings => _settings;
  OperationJournalRepository get journalRepository => _journalRepository;
  AppErrorController get errorController => _errorController;

  Rxn<PipelineMessage> get currentMessage => runtimeState.currentMessage;
  RxBool get canShowPrevious => runtimeState.canShowPrevious;
  RxBool get canShowNext => runtimeState.canShowNext;
}
