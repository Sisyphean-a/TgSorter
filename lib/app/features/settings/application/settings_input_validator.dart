class SettingsInputValidator {
  static const String batchSizeMessage = '请输入大于等于 1 的整数';
  static const String throttleMessage = '请输入大于等于 0 的整数';
  static const String portMessage = '请输入大于 0 的端口';

  String? validateBatchSizeText(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 1) {
      return batchSizeMessage;
    }
    return null;
  }

  String? validateThrottleText(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0) {
      return throttleMessage;
    }
    return null;
  }

  String? validatePortText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final value = int.tryParse(trimmed);
    if (value == null || value <= 0) {
      return portMessage;
    }
    return null;
  }

  int requireBatchSize(int value) {
    if (value < 1) {
      throw ArgumentError.value(value, 'batchSize', '批处理条数必须大于等于 1');
    }
    return value;
  }

  int requireThrottleMs(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'throttleMs', '节流毫秒必须大于等于 0');
    }
    return value;
  }

  int? parsePort(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final value = int.tryParse(trimmed);
    if (value == null || value <= 0) {
      throw ArgumentError.value(raw, 'port', '代理端口必须是大于 0 的整数');
    }
    return value;
  }
}
