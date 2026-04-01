import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

enum TdTextEntityKind { url, textUrl, emailAddress, phoneNumber, other }
enum TdMessageContentKind { text, photo, video, unsupported }

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
    this.text,
    this.localImagePath,
    this.localVideoPath,
    this.localVideoThumbnailPath,
    this.videoDurationSeconds,
    this.remoteImageFileId,
    this.remoteVideoFileId,
    this.remoteVideoThumbnailFileId,
  });

  final TdMessageContentKind kind;
  final TdFormattedTextDto? text;
  final String? localImagePath;
  final String? localVideoPath;
  final String? localVideoThumbnailPath;
  final int? videoDurationSeconds;
  final int? remoteImageFileId;
  final int? remoteVideoFileId;
  final int? remoteVideoThumbnailFileId;
}

class TdMessageDto {
  const TdMessageDto({required this.id, required this.content});

  factory TdMessageDto.fromJson(Map<String, dynamic> payload) {
    return TdMessageDto(
      id: TdResponseReader.readInt(payload, 'id'),
      content: _parseContent(TdResponseReader.readMap(payload, 'content')),
    );
  }

  final int id;
  final TdMessageContentDto content;

  static TdMessageContentDto _parseContent(Map<String, dynamic> content) {
    final type = TdResponseReader.readString(content, '@type');
    switch (type) {
      case 'messageText':
        return TdMessageContentDto(
          kind: TdMessageContentKind.text,
          text: TdFormattedTextDto.fromJson(
            TdResponseReader.readMap(content, 'text'),
          ),
        );
      case 'messagePhoto':
        return _parsePhotoContent(content);
      case 'messageVideo':
        return _parseVideoContent(content);
      default:
        return const TdMessageContentDto(kind: TdMessageContentKind.unsupported);
    }
  }

  static TdMessageContentDto _parsePhotoContent(Map<String, dynamic> content) {
    final photo = TdResponseReader.readMap(content, 'photo');
    final sizes = TdResponseReader.readList(photo, 'sizes');
    if (sizes.isEmpty) {
      throw const TdResponseReadError(
        'Missing required list item at photo.sizes.last',
      );
    }
    final last = TdResponseReader.readMap(<String, dynamic>{'item': sizes.last}, 'item');
    final photoFile = TdResponseReader.readMap(last, 'photo');
    return TdMessageContentDto(
      kind: TdMessageContentKind.photo,
      text: TdFormattedTextDto.fromJson(
        TdResponseReader.readMap(content, 'caption'),
      ),
      localImagePath: _readLocalPath(photoFile),
      remoteImageFileId: TdResponseReader.readInt(photoFile, 'id'),
    );
  }

  static TdMessageContentDto _parseVideoContent(Map<String, dynamic> content) {
    final video = TdResponseReader.readMap(content, 'video');
    final videoFile = TdResponseReader.readMap(video, 'video');
    final thumbnail = video['thumbnail'];
    final thumbnailFile = thumbnail == null
        ? null
        : TdResponseReader.readMap(
            TdResponseReader.readMap(
              <String, dynamic>{'thumbnail': thumbnail},
              'thumbnail',
            ),
            'file',
          );
    return TdMessageContentDto(
      kind: TdMessageContentKind.video,
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

  static String? _readLocalPath(Map<String, dynamic> file) {
    final local = TdResponseReader.readMap(file, 'local');
    final path = local['path']?.toString() ?? '';
    return path.isEmpty ? null : path;
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
