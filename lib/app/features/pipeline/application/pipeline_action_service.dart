import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';

import 'classify_gateway.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_runtime_state.dart';
import 'pipeline_settings_reader.dart';

class PipelineActionService {
  PipelineActionService({
    required PipelineRuntimeState state,
    required PipelineNavigationService navigation,
    required ClassifyGateway classifyGateway,
    required PipelineSettingsReader settings,
    required OperationJournalRepository journalRepository,
  }) : _state = state,
       _navigation = navigation,
       _classifyGateway = classifyGateway,
       _settings = settings,
       _journalRepository = journalRepository;

  final PipelineRuntimeState _state;
  final PipelineNavigationService _navigation;
  final ClassifyGateway _classifyGateway;
  final PipelineSettingsReader _settings;
  final OperationJournalRepository _journalRepository;

  Future<bool> classifyCurrent(String key) async {
    final message = _state.currentMessage.value;
    if (message == null || _state.processing.value) {
      return false;
    }
    final target = _settings.getCategory(key);
    _state.processing.value = true;
    try {
      await _classifyGateway.classifyMessage(
        sourceChatId: message.sourceChatId,
        messageIds: message.messageIds,
        targetChatId: target.targetChatId,
        asCopy: _settings.currentSettings.forwardAsCopy,
      );
      final logs = _journalRepository.loadLogs().toList(growable: true);
      logs.insert(
        0,
        ClassifyOperationLog(
          id: 'ok-${message.id}',
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.success,
        ),
      );
      await _journalRepository.saveLogs(logs);
      _navigation.removeCurrentAndSync();
      return true;
    } finally {
      _state.processing.value = false;
    }
  }
}
