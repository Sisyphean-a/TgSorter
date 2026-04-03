import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/media_download_coordinator.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/telegram_message_reader.dart';

class TelegramMediaService {
  TelegramMediaService({
    required TdlibAdapter adapter,
    required TelegramMessageReader reader,
    MediaDownloadCoordinator? mediaDownloadCoordinator,
  }) : _reader = reader,
       _mediaDownloadCoordinator =
           mediaDownloadCoordinator ??
           MediaDownloadCoordinator(adapter: adapter);

  final TelegramMessageReader _reader;
  final MediaDownloadCoordinator _mediaDownloadCoordinator;

  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    final message = await _reader.loadMessage(sourceChatId, messageId);
    final content = message.content;
    await _mediaDownloadCoordinator.preparePlayback(content);
    if (!_shouldRefreshAfterPrepare(content)) {
      return _reader.toPipelineMessage(
        message: message,
        sourceChatId: sourceChatId,
      );
    }
    // 音视频下载启动后需要重新读取消息，拿到最新本地路径。
    return _reader.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    final message = await _reader.loadMessage(sourceChatId, messageId);
    await _mediaDownloadCoordinator.warmUpPreview(message.content);
  }

  bool _shouldRefreshAfterPrepare(TdMessageContentDto content) {
    return content.kind == TdMessageContentKind.audio ||
        content.kind == TdMessageContentKind.video;
  }
}
