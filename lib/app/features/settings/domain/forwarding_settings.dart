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
    required this.mediaBackgroundDownloadConcurrency,
    required this.mediaRetryLimit,
    required this.mediaRetryDelayMs,
    required this.categories,
  });

  final int? sourceChatId;
  final MessageFetchDirection fetchDirection;
  final bool forwardAsCopy;
  final int batchSize;
  final int throttleMs;
  final int previewPrefetchCount;
  final int mediaBackgroundDownloadConcurrency;
  final int mediaRetryLimit;
  final int mediaRetryDelayMs;
  final List<CategoryConfig> categories;
}
