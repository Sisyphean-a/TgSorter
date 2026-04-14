import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/media_download_coordinator.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

void main() {
  group('MediaDownloadCoordinator', () {
    test('warmUpPreview downloads photo preview file', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final coordinator = MediaDownloadCoordinator(adapter: adapter);

      await coordinator.warmUpPreview(
        const TdMessageContentDto(
          kind: TdMessageContentKind.photo,
          messageId: 10,
          remoteImageFileId: 110,
          localImagePath: '',
        ),
      );

      expect(adapter.downloadedFileIds, <int>[110]);
      expect(adapter.downloadFileSyncFlags, <bool>[true]);
    });

    test('warmUpPreview downloads video thumbnail only', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final coordinator = MediaDownloadCoordinator(adapter: adapter);

      await coordinator.warmUpPreview(
        const TdMessageContentDto(
          kind: TdMessageContentKind.video,
          messageId: 10,
          remoteVideoThumbnailFileId: 31,
          remoteVideoFileId: 41,
          localVideoThumbnailPath: '',
          localVideoPath: '',
        ),
      );

      expect(adapter.downloadedFileIds, <int>[31]);
    });

    test('warmUpPreview downloads link preview image', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final coordinator = MediaDownloadCoordinator(adapter: adapter);

      await coordinator.warmUpPreview(
        const TdMessageContentDto(
          kind: TdMessageContentKind.text,
          messageId: 10,
          text: TdFormattedTextDto(text: 'hello', entities: []),
          linkPreview: TdLinkPreviewDto(
            url: 'https://example.com',
            displayUrl: 'example.com',
            siteName: 'Example',
            title: 'Example',
            description: 'Desc',
            localImagePath: '',
            remoteImageFileId: 90,
          ),
        ),
      );

      expect(adapter.downloadedFileIds, <int>[90]);
    });

    test('preparePlayback downloads audio file', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final coordinator = MediaDownloadCoordinator(adapter: adapter);

      final changed = await coordinator.preparePlayback(
        const TdMessageContentDto(
          kind: TdMessageContentKind.audio,
          messageId: 10,
          remoteAudioFileId: 55,
          localAudioPath: '',
        ),
      );

      expect(changed, isTrue);
      expect(adapter.downloadedFileIds, <int>[55]);
    });

    test('preparePlayback downloads video file', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final coordinator = MediaDownloadCoordinator(adapter: adapter);

      final changed = await coordinator.preparePlayback(
        const TdMessageContentDto(
          kind: TdMessageContentKind.video,
          messageId: 10,
          remoteVideoFileId: 41,
          localVideoPath: '',
        ),
      );

      expect(changed, isTrue);
      expect(adapter.downloadedFileIds, <int>[41]);
    });

    test('preparePlayback downloads full photo file', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final coordinator = MediaDownloadCoordinator(adapter: adapter);

      final changed = await coordinator.preparePlayback(
        const TdMessageContentDto(
          kind: TdMessageContentKind.photo,
          messageId: 10,
          remoteFullImageFileId: 210,
          fullImagePath: '',
        ),
      );

      expect(changed, isTrue);
      expect(adapter.downloadedFileIds, <int>[210]);
    });

    test(
      'preparePlayback skips download when local path already exists',
      () async {
        final adapter = _FakeTdlibAdapter(wireResponses: const {});
        final coordinator = MediaDownloadCoordinator(adapter: adapter);

        final changed = await coordinator.preparePlayback(
          const TdMessageContentDto(
            kind: TdMessageContentKind.video,
            messageId: 10,
            remoteVideoFileId: 41,
            localVideoPath: '/tmp/video.mp4',
          ),
        );

        expect(changed, isFalse);
        expect(adapter.downloadedFileIds, isEmpty);
      },
    );

    test('warmUpPreview skips when file id is missing', () async {
      final adapter = _FakeTdlibAdapter(wireResponses: const {});
      final coordinator = MediaDownloadCoordinator(adapter: adapter);

      await coordinator.warmUpPreview(
        const TdMessageContentDto(
          kind: TdMessageContentKind.photo,
          messageId: 10,
          remoteImageFileId: null,
          localImagePath: '',
        ),
      );

      expect(adapter.downloadedFileIds, isEmpty);
    });
  });
}

class _FakeTdlibAdapter extends TdlibAdapter {
  _FakeTdlibAdapter({required this.wireResponses})
    : super(
        transport: _NoopTransport(),
        credentials: const TdlibCredentials(
          apiId: 1,
          apiHash: 'hash',
          proxyServer: null,
          proxyPort: null,
          proxyUsername: '',
          proxyPassword: '',
        ),
        readProxySettings: () => const ProxySettings(
          server: '',
          port: null,
          username: '',
          password: '',
        ),
        runtimePaths: const TdlibRuntimePaths(
          libraryPath: 'tdjson.dll',
          databaseDirectory: 'db',
          filesDirectory: 'files',
        ),
        detectCapabilities: () async => const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.flatArgs,
        ),
        initializeTdlib: (_) async {},
      );

  final Map<String, List<TdWireEnvelope>> wireResponses;
  final List<int> downloadedFileIds = <int>[];
  final List<bool> downloadFileSyncFlags = <bool>[];

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final constructor = function.getConstructor();
    if (function is DownloadFile) {
      downloadedFileIds.add(function.fileId);
      downloadFileSyncFlags.add(function.synchronous);
    }
    final queue = wireResponses[constructor];
    if (queue == null || queue.isEmpty) {
      throw StateError('Missing fake wire response for $constructor');
    }
    return queue.removeAt(0);
  }
}

class _NoopTransport implements TdTransport {
  @override
  Stream<TdObject> get updates => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<TdObject> send(TdFunction function) async {
    throw UnimplementedError();
  }

  @override
  void sendWithoutResponse(TdFunction function) {}

  @override
  Future<TdObject> sendWithTimeout(
    TdFunction function,
    Duration timeout,
  ) async {
    throw UnimplementedError();
  }
}
