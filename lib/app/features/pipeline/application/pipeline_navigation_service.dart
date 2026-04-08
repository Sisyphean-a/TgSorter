import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class PipelineNavigationService {
  PipelineNavigationService({required PipelineRuntimeState state})
    : _state = state;

  final PipelineRuntimeState _state;

  bool get isEmpty => _state.cache.isEmpty;

  void replaceMessages(List<PipelineMessage> messages) {
    _state.cache
      ..clear()
      ..addAll(messages);
    _state.currentIndex = messages.isEmpty ? -1 : 0;
    syncCurrentMessage();
  }

  void appendUniqueMessages(List<PipelineMessage> messages) {
    if (messages.isEmpty) {
      return;
    }
    final knownIds = _state.cache.map((item) => item.id).toSet();
    for (final item in messages) {
      if (knownIds.add(item.id)) {
        _state.cache.add(item);
      }
    }
    syncNavigationState();
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

  void removeCurrent() {
    if (_state.currentIndex < 0 || _state.currentIndex >= _state.cache.length) {
      return;
    }
    _state.cache.removeAt(_state.currentIndex);
    syncNavigationState();
  }

  void removeCurrentAndSync() {
    removeCurrent();
    ensureCurrentAndSync();
  }

  void ensureCurrentIndex() {
    if (_state.cache.isEmpty) {
      _state.currentIndex = -1;
      return;
    }
    if (_state.currentIndex < 0) {
      _state.currentIndex = 0;
      return;
    }
    if (_state.currentIndex >= _state.cache.length) {
      _state.currentIndex = _state.cache.length - 1;
    }
  }

  void ensureCurrentAndSync() {
    ensureCurrentIndex();
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
    _state.canShowNext.value = _hasCachedNext() || _hasUnloadedNext();
  }

  bool _hasCachedNext() {
    return _state.currentIndex >= 0 && _state.currentIndex + 1 < _state.cache.length;
  }

  bool _hasUnloadedNext() {
    final remainingCount = _state.remainingCount.value;
    if (remainingCount == null || _state.currentIndex < 0) {
      return false;
    }
    return _state.currentIndex + 1 < remainingCount;
  }
}
