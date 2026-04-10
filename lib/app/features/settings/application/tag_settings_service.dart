import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/tag_config.dart';

class TagSettingsService {
  AppSettings updateTagSourceChat({
    required AppSettings current,
    required int? chatId,
  }) {
    return current.copyWith(
      tagSourceChatId: chatId,
      clearTagSourceChatId: chatId == null,
    );
  }

  AppSettings addDefaultTag({
    required AppSettings current,
    required String rawName,
  }) {
    final tag = TagConfig.fromRaw(rawName);
    final group = _defaultGroup(current.tagGroups);
    final updatedTags = [...group.tags, tag];
    final updated = group.copyWith(tags: updatedTags);
    return current.copyWith(tagGroups: _replaceDefaultGroup(current, updated));
  }

  AppSettings removeDefaultTag({
    required AppSettings current,
    required String rawName,
  }) {
    final name = TagConfig.normalizeName(rawName);
    final group = _defaultGroup(current.tagGroups);
    final updated = group.copyWith(
      tags: group.tags
          .where((item) => item.name != name)
          .toList(growable: false),
    );
    return current.copyWith(tagGroups: _replaceDefaultGroup(current, updated));
  }

  TagGroupConfig _defaultGroup(List<TagGroupConfig> groups) {
    for (final group in groups) {
      if (group.key == TagGroupConfig.defaultGroupKey) {
        return group;
      }
    }
    return TagGroupConfig.emptyDefault;
  }

  List<TagGroupConfig> _replaceDefaultGroup(
    AppSettings current,
    TagGroupConfig next,
  ) {
    var replaced = false;
    final updated = <TagGroupConfig>[];
    for (final group in current.tagGroups) {
      if (group.key == TagGroupConfig.defaultGroupKey) {
        updated.add(next);
        replaced = true;
        continue;
      }
      updated.add(group);
    }
    return replaced ? updated : [next];
  }
}
