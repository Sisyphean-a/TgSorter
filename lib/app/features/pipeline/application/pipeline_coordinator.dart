import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';

import 'classify_gateway.dart';
import 'media_gateway.dart';
import 'message_read_gateway.dart';
import 'pipeline_settings_reader.dart';
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
}
