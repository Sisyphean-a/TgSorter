import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class PipelineNavigationService {
  PipelineNavigationService({required PipelineRuntimeState state})
    : _state = state;

  final PipelineRuntimeState _state;

  void replaceMessages(List<PipelineMessage> messages) {
    _state.cache
      ..clear()
      ..addAll(messages);
    _state.currentIndex = messages.isEmpty ? -1 : 0;
    syncCurrentMessage();
  }

  Future<void> showNext() async {
    if (_state.currentIndex + 1 >= _state.cache.length) {
      return;
    }
    _state.currentIndex++;
    syncCurrentMessage();
  }

  Future<void> showPrevious() async {
    if (_state.currentIndex <= 0) {
      return;
    }
    _state.currentIndex--;
    syncCurrentMessage();
  }

  void syncCurrentMessage() {
    _state.currentMessage.value = _state.currentIndex < 0
        ? null
        : _state.cache[_state.currentIndex];
    syncNavigationState();
  }

  void syncNavigationState() {
    _state.canShowPrevious.value = _state.currentIndex > 0;
    _state.canShowNext.value =
        _state.currentIndex >= 0 &&
        _state.currentIndex + 1 < _state.cache.length;
  }
}
