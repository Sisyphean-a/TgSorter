# 稳态架构重构设计

- 日期：2026-04-03
- 适用范围：TgSorter Flutter + GetX + TDLib 主应用
- 设计目标：在保持现有用户行为、路由语义和主要交互基本不变的前提下，完成一次覆盖多个方向的稳态大重构，降低核心模块复杂度并提升测试回归质量

## 1. 背景与问题

当前项目已经完成多轮拆分，基础质量不差，测试覆盖也已形成规模。但代码结构仍然保留了明显的“第一阶段演进痕迹”：

- 目录以 `controllers / services / pages / widgets / models / domain` 横切组织，物理结构与业务边界不完全一致。
- `PipelineController` 已成为运行时复杂度中心，承担导航、分类、恢复、剩余统计、媒体刷新、设置响应等多类职责。
- `SettingsController` 同时承担草稿管理、持久化、校验、会话加载、TDLib 重启判定等职责，已接近第二个中心。
- `TelegramGateway` 仍然是大而全接口，`auth / settings / pipeline` 三个模块都通过同一个能力口访问业务服务。
- `bindings.dart` 已经演化为集中式装配中心，后续继续扩展会放大依赖耦合和测试组装成本。
- 部分重构已经完成第一轮拆分，但物理目录和能力边界尚未同步收口，后续继续开发仍然容易把新逻辑堆回大文件。

项目当前最适合的方向不是推倒重来，也不是继续做零碎拆分，而是进行一次“稳态大重构”：在保留当前技术栈、页面行为和外部契约主形态的前提下，重组模块边界和依赖关系。

## 2. 目标与非目标

### 2.1 目标

- 拆掉当前几个主要复杂度中心，尤其是 `PipelineController`、`SettingsController`、`TelegramGateway`、`bindings.dart`。
- 让目录结构更接近真实业务边界，而不是继续围绕技术层组织。
- 把控制器变薄，把复杂行为下沉到可独立测试的协作者。
- 把跨模块依赖从“依赖具体实现”收敛成“依赖能力接口”。
- 在最终收口时，以测试与可回归性为第一优先级，建立稳定的重构后回归基线。

### 2.2 非目标

- 不更换 GetX。
- 不重做 UI 设计语言。
- 不重写 TDLib 底层协议适配逻辑。
- 不引入与当前痛点无关的大型抽象体系。
- 不追求一步到位切成纯粹的理想架构。

## 3. 约束与设计原则

### 3.1 用户约束

- 重构类型：稳态重构。
- 目录调整接受度：高，可进行较大范围文件迁移与重组。
- 成功标准优先级：测试与可回归优先。
- 交付约束：中途允许短暂不稳定，但最终必须收口到稳定状态。

### 3.2 设计原则

- 先定边界，再搬代码。
- 先拆协作者，再拆目录。
- 先保留兼容入口，再逐步收缩旧入口。
- 先补新边界测试，再考虑删除旧的大类回归测试。
- 迁移顺序按依赖收口组织，而不是按文件大小组织。

## 4. 目标架构

### 4.1 总体思路

本次重构采用“按业务模块为主，按基础设施为辅”的组织方式。

- `core/` 存放跨模块基础设施，例如 TDLib 底层接入、DI、路由、全局错误。
- `features/` 承载 `auth / pipeline / settings` 三个明确业务边界。
- `shared/` 仅保留真正共享的 UI 主题与通用组件。

这样做的核心目的是避免后续新逻辑再次集中回流到 `services/` 或 `controllers/` 这种横切目录。

### 4.2 目标目录结构

```text
lib/app/
  app.dart
  bootstrap_app.dart

  core/
    di/
      app_bindings.dart
      auth_module.dart
      pipeline_module.dart
      settings_module.dart
    routing/
      app_routes.dart
    errors/
      app_error_controller.dart
      app_error_models.dart
    tdlib/
      adapter/
      transport/
      auth/
      proxy/
      schema/
      dto/

  features/
    auth/
      application/
        auth_coordinator.dart
        auth_gateway.dart
      presentation/
        auth_page.dart
        auth_view_model.dart
        widgets/
    pipeline/
      application/
        pipeline_coordinator.dart
        pipeline_navigation_service.dart
        pipeline_action_service.dart
        pipeline_recovery_service.dart
        pipeline_media_refresh_service.dart
        remaining_count_service.dart
        pipeline_runtime_state.dart
        pipeline_settings_reader.dart
      domain/
        pipeline_message.dart
        message_preview_builder.dart
        message_preview_mapper.dart
        flood_wait.dart
        td_error_classifier.dart
      infrastructure/
        telegram_message_reader.dart
        telegram_media_service.dart
        telegram_classify_workflow.dart
        telegram_message_forwarder.dart
        telegram_session_resolver.dart
        message_history_paginator.dart
        media_download_coordinator.dart
      presentation/
        pipeline_page.dart
        pipeline_mobile_view.dart
        pipeline_desktop_view.dart
        pipeline_desktop_panels.dart
        pipeline_log_formatter.dart
        widgets/
    settings/
      application/
        settings_coordinator.dart
        settings_draft_session.dart
        category_settings_service.dart
        shortcut_settings_service.dart
        connection_settings_service.dart
        chat_selection_service.dart
      domain/
        app_settings.dart
        workflow_settings.dart
        connection_settings.dart
        shortcut_settings.dart
        category_config.dart
        proxy_settings.dart
        shortcut_binding.dart
      infrastructure/
        settings_repository.dart
        operation_journal_repository.dart
      presentation/
        settings_page.dart
        settings_sections.dart
        settings_page_parts.dart
        settings_common_editors.dart
        settings_category_dialog.dart

  shared/
    theme/
    widgets/
```

### 4.3 关键边界定义

- `auth`
  - 负责登录流程、授权状态推进、启动失败恢复。
  - 不直接持有 settings 草稿管理细节。
- `pipeline`
  - 负责消息浏览、分类、恢复、媒体准备、剩余统计等运行时流程。
  - 只读取必要配置能力，不依赖 settings 具体实现。
- `settings`
  - 负责草稿编辑、持久化、配置发布和重启判定。
  - 不承担 pipeline 的运行时控制逻辑。
- `core/tdlib`
  - 只负责 TDLib 生命周期、收发、协议解析与运行环境适配。
  - 不承载上层业务语义。

## 5. 核心拆分设计

### 5.1 Pipeline 子系统

当前 `PipelineController` 已经承担过多职责。本次重构将其从“神控制器”改为“薄协调器 + 协作者组”。

#### 新的角色划分

- `PipelineCoordinator`
  - 暴露页面所需状态和交互入口。
  - 编排协作者，但不承载复杂业务细节。
- `PipelineNavigationService`
  - 负责消息缓存、当前索引、前后切换、预取与可见项同步。
- `PipelineActionService`
  - 负责 `classify / skip / undo / retry`。
- `PipelineRecoveryService`
  - 负责 pending classify 恢复。
- `PipelineMediaRefreshService`
  - 负责媒体准备、轮询刷新、播放前状态推进。
- `RemainingCountService`
  - 负责剩余数量统计与请求竞争控制。
- `PipelineRuntimeState`
  - 收敛当前分散在控制器中的运行态字段。

#### 设计结果

- 页面依赖 `PipelineCoordinator`。
- 复杂业务逻辑可以落到 focused test，而不是只能通过大控制器测试。
- `PipelineCoordinator` 本身的职责收敛到状态暴露与协作者编排。

### 5.2 Settings 子系统

当前 `SettingsController` 同时承担草稿管理、校验、持久化、会话加载与重启判定。重构后将其改为协调器与子域服务组合。

#### 新的角色划分

- `SettingsCoordinator`
  - 对页面提供统一的 `draft / save / discard / loadChats` 入口。
  - 对外发布当前已生效设置。
- `SettingsDraftSession`
  - 管理草稿、副本同步和 dirty 状态。
- `CategorySettingsService`
  - 负责分类项增删改与重复检测。
- `ShortcutSettingsService`
  - 负责快捷键更新与冲突校验。
- `ConnectionSettingsService`
  - 负责来源 chat、代理配置、重启需求判定。
- `ChatSelectionService`
  - 负责可选会话加载。

#### 设置模型拆分

保留 `AppSettings` 作为聚合根，但内部拆出子值对象：

- `WorkflowSettings`
- `ConnectionSettings`
- `ShortcutSettings`

这样可以在不破坏仓储整体语义的前提下，把设置逻辑按领域分开。

### 5.3 Telegram 能力接口

当前 `TelegramGateway` 同时承载 auth、session、message、media、classify 等能力，边界过宽。重构后按使用者视角拆成能力接口组。

#### 能力接口

- `AuthGateway`
- `SessionQueryGateway`
- `MessageReadGateway`
- `MediaGateway`
- `ClassifyGateway`
- `RecoveryGateway`

#### 实现策略

- `TelegramService` 保留为 facade。
- facade 实现多个能力接口。
- feature 模块只注入自己需要的能力口。

这样做可以在保持总体实现稳定的情况下，减少 feature 对单一大接口的耦合。

### 5.4 Composition Root

当前 `bindings.dart` 负责所有实例注册，已经接近集中式装配中心。重构后拆成模块装配：

- `registerCoreModule()`
- `registerAuthModule()`
- `registerPipelineModule()`
- `registerSettingsModule()`

总入口仍保留 `initDependencies()`，但内部只做模块编排，不再直接承载所有构造细节。

## 6. 迁移方案

本次重构采用六阶段迁移。每个阶段覆盖多个方向，但只有一个主要变化中心。

### Phase 1：建立新骨架与过渡入口

目标：

- 建立 `core/`、`features/`、`shared/` 目录骨架。
- 建立新的 coordinator、service、gateway 接口骨架。
- 保留旧入口作为过渡 facade 或兼容层。

要求：

- 本阶段尽量不改变运行时行为。
- 重点是为后续迁移提供落点。

### Phase 2：重构 Pipeline 子系统

目标：

- 拆分 `PipelineController`。
- 引入运行态对象和导航、动作、恢复、媒体、剩余统计等协作者。
- 页面改依赖 `PipelineCoordinator`。

要求：

- pipeline 是当前最大复杂度中心，应优先处理。
- 旧测试先保留，用作迁移保护网。

### Phase 3：重构 Telegram capability 边界

目标：

- 将 `TelegramGateway` 拆成能力接口组。
- `TelegramService` 变为实现多个接口的 facade。
- `auth / pipeline / settings` 分别改为依赖各自所需能力。

要求：

- 只调整边界与注入，不重写 TDLib 业务语义。

### Phase 4：重构 Settings 子系统

目标：

- 拆分 `SettingsController`。
- 建立草稿会话、分类、快捷键、连接设置和会话加载等服务。
- 保留 `AppSettings` 聚合根，同时把内部结构拆为子值对象。

要求：

- 保持存储格式兼容。
- 不顺手更改页面表单交互语义。

### Phase 5：目录大迁移与共享组件收口

目标：

- 将旧的横切目录内容迁到 `core / features / shared`。
- 把 feature 专属组件收回各自模块。
- 删除过渡 re-export 和旧路径壳文件。

要求：

- 这一阶段以物理迁移与 import 修复为主。
- 尽量避免引入新的行为变化。

### Phase 6：装配收尾与最终回归

目标：

- 完成 DI 模块化。
- 页面装配改为面向 coordinator。
- 清理多余 `Get.find<ConcreteType>()`。
- 更新架构文档并完成最终回归。

要求：

- 最终以 analyze 与测试结果作为收口标准。

## 7. 测试与回归策略

本次重构以测试与可回归性为第一优先级。测试策略遵循“先保旧回归，再补新边界，最后收缩旧测试”。

### 7.1 保留旧测试作为迁移保护网

前期不删除现有 controller / service / page / widget 测试，即使其中一部分围绕旧大类组织，也先保留其回归价值。

### 7.2 新增 focused tests

随着协作者下沉，为以下对象补充 focused test：

- `PipelineNavigationService`
- `PipelineActionService`
- `PipelineRecoveryService`
- `PipelineMediaRefreshService`
- `RemainingCountService`
- `SettingsDraftSession`
- `CategorySettingsService`
- `ShortcutSettingsService`
- `ConnectionSettingsService`
- capability-based gateway fakes 或 contract-style tests

### 7.3 协调器测试

对 `PipelineCoordinator`、`SettingsCoordinator`、`AuthCoordinator` 保留行为回归测试，用于确认页面依赖的状态与交互入口未发生语义偏移。

### 7.4 页面与组件测试策略

UI 测试只保关键路径，不承担全部业务回归责任。重点保留：

- auth 页面
- pipeline 页面与移动端/桌面端视图
- settings 页面
- 关键消息预览组件

### 7.5 强检查点

- 检查点 A：Phase 2 结束后，pipeline 相关核心测试恢复。
- 检查点 B：Phase 4 结束后，auth / settings / pipeline 主流程测试恢复。
- 检查点 C：Phase 6 结束后，`dart analyze`、核心单测、关键页面/组件测试、integration test 全部收口。

## 8. 风险与控制策略

### 8.1 接口拆分与目录迁移混合放大 diff

风险：

- 接口、注入、路径、import 同时变化，会显著放大 review 和回归难度。

控制：

- 每阶段只允许一个主变化中心。
- 目录大迁移集中到后半程处理。

### 8.2 Pipeline 重构引入行为偏移

风险：

- 自动抓取、当前消息同步、undo/retry、媒体刷新、剩余统计都容易在拆分时出现细微偏移。

控制：

- 先抽状态对象和协作者，再迁移方法。
- 旧的 pipeline 回归测试前期全部保留。

### 8.3 Settings 结构调整破坏存储兼容

风险：

- `AppSettings` 内部拆分后，如果仓储格式同步大改，可能破坏既有配置。

控制：

- 先保持现有持久化结构兼容。
- 如确需迁移格式，单独实现显式 migration。

### 8.4 能力接口拆得过碎

风险：

- 过度拆分会制造样板接口和装配负担。

控制：

- 接口按使用者视角组织，而不是按单个方法机械拆分。

### 8.5 大规模文件迁移损害 git 历史可读性

风险：

- 边重命名边大改内容会降低 blame 和 review 可读性。

控制：

- 尽量做到“先拆职责，再搬位置”。
- 逻辑变化与物理迁移尽量分批提交。

## 9. 预期收益

完成本次重构后，项目应获得以下收益：

- 几个主要复杂度中心被打散，不再继续膨胀。
- 目录结构更接近真实业务边界。
- 新逻辑能优先落到 feature 模块，而不是回流到横切大目录。
- 测试从围绕大类兜底，逐步转向围绕清晰协作者和协调器回归。
- 后续继续重构或增加功能时，成本明显下降。

## 10. 执行建议

建议采用以下实际执行顺序：

1. 先基于本设计编写详细实施计划。
2. 实施时按“接口收口 -> 协作者拆分 -> 目录迁移 -> 装配收尾”推进。
3. 中途允许局部不稳定，但必须保留强检查点。
4. 最终以 analyze、核心测试和架构文档更新作为收口条件。

## 11. 验收标准

满足以下条件时，本次重构视为完成：

- `PipelineController`、`SettingsController`、`TelegramGateway`、`bindings.dart` 的核心职责已被实质拆分。
- 目录结构已迁移到 `core / features / shared` 主体形态。
- feature 页面依赖 coordinator，coordinator 依赖能力接口，复杂行为下沉到服务。
- 现有用户行为、主要页面交互和路由语义保持稳定。
- `dart analyze` 收口。
- 核心服务、协调器、页面、组件和集成测试回归通过。
