import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_dedup_media_gateway.dart';

void main() {
  test(
    'offers forwarding source chats and resolves Saved Messages to its chat ID',
    () async {
      final adapter = _Adapter();
      adapter.reply = (request) => switch (request['@type']) {
        'loadChats' => throw TdlibFailure.tdError(
          code: 404,
          message: 'No more chats',
          request: 'loadChats',
          phase: TdlibPhase.business,
        ),
        'getChats' => {
          'chat_ids': [-1001, -2000, 42, 50],
        },
        'getChat' => switch (request['chat_id']) {
          -1001 => {
            'id': -1001,
            'title': '资料群',
            'type': {'@type': 'chatTypeBasicGroup'},
          },
          -2000 => {
            'id': -2000,
            'title': '资料频道',
            'type': {'@type': 'chatTypeSupergroup', 'is_channel': true},
          },
          final id => {
            'id': id,
            'title': '私聊',
            'type': {'@type': 'chatTypePrivate'},
          },
        },
        'getOption' => {'@type': 'optionValueInteger', 'value': '42'},
        'createPrivateChat' => {
          '@type': 'chat',
          'id': 42,
          'title': '收藏夹',
          'type': {'@type': 'chatTypePrivate'},
        },
        _ => throw StateError('unexpected request'),
      };
      final gateway = TelegramDedupMediaGateway(adapter);

      final chats = await gateway.listChats();
      expect(chats.first.title, '收藏夹（Saved Messages）');
      expect(chats.first.id, 42);
      expect(
        chats.skip(1).map((chat) => chat.id),
        unorderedEquals([-1001, -2000]),
      );

      adapter.reply = (request) {
        expect(request['@type'], 'getChatHistory');
        expect(request['chat_id'], 42);
        return {'messages': []};
      };
      expect(await gateway.readHistory(chats.first.id).toList(), isEmpty);
    },
  );

  test('音频和语音按各自文件标识去重，只读取历史元数据', () async {
    final adapter = _Adapter();
    Map<String, dynamic> audio(int id, int fileId, String identity) =>
        _message(id, {
          '@type': 'messageAudio',
          'caption': {'text': '音频说明'},
          'audio': {
            'audio': {
              ..._file(fileId, 123),
              'remote': {'unique_id': identity},
            },
            'duration': 90,
            'title': '访谈',
            'performer': '主持人',
          },
        });
    Map<String, dynamic> voice(int id, int fileId) => _message(id, {
      '@type': 'messageVoiceNote',
      'caption': {'text': ''},
      'voice_note': {
        'voice': {
          ..._file(fileId, 0),
          'remote': {'unique_id': 'shared'},
        },
        'duration': 12,
      },
    });
    final messages = [
      audio(50, 1, 'shared'),
      voice(40, 2),
      audio(30, 3, 'different'),
      audio(20, 4, 'shared'),
      voice(10, 5),
    ];
    adapter.reply = (request) {
      expect(request['@type'], 'getChatHistory');
      return {'messages': request['from_message_id'] == 0 ? messages : []};
    };
    final result = await MediaDedupWorkbench(
      TelegramDedupMediaGateway(adapter),
    ).scan(-1001, stop: DedupScanStop(), onProgress: (_) {});
    expect(result.groups.map((group) => group.kind), [
      DedupMediaKind.audio,
      DedupMediaKind.voiceNote,
    ]);
    expect(
      result.groups.map((group) => group.copies.map((copy) => copy.messageId)),
      [
        [50, 20],
        [40, 10],
      ],
    );
    final track = result.groups.first.copies.first;
    expect(track.audioTitle, '访谈');
    expect(track.audioPerformer, '主持人');
    expect(track.caption, '音频说明');
    expect(track.durationSeconds, 90);
    expect(result.groups.last.copies.first.durationSeconds, 12);
  });

  test('续扫从超时的历史游标继续，跨页副本只归组一次', () async {
    final adapter = _Adapter();
    final text = _message(30, {'@type': 'messageText'});
    var timeOut = true;
    adapter.reply = (request) {
      expect(request['@type'], 'getChatHistory');
      final cursor = request['from_message_id'];
      if (cursor == 30 && timeOut) {
        throw TdlibFailure.timeout(
          request: 'getChatHistory',
          phase: TdlibPhase.business,
          message: 'timeout',
        );
      }
      return {
        'messages': switch (cursor) {
          0 => [_photo(40, 10), text],
          30 => [text, _photo(20, 10)],
          20 => [],
          _ => throw StateError('unexpected cursor: $cursor'),
        },
      };
    };
    final workbench = MediaDedupWorkbench(TelegramDedupMediaGateway(adapter));
    final counts = <int>[];
    late DedupScanCheckpoint checkpoint;
    try {
      await workbench.scan(
        -1001,
        stop: DedupScanStop(),
        onProgress: counts.add,
      );
      fail('应报告读取超时');
    } on DedupScanInterrupted catch (interrupted) {
      checkpoint = interrupted.checkpoint;
    }
    expect(checkpoint.inspected, 1);
    timeOut = false;
    final result = await workbench.scan(
      -1001,
      stop: DedupScanStop(),
      onProgress: counts.add,
      resumeFrom: checkpoint,
    );
    expect(counts, [0, 1, 1, 2]);
    expect(result.groups.single.copies.map((copy) => copy.messageId), [40, 20]);
    expect(adapter.requests.map((request) => request['from_message_id']), [
      0,
      30,
      30,
      20,
    ]);
  });

  test('pages through mixed albums and uses full photos and videos', () async {
    final adapter = _Adapter();
    final photo = _photo(40, 10);
    final video = _message(30, {
      '@type': 'messageVideo',
      'caption': {'text': ''},
      'video': {
        'video': _file(11, 123),
        'duration': 601,
        'minithumbnail': {'data': 'AA=='},
        'thumbnail': {'file': _file(99, 20)},
      },
    });
    adapter.reply = (request) {
      expect(request['chat_id'], -1001);
      expect(request['only_local'], false);
      return {
        '@type': 'messages',
        'messages': switch (request['from_message_id']) {
          0 => [photo, video],
          30 => [
            video,
            _message(20, {'@type': 'messageText'}),
            _photo(10, 12),
          ],
          10 => [],
          _ => throw StateError('unexpected cursor'),
        },
      };
    };

    final history = await TelegramDedupMediaGateway(adapter)
        .readHistory(-1001)
        .where((entry) => entry.media != null)
        .map((entry) => entry.media!)
        .toList();
    expect(history.map((item) => (item.messageId, item.fileId, item.size)), [
      (40, 10, 100),
      (30, 11, 123),
      (10, 12, 100),
    ]);
    expect(history.first.caption, '第一份');
    expect(history.first.fileUniqueId, 'file-10');
    expect(history.first.photoPreviewFileId, 97);
    expect(history[1].fileUniqueId, 'file-11');
    expect(history[1].durationSeconds, 601);
    expect(history[1].inlineThumbnail, 'AA==');
    expect(
      adapter.requests.map((request) => request['@type']),
      everyElement('getChatHistory'),
    );
  });

  test(
    'uses deletion permission from both TDLib schemas and aborts on edits',
    () async {
      final adapter = _Adapter();
      final gateway = TelegramDedupMediaGateway(adapter);
      final original = await _readFirst(gateway, adapter);

      adapter.reply = (request) => {
        ..._photo(40, 10),
        'can_be_deleted_for_all_users': false,
      };
      await expectLater(
        gateway.verifyMessage(original, forDeletion: true),
        throwsStateError,
      );
      expect(adapter.requests.last['@type'], 'getMessage');
      await gateway.verifyMessage(original, forDeletion: false);

      adapter.reply = (request) => switch (request['@type']) {
        'getMessage' => _photo(40, 10),
        'getMessageProperties' => {
          '@type': 'messageProperties',
          'can_be_deleted_for_all_users': true,
        },
        _ => throw StateError('unexpected request'),
      };
      await gateway.verifyMessage(original, forDeletion: true);
      expect(adapter.requests.last['@type'], 'getMessageProperties');
      expect(adapter.requests.last['chat_id'], -1001);
      expect(adapter.requests.last['message_id'], 40);

      adapter.reply = (_) => _photo(40, 11);
      await expectLater(
        gateway.verifyMessage(original, forDeletion: false),
        throwsStateError,
      );
      adapter.reply = (request) => {..._photo(40, 10), 'edit_date': 5};
      await expectLater(
        gateway.verifyMessage(original, forDeletion: false),
        throwsStateError,
      );
      expect(
        adapter.requests.where(
          (request) => request['@type'] == 'deleteMessages',
        ),
        isEmpty,
      );
    },
  );

  test('只按请求加载指定照片文件，且要求完整文件', () async {
    final adapter = _Adapter();
    var complete = false;
    adapter.reply = (request) {
      expect(request, containsPair('@type', 'downloadFile'));
      expect(request, containsPair('file_id', 97));
      expect(request, containsPair('synchronous', true));
      return {
        '@type': 'file',
        'local': {'is_downloading_completed': complete, 'path': 'photo.jpg'},
      };
    };
    final gateway = TelegramDedupMediaGateway(adapter);
    await expectLater(gateway.loadPhotoFile(97), throwsStateError);
    complete = true;
    expect(await gateway.loadPhotoFile(97), 'photo.jpg');
  });

  test('sends revocable deletion only for the specified message ids', () async {
    final adapter = _Adapter()..reply = (_) => {'@type': 'ok'};
    await TelegramDedupMediaGateway(adapter).deleteMessages(-1001, [30, 20]);
    expect(adapter.requests.single, containsPair('chat_id', -1001));
    expect(adapter.requests.single, containsPair('message_ids', [30, 20]));
    expect(adapter.requests.single, containsPair('revoke', true));
  });
}

Future<DedupMedia> _readFirst(
  TelegramDedupMediaGateway gateway,
  _Adapter adapter,
) async {
  adapter.reply = (_) => {
    '@type': 'messages',
    'messages': [_photo(40, 10)],
  };
  return (await gateway.readHistory(-1001).first).media!;
}

Map<String, dynamic> _file(int id, int size) => {
  'id': id,
  'size': size,
  'remote': {'unique_id': 'file-$id'},
};

Map<String, dynamic> _photo(int id, int fileId) => _message(id, {
  '@type': 'messagePhoto',
  'caption': {'text': '第一份'},
  'photo': {
    'sizes': [
      {'width': 1500, 'height': 1500, 'photo': _file(fileId, 100)},
      {'width': 900, 'height': 900, 'photo': _file(96, 40)},
      {'width': 640, 'height': 640, 'photo': _file(97, 20)},
      {'width': 100, 'height': 100, 'photo': _file(98, 1)},
    ],
  },
});

Map<String, dynamic> _message(int id, Map<String, dynamic> content) => {
  '@type': 'message',
  'chat_id': -1001,
  'id': id,
  'media_album_id': id >= 30 ? '1' : '2',
  'date': 1710000000,
  'edit_date': 0,
  'content': content,
};

class _Adapter extends Fake implements TdlibAdapter {
  final requests = <Map<String, dynamic>>[];
  late Map<String, dynamic> Function(Map<String, dynamic>) reply;

  @override
  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final payload = function.toJson();
    requests.add(payload);
    return TdWireEnvelope.fromJson(reply(payload));
  }

  @override
  Future<void> sendWireExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final envelope = await sendWire(
      function,
      request: request,
      phase: phase,
      timeout: timeout,
    );
    expect(envelope.type, 'ok');
  }
}
