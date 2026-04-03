# Telegram 分类恢复链路重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `TelegramService` 中的分类事务与恢复规则抽到独立协调器中，在不改变 `TelegramGateway` 对外行为的前提下显著降低服务层耦合。

**Architecture:** 保留 `TelegramService` 作为 TDLib 业务编排入口，只让它负责 `forward/delete` 与投递确认；新增 `ClassifyTransactionCoordinator` 负责事务创建、阶段推进、失败记录和恢复策略。协调器通过回调依赖“检查源消息是否存在”和“删除源消息”能力，从而不直接依赖 TDLib 细节。

**Tech Stack:** Dart 3、Flutter test、GetX、TDLib adapter、SharedPreferences 持久化仓储

---

## 文件结构

- Create: `lib/app/services/classify_transaction_coordinator.dart`
  - 分类事务协调器，封装事务状态机与恢复策略
- Modify: `lib/app/services/telegram_service.dart`
  - 将事务创建/推进/恢复委托给协调器，保留转发确认和删除调用
- Create: `test/services/classify_transaction_coordinator_test.dart`
  - 协调器行为单测，锁定事务与恢复语义
- Modify: `test/services/telegram_service_test.dart`
  - 适配构造方式，继续回归 `TelegramService` 外部行为
- Modify: `docs/ARCHITECTURE.md`
  - 实现完成后补充职责边界说明

### Task 1: 为协调器写失败测试

**Files:**
- Create: `test/services/classify_transaction_coordinator_test.dart`
- Reference: `lib/app/models/classify_transaction_entry.dart`
- Reference: `lib/app/services/operation_journal_repository.dart`

- [ ] **Step 1: 写 `startTransaction` 的失败测试**

```dart
test('startTransaction persists created transaction', () async {
  final repository = _FakeJournalRepository();
  final coordinator = ClassifyTransactionCoordinator(
    repository: repository,
    anySourceMessageExists: (_) async => true,
    deleteSourceMessages: (_) async {},
    nowMs: () => 1000,
    buildTransactionId: ({required sourceChatId, required sourceMessageIds}) =>
        'tx-$sourceChatId-${sourceMessageIds.first}',
  );

  final transaction = await coordinator.startTransaction(
    sourceChatId: 777,
    sourceMessageIds: const [10],
    targetChatId: 999,
    asCopy: false,
  );

  expect(transaction.stage, ClassifyTransactionStage.created);
  expect(repository.upserted.single.stage, ClassifyTransactionStage.created);
});
```

- [ ] **Step 2: 运行单测确认失败**

Run: `flutter test test/services/classify_transaction_coordinator_test.dart`
Expected: FAIL，提示 `ClassifyTransactionCoordinator` 未定义

- [ ] **Step 3: 写 `markForwardConfirmed` 的失败测试**

```dart
test('markForwardConfirmed stores target ids and stage', () async {
  final repository = _FakeJournalRepository();
  final coordinator = _buildCoordinator(repository);
  final started = await coordinator.startTransaction(
    sourceChatId: 777,
    sourceMessageIds: const [10],
    targetChatId: 999,
    asCopy: false,
  );

  final updated = await coordinator.markForwardConfirmed(
    started,
    targetMessageIds: const [88],
  );

  expect(updated.stage, ClassifyTransactionStage.forwardConfirmed);
  expect(updated.targetMessageIds, const [88]);
  expect(repository.upserted.last.stage, ClassifyTransactionStage.forwardConfirmed);
});
```

- [ ] **Step 4: 写 `markSourceDeleteConfirmed` 的失败测试**

```dart
test('markSourceDeleteConfirmed removes finished transaction', () async {
  final repository = _FakeJournalRepository();
  final coordinator = _buildCoordinator(repository);
  final started = await coordinator.startTransaction(
    sourceChatId: 777,
    sourceMessageIds: const [10],
    targetChatId: 999,
    asCopy: false,
  );
  final forwarded = await coordinator.markForwardConfirmed(
    started,
    targetMessageIds: const [88],
  );

  await coordinator.markSourceDeleteConfirmed(forwarded);

  expect(repository.removedIds, [forwarded.id]);
});
```

- [ ] **Step 5: 写 `recordFailure` 的失败测试**

```dart
test('recordFailure moves created transaction to manual review', () async {
  final repository = _FakeJournalRepository();
  final coordinator = _buildCoordinator(repository);
  final started = await coordinator.startTransaction(
    sourceChatId: 777,
    sourceMessageIds: const [10],
    targetChatId: 999,
    asCopy: false,
  );

  await coordinator.recordFailure(started, StateError('boom'));

  expect(repository.upserted.last.stage, ClassifyTransactionStage.needsManualReview);
  expect(repository.upserted.last.lastError, contains('boom'));
});
```

### Task 2: 为恢复策略写失败测试

**Files:**
- Modify: `test/services/classify_transaction_coordinator_test.dart`

- [ ] **Step 1: 写 `forwardConfirmed + source exists` 恢复测试**

```dart
test('recoverPendingTransactions deletes source for forwardConfirmed entry', () async {
  final repository = _FakeJournalRepository(
    storedTransactions: [
      _entry(stage: ClassifyTransactionStage.forwardConfirmed),
    ],
  );
  var deleteCalls = 0;
  final coordinator = ClassifyTransactionCoordinator(
    repository: repository,
    anySourceMessageExists: (_) async => true,
    deleteSourceMessages: (_) async {
      deleteCalls++;
    },
    nowMs: () => 2000,
    buildTransactionId: _buildId,
  );

  final summary = await coordinator.recoverPendingTransactions();

  expect(deleteCalls, 1);
  expect(summary.recoveredCount, 1);
  expect(repository.removedIds, hasLength(1));
});
```

- [ ] **Step 2: 写 `forwardConfirmed + source missing` 恢复测试**

```dart
test('recoverPendingTransactions removes forwardConfirmed entry when source already missing', () async {
  final repository = _FakeJournalRepository(
    storedTransactions: [
      _entry(stage: ClassifyTransactionStage.forwardConfirmed),
    ],
  );
  final coordinator = ClassifyTransactionCoordinator(
    repository: repository,
    anySourceMessageExists: (_) async => false,
    deleteSourceMessages: (_) async => fail('should not delete'),
    nowMs: () => 2000,
    buildTransactionId: _buildId,
  );

  final summary = await coordinator.recoverPendingTransactions();

  expect(summary.recoveredCount, 1);
  expect(repository.removedIds, hasLength(1));
});
```

- [ ] **Step 3: 写 `created` 恢复测试**

```dart
test('recoverPendingTransactions marks created entry as manual review', () async {
  final repository = _FakeJournalRepository(
    storedTransactions: [_entry(stage: ClassifyTransactionStage.created)],
  );
  final coordinator = _buildCoordinator(repository);

  final summary = await coordinator.recoverPendingTransactions();

  expect(summary.manualReviewCount, 1);
  expect(repository.upserted.last.stage, ClassifyTransactionStage.needsManualReview);
});
```

- [ ] **Step 4: 写 `sourceDeleteConfirmed` 恢复测试**

```dart
test('recoverPendingTransactions clears sourceDeleteConfirmed entry directly', () async {
  final repository = _FakeJournalRepository(
    storedTransactions: [
      _entry(stage: ClassifyTransactionStage.sourceDeleteConfirmed),
    ],
  );
  final coordinator = _buildCoordinator(repository);

  final summary = await coordinator.recoverPendingTransactions();

  expect(summary.recoveredCount, 1);
  expect(repository.removedIds, hasLength(1));
});
```

- [ ] **Step 5: 再跑单测确认仍然是“缺实现失败”**

Run: `flutter test test/services/classify_transaction_coordinator_test.dart`
Expected: FAIL，失败原因来自协调器尚未实现，而不是测试拼写错误

### Task 3: 最小实现协调器并让新测试变绿

**Files:**
- Create: `lib/app/services/classify_transaction_coordinator.dart`
- Modify: `test/services/classify_transaction_coordinator_test.dart`

- [ ] **Step 1: 实现最小协调器骨架**

```dart
class ClassifyTransactionCoordinator {
  ClassifyTransactionCoordinator({
    required OperationJournalRepository? repository,
    required this.anySourceMessageExists,
    required this.deleteSourceMessages,
    required this.nowMs,
    required this.buildTransactionId,
  }) : _repository = repository;

  final OperationJournalRepository? _repository;
  final Future<bool> Function(ClassifyTransactionEntry transaction)
      anySourceMessageExists;
  final Future<void> Function(ClassifyTransactionEntry transaction)
      deleteSourceMessages;
  final int Function() nowMs;
  final String Function({
    required int sourceChatId,
    required List<int> sourceMessageIds,
  }) buildTransactionId;

  // startTransaction / markForwardConfirmed / markSourceDeleteConfirmed /
  // recordFailure / recoverPendingTransactions
}
```

- [ ] **Step 2: 实现 `startTransaction` / `markForwardConfirmed` / `markSourceDeleteConfirmed`**

```dart
Future<ClassifyTransactionEntry> startTransaction({...}) async { ... }
Future<ClassifyTransactionEntry> markForwardConfirmed(...) async { ... }
Future<void> markSourceDeleteConfirmed(...) async { ... }
```

要求：
- `startTransaction` 创建 `created` 阶段并 upsert
- `markForwardConfirmed` 更新 `targetMessageIds` 和 `forwardConfirmed`
- `markSourceDeleteConfirmed` 先 upsert `sourceDeleteConfirmed`，再 remove

- [ ] **Step 3: 实现 `recordFailure`**

```dart
Future<void> recordFailure(ClassifyTransactionEntry transaction, Object error) async {
  if (transaction.stage == ClassifyTransactionStage.sourceDeleteConfirmed) {
    await _remove(transaction.id);
    return;
  }
  if (transaction.stage == ClassifyTransactionStage.created) {
    await _upsert(transaction.copyWith(
      stage: ClassifyTransactionStage.needsManualReview,
      updatedAtMs: nowMs(),
      lastError: '$error',
    ));
    return;
  }
  await _upsert(transaction.copyWith(
    updatedAtMs: nowMs(),
    lastError: '$error',
  ));
}
```

- [ ] **Step 4: 实现 `recoverPendingTransactions` 最小逻辑**

```dart
Future<ClassifyRecoverySummary> recoverPendingTransactions() async {
  final pending = _repository?.loadClassifyTransactions() ?? const [];
  // 按 stage 执行 created / forwardConfirmed / sourceDeleteConfirmed /
  // needsManualReview 逻辑并累积 summary
}
```

- [ ] **Step 5: 跑协调器测试确认变绿**

Run: `flutter test test/services/classify_transaction_coordinator_test.dart`
Expected: PASS

### Task 4: 让 `TelegramService` 委托协调器

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 先改 `TelegramService` 相关测试，增加构造适配**

```dart
final service = TelegramService(
  adapter: adapter,
  journalRepository: repository,
);
```

并保持原有 `classifyMessage` / `recoverPendingClassifyOperations` 断言不变。

- [ ] **Step 2: 运行服务测试确认失败点落在新委托实现**

Run: `flutter test test/services/telegram_service_test.dart`
Expected: FAIL，若失败则应集中在 `TelegramService` 尚未接入协调器，而不是测试编译错误

- [ ] **Step 3: 在 `TelegramService` 中注入协调器**

```dart
late final ClassifyTransactionCoordinator _classifyCoordinator =
    ClassifyTransactionCoordinator(
      repository: _journalRepository,
      anySourceMessageExists: _anySourceMessageExists,
      deleteSourceMessages: _deleteSourceMessagesForRecovery,
      nowMs: _nowMs,
      buildTransactionId: _buildClassifyTransactionId,
    );
```

- [ ] **Step 4: 重写 `classifyMessage` 的事务部分为委托调用**

```dart
final startedTransaction = await _classifyCoordinator.startTransaction(...);
...
transaction = await _classifyCoordinator.markForwardConfirmed(
  transaction,
  targetMessageIds: targetMessageIds,
);
...
await _classifyCoordinator.markSourceDeleteConfirmed(transaction);
```

失败路径改为：

```dart
await _classifyCoordinator.recordFailure(transaction, error);
```

- [ ] **Step 5: 将 `recoverPendingClassifyOperations` 改为单行委托**

```dart
@override
Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
  return _classifyCoordinator.recoverPendingTransactions();
}
```

同时新增恢复用私有辅助：

```dart
Future<void> _deleteSourceMessagesForRecovery(
  ClassifyTransactionEntry transaction,
) async {
  await _sendExpectOk(
    DeleteMessages(
      chatId: transaction.sourceChatId,
      messageIds: transaction.sourceMessageIds,
      revoke: true,
    ),
    request: 'deleteMessages(recover)',
    phase: TdlibPhase.business,
  );
}
```

### Task 5: 回归、整理与文档

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: 跑目标测试集**

Run:
`flutter test test/services/classify_transaction_coordinator_test.dart test/services/telegram_service_test.dart test/controllers/pipeline_controller_test.dart test/integration/auth_pipeline_flow_test.dart`

Expected: PASS

- [ ] **Step 2: 清理 `TelegramService` 中已迁出的私有方法**

删除以下已不再使用的方法：

```dart
_buildClassifyTransaction
_recordClassifyTransactionError
_upsertClassifyTransaction
_removeClassifyTransaction
```

保留：

```dart
_anySourceMessageExists
_buildClassifyTransactionId
_nowMs
```

若仍被协调器通过回调使用，则只保留最小必要实现。

- [ ] **Step 3: 更新架构文档**

在 `docs/ARCHITECTURE.md` 中补充：

```md
- `ClassifyTransactionCoordinator`
  - 管理分类事务状态推进、失败记录与未完成事务恢复。
- `TelegramService`
  - 保留 TDLib 业务编排与消息转发确认，不再持有分类恢复状态机。
```

- [ ] **Step 4: 格式化修改文件**

Run:
`dart format lib/app/services/classify_transaction_coordinator.dart lib/app/services/telegram_service.dart test/services/classify_transaction_coordinator_test.dart test/services/telegram_service_test.dart docs/ARCHITECTURE.md`

Expected: Dart 文件格式化成功；文档文件无需改动格式化工具则跳过

- [ ] **Step 5: 跑最终验证**

Run:
`flutter test test/services/classify_transaction_coordinator_test.dart test/services/telegram_service_test.dart`

Expected: PASS

## 自检

- Spec coverage：已覆盖“事务拆分、恢复独立、接口不变、TDD、文档补充”要求
- Placeholder scan：全文无 `TODO/TBD/implement later/待定`
- Type consistency：统一使用 `ClassifyTransactionCoordinator`、`recoverPendingTransactions()`、`markForwardConfirmed()` 等命名

## 说明

- 本计划不包含提交步骤，因为当前仓库工作约束是不主动 `git commit`
- 若全量 `flutter analyze` 或全量 `flutter test` 被既有问题阻塞，只报告证据，不顺手修 unrelated 问题
