import 'dart:convert';

import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';
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

enum TdlibLifecycleState {
  idle,
  starting,
  running,
  stopping,
  closing,
  closed,
  failed,
}

typedef TdlibCapabilitiesDetector = Future<TdlibSchemaCapabilities> Function();
typedef TdlibInitializer = Future<void> Function(String libraryPath);

class AddProxyCompatRequest extends TdFunction {
  const AddProxyCompatRequest({
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

Future<void> configureTdPlugin({
  required String libraryPath,
  required void Function() registerNativePlugin,
  required Future<void> Function(String libraryPath) initializePlugin,
}) async {
  registerNativePlugin();
  await initializePlugin(libraryPath);
}

Future<void> defaultTdlibInitializer(String libraryPath) {
  return configureTdPlugin(
    libraryPath: libraryPath,
    registerNativePlugin: TdNativePlugin.registerWith,
    initializePlugin: (path) => TdPlugin.initialize(path),
  );
}
