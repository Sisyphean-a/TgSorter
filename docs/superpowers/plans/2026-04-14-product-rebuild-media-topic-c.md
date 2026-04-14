# Product Rebuild Media Topic C Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成专题 C 的前后台协同预取、参数化后台媒体调度，以及统一媒体自动重试基础能力。

**Architecture:** 保留 `PipelineMediaController` 作为当前消息媒体状态推进器，把前台/后台预取编排收敛到 `PipelineFeedController`。设置层新增媒体后台并发和自动重试参数；媒体失败不复用分类 retry queue，而是在 pipeline 媒体链路内维护短周期自动重试并把结果落到统一日志模型。

**Tech Stack:** Flutter, GetX, TDLib adapter, flutter_test

---

### Task 1: 扩展设置模型与持久化参数

**Files:**
- Modify: `lib/app/models/app_settings.dart`
- Modify: `lib/app/services/settings_repository.dart`
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Modify: `lib/app/features/settings/presentation/settings_common_editors.dart`
- Test: `test/services/settings_repository_test.dart`
- Test: `test/features/settings/application/settings_coordinator_test.dart`

- [ ] 写失败测试，覆盖新媒体后台参数的默认值、持久化和草稿更新
- [ ] 最小修改设置模型，新增后台下载并发度、自动重试次数、重试间隔
- [ ] 最小修改设置页，明确文案区分预览预取 / 媒体后台下载 / 自动重试
- [ ] 运行相关设置测试

### Task 2: 重构 feed 预取编排为前台/后台双层

**Files:**
- Modify: `lib/app/features/pipeline/application/pipeline_feed_controller.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Test: `test/features/pipeline/application/pipeline_feed_controller_test.dart`

- [ ] 写失败测试，覆盖当前消息优先准备 + 后续消息后台批量预取
- [ ] 写失败测试，覆盖后台并发度限制与 session reset 取消
- [ ] 最小修改 feed controller，拆出前台准备批次与后台预取批次
- [ ] 运行 feed controller 测试

### Task 3: 建立统一媒体自动重试与日志事件

**Files:**
- Modify: `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_runtime_state.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `lib/app/models/classify_operation_log.dart`
- Modify: `lib/app/shared/presentation/formatters/pipeline_log_formatter.dart`
- Test: `test/features/pipeline/application/pipeline_media_controller_test.dart`
- Test: `test/shared/presentation/pipeline_log_view_models_test.dart`

- [ ] 写失败测试，覆盖媒体失败自动重试、重试成功、最终失败三个阶段
- [ ] 扩展媒体控制器，把失败项按设置执行自动重试并更新运行态
- [ ] 扩展日志模型/格式化，使媒体失败和恢复能进日志页
- [ ] 运行媒体控制器与日志测试

### Task 4: 组合验证与收尾

**Files:**
- Modify: `.codexpotter/projects/2026/04/13/3/MAIN.md`

- [ ] 运行专题 C 相关组合测试
- [ ] 复查专题 C 验收项
- [ ] 更新进度文件
- [ ] 提交代码
