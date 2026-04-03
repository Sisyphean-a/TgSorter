# 最终架构演化设计

- 日期：2026-04-04
- 适用范围：TgSorter Flutter + GetX + TDLib 主应用
- 设计目标：在现有稳态重构成果基础上，彻底移除兼容层与 legacy 语义，完成一次性架构收口，使 `features/*` 成为唯一真实代码入口

## 1. 背景

2026-04-03 的稳态架构重构已经完成了主要拆分：

- 引入了 `core/di` 与 `core/routing`
- 建立了 `features/auth`、`features/pipeline`、`features/settings`
- 将 `TelegramService` 收口为 capability-based facade
- 将 pipeline / settings 的复杂逻辑拆入 coordinator 与子服务

但当前结构仍然保留一整层迁移中间态：

- `lib/app/controllers/*` 仍是兼容导出壳
- `lib/app/pages/*` 仍是兼容导出壳
- `features/*/application/*_legacy.dart` 承载真实实现
- DI、路由、页面和测试仍然混合使用旧 controller 语义与新 coordinator 语义
- `shared/` 尚未真正建立，跨 feature 共用部件仍散落在 `widgets/`、`pages/` 与 feature presentation 内

这导致当前项目虽然“结构方向正确”，但还不是最终形态：

- 路径与职责不完全一致
- 新老命名混用
- 调用链仍带有明显过渡痕迹
- 后续开发容易继续沿用旧路径或旧语义接入

本次演化的目标不是再做一次渐进兼容式迁移，而是完成最终清算：删除兼容层、统一入口、统一命名、统一共享边界。

## 2. 目标与非目标

### 2.1 目标

- 删除 `lib/app/controllers/*` 与 `lib/app/pages/*` 兼容导出壳
- 删除 `*_legacy.dart`
- 让 `features/*` 成为唯一真实代码入口
- 统一将 feature 应用层入口收敛为 coordinator 语义
- 将真正跨 feature 共享的部件下沉到 `shared/`
- 让 DI、路由、页面、测试全部改为依赖最终边界
- 保持现有用户行为、路由语义与 TDLib 业务语义稳定

### 2.2 非目标

- 不更换 GetX
- 不重写 Telegram / TDLib 底层实现
- 不重做视觉设计
- 不引入新的大型框架
- 不为了“概念纯度”而做与当前痛点无关的拆分

## 3. 设计原则

### 3.1 单一路径原则

同一职责只能有一套真实路径：

- 页面只能从 `features/*/presentation` 暴露
- 应用层入口只能从 `features/*/application` 暴露
- 删除旧路径壳，禁止双路径共存

### 3.2 命名与职责一致

既然当前应用层入口已经不再是传统页面级 GetX controller，就不继续保留 `*Controller` 命名伪装。命名必须反映真实职责：

- 协调业务流程、组合子服务的类型使用 `*Coordinator`
- 负责局部算法或流程片段的类型使用 `*Service`
- 只承载数据/状态的类型使用 `*State` 或 domain/value object

### 3.3 页面只面向最终应用边界

页面不再依赖旧 controller 路径或中间过渡别名，而是直接依赖：

- `AuthCoordinator`
- `PipelineCoordinator`
- `SettingsCoordinator`

页面可以读取 coordinator 暴露的状态与命令，但不直接依赖 TDLib、仓储或底层 facade 细节。

### 3.4 shared 只承接真实共享

`shared/` 不是“放不下的杂物间”，只接收以下内容：

- 至少被两个 feature 使用的展示组件
- 明显属于通用 UI 壳层或展示能力的组件
- 与单一 feature 业务规则无关的格式化或展示辅助

任何强依赖某个 feature 语义的页面部件，仍应留在该 feature 内。

## 4. 目标架构

### 4.1 最终调用链

```text
GetMaterialApp
  -> core/routing/app_routes.dart
    -> features/*/presentation pages
      -> features/*/application coordinators
        -> features/*/application services
          -> capability interfaces
            -> services/TelegramService / repositories / tdlib adapter
```

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

  features/
    auth/
      application/
        auth_coordinator.dart
        auth_gateway.dart
      presentation/
        auth_page.dart
        widgets/

    pipeline/
      application/
        pipeline_coordinator.dart
        pipeline_runtime_state.dart
        pipeline_navigation_service.dart
        pipeline_action_service.dart
        pipeline_recovery_service.dart
        pipeline_media_refresh_service.dart
        remaining_count_service.dart
        pipeline_settings_reader.dart
        message_read_gateway.dart
        media_gateway.dart
        classify_gateway.dart
        recovery_gateway.dart
      presentation/
        pipeline_page.dart
        pipeline_mobile_view.dart
        pipeline_desktop_view.dart
        pipeline_desktop_panels.dart
        widgets/

    settings/
      application/
        settings_coordinator.dart
        settings_draft_session.dart
        category_settings_service.dart
        shortcut_settings_service.dart
        connection_settings_service.dart
        chat_selection_service.dart
        session_query_gateway.dart
      domain/
        workflow_settings.dart
        connection_settings.dart
        shortcut_settings.dart
      presentation/
        settings_page.dart
        settings_sections.dart
        settings_page_parts.dart
        settings_common_editors.dart
        settings_category_dialog.dart

  shared/
    presentation/
      widgets/
      formatters/
    domain/
    utils/

  models/
  services/
  theme/
```

## 5. 类型收口设计

### 5.1 重命名策略

以下真实应用层入口全部切换为 coordinator 命名：

- `AuthController` -> `AuthCoordinator`
- `PipelineController` -> `PipelineCoordinator`
- `SettingsController` -> `SettingsCoordinator`

重命名后：

- DI 只注册 coordinator
- 路由只注入 coordinator
- 页面构造参数只接收 coordinator
- 测试只构造 coordinator

### 5.2 删除策略

以下内容全部删除，不保留兼容路径：

- `lib/app/controllers/auth_controller.dart`
- `lib/app/controllers/pipeline_controller.dart`
- `lib/app/controllers/settings_controller.dart`
- `lib/app/controllers/pipeline_settings_provider.dart`
- `lib/app/pages/*`
- `features/*/application/*_legacy.dart`

该删除不是单独动作，而是在调用方全部迁移完成后执行。

### 5.3 应用层职责

#### AuthCoordinator

- 监听授权状态
- 暴露登录阶段与 loading 状态
- 处理手机号、验证码、密码提交
- 协调代理保存与重启重试

#### PipelineCoordinator

- 作为 pipeline 页面唯一应用层入口
- 暴露运行状态、当前消息、剩余数量、导航能力与分类命令
- 组合 `PipelineNavigationService / PipelineActionService / PipelineRecoveryService / PipelineMediaRefreshService / RemainingCountService`
- 吸收旧 `PipelineController` 中仍然属于应用层的编排逻辑

#### SettingsCoordinator

- 作为 settings 页面唯一应用层入口
- 暴露已保存配置、草稿配置、dirty 状态、可选 chats、保存/放弃等命令
- 组合 draft session 与各类 settings 子服务

## 6. shared 归位设计

### 6.1 迁入 shared 的候选

以下类型符合跨 feature 共享条件，应迁入 `shared`：

- `AppShell`
- `BrandAppBar`
- `StatusBadge`
- `WorkspacePanel`
- `StickyActionBar`
- `MessageViewerCard`
- `message_preview_*`
- `pipeline_log_formatter.dart`

### 6.2 保留在 feature 内的内容

以下内容仍留在各 feature presentation：

- 只被单个 feature 页面使用的布局容器
- settings 专属 editor / dialog
- pipeline 专属桌面 / 移动布局切换部件
- 带明显 feature 语义的按钮组与状态条

### 6.3 shared 边界要求

- shared 组件不能依赖 feature coordinator
- shared 组件可以依赖 `models/`、`theme/`、shared 内部工具
- shared formatter 不能编码单个 feature 的业务判断

## 7. DI 与路由收口

### 7.1 DI

`core/di/*` 最终只注册以下真实入口：

- `AuthCoordinator`
- `PipelineCoordinator`
- `SettingsCoordinator`
- capability interfaces 的实现
- 底层仓储与 TDLib 运行依赖

不再注册旧 controller 名称或兼容别名。

### 7.2 路由

`app_routes.dart` 只装配 feature 真路径页面，并传入真实 coordinator：

- `AuthPage(auth: Get.find<AuthCoordinator>(), ...)`
- `PipelinePage(pipeline: Get.find<PipelineCoordinator>(), ...)`
- `SettingsPage(settings: Get.find<SettingsCoordinator>(), ...)`

路由常量继续保留，以维持外部导航语义稳定。

## 8. 测试迁移设计

### 8.1 测试边界

测试同步迁移到最终结构：

- application 测试面向 coordinator 与子服务
- page 测试面向 feature presentation 真路径
- integration 测试面向真实路由与真实 coordinator 装配

### 8.2 删除旧依赖

测试中不再允许：

- import `app/controllers/*`
- import `app/pages/*`
- 引用 `*_legacy.dart`

### 8.3 回归范围

最终回归至少覆盖：

- `dart analyze`
- `test/features/pipeline/application`
- `test/features/settings/application`
- `test/services`
- `test/pages`
- `test/widgets`
- `test/integration/auth_pipeline_flow_test.dart`
- `test/controllers` 若目录保留则应完成迁移或被移除

## 9. 风险与控制策略

### 9.1 主要风险

- 类型名统一改为 coordinator 后，`Get.find<T>()` 与页面构造可能遗漏
- 删除兼容壳后，旧 import 会集中爆出 analyzer error
- PipelineCoordinator 吸收旧编排逻辑时，容易顺手改行为
- shared 抽取时，容易把 feature 专属逻辑误抽成公共组件

### 9.2 控制策略

- 先完成命名与装配切换，再删兼容层
- 先保证页面和测试都跑通，再做 shared 归位
- shared 迁移只做物理归位与 import 改写，不顺手改行为
- 每轮调整后先跑 `dart analyze`，再跑受影响测试集

## 10. 验收标准

完成后必须满足：

- 项目中不存在 `*_legacy.dart`
- `lib/app/controllers/` 不再承载兼容导出壳
- `lib/app/pages/` 不再承载兼容导出壳
- 页面与测试不再引用旧 controller / page 路径
- `features/*` 成为唯一真实 feature 入口
- `shared/` 承接真实跨 feature 共享部件
- `dart analyze` 通过
- 关键测试集全部通过
- `docs/ARCHITECTURE.md` 与真实结构一致

## 11. 推荐执行顺序

1. 统一 coordinator 命名与主调用链
2. 迁移页面、DI、路由、测试到真路径
3. 删除兼容层与 `*_legacy.dart`
4. 迁移 shared 公共部件
5. 更新文档并执行最终回归

## 12. 结论

这不是一次“继续保守兼容”的重构，而是对当前迁移中间态的最终收口。完成后，项目会从“带兼容壳的模块化单体”升级为“以 feature 为唯一真实入口、以 coordinator 为应用层中心、以 shared 为横向复用边界”的稳定架构。
