import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

enum MessageFetchDirection { latestFirst, oldestFirst }

class AppSettings {
  const AppSettings({
    required this.categories,
    required this.sourceChatId,
    required this.fetchDirection,
    required this.batchSize,
    required this.throttleMs,
    this.shortcutBindings = defaultShortcutBindings,
  });

  final List<CategoryConfig> categories;
  final int? sourceChatId;
  final MessageFetchDirection fetchDirection;
  final int batchSize;
  final int throttleMs;
  final Map<ShortcutAction, ShortcutBinding> shortcutBindings;

  static AppSettings defaults() {
    return const AppSettings(
      categories: [
        CategoryConfig(key: 'a', name: '分类 A', targetChatId: null),
        CategoryConfig(key: 'b', name: '分类 B', targetChatId: null),
        CategoryConfig(key: 'c', name: '分类 C', targetChatId: null),
      ],
      sourceChatId: null,
      fetchDirection: MessageFetchDirection.latestFirst,
      batchSize: 5,
      throttleMs: 1200,
      shortcutBindings: defaultShortcutBindings,
    );
  }

  static const Map<ShortcutAction, ShortcutBinding> defaultShortcutBindings = {
    ShortcutAction.classifyA: ShortcutBinding(
      action: ShortcutAction.classifyA,
      trigger: ShortcutTrigger.digit1,
      ctrl: false,
    ),
    ShortcutAction.classifyB: ShortcutBinding(
      action: ShortcutAction.classifyB,
      trigger: ShortcutTrigger.digit2,
      ctrl: false,
    ),
    ShortcutAction.classifyC: ShortcutBinding(
      action: ShortcutAction.classifyC,
      trigger: ShortcutTrigger.digit3,
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
    ShortcutAction.batchA: ShortcutBinding(
      action: ShortcutAction.batchA,
      trigger: ShortcutTrigger.keyB,
      ctrl: true,
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
      shortcutBindings: Map.unmodifiable(updated),
    );
  }
}
