# countRemainingMessages Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将剩余消息统计从“全量拉取后取长度”改为“分页累计计数”，降低内存占用并保持现有行为。

**Architecture:** 仅调整 `TelegramMessageReader.countRemainingMessages()` 的实现，继续使用现有 Tdlib 历史翻页语义、防重集合与游标推进保护，不影响其它读取链路。

**Tech Stack:** Flutter、Dart、TDLib、`flutter_test`

---

## File Map

**Modify**
- `lib/app/services/telegram_message_reader.dart` — 改为分页累计计数
- `test/services/telegram_service_test.dart` — 增加重复游标不重复计数测试

### Task 1: 优化计数实现并补回归

**Files:**
- Modify: `lib/app/services/telegram_message_reader.dart`
- Modify: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 写重复游标不重复计数的失败测试**

```dart
test('countRemainingMessages skips duplicate cursor message between pages', () async {
  // 第一页 [10, 9]，第二页 [9, 8]，期望计数 3
});
```

- [ ] **Step 2: 跑单测确认先失败**

Run: `flutter test test/services/telegram_service_test.dart --plain-name "countRemainingMessages skips duplicate cursor message between pages"`
Expected: FAIL

- [ ] **Step 3: 改为分页累计计数最小实现**

```dart
Future<int> countRemainingMessages(int chatId) async {
  var count = 0;
  var cursor = 0;
  final seenMessageIds = <int>{};
  while (true) {
    final page = await _fetchHistoryPage(...);
    if (page.isEmpty) return count;
    ...
    count++;
  }
}
```

- [ ] **Step 4: 跑服务测试与控制器回归**

Run: `flutter test test/services/telegram_service_test.dart test/controllers/pipeline_controller_test.dart`
Expected: PASS
