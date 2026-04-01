# TDLib Adapter Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 TDLib 协议交互从 `TelegramService` 中拆出，建立显式启动状态机、统一错误模型与启动期 schema 能力探测，并补齐 Adapter 集成测试。

**Architecture:** 以 `TdClientTransport` 作为最底层收发器，新建 `TdlibAdapter` 负责 TDLib 协议和状态机，`TelegramService` 保留业务编排职责，控制器继续依赖 `TelegramGateway`。重构先从错误模型和测试骨架入手，再迁移协议逻辑，最后调整依赖注入与回归验证。

**Tech Stack:** Flutter, Dart 3, tdlib package, flutter_test, GetX

---

## Chunk 1: 错误模型与分类迁移

### Task 1: 新增统一错误模型

**Files:**
- Create: `lib/app/services/tdlib_failure.dart`
- Modify: `lib/app/domain/td_error_classifier.dart`
- Test: `test/domain/tdlib_failure_test.dart`
- Test: `test/domain/td_error_classifier_test.dart`

- [ ] **Step 1: 写失败测试，定义错误对象与分类行为**

```dart
final failure = TdlibFailure.tdError(
  code: 420,
  message: 'FLOOD_WAIT_9',
  request: 'forwardMessages',
  phase: TdlibPhase.business,
);
expect(classifyTdlibError(failure), TdErrorKind.rateLimit);
expect(failure.code, 420);
expect(failure.message, 'FLOOD_WAIT_9');
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `flutter test test/domain/tdlib_failure_test.dart test/domain/td_error_classifier_test.dart`
Expected: FAIL，缺少 `TdlibFailure` 或旧分类签名不匹配

- [ ] **Step 3: 实现最小错误模型与分类器迁移**

实现内容：
- 定义 `TdlibFailureKind`、`TdlibPhase`、`TdlibFailure`
- 支持 TD error、timeout、transport error 构造
- `classifyTdlibError` 改为接收 `TdlibFailure`

- [ ] **Step 4: 再跑测试确认通过**

Run: `flutter test test/domain/tdlib_failure_test.dart test/domain/td_error_classifier_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/app/services/tdlib_failure.dart lib/app/domain/td_error_classifier.dart test/domain/tdlib_failure_test.dart test/domain/td_error_classifier_test.dart
git commit -m "refactor: unify tdlib failure model"
```

## Chunk 2: Schema 能力探测

### Task 2: 提炼 schema capability 与 probe

**Files:**
- Create: `lib/app/services/tdlib_schema_capabilities.dart`
- Create: `lib/app/services/tdlib_schema_probe.dart`
- Test: `test/services/tdlib_schema_probe_test.dart`

- [ ] **Step 1: 写失败测试，定义能力探测输出**

```dart
final probe = TdlibSchemaProbe(send: fakeSend);
final capabilities = await probe.detect();
expect(capabilities.addProxyMode, TdlibAddProxyMode.nestedProxyObject);
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `flutter test test/services/tdlib_schema_probe_test.dart`
Expected: FAIL，缺少 probe/capabilities

- [ ] **Step 3: 实现能力枚举与 probe**

实现内容：
- `TdlibAddProxyMode`
- `TdlibSchemaCapabilities`
- `TdlibSchemaProbe.detect()`
- 将探测失败显式包装成 `TdlibFailure`

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/services/tdlib_schema_probe_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/app/services/tdlib_schema_capabilities.dart lib/app/services/tdlib_schema_probe.dart test/services/tdlib_schema_probe_test.dart
git commit -m "refactor: add tdlib schema probe"
```

## Chunk 3: 启动状态机与 Adapter

### Task 3: 建立可测试的 TDLib 适配层接口

**Files:**
- Create: `lib/app/services/tdlib_adapter.dart`
- Create: `lib/app/services/tdlib_runtime_paths.dart`
- Modify: `lib/app/services/td_client_transport.dart`
- Test: `test/services/tdlib_startup_state_machine_test.dart`
- Test: `test/services/tdlib_adapter_test.dart`

- [ ] **Step 1: 先写状态机与 adapter 集成测试**

```dart
await adapter.start();
expect(states, [
  TdlibStartupState.init,
  TdlibStartupState.setParams,
  TdlibStartupState.setProxy,
  TdlibStartupState.auth,
]);

await adapter.submitPhoneNumber('+8613800000000');
expect(fakeTransport.requests.last['@type'], 'setAuthenticationPhoneNumber');
```

- [ ] **Step 2: 运行测试，确认当前失败**

Run: `flutter test test/services/tdlib_startup_state_machine_test.dart test/services/tdlib_adapter_test.dart`
Expected: FAIL，缺少 adapter 与状态机

- [ ] **Step 3: 实现最小 adapter 与状态机**

实现内容：
- 统一启动状态流
- 订阅 transport updates
- 启动期能力探测
- `setTdlibParameters`
- `addProxy/getProxies/disableProxy`
- `submitPhoneNumber/submitCode/submitPassword`
- `AuthorizationStateReady` 解锁机制
- 所有错误转换为 `TdlibFailure`

- [ ] **Step 4: 再跑测试确认通过**

Run: `flutter test test/services/tdlib_startup_state_machine_test.dart test/services/tdlib_adapter_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/app/services/tdlib_adapter.dart lib/app/services/tdlib_runtime_paths.dart lib/app/services/td_client_transport.dart test/services/tdlib_startup_state_machine_test.dart test/services/tdlib_adapter_test.dart
git commit -m "refactor: extract tdlib adapter"
```

## Chunk 4: 业务层迁移

### Task 4: 将 TelegramService 改为依赖 Adapter

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Modify: `lib/app/controllers/auth_controller.dart`
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Modify: `lib/app/bindings.dart`
- Test: `test/integration/auth_pipeline_flow_test.dart`
- Test: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 写或更新失败测试，固定外部行为**

```dart
expect(authController.stage.value, AuthStage.waitPhone);
expect(pipelineController.isOnline.value, isTrue);
```

- [ ] **Step 2: 运行相关测试，确认迁移前有失败或编译错误**

Run: `flutter test test/integration/auth_pipeline_flow_test.dart test/controllers/pipeline_controller_test.dart`
Expected: FAIL 或编译错误，旧异常类型仍被引用

- [ ] **Step 3: 实现 service/controller 迁移**

实现内容：
- `TelegramService` 通过 adapter 调用 TDLib
- `TelegramGateway` 暴露不变的业务方法
- 控制器捕获 `TdlibFailure`
- `bindings.dart` 注册 adapter 并注入 service

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/integration/auth_pipeline_flow_test.dart test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/app/services/telegram_service.dart lib/app/services/telegram_gateway.dart lib/app/controllers/auth_controller.dart lib/app/controllers/pipeline_controller.dart lib/app/bindings.dart test/integration/auth_pipeline_flow_test.dart test/controllers/pipeline_controller_test.dart
git commit -m "refactor: route telegram service through adapter"
```

## Chunk 5: 全量验证

### Task 5: 运行静态检查与重点测试

**Files:**
- Modify: 如验证中发现的小修复文件

- [ ] **Step 1: 运行格式化**

Run: `dart format lib test`
Expected: 所有改动文件格式化完成

- [ ] **Step 2: 运行静态检查**

Run: `flutter analyze`
Expected: PASS

- [ ] **Step 3: 运行重点测试**

Run: `flutter test test/domain/tdlib_failure_test.dart test/domain/td_error_classifier_test.dart test/services/tdlib_schema_probe_test.dart test/services/tdlib_startup_state_machine_test.dart test/services/tdlib_adapter_test.dart test/integration/auth_pipeline_flow_test.dart test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 4: 运行全量测试**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "test: verify tdlib adapter refactor"
```
