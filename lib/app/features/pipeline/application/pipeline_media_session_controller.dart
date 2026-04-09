import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_projector.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';

abstract interface class PipelineLegacyMediaController {
  bool isPreparingMessageId(int? messageId);

  Future<void> prepareCurrentMedia([int? targetMessageId]);

  Future<void> refreshCurrentMediaIfNeeded();

  void stop();
}

class PipelineMediaSessionController {
  PipelineMediaSessionController({
    required PipelineRuntimeState state,
    required PipelineLegacyMediaController legacyController,
    required MediaSessionProjector projector,
  }) : _state = state,
       _legacyController = legacyController,
       _projector = projector {
    _currentMessageWorker = ever(
      _state.currentMessage,
      (_) => _syncFromRuntime(),
    );
    _preparingFlagWorker = ever(
      _state.videoPreparing,
      (_) => _syncFromRuntime(),
    );
    _preparingIdsWorker = ever(
      _state.preparingMessageIds,
      (_) => _syncFromRuntime(),
    );
    _syncFromRuntime();
  }

  final PipelineRuntimeState _state;
  final PipelineLegacyMediaController _legacyController;
  final MediaSessionProjector _projector;
  int? _activeItemMessageId;
  late final Worker _currentMessageWorker;
  late final Worker _preparingFlagWorker;
  late final Worker _preparingIdsWorker;

  void selectItem(int messageId) {
    _activeItemMessageId = messageId;
    _syncFromRuntime();
  }

  Future<void> requestPlayback([int? targetMessageId]) async {
    final current = _state.currentMessage.value;
    if (current == null) {
      return;
    }
    final targetId =
        targetMessageId ??
        _state.mediaSession.value?.activeItemMessageId ??
        current.id;
    selectItem(targetId);
    await _legacyController.prepareCurrentMedia(targetId);
    _syncFromRuntime();
  }

  Future<void> refreshCurrentMediaIfNeeded() async {
    await _legacyController.refreshCurrentMediaIfNeeded();
    _syncFromRuntime();
  }

  bool isPreparingMessageId(int? messageId) {
    return _legacyController.isPreparingMessageId(messageId);
  }

  void stop() {
    _legacyController.stop();
    _syncFromRuntime();
  }

  void dispose() {
    _currentMessageWorker.dispose();
    _preparingFlagWorker.dispose();
    _preparingIdsWorker.dispose();
  }

  void _syncFromRuntime() {
    final session = _projector.project(
      _state.currentMessage.value,
      currentSession: _state.mediaSession.value,
      activeItemMessageId:
          _activeItemMessageId ??
          _state.mediaSession.value?.activeItemMessageId,
      preparingItemIds: _state.preparingMessageIds,
    );
    _activeItemMessageId = session.activeItemMessageId;
    _state.mediaSession.value = session;
  }
}
