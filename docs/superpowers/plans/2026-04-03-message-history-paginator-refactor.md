# Message History Paginator 重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `TelegramService` 中的消息历史分页、游标推进和全量遍历规则抽到独立分页器中，在不改变 `TelegramGateway` 对外行为的前提下降低服务层耦合。

**Architecture:** 保留 `TelegramService` 作为业务编排入口，只让它负责鉴权、来源 chat 解析、媒体预热和流水线组装；新增 `MessageHistoryPaginator` 负责 latest-first / oldest-first 的历史读取规则、去重游标和跨页遍历。分页器直接依赖 `TdlibAdapter` 发起底层 `getChatHistory` 请求，但不参与预览构建与媒体下载策略。

**Tech Stack:** Dart 3、Flutter test、TDLib adapter、GetX、SharedPreferences

---

## 文件结构

- Create: `lib/app/services/message_history_paginator.dart`
  - 封装消息历史分页与游标推进逻辑
- Modify: `lib/app/services/telegram_service.dart`
  - 将历史读取与全量遍历委托给分页器，保留业务编排
- Create: `test/services/message_history_paginator_test.dart`
  - 分页器单测，锁定 latest/oldest 行为和全量遍历
- Modify: `test/services/telegram_service_test.dart`
  - 保留服务级回归测试，适配分页器委托后的构造
- Modify: `docs/ARCHITECTURE.md`
  - 实现完成后补充分页职责边界

### Task 1: 为分页器写失败测试

**Files:**
- Create: `test/services/message_history_paginator_test.dart`
- Reference: `lib/app/services/td_message_dto.dart`
- Reference: `lib/app/models/app_settings.dart`

- [ ] **Step 1: 写 `latestFirst` 去重游标的失败测试**

```dart
test('fetchSavedMessagePage removes duplicate cursor item in latestFirst', () async {
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
  final paginator = MessageHistoryPaginator(adapter: adapter);

  final page = await paginator.fetchSavedMessagePage(
    chatId: 777,
    direction: MessageFetchDirection.latestFirst,
    fromMessageId: 10,
    limit: 2,
  );

  expect(page.map((item) => item.id), [9]);
});
```

- [ ] **Step 2: 写 `oldestFirst` 保持升序的失败测试**

```dart
test('fetchSavedMessagePage returns ascending ids in oldestFirst', () async {
  final adapter = _FakeTdlibAdapter(
    wireResponses: <String, List<TdWireEnvelope>>{
      'getChatHistory': <TdWireEnvelope>[
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            _textMessageJson(12, 'm12'),
            _textMessageJson(11, 'm11'),
          ],
        }),
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [],
        }),
      ],
    },
  );
  final paginator = MessageHistoryPaginator(adapter: adapter);

  final page = await paginator.fetchSavedMessagePage(
    chatId: 777,
    direction: MessageFetchDirection.oldestFirst,
    fromMessageId: null,
    limit: 2,
  );

  expect(page.map((item) => item.id), [11, 12]);
});
```

- [ ] **Step 3: 写 `fetchSavedMessage` 单条读取的失败测试**

```dart
test('fetchSavedMessage returns first message for direction', () async {
  final adapter = _FakeTdlibAdapter(
    wireResponses: <String, List<TdWireEnvelope>>{
      'getChatHistory': <TdWireEnvelope>[
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [_textMessageJson(20, 'latest')],
        }),
      ],
    },
  );
  final paginator = MessageHistoryPaginator(adapter: adapter);

  final message = await paginator.fetchSavedMessage(
    chatId: 777,
    direction: MessageFetchDirection.latestFirst,
  );

  expect(message?.id, 20);
});
```

- [ ] **Step 4: 写 `fetchAllHistoryMessages` 全量遍历的失败测试**

```dart
test('fetchAllHistoryMessages reads until empty page', () async {
  final adapter = _FakeTdlibAdapter(
    wireResponses: <String, List<TdWireEnvelope>>{
      'getChatHistory': <TdWireEnvelope>[
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            _textMessageJson(5, 'm5'),
            _textMessageJson(4, 'm4'),
          ],
        }),
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            _textMessageJson(3, 'm3'),
            _textMessageJson(2, 'm2'),
          ],
        }),
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [],
        }),
      ],
    },
  );
  final paginator = MessageHistoryPaginator(adapter: adapter, historyBatchSize: 2);

  final page = await paginator.fetchAllHistoryMessages(777);

  expect(page.map((item) => item.id), [2, 3, 4, 5]);
});
```

- [ ] **Step 5: 运行单测确认失败**

Run: `flutter test test/services/message_history_paginator_test.dart`
Expected: FAIL，提示 `MessageHistoryPaginator` 未定义或对应文件不存在

### Task 2: 为 oldest-first 跨短页补拉写失败测试

**Files:**
- Modify: `test/services/message_history_paginator_test.dart`

- [ ] **Step 1: 写 oldest-first 跨短页补拉测试**

```dart
test('fetchSavedMessagePage oldestFirst continues across short pages', () async {
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
  final paginator = MessageHistoryPaginator(adapter: adapter);

  final page = await paginator.fetchSavedMessagePage(
    chatId: 777,
    direction: MessageFetchDirection.oldestFirst,
    fromMessageId: null,
    limit: 20,
  );

  expect(page.map((item) => item.id), List.generate(20, (index) => index + 1));
});
```

- [ ] **Step 2: 再跑单测确认仍是“缺实现失败”**

Run: `flutter test test/services/message_history_paginator_test.dart`
Expected: FAIL，失败原因来自分页器尚未实现，而不是测试本身拼写错误

### Task 3: 最小实现分页器并让新测试变绿

**Files:**
- Create: `lib/app/services/message_history_paginator.dart`
- Modify: `test/services/message_history_paginator_test.dart`

- [ ] **Step 1: 实现分页器骨架**

```dart
class MessageHistoryPaginator {
  MessageHistoryPaginator({
    required TdlibAdapter adapter,
    Duration defaultTimeout = const Duration(seconds: 20),
    int historyBatchSize = 100,
  }) : _adapter = adapter,
       _defaultTimeout = defaultTimeout,
       _historyBatchSize = historyBatchSize;

  final TdlibAdapter _adapter;
  final Duration _defaultTimeout;
  final int _historyBatchSize;
}
```

- [ ] **Step 2: 实现底层 `getChatHistory` 读取方法**

```dart
Future<List<TdMessageDto>> _fetchHistoryPage({
  required int chatId,
  required int? fromMessageId,
  required int limit,
}) async { ... }
```

要求：
- 调用 `adapter.sendWire(GetChatHistory(...))`
- 使用 `TdMessageListDto.fromEnvelope(...)`
- 返回 `List<TdMessageDto>`

- [ ] **Step 3: 实现 `fetchAllHistoryMessages` / `fetchSavedMessagePage` / `fetchSavedMessage`**

```dart
Future<List<TdMessageDto>> fetchAllHistoryMessages(int chatId) async { ... }
Future<List<TdMessageDto>> fetchSavedMessagePage({...}) async { ... }
Future<TdMessageDto?> fetchSavedMessage({...}) async { ... }
```

要求：
- `latestFirst` 保持去重游标逻辑
- `oldestFirst` 通过全量遍历后再截断
- `fetchSavedMessage` 通过 `limit: 1` 复用分页逻辑

- [ ] **Step 4: 跑分页器测试确认变绿**

Run: `flutter test test/services/message_history_paginator_test.dart`
Expected: PASS

### Task 4: 让 `TelegramService` 委托分页器

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 先保留现有服务测试不改断言**

确保以下断言不变：

```dart
expect(page.map((item) => item.id), [9]);
expect(page.map((item) => item.id), List.generate(20, (index) => index + 1));
expect(count, 100);
```

- [ ] **Step 2: 在 `TelegramService` 中注入分页器**

```dart
late final MessageHistoryPaginator _historyPaginator = MessageHistoryPaginator(
  adapter: _adapter,
  defaultTimeout: _defaultTimeout,
  historyBatchSize: _historyBatchSize,
);
```

- [ ] **Step 3: 将历史读取入口改为委托调用**

```dart
final messages = await _historyPaginator.fetchSavedMessagePage(...);
final message = await _historyPaginator.fetchSavedMessage(...);
final messages = await _historyPaginator.fetchAllHistoryMessages(chatId);
```

替换范围：
- `countRemainingMessages()`
- `fetchMessagePage()`
- `fetchNextMessage()`

- [ ] **Step 4: 删除已迁出的私有方法**

删除：

```dart
_fetchSavedMessage
_fetchSavedMessagePage
_fetchAllHistoryMessages
_fetchLatestSavedMessagePage
_fetchOldestSavedMessagePage
_fetchHistoryPage
```

- [ ] **Step 5: 运行服务测试确认回归通过**

Run: `flutter test test/services/telegram_service_test.dart`
Expected: PASS

### Task 5: 整理、文档与目标验证

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `lib/app/services/telegram_service.dart`
- Create: `lib/app/services/message_history_paginator.dart`
- Create: `test/services/message_history_paginator_test.dart`

- [ ] **Step 1: 更新架构文档**

在 `docs/ARCHITECTURE.md` 中补充：

```md
- `MessageHistoryPaginator`
  - 管理消息历史分页、游标推进与全量遍历规则。
- `TelegramService`
  - 保留业务编排、媒体预热与流水线组装，不再持有历史分页核心规则。
```

- [ ] **Step 2: 格式化修改文件**

Run:
`dart format lib/app/services/message_history_paginator.dart lib/app/services/telegram_service.dart test/services/message_history_paginator_test.dart test/services/telegram_service_test.dart`

Expected: PASS

- [ ] **Step 3: 跑目标验证集**

Run:
`flutter test test/services/message_history_paginator_test.dart test/services/telegram_service_test.dart test/controllers/pipeline_controller_test.dart`

Expected: PASS

- [ ] **Step 4: 如目标验证集通过，再做最终回顾**

检查：
- `TelegramService` 是否已不再持有分页规则
- `MessageHistoryPaginator` 是否只处理历史读取，不含预览构建和媒体下载逻辑
- 外部接口是否完全未变

## 自检

- Spec coverage：已覆盖“分页器抽离、接口保持不变、TDD、文档补充、保留服务回归”要求
- Placeholder scan：全文无 `TODO/TBD/implement later/待定`
- Type consistency：统一使用 `MessageHistoryPaginator`、`fetchSavedMessagePage()`、`fetchSavedMessage()`、`fetchAllHistoryMessages()` 命名

## 说明

- 当前仓库已有未合并工作继续叠加，本计划默认在当前工作区顺延实施
- 若 `flutter analyze` 或全量 `flutter test` 被既有问题阻塞，只报告证据，不顺手修 unrelated 问题
