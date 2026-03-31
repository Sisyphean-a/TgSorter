# Android TDLib 运行参数说明

当前实现在 `TelegramService._configureTdlib()` 中完成 TDLib 参数初始化，重点如下：

- 数据目录：`${ApplicationSupportDirectory}/tgsorter/tdlib/db`
- 文件目录：`${ApplicationSupportDirectory}/tgsorter/tdlib/files`
- 目录创建：启动时递归创建，避免目录缺失导致初始化失败
- 日志级别：`setLogVerbosityLevel(1)`（错误级）
- 设备信息：
  - `deviceModel = Flutter <operatingSystem>`
  - `systemVersion = Platform.operatingSystemVersion`
- 应用版本：`applicationVersion = 1.0.0`
- 数据库配置：
  - `useFileDatabase = true`
  - `useChatInfoDatabase = true`
  - `useMessageDatabase = true`
  - `enableStorageOptimizer = true`

这些参数遵循“显式失败”策略：配置异常会直接抛错，不做静默降级。
