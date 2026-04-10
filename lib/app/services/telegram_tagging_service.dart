import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_builder.dart';
import 'package:tgsorter/app/features/tagging/application/tag_append_service.dart';
import 'package:tgsorter/app/features/tagging/application/tag_target_selector.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class TelegramTaggingService {
  TelegramTaggingService({
    required TdlibAdapter adapter,
    TagAppendService appendService = const TagAppendService(),
    TagTargetSelector targetSelector = const TagTargetSelector(),
    MessagePreviewBuilder previewBuilder = const MessagePreviewBuilder(),
  }) : _adapter = adapter,
       _appendService = appendService,
       _targetSelector = targetSelector,
       _previewBuilder = previewBuilder;

  final TdlibAdapter _adapter;
  final TagAppendService _appendService;
  final TagTargetSelector _targetSelector;
  final MessagePreviewBuilder _previewBuilder;

  Future<ApplyTagResult> applyTag({
    required int sourceChatId,
    required List<int> messageIds,
    required String tagName,
  }) async {
    final messages = await _loadMessages(sourceChatId, messageIds);
    final target = _targetSelector.select(messages);
    final appended = _appendService.appendTag(target.currentText, tagName);
    if (!appended.changed) {
      return _buildResult(sourceChatId, messages, changed: false);
    }
    final edited = await _editTarget(sourceChatId, target, appended.text);
    final updated = _replaceMessage(messages, edited);
    return _buildResult(sourceChatId, updated, changed: true);
  }

  Future<List<TdMessageDto>> _loadMessages(
    int sourceChatId,
    List<int> messageIds,
  ) async {
    final messages = <TdMessageDto>[];
    for (final messageId in messageIds) {
      final envelope = await _adapter.sendWire(
        GetMessage(chatId: sourceChatId, messageId: messageId),
        request: 'getMessage($sourceChatId,$messageId)',
        phase: TdlibPhase.business,
      );
      messages.add(TdMessageDto.fromJson(envelope.payload));
    }
    return messages;
  }

  Future<TdMessageDto> _editTarget(
    int sourceChatId,
    TagEditTarget target,
    String text,
  ) async {
    final envelope = switch (target.kind) {
      TagEditKind.text => await _editText(sourceChatId, target.messageId, text),
      TagEditKind.caption => await _editCaption(
        sourceChatId,
        target.messageId,
        text,
      ),
    };
    return TdMessageDto.fromJson(envelope.payload);
  }

  Future<TdWireEnvelope> _editText(int chatId, int messageId, String text) {
    return _adapter.sendWire(
      EditMessageText(
        chatId: chatId,
        messageId: messageId,
        replyMarkup: null,
        inputMessageContent: InputMessageText(
          text: FormattedText(text: text, entities: const []),
          disableWebPagePreview: false,
          clearDraft: false,
        ),
      ),
      request: 'editMessageText',
      phase: TdlibPhase.business,
    );
  }

  Future<TdWireEnvelope> _editCaption(int chatId, int messageId, String text) {
    return _adapter.sendWire(
      EditMessageCaption(
        chatId: chatId,
        messageId: messageId,
        replyMarkup: null,
        caption: FormattedText(text: text, entities: const []),
      ),
      request: 'editMessageCaption',
      phase: TdlibPhase.business,
    );
  }

  List<TdMessageDto> _replaceMessage(
    List<TdMessageDto> messages,
    TdMessageDto edited,
  ) {
    return messages
        .map((item) => item.id == edited.id ? edited : item)
        .toList(growable: false);
  }

  ApplyTagResult _buildResult(
    int sourceChatId,
    List<TdMessageDto> messages, {
    required bool changed,
  }) {
    return ApplyTagResult(
      message: _previewBuilder.toPipelineMessage(
        messages: messages,
        sourceChatId: sourceChatId,
      ),
      changed: changed,
    );
  }
}
