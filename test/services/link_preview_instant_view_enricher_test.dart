import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/link_preview_instant_view_enricher.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

void main() {
  test('enriches link preview with first instant view photo URL', () async {
    final adapter = _FakeTdlibAdapter(
      wireResponses: <String, List<TdWireEnvelope>>{
        'getWebPageInstantView': [
          TdWireEnvelope.fromJson({
            '@type': 'webPageInstantView',
            'page_blocks': [
              {
                '@type': 'pageBlockParagraph',
                'text': {'text': 'intro', 'entities': []},
              },
              {
                '@type': 'pageBlockPhoto',
                'url': 'https://telegra.ph/file/preview.jpg',
                'caption': {
                  'text': {'text': '', 'entities': []},
                  'credit': {'text': '', 'entities': []},
                },
              },
            ],
          }),
        ],
      },
    );
    final enricher = LinkPreviewInstantViewEnricher(adapter: adapter);

    final enriched = await enricher.enrich(
      const TdMessageDto(
        id: 7,
        mediaAlbumId: null,
        canBeEdited: false,
        content: TdMessageContentDto(
          kind: TdMessageContentKind.text,
          messageId: 7,
          text: TdFormattedTextDto(
            text: 'https://telegra.ph/demo',
            entities: [],
          ),
          linkPreview: TdLinkPreviewDto(
            url: 'https://telegra.ph/demo',
            displayUrl: 'telegra.ph/demo',
            siteName: 'Telegraph',
            title: 'Demo',
            description: '',
          ),
        ),
      ),
    );

    expect(
      enriched.content.linkPreview?.remoteImageUrl,
      'https://telegra.ph/file/preview.jpg',
    );
    expect(adapter.requestedConstructors, ['getWebPageInstantView']);
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
  final List<String> requestedConstructors = <String>[];

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
    requestedConstructors.add(constructor);
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
