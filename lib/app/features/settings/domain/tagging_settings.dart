import 'package:tgsorter/app/models/tag_config.dart';

class TaggingSettings {
  const TaggingSettings({required this.sourceChatId, required this.groups});

  final int? sourceChatId;
  final List<TagGroupConfig> groups;

  TagGroupConfig get defaultGroup {
    for (final group in groups) {
      if (group.key == TagGroupConfig.defaultGroupKey) {
        return group;
      }
    }
    return TagGroupConfig.emptyDefault;
  }
}
