import 'package:tgsorter/app/features/settings/domain/connection_settings.dart';
import 'package:tgsorter/app/features/settings/domain/shortcut_settings.dart';
import 'package:tgsorter/app/features/settings/domain/workflow_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

enum MessageFetchDirection { latestFirst, oldestFirst }

class AppSettings {
  static const int defaultPreviewPrefetchCount = 3;

  const AppSettings({
    required this.categories,
    required this.sourceChatId,
    required this.fetchDirection,
    required this.forwardAsCopy,
    required this.batchSize,
    required this.throttleMs,
    required this.proxy,
    this.previewPrefetchCount = defaultPreviewPrefetchCount,
    this.shortcutBindings = defaultShortcutBindings,
  });

  final List<CategoryConfig> categories;
  final int? sourceChatId;
  final MessageFetchDirection fetchDirection;
  final bool forwardAsCopy;
  final int batchSize;
  final int throttleMs;
  final ProxySettings proxy;
  final int previewPrefetchCount;
  final Map<ShortcutAction, ShortcutBinding> shortcutBindings;

  WorkflowSettings get workflow => WorkflowSettings(
    sourceChatId: sourceChatId,
    fetchDirection: fetchDirection,
    forwardAsCopy: forwardAsCopy,
    batchSize: batchSize,
    throttleMs: throttleMs,
    previewPrefetchCount: previewPrefetchCount,
    categories: categories,
  );

  ConnectionSettings get connection => ConnectionSettings(proxy: proxy);

  ShortcutSettings get shortcuts => ShortcutSettings(bindings: shortcutBindings);

  static AppSettings defaults() {
    return const AppSettings(
      categories: [],
      sourceChatId: null,
      fetchDirection: MessageFetchDirection.latestFirst,
      forwardAsCopy: false,
      batchSize: 5,
      throttleMs: 1200,
      proxy: ProxySettings.empty,
      previewPrefetchCount: defaultPreviewPrefetchCount,
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

  AppSettings copyWith({
    List<CategoryConfig>? categories,
    int? sourceChatId,
    bool clearSourceChatId = false,
    MessageFetchDirection? fetchDirection,
    bool? forwardAsCopy,
    int? batchSize,
    int? throttleMs,
    ProxySettings? proxy,
    int? previewPrefetchCount,
    Map<ShortcutAction, ShortcutBinding>? shortcutBindings,
  }) {
    return AppSettings(
      categories: categories ?? this.categories,
      sourceChatId: clearSourceChatId ? null : sourceChatId ?? this.sourceChatId,
      fetchDirection: fetchDirection ?? this.fetchDirection,
      forwardAsCopy: forwardAsCopy ?? this.forwardAsCopy,
      batchSize: batchSize ?? this.batchSize,
      throttleMs: throttleMs ?? this.throttleMs,
      proxy: proxy ?? this.proxy,
      previewPrefetchCount:
          previewPrefetchCount ?? this.previewPrefetchCount,
      shortcutBindings: shortcutBindings ?? this.shortcutBindings,
    );
  }

  AppSettings updateCategory(CategoryConfig config) {
    final updated = categories
        .map((item) => item.key == config.key ? config : item)
        .toList(growable: false);
    return copyWith(categories: updated);
  }

  AppSettings addCategory(CategoryConfig config) {
    return copyWith(categories: [...categories, config]);
  }

  AppSettings removeCategory(String key) {
    return copyWith(
      categories: categories
          .where((item) => item.key != key)
          .toList(growable: false),
    );
  }

  AppSettings updateSourceChatId(int? chatId) {
    return copyWith(
      sourceChatId: chatId,
      clearSourceChatId: chatId == null,
    );
  }

  AppSettings updateFetchDirection(MessageFetchDirection direction) {
    return copyWith(fetchDirection: direction);
  }

  AppSettings updateBatchOptions({
    required int batchSize,
    required int throttleMs,
  }) {
    return copyWith(batchSize: batchSize, throttleMs: throttleMs);
  }

  AppSettings updatePreviewPrefetchCount(int value) {
    return copyWith(previewPrefetchCount: value);
  }

  AppSettings updateProxySettings(ProxySettings nextProxy) {
    return copyWith(proxy: nextProxy.sanitize());
  }

  AppSettings updateShortcutBinding(
    ShortcutAction action,
    ShortcutBinding binding,
  ) {
    final updated = Map<ShortcutAction, ShortcutBinding>.from(shortcutBindings);
    updated[action] = binding;
    return copyWith(shortcutBindings: Map.unmodifiable(updated));
  }

  AppSettings updateForwardAsCopy(bool value) {
    return copyWith(forwardAsCopy: value);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppSettings &&
            _listEquals(categories, other.categories) &&
            sourceChatId == other.sourceChatId &&
            fetchDirection == other.fetchDirection &&
            forwardAsCopy == other.forwardAsCopy &&
            batchSize == other.batchSize &&
            throttleMs == other.throttleMs &&
            proxy == other.proxy &&
            previewPrefetchCount == other.previewPrefetchCount &&
            _mapEquals(shortcutBindings, other.shortcutBindings);
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(categories),
      sourceChatId,
      fetchDirection,
      forwardAsCopy,
      batchSize,
      throttleMs,
      proxy,
      previewPrefetchCount,
      Object.hashAll(shortcutBindings.entries),
    );
  }

  bool _listEquals(List<CategoryConfig> left, List<CategoryConfig> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _mapEquals(
    Map<ShortcutAction, ShortcutBinding> left,
    Map<ShortcutAction, ShortcutBinding> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
