import 'dart:io';

class TdlibRuntimeInfo {
  const TdlibRuntimeInfo({
    required this.isAndroid,
    required this.isLinux,
    required this.isWindows,
    required this.isMacOS,
    required this.isIOS,
    required this.executablePath,
    required this.environment,
  });

  factory TdlibRuntimeInfo.current() {
    return TdlibRuntimeInfo(
      isAndroid: Platform.isAndroid,
      isLinux: Platform.isLinux,
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
      isIOS: Platform.isIOS,
      executablePath: Platform.resolvedExecutable,
      environment: Platform.environment,
    );
  }

  final bool isAndroid;
  final bool isLinux;
  final bool isWindows;
  final bool isMacOS;
  final bool isIOS;
  final String executablePath;
  final Map<String, String> environment;
}

String resolveTdlibLibraryPath(TdlibRuntimeInfo runtime) {
  if (runtime.isAndroid || runtime.isLinux) {
    return 'libtdjson.so';
  }
  if (runtime.isMacOS || runtime.isIOS) {
    return 'libtdjson.dylib';
  }
  if (runtime.isWindows) {
    return _resolveWindowsTdlibPath(runtime);
  }
  throw UnsupportedError('当前平台不支持 TDLib 动态库加载');
}

String _resolveWindowsTdlibPath(TdlibRuntimeInfo runtime) {
  const envKey = 'TDLIB_DLL_PATH';
  const dllName = 'tdjson.dll';
  final overridePath = runtime.environment[envKey]?.trim();
  if (overridePath != null && overridePath.isNotEmpty) {
    final envFile = File(overridePath);
    if (!envFile.existsSync()) {
      throw StateError('环境变量 $envKey 指向的文件不存在: $overridePath');
    }
    return envFile.path;
  }

  final executableDir = File(runtime.executablePath).parent.path;
  final defaultPath = '$executableDir\\$dllName';
  final defaultFile = File(defaultPath);
  if (defaultFile.existsSync()) {
    return defaultFile.path;
  }

  throw StateError('未找到 $dllName。请将其放到 $defaultPath，或设置环境变量 $envKey 指向该文件。');
}
