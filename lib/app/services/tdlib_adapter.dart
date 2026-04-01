import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_adapter_support.dart';
import 'package:tgsorter/app/services/tdlib_auth_manager.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_proxy_manager.dart';
import 'package:tgsorter/app/services/tdlib_request_executor.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

export 'package:tgsorter/app/services/tdlib_adapter_support.dart';

class TdlibAdapter {
  TdlibAdapter({
    required TdTransport transport,
    required TdlibCredentials credentials,
    required TdlibRuntimePaths runtimePaths,
    required TdlibCapabilitiesDetector detectCapabilities,
    required TdlibInitializer initializeTdlib,
  }) : _transport = transport,
       _credentials = credentials,
       _runtimePaths = runtimePaths,
       _detectCapabilities = detectCapabilities,
       _initializeTdlib = initializeTdlib;

  static const Duration _defaultTimeout = Duration(seconds: 20);
  final TdTransport _transport;
  final TdlibCredentials _credentials;
  final TdlibRuntimePaths _runtimePaths;
  final TdlibCapabilitiesDetector _detectCapabilities;
  final TdlibInitializer _initializeTdlib;
  late final TdlibRequestExecutor _requestExecutor = TdlibRequestExecutor(
    transport: _transport,
  );
  late final TdlibProxyManager _proxyManager = TdlibProxyManager(
    transport: _transport,
    credentials: _credentials,
    requestExecutor: _requestExecutor,
  );
  late final TdlibAuthManager _authManager = TdlibAuthManager(
    requestExecutor: _requestExecutor,
  );

  final _authStateController = StreamController<AuthorizationState>.broadcast(
    sync: true,
  );
  final _connectionController = StreamController<ConnectionState>.broadcast(
    sync: true,
  );
  final _startupController = StreamController<TdlibStartupState>.broadcast(
    sync: true,
  );
  final _lifecycleController = StreamController<TdlibLifecycleState>.broadcast(
    sync: true,
  );

  StreamSubscription<TdObject>? _updatesSub;
  Completer<void>? _startCompleter;
  Completer<void>? _closeCompleter;
  Completer<void> _authorizationReady = Completer<void>();
  TdlibSchemaCapabilities? _capabilities;
  TdlibLifecycleState _lifecycleState = TdlibLifecycleState.idle;

  Stream<AuthorizationState> get authorizationStates =>
      _authStateController.stream;
  Stream<ConnectionState> get connectionStates => _connectionController.stream;
  Stream<TdlibStartupState> get startupStates => _startupController.stream;
  Stream<TdlibLifecycleState> get lifecycleStates =>
      _lifecycleController.stream;

  TdlibSchemaCapabilities? get capabilities => _capabilities;
  TdlibLifecycleState get lifecycleState => _lifecycleState;
  bool get isRunning => _lifecycleState == TdlibLifecycleState.running;

  Future<void> start() async {
    final running = _startCompleter;
    if (running != null) {
      return running.future;
    }
    final completer = Completer<void>();
    _startCompleter = completer;
    try {
      _emitLifecycle(TdlibLifecycleState.starting);
      _emitStartup(TdlibStartupState.init);
      await _initializeTdlib(_runtimePaths.libraryPath);
      await _transport.start();
      _updatesSub = _transport.updates.listen(
        _handleUpdate,
        onError: _handleTransportError,
      );
      _capabilities ??= await _detectCapabilities();
      final state = await _getAuthorizationState();
      if (state is AuthorizationStateWaitTdlibParameters) {
        _emitStartup(TdlibStartupState.setParams);
        await _setTdlibParameters();
      }
      _emitStartup(TdlibStartupState.setProxy);
      await _syncProxy();
      _emitStartup(TdlibStartupState.auth);
      if (state is AuthorizationStateReady) {
        _recordAuthorizationState(state);
        _emitStartup(TdlibStartupState.ready);
      }
      _emitLifecycle(TdlibLifecycleState.running);
      completer.complete();
    } catch (error, stackTrace) {
      _emitLifecycle(TdlibLifecycleState.failed);
      _emitStartup(TdlibStartupState.failed);
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      _startCompleter = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_lifecycleState == TdlibLifecycleState.idle ||
        _lifecycleState == TdlibLifecycleState.closed) {
      return;
    }
    _emitLifecycle(TdlibLifecycleState.stopping);
    await _disposeTransport();
    _resetSessionState();
    _emitLifecycle(TdlibLifecycleState.idle);
  }

  Future<void> close() async {
    if (_lifecycleState == TdlibLifecycleState.closed) {
      return;
    }
    if (_lifecycleState == TdlibLifecycleState.idle) {
      _resetSessionState();
      _emitStartup(TdlibStartupState.closed);
      _emitLifecycle(TdlibLifecycleState.closed);
      return;
    }
    _emitLifecycle(TdlibLifecycleState.closing);
    _closeCompleter ??= Completer<void>();
    await _sendExpectOk(
      const Close(),
      request: 'close',
      phase: TdlibPhase.startup,
    );
    await _closeCompleter!.future;
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> submitPhoneNumber(String phoneNumber) =>
      _authManager.submitPhoneNumber(phoneNumber);

  Future<void> submitCode(String code) => _authManager.submitCode(code);

  Future<void> submitPassword(String password) =>
      _authManager.submitPassword(password);

  Future<Proxies> getProxies() async {
    return _proxyManager.getProxies();
  }

  Future<void> addProxy() async {
    final capabilities = _capabilities ?? await _detectCapabilities();
    _capabilities = capabilities;
    await _proxyManager.addProxy(capabilities);
  }

  Future<void> disableProxy() {
    return _proxyManager.disableProxy();
  }

  Future<TdObject> send(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = _defaultTimeout,
  }) => _requestExecutor.send(
    function,
    request: request,
    phase: phase,
    timeout: timeout,
  );

  Future<void> waitUntilReady() {
    if (_authorizationReady.isCompleted) {
      return Future<void>.value();
    }
    return _authorizationReady.future;
  }

  Future<AuthorizationState> _getAuthorizationState() async {
    final object = await send(
      const GetAuthorizationState(),
      request: 'getAuthorizationState',
      phase: TdlibPhase.startup,
    );
    if (object is! AuthorizationState) {
      throw StateError(
        'GetAuthorizationState 返回类型异常: ${object.getConstructor()}',
      );
    }
    _authStateController.add(object);
    return object;
  }

  Future<void> _setTdlibParameters() {
    return _sendExpectOk(
      SetTdlibParameters(
        useTestDc: false,
        databaseDirectory: _runtimePaths.databaseDirectory,
        filesDirectory: _runtimePaths.filesDirectory,
        databaseEncryptionKey: '',
        useFileDatabase: true,
        useChatInfoDatabase: true,
        useMessageDatabase: true,
        useSecretChats: false,
        apiId: _credentials.apiId,
        apiHash: _credentials.apiHash,
        systemLanguageCode: 'zh-hans',
        deviceModel: 'Flutter',
        systemVersion: 'unknown',
        applicationVersion: '1.0.0',
        enableStorageOptimizer: true,
        ignoreFileNames: false,
      ),
      request: 'setTdlibParameters',
      phase: TdlibPhase.startup,
    );
  }

  Future<void> _syncProxy() async {
    if (_credentials.proxyServer == null || _credentials.proxyPort == null) {
      await disableProxy();
      return;
    }
    await addProxy();
  }

  Future<void> _sendExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = _defaultTimeout,
  }) => _requestExecutor.sendExpectOk(
    function,
    request: request,
    phase: phase,
    timeout: timeout,
  );

  void _handleUpdate(TdObject update) {
    if (update is UpdateAuthorizationState) {
      _authStateController.add(update.authorizationState);
      _recordAuthorizationState(update.authorizationState);
      return;
    }
    if (update is UpdateConnectionState) {
      _connectionController.add(update.state);
    }
  }

  void _handleTransportError(Object error, StackTrace stackTrace) {
    final failure = TdlibFailure.transport(
      message: error.toString(),
      request: 'updates',
      phase: TdlibPhase.startup,
      cause: error,
      stackTrace: stackTrace,
    );
    _authStateController.addError(failure, stackTrace);
    _connectionController.addError(failure, stackTrace);
  }

  void _recordAuthorizationState(AuthorizationState state) {
    if (state is AuthorizationStateReady) {
      if (!_authorizationReady.isCompleted) {
        _authorizationReady.complete();
      }
      _emitStartup(TdlibStartupState.ready);
      return;
    }
    if (state is AuthorizationStateClosed) {
      _completeClose();
      _emitStartup(TdlibStartupState.closed);
    }
  }

  void _emitStartup(TdlibStartupState state) {
    _startupController.add(state);
  }

  void _emitLifecycle(TdlibLifecycleState state) {
    _lifecycleState = state;
    _lifecycleController.add(state);
  }

  Future<void> _disposeTransport() async {
    await _updatesSub?.cancel();
    _updatesSub = null;
    await _transport.stop();
  }

  void _resetSessionState() {
    _startCompleter = null;
    _closeCompleter = null;
    _authorizationReady = Completer<void>();
  }

  void _completeClose() {
    final completer = _closeCompleter;
    unawaited(
      _finishClose().then((_) {
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }),
    );
  }

  Future<void> _finishClose() async {
    await _disposeTransport();
    _resetSessionState();
    _emitLifecycle(TdlibLifecycleState.closed);
  }
}
