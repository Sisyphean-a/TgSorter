class RemainingCountService {
  int _requestId = 0;

  int beginRequest() {
    _requestId++;
    return _requestId;
  }

  bool shouldApply(int requestId) => requestId == _requestId;

  Future<void> refreshRemainingCount({
    required Future<int> Function() loadCount,
    required void Function() onStart,
    required void Function(int count) onSuccess,
    required void Function(Object error) onError,
    required void Function() onComplete,
  }) async {
    final requestId = beginRequest();
    onStart();
    try {
      final nextCount = await loadCount();
      if (!shouldApply(requestId)) {
        return;
      }
      onSuccess(nextCount);
    } catch (error) {
      if (!shouldApply(requestId)) {
        return;
      }
      onError(error);
    } finally {
      if (shouldApply(requestId)) {
        onComplete();
      }
    }
  }
}
