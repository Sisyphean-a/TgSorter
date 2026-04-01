import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

enum TdTextEntityKind { url, textUrl, emailAddress, phoneNumber, other }

enum TdMessageContentKind { text, photo, video, audio, unsupported }

class TdTextEntityDto {
  const TdTextEntityDto({
    required this.offset,
    required this.length,
    required this.kind,
    this.url,
  });

  factory TdTextEntityDto.fromJson(Map<String, dynamic> payload) {
    final type = TdResponseReader.readMap(payload, 'type');
    final kindName = TdResponseReader.readString(type, '@type');
    return TdTextEntityDto(
      offset: TdResponseReader.readInt(payload, 'offset'),
      length: TdResponseReader.readInt(payload, 'length'),
      kind: _mapKind(kindName),
      url: kindName == 'textEntityTypeTextUrl'
          ? TdResponseReader.readString(type, 'url')
          : null,
    );
  }

  final int offset;
  final int length;
  final TdTextEntityKind kind;
  final String? url;

  static TdTextEntityKind _mapKind(String kindName) {
    switch (kindName) {
      case 'textEntityTypeUrl':
        return TdTextEntityKind.url;
      case 'textEntityTypeTextUrl':
        return TdTextEntityKind.textUrl;
      case 'textEntityTypeEmailAddress':
        return TdTextEntityKind.emailAddress;
      case 'textEntityTypePhoneNumber':
        return TdTextEntityKind.phoneNumber;
      default:
        return TdTextEntityKind.other;
    }
  }
}

class TdFormattedTextDto {
  const TdFormattedTextDto({required this.text, required this.entities});

  factory TdFormattedTextDto.fromJson(Map<String, dynamic> payload) {
    final rawEntities = TdResponseReader.readList(payload, 'entities');
    final textValue = payload['text'];
    if (textValue is! String) {
      throw const TdResponseReadError('Missing required string at text');
    }
    return TdFormattedTextDto(
      text: textValue,
      entities: rawEntities
          .map(
            (item) => TdTextEntityDto.fromJson(
              TdResponseReader.readMap(<String, dynamic>{'item': item}, 'item'),
            ),
          )
          .toList(growable: false),
    );
  }

  final String text;
  final List<TdTextEntityDto> entities;
}

class TdMessageContentDto {
  const TdMessageContentDto({
    required this.kind,
    required this.messageId,
    this.text,
    this.localImagePath,
    this.localVideoPath,
    this.localVideoThumbnailPath,
    this.videoDurationSeconds,
    this.remoteImageFileId,
    this.remoteVideoFileId,
    this.remoteVideoThumbnailFileId,
    this.localAudioPath,
    this.remoteAudioFileId,
    this.audioDurationSeconds,
    this.fileName,
    this.audioTitle,
    this.audioPerformer,
  });

  final TdMessageContentKind kind;
  final int messageId;
  final TdFormattedTextDto? text;
  final String? localImagePath;
  final String? localVideoPath;
  final String? localVideoThumbnailPath;
  final int? videoDurationSeconds;
  final int? remoteImageFileId;
  final int? remoteVideoFileId;
  final int? remoteVideoThumbnailFileId;
  final String? localAudioPath;
  final int? remoteAudioFileId;
  final int? audioDurationSeconds;
  final String? fileName;
  final String? audioTitle;
  final String? audioPerformer;
}

class TdMessageDto {
  const TdMessageDto({
    required this.id,
    required this.mediaAlbumId,
    required this.content,
  });

  factory TdMessageDto.fromJson(Map<String, dynamic> payload) {
    final id = TdResponseReader.readInt(payload, 'id');
    return TdMessageDto(
      id: id,
      mediaAlbumId: _readMediaAlbumId(payload),
      content: _parseContent(
        TdResponseReader.readMap(payload, 'content'),
        messageId: id,
      ),
    );
  }

  final int id;
  final String? mediaAlbumId;
  final TdMessageContentDto content;

  static TdMessageContentDto _parseContent(
    Map<String, dynamic> content, {
    required int messageId,
  }) {
    final type = TdResponseReader.readString(content, '@type');
    switch (type) {
      case 'messageText':
        return TdMessageContentDto(
          kind: TdMessageContentKind.text,
          messageId: messageId,
          text: TdFormattedTextDto.fromJson(
            TdResponseReader.readMap(content, 'text'),
          ),
        );
      case 'messagePhoto':
        return _parsePhotoContent(content, messageId: messageId);
      case 'messageVideo':
        return _parseVideoContent(content, messageId: messageId);
      case 'messageAudio':
        return _parseAudioContent(content, messageId: messageId);
      case 'messageVoiceNote':
        return _parseVoiceNoteContent(content, messageId: messageId);
      default:
        return TdMessageContentDto(
          kind: TdMessageContentKind.unsupported,
          messageId: messageId,
        );
    }
  }

  static TdMessageContentDto _parsePhotoContent(
    Map<String, dynamic> content, {
    required int messageId,
  }) {
    final photo = TdResponseReader.readMap(content, 'photo');
    final sizes = TdResponseReader.readList(photo, 'sizes');
    if (sizes.isEmpty) {
      throw const TdResponseReadError(
        'Missing required list item at photo.sizes.last',
      );
    }
    final last = TdResponseReader.readMap(<String, dynamic>{
      'item': sizes.last,
    }, 'item');
    final photoFile = TdResponseReader.readMap(last, 'photo');
    return TdMessageContentDto(
      kind: TdMessageContentKind.photo,
      messageId: messageId,
      text: TdFormattedTextDto.fromJson(
        TdResponseReader.readMap(content, 'caption'),
      ),
      localImagePath: _readLocalPath(photoFile),
      remoteImageFileId: TdResponseReader.readInt(photoFile, 'id'),
    );
  }

  static TdMessageContentDto _parseVideoContent(
    Map<String, dynamic> content, {
    required int messageId,
  }) {
    final video = TdResponseReader.readMap(content, 'video');
    final videoFile = TdResponseReader.readMap(video, 'video');
    final thumbnail = video['thumbnail'];
    final thumbnailFile = thumbnail == null
        ? null
        : TdResponseReader.readMap(
            TdResponseReader.readMap(<String, dynamic>{
              'thumbnail': thumbnail,
            }, 'thumbnail'),
            'file',
          );
    return TdMessageContentDto(
      kind: TdMessageContentKind.video,
      messageId: messageId,
      text: TdFormattedTextDto.fromJson(
        TdResponseReader.readMap(content, 'caption'),
      ),
      localVideoPath: _readLocalPath(videoFile),
      localVideoThumbnailPath: thumbnailFile == null
          ? null
          : _readLocalPath(thumbnailFile),
      videoDurationSeconds: TdResponseReader.readInt(video, 'duration'),
      remoteVideoFileId: TdResponseReader.readInt(videoFile, 'id'),
      remoteVideoThumbnailFileId: thumbnailFile == null
          ? null
          : TdResponseReader.readInt(thumbnailFile, 'id'),
    );
  }

  static TdMessageContentDto _parseAudioContent(
    Map<String, dynamic> content, {
    required int messageId,
  }) {
    final audio = TdResponseReader.readMap(content, 'audio');
    final audioFile = TdResponseReader.readMap(audio, 'audio');
    return TdMessageContentDto(
      kind: TdMessageContentKind.audio,
      messageId: messageId,
      text: TdFormattedTextDto.fromJson(
        TdResponseReader.readMap(content, 'caption'),
      ),
      localAudioPath: _readLocalPath(audioFile),
      remoteAudioFileId: TdResponseReader.readInt(audioFile, 'id'),
      audioDurationSeconds: TdResponseReader.readInt(audio, 'duration'),
      fileName: audio['file_name']?.toString(),
      audioTitle: audio['title']?.toString(),
      audioPerformer: audio['performer']?.toString(),
    );
  }

  static TdMessageContentDto _parseVoiceNoteContent(
    Map<String, dynamic> content, {
    required int messageId,
  }) {
    final voiceNote = TdResponseReader.readMap(content, 'voice_note');
    final voiceFile = TdResponseReader.readMap(voiceNote, 'voice');
    return TdMessageContentDto(
      kind: TdMessageContentKind.audio,
      messageId: messageId,
      text: TdFormattedTextDto.fromJson(
        TdResponseReader.readMap(content, 'caption'),
      ),
      localAudioPath: _readLocalPath(voiceFile),
      remoteAudioFileId: TdResponseReader.readInt(voiceFile, 'id'),
      audioDurationSeconds: TdResponseReader.readInt(voiceNote, 'duration'),
      fileName: voiceNote['mime_type']?.toString(),
      audioTitle: '语音消息',
      audioPerformer: null,
    );
  }

  static String? _readLocalPath(Map<String, dynamic> file) {
    final local = TdResponseReader.readMap(file, 'local');
    final completed = local['is_downloading_completed'];
    if (completed is bool && !completed) {
      return null;
    }
    final path = local['path']?.toString() ?? '';
    return path.isEmpty ? null : path;
  }

  static String? _readMediaAlbumId(Map<String, dynamic> payload) {
    final raw = payload['media_album_id'];
    if (raw == null) {
      return null;
    }
    final value = raw.toString();
    if (value.isEmpty || value == '0') {
      return null;
    }
    return value;
  }
}

class TdMessagesDto {
  const TdMessagesDto({required this.messages});

  factory TdMessagesDto.fromEnvelope(TdWireEnvelope envelope) {
    final rawMessages = TdResponseReader.readList(envelope.payload, 'messages');
    return TdMessagesDto(
      messages: rawMessages
          .map(
            (item) => TdMessageDto.fromJson(
              TdResponseReader.readMap(<String, dynamic>{'item': item}, 'item'),
            ),
          )
          .toList(growable: false),
    );
  }

  final List<TdMessageDto> messages;
}
