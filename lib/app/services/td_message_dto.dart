import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

enum TdTextEntityKind { url, textUrl, emailAddress, phoneNumber, other }

enum TdMessageContentKind { text, photo, video, audio, unsupported }

class TdPhotoSizeDto {
  const TdPhotoSizeDto({
    required this.type,
    required this.width,
    required this.height,
    required this.localPath,
    required this.remoteFileId,
  });

  final String type;
  final int width;
  final int height;
  final String? localPath;
  final int remoteFileId;
}

class TdLinkPreviewDto {
  const TdLinkPreviewDto({
    required this.url,
    required this.displayUrl,
    required this.siteName,
    required this.title,
    required this.description,
    this.localImagePath,
    this.remoteImageFileId,
  });

  final String url;
  final String displayUrl;
  final String siteName;
  final String title;
  final String description;
  final String? localImagePath;
  final int? remoteImageFileId;
}

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
    this.mediaWidth,
    this.mediaHeight,
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
    this.photoSizes = const <TdPhotoSizeDto>[],
    this.fullImagePath,
    this.remoteFullImageFileId,
    this.linkPreview,
  });

  final TdMessageContentKind kind;
  final int messageId;
  final TdFormattedTextDto? text;
  final int? mediaWidth;
  final int? mediaHeight;
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
  final List<TdPhotoSizeDto> photoSizes;
  final String? fullImagePath;
  final int? remoteFullImageFileId;
  final TdLinkPreviewDto? linkPreview;
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
          linkPreview: _parseLinkPreview(content),
        );
      case 'messagePhoto':
        return _parsePhotoContent(content, messageId: messageId);
      case 'messageVideo':
        return _parseVideoContent(content, messageId: messageId);
      case 'messageDocument':
        return _parseDocumentContent(content, messageId: messageId);
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
    final parsedSizes =
        sizes
            .map(
              (item) => _parsePhotoSize(
                TdResponseReader.readMap(<String, dynamic>{
                  'item': item,
                }, 'item'),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final areaCompare = (a.width * a.height).compareTo(
              b.width * b.height,
            );
            if (areaCompare != 0) {
              return areaCompare;
            }
            return a.remoteFileId.compareTo(b.remoteFileId);
          });
    final preview = parsedSizes.first;
    final full = parsedSizes.last;
    return TdMessageContentDto(
      kind: TdMessageContentKind.photo,
      messageId: messageId,
      text: TdFormattedTextDto.fromJson(
        TdResponseReader.readMap(content, 'caption'),
      ),
      mediaWidth: preview.width,
      mediaHeight: preview.height,
      photoSizes: parsedSizes,
      localImagePath: preview.localPath,
      remoteImageFileId: preview.remoteFileId,
      fullImagePath: full.localPath,
      remoteFullImageFileId: full.remoteFileId,
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
      mediaWidth: _readOptionalInt(video['width']),
      mediaHeight: _readOptionalInt(video['height']),
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

  static TdPhotoSizeDto _parsePhotoSize(Map<String, dynamic> payload) {
    final photoFile = TdResponseReader.readMap(payload, 'photo');
    return TdPhotoSizeDto(
      type: payload['type']?.toString() ?? '',
      width: _readOptionalInt(payload['width']),
      height: _readOptionalInt(payload['height']),
      localPath: _readLocalPath(photoFile),
      remoteFileId: TdResponseReader.readInt(photoFile, 'id'),
    );
  }

  static TdMessageContentDto _parseDocumentContent(
    Map<String, dynamic> content, {
    required int messageId,
  }) {
    final document = TdResponseReader.readMap(content, 'document');
    final mimeType = document['mime_type']?.toString() ?? '';
    if (!mimeType.startsWith('video/')) {
      return TdMessageContentDto(
        kind: TdMessageContentKind.unsupported,
        messageId: messageId,
        fileName: document['file_name']?.toString(),
        text: TdFormattedTextDto.fromJson(
          TdResponseReader.readMap(content, 'caption'),
        ),
      );
    }
    final documentFile = TdResponseReader.readMap(document, 'document');
    final thumbnail = document['thumbnail'];
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
      mediaWidth: _readOptionalInt(document['width']) > 0
          ? _readOptionalInt(document['width'])
          : _readOptionalInt(thumbnail?['width']),
      mediaHeight: _readOptionalInt(document['height']) > 0
          ? _readOptionalInt(document['height'])
          : _readOptionalInt(thumbnail?['height']),
      localVideoPath: _readLocalPath(documentFile),
      localVideoThumbnailPath: thumbnailFile == null
          ? null
          : _readLocalPath(thumbnailFile),
      remoteVideoFileId: TdResponseReader.readInt(documentFile, 'id'),
      remoteVideoThumbnailFileId: thumbnailFile == null
          ? null
          : TdResponseReader.readInt(thumbnailFile, 'id'),
      fileName: document['file_name']?.toString(),
    );
  }

  static TdLinkPreviewDto? _parseLinkPreview(Map<String, dynamic> content) {
    final raw = content['web_page'];
    if (raw == null) {
      return null;
    }
    final webPage = TdResponseReader.readMap(<String, dynamic>{
      'web_page': raw,
    }, 'web_page');
    final photo = webPage['photo'];
    final image = photo == null ? null : _parsePreviewPhoto(photo);
    return TdLinkPreviewDto(
      url: webPage['url']?.toString() ?? '',
      displayUrl: webPage['display_url']?.toString() ?? '',
      siteName: webPage['site_name']?.toString() ?? '',
      title: webPage['title']?.toString() ?? '',
      description: _readFormattedTextText(webPage['description']),
      localImagePath: image?.localPath,
      remoteImageFileId: image?.remoteFileId,
    );
  }

  static TdPhotoSizeDto? _parsePreviewPhoto(dynamic photoRaw) {
    final photo = TdResponseReader.readMap(<String, dynamic>{
      'photo': photoRaw,
    }, 'photo');
    final sizes = TdResponseReader.readList(photo, 'sizes');
    if (sizes.isEmpty) {
      return null;
    }
    final parsedSizes =
        sizes
            .map(
              (item) => _parsePhotoSize(
                TdResponseReader.readMap(<String, dynamic>{
                  'item': item,
                }, 'item'),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
    return parsedSizes.first;
  }

  static String _readFormattedTextText(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return '';
    }
    final text = raw['text'];
    return text is String ? text : '';
  }

  static int _readOptionalInt(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
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
