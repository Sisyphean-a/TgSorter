# TelegramService 重构设计

## 背景

当前 `TelegramService` 集中了过多职责：

- TDLib 授权与连接状态代理
- Saved Messages / source chat 解析
- 会话列表查询
- 消息计数、分页读取、预览组装
- 媒体预热与播放前准备
- 分类事务编排、撤销、恢复
- 转发结果解析与发送状态确认

现状问题：

1. 单类体量过大，当前实现约 677 行，阅读与定位成本高。
2. 多种职责交织，导致测试粒度偏粗，复杂逻辑主要依赖大而全的服务测试覆盖。
3. 分类与转发确认逻辑耦合较深，边界条件测试不够独立。
4. self chat 解析、消息读取、媒体准备等辅助逻辑混在同一类中，后续演进风险较高。

## 目标

本次重构采用“稳妥型重构”策略：

- 保持 `TelegramGateway` 对外契约尽量不变
- 不要求 `PipelineController`、`AuthController`、`SettingsController` 做行为级改造
- 优先提升可测试性
- 采用中等颗粒度拆分，新增 3~5 个协作者
- 验收标准为：现有测试通过，并为核心拆分类补充独立单测

## 非目标

以下内容不在本次范围内：

- 不重新设计 `TelegramGateway` 的上层接口
- 不引入新的业务能力或 UI 行为变化
- 不全面替换现有的 `TdlibAdapter`、`MessageHistoryPaginator`、`MediaDownloadCoordinator`
- 不做与本次重构无关的性能优化或错误处理风格统一

## 方案结论

采用“领域能力 + 基础设施”拆分方案。

保留 `TelegramService` 作为外部门面，对外继续实现：

- `TelegramGateway`
- `RecoverableClassifyGateway`

内部拆分为以下协作者：

1. `TelegramSessionResolver`
2. `TelegramMessageReader`
3. `TelegramMediaService`
4. `TelegramMessageForwarder`
5. `TelegramClassifyWorkflow`

## 模块职责

### `TelegramService`

职责：

- 保留现有公开方法与流式状态代理
- 统一执行 `_requireAuthorizationReady()`
- 将请求委派给对应协作者
- 维持当前对外异常语义与结果语义

重构后，`TelegramService` 应尽量成为一个薄门面，不再持有大量业务细节。

### `TelegramSessionResolver`

职责：

- 解析 `sourceChatId`
- 维护与缓存 self chat id
- 负责 `GetOption(name: 'my_id')` → `CreatePrivateChat` 路径
- 在必要时回退到 `GetMe()` → `CreatePrivateChat`
- 提供可选会话列表装载能力，包括 `loadChats(main)` 与 `getChats(main)` 协同逻辑

建议对外提供的方法：

- `Future<int> resolveSourceChatId(int? sourceChatId)`
- `Future<List<SelectableChat>> listSelectableChats()`

### `TelegramMessageReader`

职责：

- 负责消息读取与展示模型构建
- 使用 `MessageHistoryPaginator` 获取历史消息
- 加载单条消息
- 统计剩余消息数量
- 将原始消息映射为 `PipelineMessage`

建议对外提供的方法：

- `Future<int> countRemainingMessages({required int chatId})`
- `Future<List<PipelineMessage>> fetchMessagePage(...)`
- `Future<PipelineMessage?> fetchNextMessage(...)`
- `Future<PipelineMessage> refreshMessage(...)`
- `Future<TdMessageDto> loadMessage(...)`

其中：

- `fetchMessagePage` 与 `fetchNextMessage` 仍沿用当前 `MessageHistoryPaginator` 逻辑
- album 分组与预览构建继续交给 `MessagePreviewBuilder`

### `TelegramMediaService`

职责：

- 负责消息内容相关的媒体预热
- 负责音视频播放前的下载准备
- 不负责分页、计数或分类逻辑

建议对外提供的方法：

- `Future<void> warmUpPreview(TdMessageDto message)`
- `Future<void> prepareMediaPreview(TdMessageDto message)`
- `Future<void> preparePlayback(TdMessageDto message)`

说明：

- `prepareMediaPreview` 与 `warmUpPreview` 可以在实现上复用
- 是否刷新消息，由门面或 `TelegramMessageReader` 组合完成，不让媒体服务直接承担展示组装职责

### `TelegramMessageForwarder`

职责：

- 发送 `ForwardMessages`
- 解析返回的目标消息与发送状态
- 检查返回数量是否与源消息一致
- 对 pending 状态执行轮询确认
- 在失败、超时、返回异常时抛出明确错误

建议对外提供的方法：

- `Future<List<int>> forwardAndConfirm({...})`

边界约束：

- 不负责事务日志持久化
- 不负责删除源消息
- 不负责恢复逻辑决策

这是本次最关键的可测试模块之一。

### `TelegramClassifyWorkflow`

职责：

- 编排 `classifyMessage`
- 编排 `undoClassify`
- 委派 `recoverPendingClassifyOperations`
- 调用 `ClassifyTransactionCoordinator` 管理事务状态
- 组合 `TelegramMessageForwarder` 与删除动作

建议对外提供的方法：

- `Future<ClassifyReceipt> classifyMessage({...})`
- `Future<void> undoClassify({...})`
- `Future<ClassifyRecoverySummary> recoverPendingClassifyOperations()`

边界约束：

- 不自行解析 `sourceChatId == null` 的场景，由调用方先传入实际 chat id
- 不承担消息展示模型构建职责

## 依赖关系

建议依赖关系如下：

```text
TelegramService
├── TelegramSessionResolver
├── TelegramMessageReader
├── TelegramMediaService
└── TelegramClassifyWorkflow
    ├── TelegramMessageForwarder
    └── ClassifyTransactionCoordinator
```

约束原则：

- `TelegramService` 统一做授权就绪检查
- `TelegramSessionResolver` 只处理会话解析与聊天列表
- `TelegramMessageReader` 只处理读取与预览构建
- `TelegramMediaService` 只处理媒体文件准备
- `TelegramMessageForwarder` 只处理转发与确认
- `TelegramClassifyWorkflow` 只处理分类事务编排

## 核心调用链

### 消息分页

```text
fetchMessagePage
  → TelegramService
  → _requireAuthorizationReady()
  → TelegramSessionResolver.resolveSourceChatId()
  → TelegramMessageReader.fetchMessagePage()
  → TelegramMediaService.warmUpPreview() 逐条预热
  → 返回 PipelineMessage 列表
```

### 读取下一条

```text
fetchNextMessage
  → TelegramService
  → _requireAuthorizationReady()
  → TelegramSessionResolver.resolveSourceChatId()
  → TelegramMessageReader.fetchNextMessage()
  → TelegramMediaService.warmUpPreview()
  → 返回 PipelineMessage?
```

### 媒体播放准备

```text
prepareMediaPlayback
  → TelegramService
  → _requireAuthorizationReady()
  → TelegramMessageReader.loadMessage()
  → TelegramMediaService.preparePlayback()
  → 若为音视频则调用 TelegramMessageReader.refreshMessage()
  → 返回最新 PipelineMessage
```

### 分类消息

```text
classifyMessage
  → TelegramService
  → _requireAuthorizationReady()
  → TelegramSessionResolver.resolveSourceChatId()
  → TelegramClassifyWorkflow.classifyMessage()
      → ClassifyTransactionCoordinator.startTransaction()
      → TelegramMessageForwarder.forwardAndConfirm()
      → ClassifyTransactionCoordinator.markForwardConfirmed()
      → delete source messages
      → ClassifyTransactionCoordinator.markSourceDeleteConfirmed()
  → 返回 ClassifyReceipt
```

### 撤销分类

```text
undoClassify
  → TelegramService
  → _requireAuthorizationReady()
  → TelegramClassifyWorkflow.undoClassify()
      → TelegramMessageForwarder.forwardAndConfirm()
      → delete forwarded target messages
```

## 兼容性要求

以下接口签名与语义保持不变：

- `authStates`
- `connectionStates`
- `start()`
- `restart()`
- `submitPhoneNumber()`
- `submitCode()`
- `submitPassword()`
- `listSelectableChats()`
- `countRemainingMessages()`
- `fetchMessagePage()`
- `fetchNextMessage()`
- `prepareMediaPlayback()`
- `prepareMediaPreview()`
- `refreshMessage()`
- `classifyMessage()`
- `undoClassify()`
- `recoverPendingClassifyOperations()`

同时要求：

- `PipelineController` 无需调整调用行为
- 现有页面与控制器 fake gateway 测试不需要整体改写
- 保持现有错误抛出时机与关键语义稳定

## 测试策略

### 保底测试

继续保留并跑通 `telegram_service_test.dart` 中现有行为验证：

- 消息分页与 cursor 处理
- album 分组行为
- 媒体预热与播放准备
- 分类转发/删除/超时
- 恢复流程
- self chat 解析

这些测试继续作为门面层回归测试，证明对外行为不变。

### 新增协作者测试

建议新增以下测试：

#### `telegram_session_resolver_test.dart`

覆盖：

- 传入 `sourceChatId` 时直接返回
- `sourceChatId == null` 时解析 self chat
- `GetOption(my_id)` 正常路径
- `GetOption(my_id)` 无效时回退 `GetMe()`
- 结果缓存生效

#### `telegram_message_forwarder_test.dart`

覆盖：

- `forwardMessages` 返回空消息时失败
- 返回数量与源消息数不一致时失败
- 返回 pending 后轮询成功
- pending 轮询超时失败
- sending state failed 时失败
- 遇到临时消息 id 时失败

#### `telegram_classify_workflow_test.dart`

覆盖：

- forward 成功后才删除源消息
- forward 失败时不删除源消息
- 删除成功后标记事务完成
- 发生异常时记录 failure
- `undoClassify` 的转发与删除顺序正确

## 实施顺序

推荐按以下顺序实施，以降低风险：

1. 抽取 `TelegramSessionResolver`
2. 抽取 `TelegramMessageForwarder`
3. 抽取 `TelegramClassifyWorkflow`
4. 抽取 `TelegramMessageReader`
5. 抽取 `TelegramMediaService`
6. 将 `TelegramService` 收敛为薄门面
7. 补充新协作者单测并跑回归测试

这样做的原因：

- 先拆低耦合基础能力，便于稳定边界
- 优先隔离最复杂、最值得单测的 forward/confirm 逻辑
- 分类工作流在 forward 能力稳定后更容易迁移
- 读取与媒体能力最后收口，减少一次性大改风险

## 风险与应对

### 风险 1：协作者拆分后反而出现重复授权检查

应对：

- 统一规定授权检查只在 `TelegramService` 公共入口执行
- 协作者默认假设调用前已授权就绪

### 风险 2：读取与媒体职责边界模糊

应对：

- `TelegramMessageReader` 只负责读取与构建 `PipelineMessage`
- `TelegramMediaService` 只负责文件准备
- 组合逻辑留在 `TelegramService`

### 风险 3：分类恢复依赖私有方法，迁移后边界不清

应对：

- `TelegramClassifyWorkflow` 明确接收 `deleteSourceMessages`、`loadMessage` 等受控依赖
- 通过函数注入或小型依赖对象减少隐式耦合

### 风险 4：测试过多依赖 `TelegramService` 内部实现细节

应对：

- 保留门面层回归测试
- 将复杂边界条件迁移到协作者测试中
- 避免新测试继续依赖过重的集成式 fake adapter 场景

## 完成定义

本次重构完成需满足：

- `TelegramService` 体量明显下降，主要承担授权检查与委派职责
- 复杂分类转发逻辑已迁移到独立协作者
- self chat 解析不再散落在大服务内部
- 现有 `TelegramGateway` 对外接口保持稳定
- 现有相关测试通过
- 新增核心协作者单测通过

## 预期产出文件

预计新增或调整的核心文件包括：

- `telegram_service.dart`
- `telegram_session_resolver.dart`
- `telegram_message_reader.dart`
- `telegram_media_service.dart`
- `telegram_message_forwarder.dart`
- `telegram_classify_workflow.dart`
- `telegram_service_test.dart`
- `telegram_session_resolver_test.dart`
- `telegram_message_forwarder_test.dart`
- `telegram_classify_workflow_test.dart`

