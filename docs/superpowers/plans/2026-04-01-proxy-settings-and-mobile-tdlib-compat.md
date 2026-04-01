# Proxy Settings And Mobile Tdlib Compat Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 TDLib 代理配置迁移到运行时设置，并修复移动端 `addProxy` / `getProxies` 返回结构兼容问题。

**Architecture:** 保留 API ID / Hash 走环境变量，把代理设置沉淀到 `AppSettings` 与 `SharedPreferences`。`TdlibAdapter` 通过注入的设置读取器在启动和重连时获取最新代理配置，初始化页与设置页都编辑同一份配置。移动端 schema 兼容通过扩展探测与代理 DTO 解析实现。

**Tech Stack:** Flutter, GetX, SharedPreferences, flutter_test

---

## Chunk 1: TDLib 代理兼容回归测试

### Task 1: 为移动端 `addProxy` 返回 `proxy` 补测试

**Files:**
- Modify: `test/services/tdlib_schema_probe_test.dart`

- [ ] 写失败测试，断言 `proxy` 响应会被识别为成功 schema
- [ ] 运行单测确认先失败
- [ ] 最小实现修复探测逻辑
- [ ] 重新运行单测确认通过

### Task 2: 为移动端 `getProxies` 结构补测试

**Files:**
- Modify: `test/services/td_proxy_dto_test.dart`
- Modify: `lib/app/services/td_proxy_dto.dart`

- [ ] 写失败测试，覆盖嵌套代理端点字段的返回结构
- [ ] 运行单测确认先失败
- [ ] 最小实现修复 DTO 解析
- [ ] 重新运行单测确认通过

## Chunk 2: 代理配置持久化

### Task 3: 扩展设置模型与仓储

**Files:**
- Create: `lib/app/models/proxy_settings.dart`
- Modify: `lib/app/models/app_settings.dart`
- Modify: `lib/app/services/settings_repository.dart`
- Modify: `test/services/settings_repository_test.dart`

- [ ] 写失败测试，覆盖代理设置的加载与保存
- [ ] 运行单测确认先失败
- [ ] 最小实现 `ProxySettings` 与仓储持久化
- [ ] 重新运行单测确认通过

### Task 4: 让 TDLib 从运行时设置读取代理

**Files:**
- Modify: `lib/app/services/tdlib_credentials.dart`
- Modify: `lib/app/services/tdlib_adapter.dart`
- Modify: `lib/app/services/tdlib_proxy_manager.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/bindings.dart`
- Modify: `test/services/tdlib_adapter_test.dart`

- [ ] 写失败测试，覆盖更新设置后启动/重启使用最新代理
- [ ] 运行单测确认先失败
- [ ] 最小实现设置读取器与重连入口
- [ ] 重新运行单测确认通过

## Chunk 3: 初始化页和设置页接入

### Task 5: 初始化页增加代理表单与重试

**Files:**
- Modify: `lib/app/controllers/auth_controller.dart`
- Modify: `lib/app/pages/auth_page.dart`
- Modify: `test/integration/auth_pipeline_flow_test.dart`

- [ ] 写失败测试，覆盖初始化页保存代理并重试启动
- [ ] 运行单测确认先失败
- [ ] 最小实现代理表单、保存和重试逻辑
- [ ] 重新运行单测确认通过

### Task 6: 设置页增加代理编辑器

**Files:**
- Modify: `lib/app/controllers/settings_controller.dart`
- Modify: `lib/app/pages/settings_common_editors.dart`
- Modify: `lib/app/pages/settings_page.dart`

- [ ] 写失败测试或在现有控制器测试补覆盖
- [ ] 运行测试确认先失败
- [ ] 最小实现代理编辑器与保存后应用逻辑
- [ ] 重新运行测试确认通过

## Chunk 4: 验证

### Task 7: 运行验证命令

**Files:**
- Verify: `test/services/tdlib_schema_probe_test.dart`
- Verify: `test/services/td_proxy_dto_test.dart`
- Verify: `test/services/settings_repository_test.dart`
- Verify: `test/services/tdlib_adapter_test.dart`
- Verify: `test/integration/auth_pipeline_flow_test.dart`

- [ ] 运行针对性测试
- [ ] 运行 `flutter test` 或最小完整回归集
- [ ] 检查失败项并修复后再验证
