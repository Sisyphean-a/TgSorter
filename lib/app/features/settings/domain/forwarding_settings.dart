import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';

class ForwardingSettings {
  const ForwardingSettings({
    required this.sourceChatId,
    required this.fetchDirection,
    required this.forwardAsCopy,
    required this.batchSize,
    required this.throttleMs,
    required this.previewPrefetchCount,
    required this.categories,
  });

  final int? sourceChatId;
  final MessageFetchDirection fetchDirection;
  final bool forwardAsCopy;
  final int batchSize;
  final int throttleMs;
  final int previewPrefetchCount;
  final List<CategoryConfig> categories;
}
