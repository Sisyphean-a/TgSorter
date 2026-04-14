# Product Rebuild Media Topic B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成专题 B 的媒体终态收口，让音频一次点击后自动起播、图片失败可见且可重试、视频准备阶段语义清晰。

**Architecture:** 以现有 `PipelineMediaController` 和 `MediaSessionState` 为中心补状态，不做第二套媒体状态机。服务层继续复用 `prepareMediaPreview` / `prepareMediaPlayback`，控制器负责把准备中、失败、就绪投影到 UI；组件层只消费统一状态并提供重试入口。

**Tech Stack:** Flutter, GetX, TDLib adapter, flutter_test

---

### Task 1: 补媒体失败态与当前图片预热

**Files:**
- Modify: `lib/app/features/pipeline/application/pipeline_runtime_state.dart`
- Modify: `lib/app/features/pipeline/application/media_session_state.dart`
- Modify: `lib/app/features/pipeline/application/media_session_projector.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_media_refresh_service.dart`
- Test: `test/features/pipeline/application/pipeline_media_controller_test.dart`
- Test: `test/features/pipeline/application/pipeline_media_session_controller_test.dart`

- [ ] 写失败测试，覆盖当前图片缺预览时会先触发 `prepareMediaPreview`
- [ ] 写失败测试，覆盖媒体会话能把失败项投影成 failed + 错误文本
- [ ] 最小修改运行态和 projector，补失败映射
- [ ] 最小修改媒体控制器，补图片预热启动与失败清理
- [ ] 运行 `flutter test test/features/pipeline/application/pipeline_media_controller_test.dart test/features/pipeline/application/pipeline_media_session_controller_test.dart`

### Task 2: 补音频自动起播与图片失败重试 UI

**Files:**
- Modify: `lib/app/shared/presentation/widgets/message_preview_content.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_audio.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_media.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_image_gallery.dart`
- Test: `test/widgets/message_preview_audio_test.dart`
- Test: `test/widgets/message_preview_image_gallery_test.dart`

- [ ] 写失败测试，覆盖音频首次点击后文件就绪时自动播放
- [ ] 写失败测试，覆盖图片失败态显示重试入口并回调请求
- [ ] 最小修改音频组件，补待自动起播状态
- [ ] 最小修改图片组件，补失败占位、等待态和重试按钮
- [ ] 运行 `flutter test test/widgets/message_preview_audio_test.dart test/widgets/message_preview_image_gallery_test.dart`

### Task 3: 收紧视频阶段提示

**Files:**
- Modify: `lib/app/shared/presentation/widgets/message_preview_content.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_video.dart`
- Test: `test/widgets/message_preview_video_test.dart`

- [ ] 写失败测试，覆盖视频等待本地文件时展示明确阶段文案
- [ ] 最小修改视频组件，拆出准备态/等待缓存完成提示
- [ ] 运行 `flutter test test/widgets/message_preview_video_test.dart`

### Task 4: 回归验证与收尾

**Files:**
- Modify: `.codexpotter/projects/2026/04/13/3/MAIN.md`

- [ ] 运行 `flutter test test/features/pipeline/application/pipeline_media_controller_test.dart test/features/pipeline/application/pipeline_media_session_controller_test.dart test/widgets/message_preview_audio_test.dart test/widgets/message_preview_image_gallery_test.dart test/widgets/message_preview_video_test.dart`
- [ ] 复查专题 B 目标与代码实际表现是否一致
- [ ] 更新进度文件 Done / In Progress / Todo
- [ ] 提交代码
