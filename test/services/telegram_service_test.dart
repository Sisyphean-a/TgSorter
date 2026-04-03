import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';
import 'package:tgsorter/app/services/telegram_media_service.dart';
import 'package:tgsorter/app/services/telegram_message_reader.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

void main() {
  group('TelegramService', () {
    test('fetchNextMessage for video downloads thumbnail only', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'getChatHistory': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [
                {
                  'id': 10,
                  'content': {
                    '@type': 'messageVideo',
                    'caption': {'text': '', 'entities': []},
                    'video': {
                      'duration': 12,
                      'thumbnail': {
                        'file': {
                          'id': 31,
                          'local': {'path': ''},
                        },
                      },
                      'video': {
                        'id': 32,
                        'local': {'path': ''},
                      },
                    },
                  },
                },
              ],
            }),
          ],
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final service = TelegramService(adapter: adapter);

      await service.fetchNextMessage(
        direction: MessageFetchDirection.latestFirst,
        sourceChatId: 777,
      );

      expect(adapter.downloadedFileIds, <int>[31]);
    });

    test(
      'fetchMessagePage skips duplicate cursor in latestFirst mode',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _textMessageJson(10, 'first'),
                  _textMessageJson(9, 'second'),
                ],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: 10,
          limit: 2,
        );

        expect(page.map((item) => item.id), [9]);
      },
    );

    test(
      'classifyMessage does not delete when forward returns empty',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await expectLater(
          () => service.classifyMessage(
            sourceChatId: 777,
            messageIds: const [10],
            targetChatId: 999,
            asCopy: false,
          ),
          throwsA(isA<StateError>()),
        );

        expect(adapter.deleteMessageCalls, 0);
      },
    );

    test(
      'classifyMessage uses sendCopy when no-reference mode is enabled',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [_textMessageJson(88, 'copied')],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await service.classifyMessage(
          sourceChatId: 777,
          messageIds: const [10],
          targetChatId: 999,
          asCopy: true,
        );

        expect(adapter.lastForwardSendCopy, isTrue);
      },
    );

    test('classifyMessage deletes with revoke true', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'forwardMessages': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [_textMessageJson(88, 'copied')],
            }),
          ],
        },
      );
      final service = TelegramService(adapter: adapter);

      await service.classifyMessage(
        sourceChatId: 777,
        messageIds: const [10],
        targetChatId: 999,
        asCopy: false,
      );

      expect(adapter.deleteMessageRevokes, <bool>[true]);
    });

    test(
      'classifyMessage waits pending target message to be sent before deleting source',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _forwardedTextMessageJson(
                    88,
                    'copied',
                    sendingStateType: 'messageSendingStatePending',
                  ),
                ],
              }),
            ],
            'getMessage': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(
                _forwardedTextMessageJson(
                  88,
                  'copied',
                  sendingStateType: 'messageSendingStatePending',
                ),
              ),
              TdWireEnvelope.fromJson(_forwardedTextMessageJson(88, 'copied')),
            ],
          },
        );
        final service = TelegramService(
          adapter: adapter,
          forwardDeliveryConfirmTimeout: const Duration(milliseconds: 30),
          forwardDeliveryPollInterval: const Duration(milliseconds: 1),
        );

        await service.classifyMessage(
          sourceChatId: 777,
          messageIds: const [10],
          targetChatId: 999,
          asCopy: false,
        );

        expect(adapter.getMessageCalls, greaterThan(0));
        expect(adapter.deleteMessageRevokes, <bool>[true]);
      },
    );

    test(
      'classifyMessage does not delete when pending target message confirmation times out',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _forwardedTextMessageJson(
                    88,
                    'copied',
                    sendingStateType: 'messageSendingStatePending',
                  ),
                ],
              }),
            ],
            'getMessage': List<TdWireEnvelope>.generate(
              12,
              (_) => TdWireEnvelope.fromJson(
                _forwardedTextMessageJson(
                  88,
                  'copied',
                  sendingStateType: 'messageSendingStatePending',
                ),
              ),
            ),
          },
        );
        final service = TelegramService(
          adapter: adapter,
          forwardDeliveryConfirmTimeout: const Duration(milliseconds: 5),
          forwardDeliveryPollInterval: const Duration(milliseconds: 1),
        );

        await expectLater(
          () => service.classifyMessage(
            sourceChatId: 777,
            messageIds: const [10],
            targetChatId: 999,
            asCopy: false,
          ),
          throwsA(isA<StateError>()),
        );

        expect(adapter.deleteMessageCalls, 0);
      },
    );

    test(
      'classifyMessage does not delete when forward returns fewer target messages than source',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [_forwardedTextMessageJson(88, 'copied')],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await expectLater(
          () => service.classifyMessage(
            sourceChatId: 777,
            messageIds: const [10, 11],
            targetChatId: 999,
            asCopy: false,
          ),
          throwsA(isA<StateError>()),
        );

        expect(adapter.deleteMessageCalls, 0);
      },
    );

    test(
      'recoverPendingClassifyOperations retries delete for forwardConfirmed transaction',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final journalRepo = OperationJournalRepository(prefs);
        await journalRepo.saveClassifyTransactions([
          ClassifyTransactionEntry(
            id: 'tx-1',
            sourceChatId: 777,
            sourceMessageIds: const [10],
            targetChatId: 999,
            asCopy: false,
            targetMessageIds: const [88],
            stage: ClassifyTransactionStage.forwardConfirmed,
            createdAtMs: 1730000000000,
            updatedAtMs: 1730000000000,
            lastError: null,
          ),
        ]);
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getMessage': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(_textMessageJson(10, 'source')),
            ],
          },
        );
        final service = TelegramService(
          adapter: adapter,
          journalRepository: journalRepo,
        );

        final result = await service.recoverPendingClassifyOperations();

        expect(result.recoveredCount, 1);
        expect(result.manualReviewCount, 0);
        expect(result.failedCount, 0);
        expect(adapter.deleteMessageRevokes, <bool>[true]);
        expect(journalRepo.loadClassifyTransactions(), isEmpty);
      },
    );

    test(
      'recoverPendingClassifyOperations marks created transaction as manual review',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final journalRepo = OperationJournalRepository(prefs);
        await journalRepo.saveClassifyTransactions([
          ClassifyTransactionEntry(
            id: 'tx-1',
            sourceChatId: 777,
            sourceMessageIds: const [10],
            targetChatId: 999,
            asCopy: false,
            targetMessageIds: const [],
            stage: ClassifyTransactionStage.created,
            createdAtMs: 1730000000000,
            updatedAtMs: 1730000000000,
            lastError: null,
          ),
        ]);
        final adapter = _FakeTdlibAdapter(wireResponses: const {});
        final service = TelegramService(
          adapter: adapter,
          journalRepository: journalRepo,
        );

        final result = await service.recoverPendingClassifyOperations();
        final entries = journalRepo.loadClassifyTransactions();

        expect(result.recoveredCount, 0);
        expect(result.manualReviewCount, 1);
        expect(result.failedCount, 0);
        expect(entries.length, 1);
        expect(entries.first.stage, ClassifyTransactionStage.needsManualReview);
        expect(adapter.deleteMessageCalls, 0);
      },
    );

    test(
      'requireSelfChatId resolves real private chat id via createPrivateChat',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getOption': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'optionValueInteger',
                'value': 1774463496,
              }),
            ],
            'createPrivateChat': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'chat',
                'id': 1234567890123,
                'title': '收藏夹',
                'type': {'@type': 'chatTypePrivate', 'user_id': 1774463496},
              }),
            ],
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await service.fetchNextMessage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: null,
        );

        expect(adapter.lastHistoryChatId, 1234567890123);
      },
    );

    test(
      'fetchMessagePage groups audio album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _audioMessageJson(12, 'track 2', albumId: '700'),
                  _audioMessageJson(11, 'track 1', albumId: '700'),
                  _textMessageJson(10, 'tail'),
                ],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 3,
        );

        expect(page.length, 2);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.audioTracks.map((item) => item.title), [
          'track 1',
          'track 2',
        ]);
      },
    );

    test(
      'fetchMessagePage groups photo album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _photoMessageJson(12, albumId: '700'),
                  _photoMessageJson(11, albumId: '700'),
                ],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.mediaItems.length, 2);
      },
    );

    test(
      'fetchMessagePage groups video album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _videoMessageJson(12, albumId: '700'),
                  _videoMessageJson(11, albumId: '700'),
                ],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.mediaItems.length, 2);
      },
    );

    test(
      'fetchMessagePage keeps album messageIds increasing in oldestFirst mode',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _videoMessageJson(12, albumId: '700'),
                  _videoMessageJson(11, albumId: '700'),
                ],
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.oldestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
      },
    );

    test(
      'fetchMessagePage oldestFirst continues across short history pages',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(100 - index, 'm${100 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(80 - index, 'm${80 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(60 - index, 'm${60 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(40 - index, 'm${40 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(20 - index, 'm${20 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.oldestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 20,
        );

        expect(
          page.map((item) => item.id),
          List.generate(20, (index) => index + 1),
        );
      },
    );

    test(
      'countRemainingMessages continues across short history pages',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(100 - index, 'm${100 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(80 - index, 'm${80 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final count = await service.countRemainingMessages(sourceChatId: 777);

        expect(count, 40);
      },
    );

    test(
      'countRemainingMessages skips duplicate cursor message between pages',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _textMessageJson(10, 'm10'),
                  _textMessageJson(9, 'm9'),
                ],
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _textMessageJson(9, 'm9'),
                  _textMessageJson(8, 'm8'),
                ],
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final count = await service.countRemainingMessages(sourceChatId: 777);

        expect(count, 3);
      },
    );

    test(
      'fetchMessagePage groups document-video album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _documentVideoMessageJson(12, albumId: '700'),
                  _documentVideoMessageJson(11, albumId: '700'),
                ],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.mediaItems.length, 2);
      },
    );

    test(
      'prepareMediaPlayback downloads audio file and refreshes message',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getMessage': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'message',
                'id': 10,
                'chat_id': 777,
                'content': {
                  '@type': 'messageAudio',
                  'caption': {'text': '', 'entities': []},
                  'audio': {
                    'duration': 12,
                    'title': 'track',
                    'performer': 'artist',
                    'audio': {
                      'id': 55,
                      'local': {'path': ''},
                    },
                  },
                },
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'message',
                'id': 10,
                'chat_id': 777,
                'content': {
                  '@type': 'messageAudio',
                  'caption': {'text': '', 'entities': []},
                  'audio': {
                    'duration': 12,
                    'title': 'track',
                    'performer': 'artist',
                    'audio': {
                      'id': 55,
                      'local': {'path': '/tmp/track.mp3'},
                    },
                  },
                },
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final prepared = await service.prepareMediaPlayback(
          sourceChatId: 777,
          messageId: 10,
        );

        expect(adapter.downloadedFileIds, <int>[55]);
        expect(adapter.getMessageCalls, 2);
        expect(prepared.preview.localAudioPath, '/tmp/track.mp3');
      },
    );

    test('prepareMediaPreview downloads thumbnail for video only', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'getMessage': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'message',
              'id': 10,
              'chat_id': 777,
              'content': {
                '@type': 'messageVideo',
                'caption': {'text': '', 'entities': []},
                'video': {
                  'duration': 12,
                  'thumbnail': {
                    'file': {
                      'id': 31,
                      'local': {'path': ''},
                    },
                  },
                  'video': {
                    'id': 32,
                    'local': {'path': ''},
                  },
                },
              },
            }),
          ],
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final service = TelegramService(adapter: adapter);

      await service.prepareMediaPreview(sourceChatId: 777, messageId: 10);

      expect(adapter.downloadedFileIds, [31]);
    });
  });

  group('TelegramMediaService', () {
    test('prepareMediaPlayback 下载音频后刷新消息', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'getMessage': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'message',
              'id': 10,
              'chat_id': 777,
              'content': {
                '@type': 'messageAudio',
                'caption': {'text': '', 'entities': []},
                'audio': {
                  'duration': 12,
                  'title': 'track',
                  'performer': 'artist',
                  'audio': {
                    'id': 55,
                    'local': {'path': ''},
                  },
                },
              },
            }),
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'message',
              'id': 10,
              'chat_id': 777,
              'content': {
                '@type': 'messageAudio',
                'caption': {'text': '', 'entities': []},
                'audio': {
                  'duration': 12,
                  'title': 'track',
                  'performer': 'artist',
                  'audio': {
                    'id': 55,
                    'local': {'path': '/tmp/track.mp3'},
                  },
                },
              },
            }),
          ],
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final reader = TelegramMessageReader(adapter: adapter);
      final service = TelegramMediaService(adapter: adapter, reader: reader);

      final prepared = await service.prepareMediaPlayback(
        sourceChatId: 777,
        messageId: 10,
      );

      expect(adapter.downloadedFileIds, <int>[55]);
      expect(adapter.getMessageCalls, 2);
      expect(prepared.preview.localAudioPath, '/tmp/track.mp3');
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
  final List<bool> deleteMessageRevokes = <bool>[];
  int deleteMessageCalls = 0;
  int getMessageCalls = 0;
  bool? lastForwardSendCopy;
  int? lastHistoryChatId;

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
    }
    if (function is DeleteMessages) {
      deleteMessageCalls++;
    }
    if (function is ForwardMessages) {
      lastForwardSendCopy = function.sendCopy;
    }
    if (function is GetChatHistory) {
      lastHistoryChatId = function.chatId;
    }
    if (function is GetMessage) {
      getMessageCalls++;
    }
    final queue = wireResponses[constructor];
    if (queue == null || queue.isEmpty) {
      throw StateError('Missing fake wire response for $constructor');
    }
    return queue.removeAt(0);
  }

  @override
  Future<void> sendWireExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (function is DeleteMessages) {
      deleteMessageRevokes.add(function.revoke);
      deleteMessageCalls++;
      return;
    }
    throw UnimplementedError();
  }
}

Map<String, dynamic> _textMessageJson(int id, String text) {
  return <String, dynamic>{
    'id': id,
    'content': {
      '@type': 'messageText',
      'text': {'text': text, 'entities': []},
    },
  };
}

Map<String, dynamic> _forwardedTextMessageJson(
  int id,
  String text, {
  String? sendingStateType,
}) {
  final message = Map<String, dynamic>.from(_textMessageJson(id, text));
  if (sendingStateType == null) {
    return message;
  }
  message['sending_state'] = <String, dynamic>{'@type': sendingStateType};
  return message;
}

Map<String, dynamic> _audioMessageJson(
  int id,
  String title, {
  required String albumId,
}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
    'content': {
      '@type': 'messageAudio',
      'caption': {'text': '', 'entities': []},
      'audio': {
        'duration': 12,
        'title': title,
        'audio': {
          'id': id + 100,
          'local': {'path': ''},
        },
      },
    },
  };
}

Map<String, dynamic> _photoMessageJson(int id, {required String albumId}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
    'content': {
      '@type': 'messagePhoto',
      'caption': {'text': '', 'entities': []},
      'photo': {
        'sizes': [
          {
            'type': 's',
            'width': 90,
            'height': 90,
            'photo': {
              'id': id + 100,
              'local': {'path': ''},
            },
          },
          {
            'type': 'x',
            'width': 1280,
            'height': 720,
            'photo': {
              'id': id + 200,
              'local': {'path': ''},
            },
          },
        ],
      },
    },
  };
}

Map<String, dynamic> _videoMessageJson(int id, {required String albumId}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
    'content': {
      '@type': 'messageVideo',
      'caption': {'text': '', 'entities': []},
      'video': {
        'duration': 12,
        'thumbnail': {
          'file': {
            'id': id + 100,
            'local': {'path': ''},
          },
        },
        'video': {
          'id': id + 200,
          'local': {'path': ''},
        },
      },
    },
  };
}

Map<String, dynamic> _documentVideoMessageJson(
  int id, {
  required String albumId,
}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
    'content': {
      '@type': 'messageDocument',
      'caption': {'text': '', 'entities': []},
      'document': {
        'file_name': 'clip_$id.mp4',
        'mime_type': 'video/mp4',
        'thumbnail': {
          'width': 320,
          'height': 180,
          'file': {
            'id': id + 100,
            'local': {'path': ''},
          },
        },
        'document': {
          'id': id + 200,
          'local': {'path': ''},
        },
      },
    },
  };
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
