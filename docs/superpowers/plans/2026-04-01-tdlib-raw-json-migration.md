# TDLib Raw JSON Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留现有业务架构的前提下，把 TDLib 接入从 `package:tdlib` 的强类型响应解析迁移到 `TdPlugin + raw JSON/Map + 自定义适配层`，同时增加完整的请求/响应调试日志，避免 DLL schema 漂移继续击穿调试效率。

**Architecture:** 保留现有 `TdClientTransport -> TdlibAdapter -> TelegramService -> Controller/UI` 分层，先替换 transport 的收发与日志能力，再在 adapter/service 层逐步把响应解析收口到项目自有 DTO/解析器。请求侧短期允许继续复用 `TdFunction.toJson()` 生成 JSON，响应侧不再依赖 `td_api.dart` 的 `fromJson` 大量对象树。

**Tech Stack:** Flutter, Dart 3, TDLib native DLL via `TdPlugin`, JSON/Map parsing, flutter_test, GetX

---

## Context Summary

以下内容是本计划的前置结论，新的执行对话不要重复大规模检索验证，除非实现过程中发现与仓库现状冲突：

- 当前项目直接依赖 `tdlib: ^1.6.0`，见 `pubspec.yaml`。
- `tdlib 1.6.0` 对应的 TDLib schema 基线明显早于本机当前 DLL；继续使用“旧 Dart 强类型 API + 新 DLL”会持续出现 schema 漂移风险。
- 当前 transport 在 `tdReceive()` 解析异常时只记录日志并跳过更新，见 `lib/app/services/td_client_transport.dart`。如果跳过的是请求响应，则 pending completer 可能最终超时，这不是根治。
- 当前代码已经存在 schema 漂移证据：`addProxy` 走了 capability probe + compat request，见 `lib/app/services/tdlib_schema_probe.dart`、`lib/app/services/tdlib_proxy_manager.dart`、`lib/app/services/tdlib_adapter_support.dart`。
- 当前 TDLib 相关依赖集中在少数文件，不是全项目散落：
  - `lib/app/services/td_client_transport.dart`
  - `lib/app/services/tdlib_adapter.dart`
  - `lib/app/services/tdlib_request_executor.dart`
  - `lib/app/services/tdlib_auth_manager.dart`
  - `lib/app/services/tdlib_proxy_manager.dart`
  - `lib/app/services/telegram_service.dart`
  - `lib/app/services/telegram_gateway.dart`
  - `lib/app/domain/message_preview_mapper.dart`
  - `lib/app/widgets/message_viewer_card.dart`
  - `lib/app/controllers/auth_controller.dart`
  - `lib/app/controllers/pipeline_controller.dart`
- 最终推荐路线不是继续追逐第三方强类型绑定，而是把 TDLib 版本风险压缩在 transport / adapter 内部。

## Non-Goals

- 不在本计划里升级到最新 TDLib。
- 不在本计划里重构 UI 视觉或交互。
- 不在本计划里覆盖 TDLib 全量 API，只覆盖当前项目实际使用的那一小撮请求/响应。
- 不新增静默 fallback；解析失败必须明确暴露到日志和错误流。

## Required Debug Logging

本计划的核心要求之一是：**所有 TDLib 请求与响应都必须能在 F5 调试时直接出现在 Debug Console 中**，以便后续与 AI 协作快速迭代。

日志要求：

- 每次发请求时输出：
  - 请求方向：`TD SEND`
  - 请求名 / constructor
  - `@extra`
  - 完整 JSON 字符串
- 每次收到响应或更新时输出：
  - 响应方向：`TD RECV`
  - 响应类型 `@type`
  - `@extra`
  - 完整 JSON 字符串
- 每次解析失败时输出：
  - 解析阶段
  - 原始 JSON
  - 失败原因
  - 对应 request / update context
- 日志必须默认在 debug 模式可见；release 不要求输出完整 payload。
- 日志输出首选 `dart:developer log()`，保证 VS Code / Flutter Debug Console 能直接看到。

推荐日志格式：

```text
[TD SEND] request=getChatHistory extra=1711962000123456 payload={"@type":"getChatHistory",...}
[TD RECV] type=messages extra=1711962000123456 payload={"@type":"messages",...}
[TD UPDATE] type=updateAuthorizationState payload={"@type":"updateAuthorizationState",...}
[TD PARSE ERROR] stage=message_preview request=getChatHistory reason=missing content.photo.sizes payload={...}
```

## File Structure Plan

### New / Split Files

- Create: `lib/app/services/td_raw_transport.dart`
  - 原始 JSON 传输层，直接调用 `TdPlugin.instance.tdCreate/tdSend/tdReceive`
- Create: `lib/app/services/td_wire_message.dart`
  - 轻量 wire model：`TdWireEnvelope`、`TdWireError`、`TdWireUpdate`
- Create: `lib/app/services/td_json_logger.dart`
  - 统一 TD 请求/响应/错误日志输出
- Create: `lib/app/services/td_request_factory.dart`
  - 当前项目所需 TD 请求 JSON 构造器；初期可包装现有 `TdFunction.toJson()`
- Create: `lib/app/services/td_response_reader.dart`
  - 通用 JSON 读取辅助方法，集中做字段校验与 clear error
- Create: `lib/app/services/td_auth_state.dart`
  - 项目自定义鉴权状态枚举 / DTO
- Create: `lib/app/services/td_connection_state.dart`
  - 项目自定义连接状态枚举 / DTO
- Create: `lib/app/services/td_chat_dto.dart`
  - 聊天列表 / 聊天详情 DTO
- Create: `lib/app/services/td_message_dto.dart`
  - 消息历史 / 媒体字段 DTO
- Create: `lib/app/services/td_proxy_dto.dart`
  - 代理 capability 与代理结果 DTO

### Existing Files to Modify

- Modify: `lib/app/services/td_client_transport.dart`
  - 第一阶段保留对外接口，转成薄兼容壳或替换为 raw transport
- Modify: `lib/app/services/tdlib_adapter.dart`
  - 从 `TdObject` 过渡到项目自有 DTO / 状态
- Modify: `lib/app/services/tdlib_request_executor.dart`
  - 从 `TdObject/TdError` 迁移到 wire envelope / wire error
- Modify: `lib/app/services/tdlib_auth_manager.dart`
  - 请求仍可复用，但返回判断走 wire response
- Modify: `lib/app/services/tdlib_proxy_manager.dart`
  - 代理探测与查询使用 raw JSON DTO
- Modify: `lib/app/services/tdlib_schema_probe.dart`
  - 探测逻辑改成基于 wire response
- Modify: `lib/app/services/telegram_service.dart`
  - 从 `Message/Chat/Proxies/AuthorizationState` 迁移到自定义 DTO
- Modify: `lib/app/services/telegram_gateway.dart`
  - 输出项目自有状态流类型
- Modify: `lib/app/domain/message_preview_mapper.dart`
  - 改为处理项目自定义消息内容 DTO
- Modify: `lib/app/widgets/message_viewer_card.dart`
  - 改为处理项目自定义文本实体 DTO
- Modify: `lib/app/controllers/auth_controller.dart`
  - 改用项目自定义 auth state
- Modify: `lib/app/controllers/pipeline_controller.dart`
  - 改用项目自定义 connection state
- Modify: `lib/app/bindings.dart`
  - 绑定新的 transport/logger/parser

### Tests

- Create: `test/services/td_raw_transport_test.dart`
- Create: `test/services/td_json_logger_test.dart`
- Create: `test/services/td_response_reader_test.dart`
- Create: `test/services/td_wire_auth_parser_test.dart`
- Create: `test/services/td_wire_chat_parser_test.dart`
- Create: `test/services/td_wire_message_parser_test.dart`
- Modify: `test/services/tdlib_adapter_test.dart`
- Modify: `test/services/tdlib_adapter_lifecycle_test.dart`
- Modify: `test/services/tdlib_schema_probe_test.dart`
- Modify: `test/services/tdlib_startup_state_machine_test.dart`
- Modify: `test/controllers/pipeline_controller_test.dart`
- Modify: `test/integration/auth_pipeline_flow_test.dart`
- Modify: `test/domain/message_preview_mapper_test.dart`

## Migration Boundaries

执行时按下面的边界理解影响面：

- **全局一次性改动**
  - transport 收发逻辑
  - 请求/响应调试日志
  - 通用 error classification
- **按当前业务真实使用场景逐个适配**
  - authorization state
  - connection state
  - getProxies / addProxy / disableProxy
  - getChats / loadChats / getChat
  - getOption(my_id) / getMe
  - getChatHistory
  - forwardMessages
  - deleteMessages
  - downloadFile
  - close
- **基本不应大改**
  - UI 页面布局
  - `SettingsRepository`
  - 持久化模型

## Chunk 1: Raw Transport + Full Logging

### Task 1: 建立 raw transport 的测试基线

**Files:**
- Create: `test/services/td_raw_transport_test.dart`
- Create: `test/services/td_json_logger_test.dart`

- [ ] **Step 1: 写 transport 发请求日志的失败测试**

```dart
test('logs full request payload with constructor and extra', () async {
  // fake plugin returns no response; verify logger captured TD SEND
});
```

- [ ] **Step 2: 写 transport 收响应日志的失败测试**

```dart
test('logs full receive payload before parsing', () async {
  // fake plugin returns {"@type":"ok","@extra":"1"}
});
```

- [ ] **Step 3: 写 update 与 parse error 日志测试**

```dart
test('logs parse failure with raw payload and reason', () async {
  // malformed payload triggers parser failure
});
```

- [ ] **Step 4: 运行测试确认失败**

Run: `flutter test test/services/td_raw_transport_test.dart test/services/td_json_logger_test.dart`

Expected: FAIL，提示缺少 raw transport / logger 实现

- [ ] **Step 5: 提交测试基线**

```bash
git add test/services/td_raw_transport_test.dart test/services/td_json_logger_test.dart
git commit -m "test: add td raw transport logging baseline"
```

### Task 2: 实现 raw transport 与统一日志器

**Files:**
- Create: `lib/app/services/td_raw_transport.dart`
- Create: `lib/app/services/td_json_logger.dart`
- Modify: `lib/app/services/td_client_transport.dart`
- Modify: `lib/app/bindings.dart`

- [ ] **Step 1: 实现统一日志器**

实现要求：
- debug 模式输出完整 payload
- 提供 `logSend` / `logReceive` / `logUpdate` / `logParseError`
- 使用 `developer.log`

- [ ] **Step 2: 实现 raw transport**

实现要求：
- 直接使用 `TdPlugin.instance.tdCreate/tdSend/tdReceive`
- 内部 pending key 仍使用 `@extra`
- 接收阶段先记录原始 JSON，再决定是请求响应还是 update
- 此阶段 transport 对外可以先返回 `Map<String, dynamic>`

- [ ] **Step 3: 兼容现有依赖注入**

在 `bindings.dart` 中把 transport 注入替换成新实现，必要时保留旧接口外形，避免一次性震荡过大。

- [ ] **Step 4: 运行 transport/logger 测试**

Run: `flutter test test/services/td_raw_transport_test.dart test/services/td_json_logger_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/app/services/td_raw_transport.dart lib/app/services/td_json_logger.dart lib/app/services/td_client_transport.dart lib/app/bindings.dart test/services/td_raw_transport_test.dart test/services/td_json_logger_test.dart
git commit -m "feat: add td raw transport and debug logging"
```

## Chunk 2: Wire Envelope + Common Readers

### Task 3: 建立通用 wire model 与 reader 测试

**Files:**
- Create: `test/services/td_response_reader_test.dart`
- Create: `lib/app/services/td_wire_message.dart`
- Create: `lib/app/services/td_response_reader.dart`

- [ ] **Step 1: 写字段读取与 clear error 的失败测试**

```dart
test('throws clear error when required field is missing', () {
  // expect StateError or domain-specific parse error with field path
});
```

- [ ] **Step 2: 写 td error envelope 测试**

```dart
test('maps td error response to wire error', () {
  // {"@type":"error","code":401,"message":"PHONE_NUMBER_INVALID"}
});
```

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/services/td_response_reader_test.dart`

Expected: FAIL

- [ ] **Step 4: 提交**

```bash
git add test/services/td_response_reader_test.dart
git commit -m "test: add td response reader baseline"
```

### Task 4: 实现 wire envelope 与 reader

**Files:**
- Create: `lib/app/services/td_wire_message.dart`
- Create: `lib/app/services/td_response_reader.dart`
- Modify: `lib/app/services/tdlib_request_executor.dart`

- [ ] **Step 1: 实现基础 envelope**

至少包含：
- 原始 payload map
- `type`
- `extra`
- `clientId`
- `isError`
- `errorCode`
- `errorMessage`

- [ ] **Step 2: 实现 reader**

需要：
- `readString`
- `readInt`
- `readBool`
- `readList`
- `readMap`
- path-aware error message

- [ ] **Step 3: 调整 request executor**

从 `TdObject/TdError` 迁移到 wire envelope，保证：
- td error 仍转换为 `TdlibFailure`
- timeout / transport error 语义不变

- [ ] **Step 4: 运行测试**

Run: `flutter test test/services/td_response_reader_test.dart test/domain/tdlib_failure_test.dart test/domain/td_error_classifier_test.dart`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/app/services/td_wire_message.dart lib/app/services/td_response_reader.dart lib/app/services/tdlib_request_executor.dart test/services/td_response_reader_test.dart
git commit -m "refactor: add td wire envelope and response readers"
```

## Chunk 3: Startup Flow States

### Task 5: 替换 authorization / connection 状态为项目自定义状态

**Files:**
- Create: `lib/app/services/td_auth_state.dart`
- Create: `lib/app/services/td_connection_state.dart`
- Create: `test/services/td_wire_auth_parser_test.dart`
- Modify: `lib/app/services/tdlib_adapter.dart`
- Modify: `lib/app/controllers/auth_controller.dart`
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Modify: `test/services/tdlib_startup_state_machine_test.dart`
- Modify: `test/integration/auth_pipeline_flow_test.dart`
- Modify: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 写 auth / connection parser 失败测试**

覆盖：
- `authorizationStateWaitPhoneNumber`
- `authorizationStateWaitCode`
- `authorizationStateWaitPassword`
- `authorizationStateWaitTdlibParameters`
- `authorizationStateReady`
- `authorizationStateClosed`
- `connectionStateReady`

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/td_wire_auth_parser_test.dart`

Expected: FAIL

- [ ] **Step 3: 实现状态 DTO 与 parser**

要求：
- controller 不再 import `package:tdlib/td_api.dart`
- adapter 内部把 update payload 映射成项目自定义状态流

- [ ] **Step 4: 更新 controller / gateway**

确保 UI 行为不变：
- 登录页状态切换不变
- pipeline 在线状态切换不变

- [ ] **Step 5: 运行相关测试**

Run: `flutter test test/services/td_wire_auth_parser_test.dart test/services/tdlib_startup_state_machine_test.dart test/integration/auth_pipeline_flow_test.dart test/controllers/pipeline_controller_test.dart`

Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/app/services/td_auth_state.dart lib/app/services/td_connection_state.dart lib/app/services/tdlib_adapter.dart lib/app/controllers/auth_controller.dart lib/app/controllers/pipeline_controller.dart lib/app/services/telegram_gateway.dart test/services/td_wire_auth_parser_test.dart test/services/tdlib_startup_state_machine_test.dart test/integration/auth_pipeline_flow_test.dart test/controllers/pipeline_controller_test.dart
git commit -m "refactor: replace td auth and connection states with local models"
```

## Chunk 4: Proxy + Startup Requests

### Task 6: 迁移代理探测与启动期请求

**Files:**
- Create: `lib/app/services/td_proxy_dto.dart`
- Modify: `lib/app/services/tdlib_schema_probe.dart`
- Modify: `lib/app/services/tdlib_proxy_manager.dart`
- Modify: `lib/app/services/tdlib_auth_manager.dart`
- Modify: `test/services/tdlib_schema_probe_test.dart`
- Modify: `test/services/tdlib_adapter_test.dart`

- [ ] **Step 1: 写 legacy / flat addProxy 双路径测试**

保留现有语义：
- flat args 成功
- nested proxy object 成功
- 其他 td error 明确抛出

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/tdlib_schema_probe_test.dart test/services/tdlib_adapter_test.dart`

Expected: FAIL

- [ ] **Step 3: 实现 DTO + parser**

解析：
- `ok`
- `error`
- `proxies`

- [ ] **Step 4: 保持启动状态机行为不变**

验证：
- `setTdlibParameters`
- `disableProxy`
- `close`

- [ ] **Step 5: 运行测试**

Run: `flutter test test/services/tdlib_schema_probe_test.dart test/services/tdlib_adapter_test.dart test/services/tdlib_adapter_lifecycle_test.dart`

Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/app/services/td_proxy_dto.dart lib/app/services/tdlib_schema_probe.dart lib/app/services/tdlib_proxy_manager.dart lib/app/services/tdlib_auth_manager.dart test/services/tdlib_schema_probe_test.dart test/services/tdlib_adapter_test.dart test/services/tdlib_adapter_lifecycle_test.dart
git commit -m "refactor: migrate startup and proxy flows to wire responses"
```

## Chunk 5: Business Requests in TelegramService

### Task 7: 迁移 chat / me / history / classify 响应解析

**Files:**
- Create: `lib/app/services/td_chat_dto.dart`
- Create: `lib/app/services/td_message_dto.dart`
- Create: `test/services/td_wire_chat_parser_test.dart`
- Create: `test/services/td_wire_message_parser_test.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/domain/message_preview_mapper.dart`
- Modify: `test/domain/message_preview_mapper_test.dart`

- [ ] **Step 1: 写 chat parser 失败测试**

覆盖：
- `getChats`
- `getChat`
- `getMe`
- `getOption(my_id)`

- [ ] **Step 2: 写 message parser 失败测试**

覆盖：
- `messages`
- 文本消息
- 图片消息
- 视频消息
- unsupported message
- `forwardMessages` 返回目标 message id

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/services/td_wire_chat_parser_test.dart test/services/td_wire_message_parser_test.dart test/domain/message_preview_mapper_test.dart`

Expected: FAIL

- [ ] **Step 4: 实现 DTO 与 parser**

要求：
- 只解析当前业务实际需要字段
- 字段缺失时抛 clear parse error，不静默兜底
- 图片 / 视频路径读取逻辑迁移到自定义 DTO

- [ ] **Step 5: 更新 TelegramService**

目标：
- `TelegramService` 不再依赖 `Message/Chat/User/OptionValueInteger/Proxies`
- 对外继续返回 `SelectableChat` / `PipelineMessage` / `ClassifyReceipt`

- [ ] **Step 6: 运行业务层测试**

Run: `flutter test test/services/td_wire_chat_parser_test.dart test/services/td_wire_message_parser_test.dart test/domain/message_preview_mapper_test.dart test/controllers/pipeline_controller_test.dart test/integration/auth_pipeline_flow_test.dart`

Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add lib/app/services/td_chat_dto.dart lib/app/services/td_message_dto.dart lib/app/services/telegram_service.dart lib/app/domain/message_preview_mapper.dart test/services/td_wire_chat_parser_test.dart test/services/td_wire_message_parser_test.dart test/domain/message_preview_mapper_test.dart test/controllers/pipeline_controller_test.dart test/integration/auth_pipeline_flow_test.dart
git commit -m "refactor: migrate telegram service business responses to local dtos"
```

## Chunk 6: UI Surface Cleanup

### Task 8: 清理 UI 对 td_api.dart 的残留依赖

**Files:**
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Modify: `test/controllers/pipeline_controller_test.dart`
- Modify: `test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 1: 搜索残留 `package:tdlib/td_api.dart` 引用**

Run: `rg -n "package:tdlib/td_api.dart" lib test`

Expected: 仅剩允许保留的 bridge 层；controller/widget 不应再直接依赖

- [ ] **Step 2: 替换文本实体 / 格式化文本依赖**

让 `message_viewer_card.dart` 改读项目自定义 DTO。

- [ ] **Step 3: 跑定向测试**

Run: `flutter test test/controllers/pipeline_controller_test.dart test/integration/auth_pipeline_flow_test.dart test/domain/message_preview_mapper_test.dart`

Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lib/app/widgets/message_viewer_card.dart lib/app/services/telegram_gateway.dart test/controllers/pipeline_controller_test.dart test/integration/auth_pipeline_flow_test.dart
git commit -m "refactor: remove td_api dependency from ui-facing layers"
```

## Chunk 7: Final Verification

### Task 9: 全量验证并记录结果

**Files:**
- Modify: `README.md`
- Optionally Modify: `docs/tdlib-android-params.md`

- [ ] **Step 1: 搜索项目中残留强类型入口**

Run: `rg -n "tdReceive\\(|convertToObject|TdObject|AuthorizationState|ConnectionState|MessageContent|FormattedText|TextEntity" lib test`

Expected:
- bridge 层允许存在少量 `TdFunction`
- 不应再有 runtime response 依赖 `TdObject` 的关键路径

- [ ] **Step 2: 运行测试集**

Run: `flutter test test/domain/tdlib_failure_test.dart test/domain/td_error_classifier_test.dart test/services/td_raw_transport_test.dart test/services/td_json_logger_test.dart test/services/td_response_reader_test.dart test/services/td_wire_auth_parser_test.dart test/services/td_wire_chat_parser_test.dart test/services/td_wire_message_parser_test.dart test/services/tdlib_schema_probe_test.dart test/services/tdlib_startup_state_machine_test.dart test/services/tdlib_adapter_test.dart test/services/tdlib_adapter_lifecycle_test.dart test/integration/auth_pipeline_flow_test.dart test/controllers/pipeline_controller_test.dart test/domain/message_preview_mapper_test.dart`

Expected: PASS

- [ ] **Step 3: 手工 F5 验证日志**

检查 Debug Console 中是否能看到：
- `TD SEND`
- `TD RECV`
- `TD UPDATE`
- `TD PARSE ERROR`

- [ ] **Step 4: 更新 README 的调试说明**

补充：
- 如何在 F5 时查看 TD 请求/响应日志
- 日志是完整 payload
- release 不输出完整调试日志

- [ ] **Step 5: 提交**

```bash
git add README.md docs/tdlib-android-params.md
git commit -m "docs: document td raw json debugging workflow"
```

## Guardrails for the Next Agent

- 不要引入 silent fallback 或 mock success path。
- 不要为了“先跑起来”继续吞掉解析异常；必须把原始 payload 打出来。
- 不要一次性试图覆盖 TDLib 全量 schema；只覆盖当前项目真实使用到的请求与响应。
- 每完成一个 chunk，优先跑该 chunk 的定向测试，不要等到最后才发现回归。
- 如发现仓库中已有未提交改动与本计划冲突，先停下并在对话中说明冲突点，不要覆盖用户改动。

## Quick Start for the Next Conversation

新的执行对话建议从下面这段开始：

> 请按 `docs/superpowers/plans/2026-04-01-tdlib-raw-json-migration.md` 执行，不要重新做大规模方案调研。先实现 Chunk 1：raw transport + full logging。要求 F5 调试时 Debug Console 必须输出完整 TD 请求、响应、更新和解析错误日志。完成后先跑该 chunk 的测试，再汇报结果。

Plan complete and saved to `docs/superpowers/plans/2026-04-01-tdlib-raw-json-migration.md`. Ready to execute?
