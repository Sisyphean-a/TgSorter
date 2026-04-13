part of 'auth_pipeline_flow_test.dart';

class _IntegrationAuthGateway implements AuthGateway, AuthStateGateway {
  final _authController = StreamController<TdAuthState>.broadcast();
  int restartCalls = 0;

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  void emitAuthState(TdAuthState state) {
    _authController.add(state);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> restart() async {
    restartCalls++;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}
}

class _IntegrationSettingsGateway implements SessionQueryGateway {
  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];
}

class _NoopAuthNavigationPort implements AuthNavigationPort {
  @override
  void goToApp() {}

  @override
  void goToAuth() {}
}

class _IntegrationPipelineGateway
    implements
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway,
        TaggingGateway {
  final _connectionController = StreamController<TdConnectionState>.broadcast();

  @override
  Stream<TdConnectionState> get connectionStates =>
      _connectionController.stream;

  void emitConnectionReady() {
    _connectionController.add(
      const TdConnectionState(
        kind: TdConnectionStateKind.ready,
        rawType: 'connectionStateReady',
      ),
    );
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 0;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    return const [];
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    return null;
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    return ClassifyRecoverySummary.empty;
  }

  @override
  Future<ApplyTagResult> applyTag({
    required int sourceChatId,
    required List<int> messageIds,
    required String tagName,
  }) async {
    throw UnimplementedError();
  }
}
