import 'dart:async';
import 'dart:convert';

import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

enum TdlibStartupState {
  idle,
  init,
  setParams,
  setProxy,
  auth,
  ready,
  failed,
  closed,
}

typedef TdlibCapabilitiesDetector = Future<TdlibSchemaCapabilities> Function();
typedef TdlibInitializer = Future<void> Function(String libraryPath);

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
  static const Duration _authRequestTimeout = Duration(minutes: 2);

  final TdTransport _transport;
  final TdlibCredentials _credentials;
  final TdlibRuntimePaths _runtimePaths;
  final TdlibCapabilitiesDetector _detectCapabilities;
  final TdlibInitializer _initializeTdlib;

  final _authStateController = StreamController<AuthorizationState>.broadcast(
    sync: true,
  );
  final _connectionController = StreamController<ConnectionState>.broadcast(
    sync: true,
  );
  final _startupController = StreamController<TdlibStartupState>.broadcast(
    sync: true,
  );

  StreamSubscription<TdObject>? _updatesSub;
  Completer<void>? _startCompleter;
  Completer<void> _authorizationReady = Completer<void>();
  TdlibSchemaCapabilities? _capabilities;

  Stream<AuthorizationState> get authorizationStates =>
      _authStateController.stream;
  Stream<ConnectionState> get connectionStates => _connectionController.stream;
  Stream<TdlibStartupState> get startupStates => _startupController.stream;

  TdlibSchemaCapabilities? get capabilities => _capabilities;

  Future<void> start() async {
    final running = _startCompleter;
    if (running != null) {
      return running.future;
    }
    final completer = Completer<void>();
    _startCompleter = completer;
    try {
      _emitStartup(TdlibStartupState.init);
      await _initializeTdlib(_runtimePaths.libraryPath);
      await _transport.start();
      _updatesSub ??= _transport.updates.listen(
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
      completer.complete();
    } catch (error, stackTrace) {
      _emitStartup(TdlibStartupState.failed);
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      _startCompleter = null;
      rethrow;
    }
  }

  Future<void> submitPhoneNumber(String phoneNumber) {
    return _sendExpectOk(
      SetAuthenticationPhoneNumber(phoneNumber: phoneNumber),
      request: 'setAuthenticationPhoneNumber',
      phase: TdlibPhase.auth,
      timeout: _authRequestTimeout,
    );
  }

  Future<void> submitCode(String code) {
    return _sendExpectOk(
      CheckAuthenticationCode(code: code),
      request: 'checkAuthenticationCode',
      phase: TdlibPhase.auth,
      timeout: _authRequestTimeout,
    );
  }

  Future<void> submitPassword(String password) {
    return _sendExpectOk(
      CheckAuthenticationPassword(password: password),
      request: 'checkAuthenticationPassword',
      phase: TdlibPhase.auth,
      timeout: _authRequestTimeout,
    );
  }

  Future<Proxies> getProxies() async {
    final object = await send(
      const GetProxies(),
      request: 'getProxies',
      phase: TdlibPhase.startup,
    );
    if (object is! Proxies) {
      throw StateError('GetProxies 返回类型异常: ${object.getConstructor()}');
    }
    return object;
  }

  Future<void> addProxy() async {
    final server = _credentials.proxyServer;
    final port = _credentials.proxyPort;
    if (server == null || port == null) {
      throw StateError('代理未配置，无法执行 addProxy');
    }
    final capabilities = _capabilities ?? await _detectCapabilities();
    _capabilities = capabilities;
    if (capabilities.addProxyMode == TdlibAddProxyMode.flatArgs) {
      await _sendExpectOk(
        AddProxy(
          server: server,
          port: port,
          enable: true,
          type: ProxyTypeSocks5(
            username: _credentials.proxyUsername,
            password: _credentials.proxyPassword,
          ),
        ),
        request: 'addProxy',
        phase: TdlibPhase.startup,
      );
      return;
    }
    final request = _AddProxyCompatRequest(
      server: server,
      port: port,
      username: _credentials.proxyUsername,
      password: _credentials.proxyPassword,
    );
    _transport.sendWithoutResponse(request);
    final proxies = await getProxies();
    final matched = proxies.proxies.any(
      (proxy) =>
          proxy.server == server && proxy.port == port && proxy.isEnabled,
    );
    if (!matched) {
      throw TdlibFailure.transport(
        message: '代理兼容配置后未发现已启用代理 $server:$port',
        request: 'addProxy',
        phase: TdlibPhase.startup,
      );
    }
  }

  Future<void> disableProxy() {
    return _sendExpectOk(
      const DisableProxy(),
      request: 'disableProxy',
      phase: TdlibPhase.startup,
    );
  }

  Future<TdObject> send(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final object = await _transport.sendWithTimeout(function, timeout);
      return _assertNoError(object, request: request, phase: phase);
    } on TimeoutException catch (error, stackTrace) {
      throw TdlibFailure.timeout(
        request: request,
        phase: phase,
        message: 'TDLib request timeout',
        cause: error,
        stackTrace: stackTrace,
      );
    } on TdlibFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw TdlibFailure.transport(
        message: error.toString(),
        request: request,
        phase: phase,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

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
  }) async {
    final object = await send(
      function,
      request: request,
      phase: phase,
      timeout: timeout,
    );
    if (object is! Ok) {
      throw StateError('请求返回非 Ok: ${object.getConstructor()}');
    }
  }

  TdObject _assertNoError(
    TdObject object, {
    required String request,
    required TdlibPhase phase,
  }) {
    if (object is! TdError) {
      return object;
    }
    throw TdlibFailure.tdError(
      code: object.code,
      message: object.message,
      request: request,
      phase: phase,
    );
  }

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
      _authorizationReady = Completer<void>();
      _emitStartup(TdlibStartupState.closed);
    }
  }

  void _emitStartup(TdlibStartupState state) {
    _startupController.add(state);
  }
}

class _AddProxyCompatRequest extends TdFunction {
  const _AddProxyCompatRequest({
    required this.server,
    required this.port,
    required this.username,
    required this.password,
  });

  final String server;
  final int port;
  final String username;
  final String password;

  @override
  String getConstructor() => 'addProxy';

  @override
  Map<String, dynamic> toJson([dynamic extra]) {
    return <String, dynamic>{
      '@type': getConstructor(),
      'proxy': <String, dynamic>{
        'server': server,
        'port': port,
        'type': <String, dynamic>{
          '@type': 'proxyTypeSocks5',
          'username': username,
          'password': password,
        },
      },
      'enable': true,
      '@extra': extra,
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}

Future<void> defaultTdlibInitializer(String libraryPath) {
  return TdPlugin.initialize(libraryPath);
}
