# 转发确认显式成功实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将分类转发确认改为基于 TDLib 显式发送成功 update，避免弱网或临时 ID 切换时误判并删除源消息。

**Architecture:** 在 TD update 解析层补充消息发送结果事件，由 `TdlibAdapter` 暴露结构化发送结果流，`TelegramMessageForwarder` 对 pending 消息等待 `updateMessageSendSucceeded` / `updateMessageSendFailed`，只有显式成功后才允许分类工作流继续删除源消息。保留立即 sent 的兼容路径，移除基于 `getMessage(oldId)` 的成功判定依赖。

**Tech Stack:** Flutter、Dart、TDLib、flutter_test

---

### Task 1: 补发送结果事件模型与解析测试

**Files:**
- Modify: `e:\github\TgSorter\lib\app\services\td_update_parser.dart`
- Create: `e:\github\TgSorter\lib\app\services\td_message_send_update.dart`
- Create: `e:\github\TgSorter\test\services\td_update_parser_test.dart`

- [ ] **Step 1: 写失败测试，证明解析器当前无法识别 `updateMessageSendSucceeded`**

```dart
test('parses updateMessageSendSucceeded', () {
  final parsed = TdUpdateParser.parse(<String, dynamic>{
    '@type': 'updateMessageSendSucceeded',
    'old_message_id': 77,
    'message': {
      '@type': 'message',
      'id': 88,
      'chat_id': 999,
      'content': {
        '@type': 'messageText',
        'text': {'text': 'ok', 'entities': []},
      },
    },
  });

  expect(parsed.messageSendResult, isNotNull);
});
```

- [ ] **Step 2: 运行测试并确认先失败**

Run: `flutter test test/services/td_update_parser_test.dart`
Expected: FAIL，提示 `messageSendResult` 或对应解析逻辑不存在

- [ ] **Step 3: 增加最小事件模型并实现解析**

```dart
sealed class TdMessageSendUpdate {
  const TdMessageSendUpdate({required this.chatId});

  final int chatId;
}

class TdMessageSendSucceeded extends TdMessageSendUpdate {
  const TdMessageSendSucceeded({
    required super.chatId,
    required this.oldMessageId,
    required this.messageId,
  });

  final int oldMessageId;
  final int messageId;
}
```

- [ ] **Step 4: 补充失败 update 解析测试并跑通**

Run: `flutter test test/services/td_update_parser_test.dart`
Expected: PASS

### Task 2: 让 Adapter 暴露发送结果流

**Files:**
- Modify: `e:\github\TgSorter\lib\app\services\tdlib_adapter.dart`
- Modify: `e:\github\TgSorter\lib\app\services\td_update_parser.dart`
- Test: `e:\github\TgSorter\test\services\td_update_parser_test.dart`

- [ ] **Step 1: 写失败测试，证明 raw update 无法向上暴露发送结果**

```dart
test('adapter forwards message send updates from raw updates', () async {
  final controller = StreamController<Map<String, dynamic>>();
  final adapter = buildAdapterWithRawUpdates(controller.stream);

  final future = adapter.messageSendUpdates.first;
  controller.add(successUpdatePayload());

  final update = await future;
  expect(update, isA<TdMessageSendSucceeded>());
});
```

- [ ] **Step 2: 运行测试并确认先失败**

Run: `flutter test test/services/td_update_parser_test.dart --plain-name "adapter forwards message send updates from raw updates"`
Expected: FAIL

- [ ] **Step 3: 在 `TdlibAdapter` 中增加发送结果 `StreamController` 与分发逻辑**

```dart
final _messageSendController =
    StreamController<TdMessageSendUpdate>.broadcast(sync: true);

Stream<TdMessageSendUpdate> get messageSendUpdates =>
    _messageSendController.stream;
```

- [ ] **Step 4: 让 `_handleRawUpdate` / `_handleUpdate` 转发发送结果并验证通过**

Run: `flutter test test/services/td_update_parser_test.dart`
Expected: PASS

### Task 3: 先写 forwarder 回归测试锁住新安全语义

**Files:**
- Modify: `e:\github\TgSorter\test\services\telegram_message_forwarder_test.dart`
- Modify: `e:\github\TgSorter\test\services\telegram_service_test.dart`

- [ ] **Step 1: 写失败测试，复现“旧 ID 404 但收到成功 update 时应判成功”**

```dart
test('pending target message uses send succeeded update instead of polling old id', () async {
  final adapter = _FakeTdlibAdapter(
    wireResponses: <String, List<Object>>{
      'forwardMessages': <TdWireEnvelope>[
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            _forwardedTextMessageJson(
              77,
              'copied',
              sendingStateType: 'messageSendingStatePending',
            ),
          ],
        }),
      ],
    },
  )..emitSendSucceeded(chatId: 999, oldMessageId: 77, messageId: 88);

  final result = await forwarder.forwardMessagesAndConfirmDelivery(...);

  expect(result, <int>[88]);
});
```

- [ ] **Step 2: 写失败测试，确认只靠 404 不得判成功**

```dart
test('pending target message times out without explicit success update', () async {
  ...
  await expectLater(
    () => forwarder.forwardMessagesAndConfirmDelivery(...),
    throwsA(isA<StateError>()),
  );
});
```

- [ ] **Step 3: 运行 forwarder 测试并确认先失败**

Run: `flutter test test/services/telegram_message_forwarder_test.dart`
Expected: FAIL

- [ ] **Step 4: 写服务层失败测试，确认未显式成功前不会删除源消息**

Run: `flutter test test/services/telegram_service_test.dart --plain-name "classifyMessage does not delete when pending target message confirmation times out"`
Expected: 先保持 FAIL 或回归基线待后续实现

### Task 4: 最小实现 forwarder 的 update 驱动确认

**Files:**
- Modify: `e:\github\TgSorter\lib\app\services\telegram_message_forwarder.dart`
- Modify: `e:\github\TgSorter\lib\app\services\telegram_service.dart`
- Modify: `e:\github\TgSorter\test\services\telegram_message_forwarder_test.dart`

- [ ] **Step 1: 为 forwarder 构造函数注入发送结果流**

```dart
TelegramMessageForwarder({
  required TdlibAdapter adapter,
  Stream<TdMessageSendUpdate>? messageSendUpdates,
  ...
}) : _messageSendUpdates = messageSendUpdates ?? adapter.messageSendUpdates;
```

- [ ] **Step 2: 将 pending 确认改为等待 update，而不是 `getMessage(oldId)`**

```dart
final update = await _messageSendUpdates
    .where((item) => item.chatId == targetChatId)
    .firstWhere((item) => pendingIds.contains(item.oldMessageId))
    .timeout(_confirmTimeout);
```

- [ ] **Step 3: 记录最终消息 ID 并按 source 顺序返回**

```dart
final resolvedIds = <int, int>{};
resolvedIds[update.oldMessageId] = update.messageId;
```

- [ ] **Step 4: 运行 forwarder 测试并确认通过**

Run: `flutter test test/services/telegram_message_forwarder_test.dart`
Expected: PASS

### Task 5: 回归分类删除安全性

**Files:**
- Modify: `e:\github\TgSorter\test\services\telegram_service_test.dart`
- Modify: `e:\github\TgSorter\lib\app\services\telegram_service.dart`
- Modify: `e:\github\TgSorter\lib\app\services\telegram_classify_workflow.dart`

- [ ] **Step 1: 让服务层 fake adapter 支持推送发送结果 update**

```dart
void emitSendSucceeded({
  required int chatId,
  required int oldMessageId,
  required int messageId,
}) {
  _messageSendController.add(
    TdMessageSendSucceeded(
      chatId: chatId,
      oldMessageId: oldMessageId,
      messageId: messageId,
    ),
  );
}
```

- [ ] **Step 2: 调整现有 pending 成功测试为使用显式 success update**

Run: `flutter test test/services/telegram_service_test.dart --plain-name "classifyMessage waits pending target message to be sent before deleting source"`
Expected: PASS

- [ ] **Step 3: 保持超时不删源消息测试为绿**

Run: `flutter test test/services/telegram_service_test.dart --plain-name "classifyMessage does not delete when pending target message confirmation times out"`
Expected: PASS

- [ ] **Step 4: 增加发送失败不删源消息测试**

Run: `flutter test test/services/telegram_service_test.dart --plain-name "classifyMessage does not delete when target send failed"`
Expected: PASS

### Task 6: 全量验证

**Files:**
- Verify: `e:\github\TgSorter\test\services\td_update_parser_test.dart`
- Verify: `e:\github\TgSorter\test\services\telegram_message_forwarder_test.dart`
- Verify: `e:\github\TgSorter\test\services\telegram_service_test.dart`

- [ ] **Step 1: 跑解析与 forwarder 测试**

Run: `flutter test test/services/td_update_parser_test.dart test/services/telegram_message_forwarder_test.dart`
Expected: PASS

- [ ] **Step 2: 跑服务回归测试**

Run: `flutter test test/services/telegram_service_test.dart`
Expected: PASS

- [ ] **Step 3: 格式化修改文件**

Run: `dart format lib/app/services/td_message_send_update.dart lib/app/services/td_update_parser.dart lib/app/services/tdlib_adapter.dart lib/app/services/telegram_message_forwarder.dart lib/app/services/telegram_service.dart test/services/td_update_parser_test.dart test/services/telegram_message_forwarder_test.dart test/services/telegram_service_test.dart`
Expected: 所有文件格式化完成

- [ ] **Step 4: 复跑关键测试**

Run: `flutter test test/services/td_update_parser_test.dart test/services/telegram_message_forwarder_test.dart test/services/telegram_service_test.dart`
Expected: PASS
