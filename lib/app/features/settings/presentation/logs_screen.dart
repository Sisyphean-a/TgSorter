import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/shared/presentation/formatters/pipeline_log_formatter.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({this.pipeline, super.key});

  final PipelineLogsPort? pipeline;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  PipelineLogFilter _selectedFilter = PipelineLogFilter.all;

  @override
  Widget build(BuildContext context) {
    final chains = buildPipelineLogChains(
      widget.pipeline?.logsSnapshot ?? const [],
    );
    final visibleChains = filterPipelineLogChains(chains, _selectedFilter);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceSm,
        AppTokens.spaceSm,
        AppTokens.spaceSm,
        AppTokens.spaceMd,
      ),
      children: [
        _LogsHeader(filter: _selectedFilter, onChanged: _updateFilter),
        const SizedBox(height: AppTokens.spaceXs),
        if (visibleChains.isEmpty)
          const _LogsEmptyState()
        else
          for (final chain in visibleChains)
            _PipelineLogChainCard(chain: chain),
      ],
    );
  }

  void _updateFilter(PipelineLogFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }
}

class _LogsHeader extends StatelessWidget {
  const _LogsHeader({required this.filter, required this.onChanged});

  final PipelineLogFilter filter;
  final ValueChanged<PipelineLogFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('logs-filter-bar'),
      spacing: AppTokens.spaceXs,
      runSpacing: AppTokens.spaceXs,
      children: [
        for (final item in PipelineLogFilter.values)
          ChoiceChip(
            key: ValueKey('log-filter-${item.name}'),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(_filterLabel(item)),
            selected: filter == item,
            onSelected: (_) => onChanged(item),
          ),
      ],
    );
  }
}

class _LogsEmptyState extends StatelessWidget {
  const _LogsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('logs-empty-state'),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppTokens.spaceLg,
          horizontal: AppTokens.spaceXs,
        ),
        child: Text('当前筛选下没有匹配记录。'),
      ),
    );
  }
}

class _PipelineLogChainCard extends StatelessWidget {
  const _PipelineLogChainCard({required this.chain});

  final PipelineLogChainViewModel chain;

  @override
  Widget build(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    final textTheme = Theme.of(context).textTheme;
    final timelineText = _buildTimelineText(chain.events);
    return Container(
      key: Key('log-chain-row-${chain.chainKey}'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatTime(chain.lastOccurredAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Expanded(
                  child: Text(
                    '消息 #${chain.messageId}',
                    style: textTheme.titleSmall,
                  ),
                ),
                _StateBadge(label: chain.statusLabel, state: chain.state),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '分类 ${chain.categoryKey} -> ${chain.targetChatId} · ${chain.summaryLabel}',
              style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
            if (chain.latestReason != null) ...[
              const SizedBox(height: 2),
              Text(
                '最近失败：${chain.latestReason}',
                style: textTheme.bodySmall?.copyWith(color: colors.danger),
              ),
            ],
            if (timelineText != null) ...[
              const SizedBox(height: 2),
              Text(
                timelineText,
                style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _buildTimelineText(List<PipelineLogEventViewModel> events) {
    if (events.isEmpty) {
      return null;
    }
    return events
        .map((event) => '${_formatTime(event.timestamp)} ${event.statusLabel}')
        .join('  ·  ');
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label, required this.state});

  final String label;
  final PipelineLogChainState state;

  @override
  Widget build(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _badgeColor(colors, state),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label),
      ),
    );
  }

  Color _badgeColor(AppColorPalette colors, PipelineLogChainState value) {
    switch (value) {
      case PipelineLogChainState.failedInProgress:
        return colors.danger.withValues(alpha: 0.18);
      case PipelineLogChainState.recovered:
        return colors.brandAccentSoft;
      case PipelineLogChainState.skippedOrUndone:
        return colors.surfaceBase;
      case PipelineLogChainState.completed:
        return colors.surfaceBase;
    }
  }
}

String _formatTime(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  final ss = value.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

String _filterLabel(PipelineLogFilter filter) {
  switch (filter) {
    case PipelineLogFilter.all:
      return '全部';
    case PipelineLogFilter.failedInProgress:
      return '失败中';
    case PipelineLogFilter.recovered:
      return '已恢复';
    case PipelineLogFilter.skippedOrUndone:
      return '已跳过/已撤销';
  }
}
