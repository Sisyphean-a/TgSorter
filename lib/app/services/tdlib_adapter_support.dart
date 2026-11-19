import 'package:tdlib/td_client.dart';

enum TdlibStartupState { idle, init, setParams, auth, ready, failed, closed }

enum TdlibLifecycleState {
  idle,
  starting,
  running,
  stopping,
  closing,
  closed,
  failed,
}

typedef TdlibInitializer = Future<void> Function(String libraryPath);

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
