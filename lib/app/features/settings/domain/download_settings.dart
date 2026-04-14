enum DownloadConflictStrategy { skip, rename, overwrite }

enum DownloadMediaFilter { all, photoOnly, videoOnly, audioOnly }

enum DownloadDirectoryMode { byChat, flat }

class DownloadSettings {
  const DownloadSettings({
    required this.workbenchEnabled,
    required this.skipExistingFiles,
    required this.syncDeletedFiles,
    required this.conflictStrategy,
    required this.mediaFilter,
    required this.directoryMode,
  });

  final bool workbenchEnabled;
  final bool skipExistingFiles;
  final bool syncDeletedFiles;
  final DownloadConflictStrategy conflictStrategy;
  final DownloadMediaFilter mediaFilter;
  final DownloadDirectoryMode directoryMode;
}
