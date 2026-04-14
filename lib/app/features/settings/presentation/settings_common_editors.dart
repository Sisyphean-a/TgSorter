import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/application/settings_input_validator.dart';
import 'package:tgsorter/app/features/settings/domain/download_settings.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_dialogs.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

class SourceChatDraftEditor extends StatelessWidget {
  const SourceChatDraftEditor({
    super.key,
    required this.sourceChatId,
    required this.chats,
    required this.onChanged,
    this.label = '来源会话',
  });

  final int? sourceChatId;
  final List<SelectableChat> chats;
  final ValueChanged<int?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: label,
      value: _sourceLabel(sourceChatId, chats),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<int?>(
          context,
          title: label,
          selectedValue: sourceChatId,
          choices: [
            const SettingsChoice<int?>(
              value: null,
              label: '收藏夹（Saved Messages）',
            ),
            ...chats.map(
              (chat) => SettingsChoice<int?>(
                value: chat.id,
                label: chat.title,
              ),
            ),
          ],
        );
        if (selected == null && sourceChatId == null) {
          return;
        }
        onChanged(selected);
      },
    );
  }

  String _sourceLabel(int? sourceChatId, List<SelectableChat> chats) {
    if (sourceChatId == null) {
      return '收藏夹（Saved Messages）';
    }
    for (final chat in chats) {
      if (chat.id == sourceChatId) {
        return chat.title;
      }
    }
    return '未知会话';
  }
}

class FetchDirectionDraftEditor extends StatelessWidget {
  const FetchDirectionDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MessageFetchDirection value;
  final ValueChanged<MessageFetchDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: '消息拉取方向',
      value: _label(value),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<MessageFetchDirection>(
          context,
          title: '消息拉取方向',
          selectedValue: value,
          choices: const [
            SettingsChoice(
              value: MessageFetchDirection.latestFirst,
              label: '最新优先',
            ),
            SettingsChoice(
              value: MessageFetchDirection.oldestFirst,
              label: '最旧优先',
            ),
          ],
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  String _label(MessageFetchDirection value) {
    switch (value) {
      case MessageFetchDirection.latestFirst:
        return '最新优先';
      case MessageFetchDirection.oldestFirst:
        return '最旧优先';
    }
  }
}

class DefaultWorkbenchDraftEditor extends StatelessWidget {
  const DefaultWorkbenchDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AppDefaultWorkbench value;
  final ValueChanged<AppDefaultWorkbench> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: '首页默认工作台',
      value: _label(value),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<AppDefaultWorkbench>(
          context,
          title: '首页默认工作台',
          selectedValue: value,
          choices: const [
            SettingsChoice(
              value: AppDefaultWorkbench.forwarding,
              label: '转发工作台',
            ),
            SettingsChoice(
              value: AppDefaultWorkbench.tagging,
              label: '标签工作台',
            ),
          ],
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  String _label(AppDefaultWorkbench value) {
    switch (value) {
      case AppDefaultWorkbench.forwarding:
        return '转发工作台';
      case AppDefaultWorkbench.tagging:
        return '标签工作台';
    }
  }
}

class ForwardModeDraftEditor extends StatelessWidget {
  const ForwardModeDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      title: '无引用转发',
      subtitle: '开启后转发结果不携带原始引用关系',
      value: value,
      onChanged: onChanged,
    );
  }
}

class DownloadWorkbenchEnabledEditor extends StatelessWidget {
  const DownloadWorkbenchEnabledEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      title: '启用下载工作台',
      subtitle: '开启后在主导航中显示下载工作台入口',
      value: value,
      onChanged: onChanged,
    );
  }
}

class DownloadDirectoryModeEditor extends StatelessWidget {
  const DownloadDirectoryModeEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DownloadDirectoryMode value;
  final ValueChanged<DownloadDirectoryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: '目录映射规则',
      value: _label(value),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<DownloadDirectoryMode>(
          context,
          title: '目录映射规则',
          selectedValue: value,
          choices: const [
            SettingsChoice(
              value: DownloadDirectoryMode.byChat,
              label: '按会话分目录',
            ),
            SettingsChoice(
              value: DownloadDirectoryMode.flat,
              label: '平铺到目标目录',
            ),
          ],
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  String _label(DownloadDirectoryMode value) {
    switch (value) {
      case DownloadDirectoryMode.byChat:
        return '按会话分目录';
      case DownloadDirectoryMode.flat:
        return '平铺到目标目录';
    }
  }
}

class DownloadConflictStrategyEditor extends StatelessWidget {
  const DownloadConflictStrategyEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DownloadConflictStrategy value;
  final ValueChanged<DownloadConflictStrategy> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: '命名冲突处理',
      value: _label(value),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<DownloadConflictStrategy>(
          context,
          title: '命名冲突处理',
          selectedValue: value,
          choices: const [
            SettingsChoice(
              value: DownloadConflictStrategy.rename,
              label: '自动重命名',
            ),
            SettingsChoice(
              value: DownloadConflictStrategy.skip,
              label: '保留旧文件并跳过',
            ),
            SettingsChoice(
              value: DownloadConflictStrategy.overwrite,
              label: '覆盖旧文件',
            ),
          ],
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  String _label(DownloadConflictStrategy value) {
    switch (value) {
      case DownloadConflictStrategy.skip:
        return '保留旧文件并跳过';
      case DownloadConflictStrategy.rename:
        return '自动重命名';
      case DownloadConflictStrategy.overwrite:
        return '覆盖旧文件';
    }
  }
}

class DownloadMediaFilterEditor extends StatelessWidget {
  const DownloadMediaFilterEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DownloadMediaFilter value;
  final ValueChanged<DownloadMediaFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: '下载范围',
      value: _label(value),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<DownloadMediaFilter>(
          context,
          title: '下载范围',
          selectedValue: value,
          choices: const [
            SettingsChoice(
              value: DownloadMediaFilter.all,
              label: '全部支持的媒体',
            ),
            SettingsChoice(
              value: DownloadMediaFilter.photoOnly,
              label: '仅图片',
            ),
            SettingsChoice(
              value: DownloadMediaFilter.videoOnly,
              label: '仅视频',
            ),
            SettingsChoice(
              value: DownloadMediaFilter.audioOnly,
              label: '仅音频',
            ),
          ],
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  String _label(DownloadMediaFilter value) {
    switch (value) {
      case DownloadMediaFilter.all:
        return '全部支持的媒体';
      case DownloadMediaFilter.photoOnly:
        return '仅图片';
      case DownloadMediaFilter.videoOnly:
        return '仅视频';
      case DownloadMediaFilter.audioOnly:
        return '仅音频';
    }
  }
}

class DownloadSkipExistingFilesEditor extends StatelessWidget {
  const DownloadSkipExistingFilesEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      title: '已存在文件策略',
      subtitle: '开启后跳过已成功落盘的目标文件',
      value: value,
      onChanged: onChanged,
    );
  }
}

class DownloadSyncDeletedFilesEditor extends StatelessWidget {
  const DownloadSyncDeletedFilesEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSwitchTile(
      title: '同步删除本地文件',
      subtitle: '开启后会清理源消息已消失的本地落盘文件',
      value: value,
      onChanged: onChanged,
    );
  }
}

class BatchOptionsDraftEditor extends StatelessWidget {
  const BatchOptionsDraftEditor({
    super.key,
    required this.batchSize,
    required this.throttleMs,
    required this.onChanged,
    this.onValidationChanged,
  });

  final int batchSize;
  final int throttleMs;
  final void Function({required int batchSize, required int throttleMs})
  onChanged;
  final ValueChanged<bool>? onValidationChanged;

  @override
  Widget build(BuildContext context) {
    final validator = SettingsInputValidator();
    onValidationChanged?.call(false);
    return Column(
      children: [
        SettingsValueTile(
          title: '批处理条数 N',
          subtitle: '每次批量处理时选取的消息数量',
          value: '$batchSize',
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '批处理条数 N',
              label: '批处理条数 N',
              initialValue: '$batchSize',
              keyboardType: TextInputType.number,
              validator: validator.validateBatchSizeText,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(batchSize: int.parse(raw.trim()), throttleMs: throttleMs);
          },
        ),
        const SizedBox(height: 1),
        SettingsValueTile(
          title: '节流毫秒',
          subtitle: '批处理动作之间的等待间隔',
          value: '$throttleMs',
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '节流毫秒',
              label: '节流毫秒',
              initialValue: '$throttleMs',
              keyboardType: TextInputType.number,
              validator: validator.validateThrottleText,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(batchSize: batchSize, throttleMs: int.parse(raw.trim()));
          },
        ),
      ],
    );
  }
}

class PreviewPrefetchDraftEditor extends StatelessWidget {
  const PreviewPrefetchDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: '预加载后续预览',
      value: _label(value),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<int>(
          context,
          title: '预加载后续预览',
          selectedValue: value,
          choices: const [
            SettingsChoice(value: 0, label: '关闭'),
            SettingsChoice(value: 1, label: '1 条'),
            SettingsChoice(value: 3, label: '3 条'),
            SettingsChoice(value: 5, label: '5 条'),
          ],
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  String _label(int value) => value <= 0 ? '关闭' : '$value 条';
}

class MediaLoadOptionsDraftEditor extends StatelessWidget {
  const MediaLoadOptionsDraftEditor({
    super.key,
    required this.backgroundConcurrency,
    required this.retryLimit,
    required this.retryDelayMs,
    required this.onChanged,
    this.onValidationChanged,
  });

  final int backgroundConcurrency;
  final int retryLimit;
  final int retryDelayMs;
  final void Function({
    required int backgroundConcurrency,
    required int retryLimit,
    required int retryDelayMs,
  })
  onChanged;
  final ValueChanged<bool>? onValidationChanged;

  @override
  Widget build(BuildContext context) {
    final validator = SettingsInputValidator();
    onValidationChanged?.call(false);
    return Column(
      children: [
        SettingsValueTile(
          title: '媒体后台下载并发度',
          subtitle: '控制后续消息后台媒体准备可以并行多少项',
          value: '$backgroundConcurrency',
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '媒体后台下载并发度',
              label: '媒体后台下载并发度',
              initialValue: '$backgroundConcurrency',
              keyboardType: TextInputType.number,
              validator: validator.validateMediaBackgroundDownloadConcurrencyText,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(
              backgroundConcurrency: int.parse(raw.trim()),
              retryLimit: retryLimit,
              retryDelayMs: retryDelayMs,
            );
          },
        ),
        const SizedBox(height: 1),
        SettingsValueTile(
          title: '媒体自动重试次数',
          subtitle: '单个媒体失败后自动再尝试的最大次数',
          value: '$retryLimit',
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '媒体自动重试次数',
              label: '媒体自动重试次数',
              initialValue: '$retryLimit',
              keyboardType: TextInputType.number,
              validator: validator.validateMediaRetryLimitText,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(
              backgroundConcurrency: backgroundConcurrency,
              retryLimit: int.parse(raw.trim()),
              retryDelayMs: retryDelayMs,
            );
          },
        ),
        const SizedBox(height: 1),
        SettingsValueTile(
          title: '媒体重试间隔毫秒',
          subtitle: '自动重试之间的等待时间',
          value: '$retryDelayMs',
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '媒体重试间隔毫秒',
              label: '媒体重试间隔毫秒',
              initialValue: '$retryDelayMs',
              keyboardType: TextInputType.number,
              validator: validator.validateMediaRetryDelayText,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(
              backgroundConcurrency: backgroundConcurrency,
              retryLimit: retryLimit,
              retryDelayMs: int.parse(raw.trim()),
            );
          },
        ),
      ],
    );
  }
}

class ProxySettingsDraftEditor extends StatelessWidget {
  const ProxySettingsDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onValidationChanged,
  });

  final ProxySettings value;
  final void Function({
    required String server,
    required String port,
    required String username,
    required String password,
  })
  onChanged;
  final ValueChanged<bool>? onValidationChanged;

  @override
  Widget build(BuildContext context) {
    final validator = SettingsInputValidator();
    onValidationChanged?.call(false);
    return Column(
      children: [
        SettingsValueTile(
          title: '代理服务器',
          value: value.server.isEmpty ? '未设置' : value.server,
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '代理服务器',
              label: '代理服务器',
              initialValue: value.server,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(
              server: raw,
              port: value.port?.toString() ?? '',
              username: value.username,
              password: value.password,
            );
          },
        ),
        const SizedBox(height: 1),
        SettingsValueTile(
          title: '代理端口',
          value: value.port?.toString() ?? '未设置',
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '代理端口',
              label: '代理端口',
              initialValue: value.port?.toString() ?? '',
              keyboardType: TextInputType.number,
              validator: validator.validatePortText,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(
              server: value.server,
              port: raw,
              username: value.username,
              password: value.password,
            );
          },
        ),
        const SizedBox(height: 1),
        SettingsValueTile(
          title: '代理用户名',
          value: value.username.isEmpty ? '未设置' : value.username,
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '代理用户名',
              label: '代理用户名（可选）',
              initialValue: value.username,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(
              server: value.server,
              port: value.port?.toString() ?? '',
              username: raw,
              password: value.password,
            );
          },
        ),
        const SizedBox(height: 1),
        SettingsValueTile(
          title: '代理密码',
          value: value.password.isEmpty ? '未设置' : '已设置',
          onTap: () async {
            final raw = await showSettingsTextEditDialog(
              context,
              title: '代理密码',
              label: '代理密码（可选）',
              initialValue: value.password,
              obscureText: true,
            );
            if (raw == null || !context.mounted) {
              return;
            }
            onChanged(
              server: value.server,
              port: value.port?.toString() ?? '',
              username: value.username,
              password: raw,
            );
          },
        ),
      ],
    );
  }
}
