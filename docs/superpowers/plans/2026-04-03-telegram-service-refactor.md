# TelegramService Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持 `TelegramGateway` 外部契约稳定的前提下，拆分 `TelegramService` 内部职责，并为核心协作者补充独立单测。

**Architecture:** 以 `TelegramService` 作为薄门面，统一执行授权检查并把请求委派给 `TelegramSessionResolver`、`TelegramMessageReader`、`TelegramMediaService`、`TelegramMessageForwarder`、`TelegramClassifyWorkflow`。复杂的 self chat 解析、消息转发确认、分类事务编排下沉到可独立测试的协作者中，现有控制器与页面调用方式保持不变。

**Tech Stack:** Flutter、Dart、GetX、TDLib、`flutter_test`

---

## File Map

**Create**
- `lib/app/services/telegram_session_resolver.dart` — self chat/source chat 解析与可选会话加载
- `lib/app/services/telegram_message_forwarder.dart` — `ForwardMessages` 发送、返回解析与 pending 确认
- `lib/app/services/telegram_classify_workflow.dart` — 分类、撤销、恢复事务编排
- `lib/app/services/telegram_message_reader.dart` — 消息读取、分页、单条刷新与展示组装
- `lib/app/services/telegram_media_service.dart` — 媒体预热与播放前准备
- `test/services/telegram_session_resolver_test.dart` — session resolver 单测
- `test/services/telegram_message_forwarder_test.dart` — message forwarder 单测
- `test/services/telegram_classify_workflow_test.dart` — classify workflow 单测

**Modify**
- `lib/app/services/telegram_service.dart` — 收敛为授权检查 + 门面委派
- `test/services/telegram_service_test.dart` — 保持门面回归测试可运行，必要时微调 fake 组装方式

### Task 1: 抽取 `TelegramSessionResolver`

**Files:**
- Create: `lib/app/services/telegram_session_resolver.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Test: `test/services/telegram_session_resolver_test.dart`

- [ ] **Step 1: 写 resolver 的失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/telegram_session_resolver.dart';

void main() {
  test('sourceChatId 非空时直接返回，不触发 self chat 解析', () async {
    final harness = _SessionResolverHarness();
    final resolver = harness.build();

    final chatId = await resolver.resolveSourceChatId(777);

    expect(chatId, 777);
    expect(harness.createPrivateChatCalls, 0);
  });
}
```

- [ ] **Step 2: 运行单测确认它先失败**

Run: `flutter test test/services/telegram_session_resolver_test.dart --plain-name "sourceChatId 非空时直接返回，不触发 self chat 解析"`
Expected: FAIL，提示 `TelegramSessionResolver` 或测试桩尚未定义完整

- [ ] **Step 3: 实现最小 resolver 骨架**

```dart
class TelegramSessionResolver {
  TelegramSessionResolver({
    required this.loadOptionMyId,
    required this.loadSelfUserId,
    required this.createPrivateChatId,
    required this.loadSelectableChats,
  });

  final Future<int?> Function() loadOptionMyId;
  final Future<int> Function() loadSelfUserId;
  final Future<int> Function(int userId) createPrivateChatId;
  final Future<List<SelectableChat>> Function() loadSelectableChats;

  int? _selfChatId;

  Future<int> resolveSourceChatId(int? sourceChatId) async {
    if (sourceChatId != null) {
      return sourceChatId;
    }
    final cached = _selfChatId;
    if (cached != null) {
      return cached;
    }
    final optionMyId = await loadOptionMyId();
    final userId = optionMyId != null && optionMyId > 0
        ? optionMyId
        : await loadSelfUserId();
    final chatId = await createPrivateChatId(userId);
    _selfChatId = chatId;
    return chatId;
  }

  Future<List<SelectableChat>> listSelectableChats() => loadSelectableChats();
}
```

- [ ] **Step 4: 补全 fallback / cache / chat list 测试并跑通**

```dart
test('sourceChatId 为空时优先走 GetOption，再缓存结果', () async {
  final harness = _SessionResolverHarness(optionMyId: 123);
  final resolver = harness.build();

  expect(await resolver.resolveSourceChatId(null), 9001);
  expect(await resolver.resolveSourceChatId(null), 9001);
  expect(harness.createPrivateChatCalls, 1);
  expect(harness.getMeCalls, 0);
});
```

Run: `flutter test test/services/telegram_session_resolver_test.dart`
Expected: PASS

- [ ] **Step 5: 接入 `TelegramService` 并回归**

```dart
late final TelegramSessionResolver _sessionResolver = TelegramSessionResolver(
  loadOptionMyId: _loadOptionMyId,
  loadSelfUserId: _loadSelfUserId,
  createPrivateChatId: _createPrivateChatId,
  loadSelectableChats: _loadSelectableChats,
);
```

Run: `flutter test test/services/telegram_service_test.dart --plain-name "requireSelfChatId resolves real private chat id via createPrivateChat"`
Expected: PASS

### Task 2: 抽取 `TelegramMessageForwarder`

**Files:**
- Create: `lib/app/services/telegram_message_forwarder.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Test: `test/services/telegram_message_forwarder_test.dart`

- [ ] **Step 1: 写 forward 返回空结果的失败测试**

```dart
test('forwardMessages 返回空消息时抛出异常', () async {
  final harness = _ForwarderHarness.emptyForward();
  final forwarder = harness.build();

  await expectLater(
    () => forwarder.forwardAndConfirm(
      targetChatId: 999,
      sourceChatId: 777,
      sourceMessageIds: const [10],
      sendCopy: false,
      requestLabel: 'forwardMessages',
    ),
    throwsA(isA<StateError>()),
  );
});
```

- [ ] **Step 2: 运行单测确认先失败**

Run: `flutter test test/services/telegram_message_forwarder_test.dart --plain-name "forwardMessages 返回空消息时抛出异常"`
Expected: FAIL

- [ ] **Step 3: 实现 forwarder 最小骨架**

```dart
class TelegramMessageForwarder {
  TelegramMessageForwarder({
    required this.sendForward,
    required this.loadMessageById,
    required this.confirmTimeout,
    required this.pollInterval,
  });

  final Future<TdWireEnvelope> Function({
    required int targetChatId,
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required bool sendCopy,
  }) sendForward;
  final Future<Map<String, dynamic>> Function(int chatId, int messageId)
      loadMessageById;
  final Duration confirmTimeout;
  final Duration pollInterval;

  Future<List<int>> forwardAndConfirm({
    required int targetChatId,
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required bool sendCopy,
    required String requestLabel,
  }) async {
    final envelope = await sendForward(
      targetChatId: targetChatId,
      sourceChatId: sourceChatId,
      sourceMessageIds: sourceMessageIds,
      sendCopy: sendCopy,
    );
    final messages = TdResponseReader.readList(envelope.payload, 'messages');
    if (messages.isEmpty) {
      throw StateError('$requestLabel 返回异常，无法提取目标消息 ID');
    }
    return <int>[];
  }
}
```

- [ ] **Step 4: 按 TDD 补齐数量不匹配 / pending 成功 / pending 超时 / failed state 测试**

```dart
test('pending 状态最终发送成功后返回目标消息 ID', () async {
  final harness = _ForwarderHarness.pendingThenSent();
  final forwarder = harness.build(
    confirmTimeout: const Duration(milliseconds: 30),
    pollInterval: const Duration(milliseconds: 1),
  );

  final ids = await forwarder.forwardAndConfirm(
    targetChatId: 999,
    sourceChatId: 777,
    sourceMessageIds: const [10],
    sendCopy: false,
    requestLabel: 'forwardMessages',
  );

  expect(ids, <int>[88]);
  expect(harness.getMessageCalls, greaterThan(0));
});
```

Run: `flutter test test/services/telegram_message_forwarder_test.dart`
Expected: PASS

- [ ] **Step 5: 用新 forwarder 替换 `TelegramService` 私有实现并回归**

```dart
late final TelegramMessageForwarder _messageForwarder = TelegramMessageForwarder(
  sendForward: _sendForwardMessages,
  loadMessageById: _loadMessagePayload,
  confirmTimeout: _forwardDeliveryConfirmTimeout,
  pollInterval: _forwardDeliveryPollInterval,
);
```

Run: `flutter test test/services/telegram_service_test.dart --plain-name "classifyMessage waits pending target message to be sent before deleting source"`
Expected: PASS

### Task 3: 抽取 `TelegramClassifyWorkflow`

**Files:**
- Create: `lib/app/services/telegram_classify_workflow.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Test: `test/services/telegram_classify_workflow_test.dart`

- [ ] **Step 1: 写分类成功后才删源消息的失败测试**

```dart
test('forward 成功确认后才删除源消息', () async {
  final harness = _ClassifyWorkflowHarness.success();
  final workflow = harness.build();

  await workflow.classifyMessage(
    sourceChatId: 777,
    messageIds: const [10],
    targetChatId: 999,
    asCopy: false,
  );

  expect(harness.forwardCalls, 1);
  expect(harness.deleteCalls, 1);
  expect(harness.deleteAfterForwardConfirmed, isTrue);
});
```

- [ ] **Step 2: 运行单测确认先失败**

Run: `flutter test test/services/telegram_classify_workflow_test.dart --plain-name "forward 成功确认后才删除源消息"`
Expected: FAIL

- [ ] **Step 3: 实现 workflow 最小骨架**

```dart
class TelegramClassifyWorkflow {
  TelegramClassifyWorkflow({
    required this.coordinator,
    required this.forwardAndConfirm,
    required this.deleteMessages,
  });

  final ClassifyTransactionCoordinator coordinator;
  final Future<List<int>> Function({
    required int targetChatId,
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required bool sendCopy,
    required String requestLabel,
  }) forwardAndConfirm;
  final Future<void> Function({
    required int chatId,
    required List<int> messageIds,
    required bool revoke,
  }) deleteMessages;

  Future<ClassifyReceipt> classifyMessage({
    required int sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    final started = await coordinator.startTransaction(
      sourceChatId: sourceChatId,
      sourceMessageIds: messageIds,
      targetChatId: targetChatId,
      asCopy: asCopy,
    );
    var transaction = started;
    try {
      final targetMessageIds = await forwardAndConfirm(
        targetChatId: targetChatId,
        sourceChatId: sourceChatId,
        sourceMessageIds: messageIds,
        sendCopy: asCopy,
        requestLabel: 'forwardMessages',
      );
      transaction = await coordinator.markForwardConfirmed(
        transaction,
        targetMessageIds: targetMessageIds,
      );
      await deleteMessages(
        chatId: sourceChatId,
        messageIds: messageIds,
        revoke: true,
      );
      await coordinator.markSourceDeleteConfirmed(transaction);
      return ClassifyReceipt(
        sourceChatId: sourceChatId,
        sourceMessageIds: messageIds,
        targetChatId: targetChatId,
        targetMessageIds: targetMessageIds,
      );
    } catch (error) {
      await coordinator.recordFailure(transaction, error);
      rethrow;
    }
  }
}
```

- [ ] **Step 4: 补全 undo / recover / recordFailure 测试并跑通**

```dart
test('forward 失败时记录 failure 且不删除源消息', () async {
  final harness = _ClassifyWorkflowHarness.forwardFails();
  final workflow = harness.build();

  await expectLater(
    () => workflow.classifyMessage(
      sourceChatId: 777,
      messageIds: const [10],
      targetChatId: 999,
      asCopy: false,
    ),
    throwsA(isA<StateError>()),
  );

  expect(harness.deleteCalls, 0);
  expect(harness.failureRecorded, isTrue);
});
```

Run: `flutter test test/services/telegram_classify_workflow_test.dart`
Expected: PASS

- [ ] **Step 5: 回接 `TelegramService`，删除旧分类私有流程**

```dart
late final TelegramClassifyWorkflow _classifyWorkflow = TelegramClassifyWorkflow(
  coordinator: _classifyCoordinator,
  forwardAndConfirm: _messageForwarder.forwardAndConfirm,
  deleteMessages: _deleteMessages,
);
```

Run: `flutter test test/services/telegram_service_test.dart --plain-name "recoverPendingClassifyOperations retries delete for forwardConfirmed transaction"`
Expected: PASS

### Task 4: 抽取 `TelegramMessageReader` 与 `TelegramMediaService`

**Files:**
- Create: `lib/app/services/telegram_message_reader.dart`
- Create: `lib/app/services/telegram_media_service.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 先为 media service 写单职责测试**

```dart
test('preparePlayback 对音频消息触发文件下载', () async {
  final harness = _MediaServiceHarness.audio();
  final service = harness.build();

  await service.preparePlayback(harness.message);

  expect(harness.downloadedFileIds, <int>[110]);
});
```

- [ ] **Step 2: 运行单测确认先失败**

Run: `flutter test test/services/telegram_service_test.dart --plain-name "prepareMediaPlayback downloads audio file and refreshes message"`
Expected: 现有门面测试仍可作为回归基线；新增 media service 单测初次 FAIL

- [ ] **Step 3: 实现 reader / media service 最小骨架**

```dart
class TelegramMessageReader {
  TelegramMessageReader({
    required this.historyPaginator,
    required this.previewBuilder,
    required this.loadMessageById,
  });

  final MessageHistoryPaginator historyPaginator;
  final MessagePreviewBuilder previewBuilder;
  final Future<TdMessageDto> Function(int chatId, int messageId) loadMessageById;
}

class TelegramMediaService {
  TelegramMediaService({required MediaDownloadCoordinator coordinator})
      : _coordinator = coordinator;

  final MediaDownloadCoordinator _coordinator;

  Future<void> warmUpPreview(TdMessageDto message) =>
      _coordinator.warmUpPreview(message.content);

  Future<void> preparePlayback(TdMessageDto message) =>
      _coordinator.preparePlayback(message.content);
}
```

- [ ] **Step 4: 将分页 / next / refresh / media prepare 委派到协作者并跑门面回归**

```dart
@override
Future<PipelineMessage?> fetchNextMessage({
  required MessageFetchDirection direction,
  required int? sourceChatId,
}) async {
  await _requireAuthorizationReady();
  final chatId = await _sessionResolver.resolveSourceChatId(sourceChatId);
  final message = await _messageReader.fetchNextRawMessage(
    direction: direction,
    chatId: chatId,
  );
  if (message == null) return null;
  await _mediaService.warmUpPreview(message);
  return _messageReader.toPipelineMessage(
    messages: <TdMessageDto>[message],
    sourceChatId: chatId,
  );
}
```

Run: `flutter test test/services/telegram_service_test.dart`
Expected: PASS

- [ ] **Step 5: 清理 `TelegramService` 冗余私有方法**

```dart
// 删除已迁移的私有方法：
// - _loadSelfChatId / _requireSelfChatId / _resolveSourceChatId
// - _forwardMessagesAndConfirmDelivery / _waitPendingForwardedMessages
// - 大部分消息读取/媒体准备细节
```

Run: `flutter test test/services/telegram_service_test.dart test/controllers/pipeline_controller_test.dart`
Expected: PASS

### Task 5: 全量验证与收尾

**Files:**
- Modify: `docs/superpowers/plans/2026-04-03-telegram-service-refactor.md`
- Verify: `test/services/telegram_service_test.dart`
- Verify: `test/services/telegram_session_resolver_test.dart`
- Verify: `test/services/telegram_message_forwarder_test.dart`
- Verify: `test/services/telegram_classify_workflow_test.dart`
- Verify: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 跑新老服务测试**

Run: `flutter test test/services/telegram_service_test.dart test/services/telegram_session_resolver_test.dart test/services/telegram_message_forwarder_test.dart test/services/telegram_classify_workflow_test.dart`
Expected: PASS

- [ ] **Step 2: 跑控制器回归测试**

Run: `flutter test test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 3: 如有格式化配置，格式化涉及文件**

Run: `dart format lib/app/services/telegram_service.dart lib/app/services/telegram_session_resolver.dart lib/app/services/telegram_message_forwarder.dart lib/app/services/telegram_classify_workflow.dart lib/app/services/telegram_message_reader.dart lib/app/services/telegram_media_service.dart test/services/telegram_service_test.dart test/services/telegram_session_resolver_test.dart test/services/telegram_message_forwarder_test.dart test/services/telegram_classify_workflow_test.dart`
Expected: 所有文件格式化完成

- [ ] **Step 4: 复跑关键测试，确认格式化后仍为绿**

Run: `flutter test test/services/telegram_service_test.dart test/services/telegram_session_resolver_test.dart test/services/telegram_message_forwarder_test.dart test/services/telegram_classify_workflow_test.dart test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 5: 勾掉已完成项并准备进入开发收尾流程**

```bash
git status --short
```

Expected: 仅包含本次重构涉及文件变更

## Self Review

### Spec coverage

- 门面保持稳定：Task 1~4 中 `TelegramService` 委派化覆盖
- SessionResolver：Task 1 覆盖
- MessageForwarder：Task 2 覆盖
- ClassifyWorkflow：Task 3 覆盖
- MessageReader / MediaService：Task 4 覆盖
- 现有测试 + 新协作者测试：Task 5 覆盖

### Placeholder scan

已检查本计划，无 `TODO` / `TBD` / “后续补上”等占位描述。

### Type consistency

计划中统一使用：
- `resolveSourceChatId`
- `forwardAndConfirm`
- `classifyMessage`
- `preparePlayback`
- `warmUpPreview`

后续实现需保持这些命名一致，避免任务间漂移。
