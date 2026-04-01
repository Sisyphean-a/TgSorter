import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:tgsorter/app/services/tdlib_library_locator.dart';

class TdlibRuntimePaths {
  const TdlibRuntimePaths({
    required this.libraryPath,
    required this.databaseDirectory,
    required this.filesDirectory,
  });

  final String libraryPath;
  final String databaseDirectory;
  final String filesDirectory;
}

Future<TdlibRuntimePaths> resolveTdlibRuntimePaths() async {
  final baseDir = await getApplicationSupportDirectory();
  final databaseDirectory = Directory('${baseDir.path}/tgsorter/tdlib/db');
  final filesDirectory = Directory('${baseDir.path}/tgsorter/tdlib/files');
  await databaseDirectory.create(recursive: true);
  await filesDirectory.create(recursive: true);
  return TdlibRuntimePaths(
    libraryPath: resolveTdlibLibraryPath(TdlibRuntimeInfo.current()),
    databaseDirectory: databaseDirectory.path,
    filesDirectory: filesDirectory.path,
  );
}
