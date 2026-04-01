# Video Lazy Download And Preview Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让视频消息首屏只下载缩略图，点击播放才下载主视频，并修复深色主题下文本不可见与视频下载完成后仍不显示播放器的问题。

**Architecture:** 保持 `TelegramService` 负责 TDLib 请求与下载触发，但把视频主文件下载从消息获取阶段移到显式播放动作。UI 侧为视频预览补充下载状态与刷新机制，让缩略图、下载中、可播放三种状态明确切换，同时统一深色主题文本颜色。

**Tech Stack:** Flutter, GetX, TDLib, flutter_test

---

### Task 1: 为视频懒下载行为补测试

**Files:**
- Modify: `test/services/telegram_service_test.dart`
- Modify: `lib/app/services/telegram_service.dart`

- [ ] 写失败测试：获取视频消息时只触发缩略图下载，不触发主视频下载
- [ ] 运行单测确认先失败
- [ ] 最小实现修复服务层下载策略
- [ ] 重新运行单测确认通过

### Task 2: 为视频播放触发下载与刷新补测试

**Files:**
- Modify: `test/controllers/pipeline_controller_test.dart`
- Modify: `test/widgets/message_viewer_card_test.dart`
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`

- [ ] 写失败测试：点击播放时触发视频下载
- [ ] 写失败测试：下载完成后预览从占位态切到播放器态
- [ ] 运行测试确认先失败
- [ ] 最小实现控制器/UI 修复
- [ ] 重新运行测试确认通过

### Task 3: 为深色主题文本可见性补测试

**Files:**
- Modify: `test/widgets/message_viewer_card_test.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`

- [ ] 写失败测试：深色主题下正文/元信息使用高对比颜色
- [ ] 运行测试确认先失败
- [ ] 最小实现样式修复
- [ ] 重新运行测试确认通过

### Task 4: 回归验证

**Files:**
- Verify: `test/services/telegram_service_test.dart`
- Verify: `test/widgets/message_viewer_card_test.dart`
- Verify: `test/controllers/pipeline_controller_test.dart`
- Verify: `test/integration/auth_pipeline_flow_test.dart`

- [ ] 运行针对性回归测试
- [ ] 检查失败项并修复后再验证
