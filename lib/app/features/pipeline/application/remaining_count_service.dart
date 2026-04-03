class RemainingCountService {
  int _requestId = 0;

  int beginRequest() {
    _requestId++;
    return _requestId;
  }

  bool shouldApply(int requestId) => requestId == _requestId;
}
