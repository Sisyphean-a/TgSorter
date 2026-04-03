# Media Download Coordinator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 抽出 `MediaDownloadCoordinator`，统一承接媒体预热下载与播放下载，同时保持 `TelegramService` 对外行为不变。

**Architecture:** 新增一个只负责下载策略与 `downloadFile` 调用的协调器，直接依赖 `TdlibAdapter`。`TelegramService` 保留鉴权、消息加载、刷新与业务编排，只在拿到 `TdMessageContentDto` 后委托协调器执行预热或播放下载。

**Tech Stack:** Dart、Flutter test、TDLib DTO / Adapter、现有 `TelegramService` 测试桩

---

### Task 1: 为下载协调器写失败测试

**Files:**
- Create: `test/services/media_download_coordinator_test.dart`
- Reference: `lib/app/services/td_message_dto.dart`
- Reference: `lib/app/services/tdlib_adapter.dart`
- Reference: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 写图片预热下载测试**

```dart
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
});
```

- [ ] **Step 2: 写视频预热只下缩略图测试**

```dart
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
```

- [ ] **Step 3: 写播放下载与跳过规则测试**

```dart
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
```

```dart
test('preparePlayback skips download when local path already exists', () async {
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
});
```

- [ ] **Step 4: 运行失败测试确认缺少协调器实现**

Run: `flutter test test/services/media_download_coordinator_test.dart`
Expected: FAIL，提示 `MediaDownloadCoordinator` 未定义

### Task 2: 实现 `MediaDownloadCoordinator`

**Files:**
- Create: `lib/app/services/media_download_coordinator.dart`
- Test: `test/services/media_download_coordinator_test.dart`

- [ ] **Step 1: 写最小实现骨架**

```dart
class MediaDownloadCoordinator {
  const MediaDownloadCoordinator({required TdlibAdapter adapter})
    : _adapter = adapter;

  final TdlibAdapter _adapter;

  Future<void> warmUpPreview(TdMessageContentDto content) async {}
  Future<bool> preparePlayback(TdMessageContentDto content) async => false;
}
```

- [ ] **Step 2: 实现预热下载规则**

```dart
if (content.kind == TdMessageContentKind.photo) {
  return _ensureFileDownloadStarted(
    fileId: content.remoteImageFileId,
    localPath: content.localImagePath,
    priority: _downloadPriorityPhotoPreview,
  );
}
if (content.kind == TdMessageContentKind.video) {
  return _ensureFileDownloadStarted(
    fileId: content.remoteVideoThumbnailFileId,
    localPath: content.localVideoThumbnailPath,
    priority: _downloadPriorityVideoPreview,
  );
}
```

- [ ] **Step 3: 实现播放下载规则与统一跳过逻辑**

```dart
if (content.kind == TdMessageContentKind.audio) {
  return _ensureFileDownloadStarted(
    fileId: content.remoteAudioFileId,
    localPath: content.localAudioPath,
    priority: _downloadPriorityAudioFile,
  );
}
if (content.kind == TdMessageContentKind.video) {
  return _ensureFileDownloadStarted(
    fileId: content.remoteVideoFileId,
    localPath: content.localVideoPath,
    priority: _downloadPriorityVideoFile,
  );
}
return false;
```

- [ ] **Step 4: 运行 `flutter test test/services/media_download_coordinator_test.dart` 确认通过**

### Task 3: 回接 `TelegramService`

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 注入并持有协调器**

```dart
late final MediaDownloadCoordinator _mediaDownloadCoordinator =
    MediaDownloadCoordinator(adapter: _adapter);
```

- [ ] **Step 2: 将消息页与单条消息预热改为委托协调器**

```dart
for (final item in messages) {
  await _mediaDownloadCoordinator.warmUpPreview(item.content);
}
```

```dart
await _mediaDownloadCoordinator.warmUpPreview(message.content);
```

- [ ] **Step 3: 将 `prepareMediaPreview()` / `prepareMediaPlayback()` 改为委托协调器**

```dart
await _mediaDownloadCoordinator.warmUpPreview(message.content);
```

```dart
final changed = await _mediaDownloadCoordinator.preparePlayback(message.content);
if (!changed && content.kind != TdMessageContentKind.video) {
  return _previewBuilder.toPipelineMessage(
    messages: <TdMessageDto>[message],
    sourceChatId: sourceChatId,
  );
}
return refreshMessage(sourceChatId: sourceChatId, messageId: messageId);
```

- [ ] **Step 4: 删除服务内重复下载私有方法并运行 `flutter test test/services/telegram_service_test.dart`**

### Task 4: 更新文档并做定向回归

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Reference: `test/controllers/pipeline_controller_test.dart`
- Reference: `test/services/message_history_paginator_test.dart`

- [ ] **Step 1: 更新架构文档的下载职责边界**

```md
- `MediaDownloadCoordinator`
  - 负责媒体预热下载、播放下载与 `downloadFile` 跳过规则。
```

- [ ] **Step 2: 运行回归测试**

Run: `flutter test test/services/media_download_coordinator_test.dart test/services/telegram_service_test.dart test/controllers/pipeline_controller_test.dart test/services/message_history_paginator_test.dart`
Expected: PASS

- [ ] **Step 3: 汇总变更与剩余风险**

需要确认：
- 视频预热仍只下载缩略图；
- 音频播放下载仍会触发刷新；
- 已有本地路径时不会重复下载。
