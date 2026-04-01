import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

enum MessageFetchDirection { latestFirst, oldestFirst }

class AppSettings {
  const AppSettings({
    required this.categories,
    required this.sourceChatId,
    required this.fetchDirection,
    required this.batchSize,
    required this.throttleMs,
    required this.proxy,
    this.shortcutBindings = defaultShortcutBindings,
  });

  final List<CategoryConfig> categories;
  final int? sourceChatId;
  final MessageFetchDirection fetchDirection;
  final int batchSize;
  final int throttleMs;
  final ProxySettings proxy;
  final Map<ShortcutAction, ShortcutBinding> shortcutBindings;

  static AppSettings defaults() {
    return const AppSettings(
      categories: [],
      sourceChatId: null,
      fetchDirection: MessageFetchDirection.latestFirst,
      batchSize: 5,
      throttleMs: 1200,
      proxy: ProxySettings.empty,
      shortcutBindings: defaultShortcutBindings,
    );
  }

  static const Map<ShortcutAction, ShortcutBinding> defaultShortcutBindings = {
    ShortcutAction.previousMessage: ShortcutBinding(
      action: ShortcutAction.previousMessage,
      trigger: ShortcutTrigger.digit1,
      ctrl: false,
    ),
    ShortcutAction.nextMessage: ShortcutBinding(
      action: ShortcutAction.nextMessage,
      trigger: ShortcutTrigger.digit2,
      ctrl: false,
    ),
    ShortcutAction.skipCurrent: ShortcutBinding(
      action: ShortcutAction.skipCurrent,
      trigger: ShortcutTrigger.keyS,
      ctrl: false,
    ),
    ShortcutAction.undoLastStep: ShortcutBinding(
      action: ShortcutAction.undoLastStep,
      trigger: ShortcutTrigger.keyZ,
      ctrl: false,
    ),
    ShortcutAction.retryNextFailed: ShortcutBinding(
      action: ShortcutAction.retryNextFailed,
      trigger: ShortcutTrigger.keyR,
      ctrl: false,
    ),
  };

  AppSettings updateCategory(CategoryConfig config) {
    final updated = categories
        .map((item) => item.key == config.key ? config : item)
        .toList(growable: false);
    return AppSettings(
      categories: updated,
      sourceChatId: sourceChatId,
      fetchDirection: fetchDirection,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: proxy,
      shortcutBindings: shortcutBindings,
    );
  }

  AppSettings addCategory(CategoryConfig config) {
    return AppSettings(
      categories: [...categories, config],
      sourceChatId: sourceChatId,
      fetchDirection: fetchDirection,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: proxy,
      shortcutBindings: shortcutBindings,
    );
  }

  AppSettings removeCategory(String key) {
    return AppSettings(
      categories: categories.where((item) => item.key != key).toList(growable: false),
      sourceChatId: sourceChatId,
      fetchDirection: fetchDirection,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: proxy,
      shortcutBindings: shortcutBindings,
    );
  }

  AppSettings updateSourceChatId(int? chatId) {
    return AppSettings(
      categories: categories,
      sourceChatId: chatId,
      fetchDirection: fetchDirection,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: proxy,
      shortcutBindings: shortcutBindings,
    );
  }

  AppSettings updateFetchDirection(MessageFetchDirection direction) {
    return AppSettings(
      categories: categories,
      sourceChatId: sourceChatId,
      fetchDirection: direction,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: proxy,
      shortcutBindings: shortcutBindings,
    );
  }

  AppSettings updateBatchOptions({
    required int batchSize,
    required int throttleMs,
  }) {
    return AppSettings(
      categories: categories,
      sourceChatId: sourceChatId,
      fetchDirection: fetchDirection,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: proxy,
      shortcutBindings: shortcutBindings,
    );
  }

  AppSettings updateProxySettings(ProxySettings nextProxy) {
    return AppSettings(
      categories: categories,
      sourceChatId: sourceChatId,
      fetchDirection: fetchDirection,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: nextProxy.sanitize(),
      shortcutBindings: shortcutBindings,
    );
  }

  AppSettings updateShortcutBinding(
    ShortcutAction action,
    ShortcutBinding binding,
  ) {
    final updated = Map<ShortcutAction, ShortcutBinding>.from(shortcutBindings);
    updated[action] = binding;
    return AppSettings(
      categories: categories,
      sourceChatId: sourceChatId,
      fetchDirection: fetchDirection,
      batchSize: batchSize,
      throttleMs: throttleMs,
      proxy: proxy,
      shortcutBindings: Map.unmodifiable(updated),
    );
  }
}
