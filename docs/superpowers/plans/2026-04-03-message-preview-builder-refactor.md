# Message Preview Builder 重构计划

- 日期：2026-04-03
- 关联设计：`docs/superpowers/specs/2026-04-03-message-preview-builder-refactor-design.md`
- 执行策略：TDD，小步提交，优先保持行为不变

## 1. 任务边界

本计划只处理 `TelegramService` 中的预览组装链路，不处理媒体下载协调器。

## 2. 执行步骤

### Task 1：先写 builder 失败测试

**Files:**
- Create: `test/domain/message_preview_builder_test.dart`
- Reference: `lib/app/domain/message_preview_mapper.dart`
- Reference: `lib/app/models/pipeline_message.dart`
- Reference: `lib/app/services/td_message_dto.dart`

- [ ] 写 latest-first 音频相册聚合测试
- [ ] 写 latest-first 图片相册聚合测试
- [ ] 写 oldest-first 视频相册顺序测试
- [ ] 运行 `flutter test test/domain/message_preview_builder_test.dart`，确认因缺少 builder 失败

### Task 2：实现 `MessagePreviewBuilder`

**Files:**
- Create: `lib/app/domain/message_preview_builder.dart`

- [ ] 实现 `groupPipelineMessages()`
- [ ] 实现 `toPipelineMessage()`
- [ ] 实现内部 preview 组装逻辑
- [ ] 运行 builder 测试直到通过

### Task 3：接入 `TelegramService`

**Files:**
- Modify: `lib/app/services/telegram_service.dart`

- [ ] 注入并使用 builder
- [ ] 删除服务内重复的组装私有方法
- [ ] 保持公开接口不变

### Task 4：更新文档与回归验证

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Reference: `test/services/telegram_service_test.dart`
- Reference: `test/controllers/pipeline_controller_test.dart`

- [ ] 更新架构职责说明
- [ ] 运行 `flutter test test/services/telegram_service_test.dart`
- [ ] 运行 `flutter test test/controllers/pipeline_controller_test.dart`
- [ ] 汇总结果与剩余风险
