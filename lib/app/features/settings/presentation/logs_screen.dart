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
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      children: [
        _LogsHeader(filter: _selectedFilter, onChanged: _updateFilter),
        const SizedBox(height: AppTokens.spaceLg),
        if (visibleChains.isEmpty)
          const _LogsEmptyState()
        else
          for (final chain in visibleChains) ...[
            _PipelineLogChainCard(chain: chain),
            const SizedBox(height: AppTokens.spaceMd),
          ],
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
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppTokens.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '操作日志',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Text('按消息分类链路查看失败、重试和最终结果。', style: subtitleStyle),
        const SizedBox(height: AppTokens.spaceLg),
        Wrap(
          spacing: AppTokens.spaceSm,
          runSpacing: AppTokens.spaceSm,
          children: PipelineLogFilter.values
              .map(
                (item) => ChoiceChip(
                  key: ValueKey('log-filter-${item.name}'),
                  label: Text(_filterLabel(item)),
                  selected: filter == item,
                  onSelected: (_) => onChanged(item),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _LogsEmptyState extends StatelessWidget {
  const _LogsEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppTokens.spaceLg),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '消息 #${chain.messageId}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StateBadge(label: chain.statusLabel, state: chain.state),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              '分类 ${chain.categoryKey} -> ${chain.targetChatId}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTokens.textMuted),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            for (final event in chain.events) ...[
              _PipelineLogEventRow(event: event),
              const SizedBox(height: AppTokens.spaceSm),
            ],
          ],
        ),
      ),
    );
  }
}

class _PipelineLogEventRow extends StatelessWidget {
  const _PipelineLogEventRow({required this.event});

  final PipelineLogEventViewModel event;

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(event.timestamp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$time ${event.statusLabel}'),
        if (event.reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '原因：${event.reason}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTokens.danger),
            ),
          ),
      ],
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label, required this.state});

  final String label;
  final PipelineLogChainState state;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _badgeColor(state),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label),
      ),
    );
  }

  Color _badgeColor(PipelineLogChainState value) {
    switch (value) {
      case PipelineLogChainState.failedInProgress:
        return AppTokens.danger.withValues(alpha: 0.18);
      case PipelineLogChainState.recovered:
        return AppTokens.brandAccentSoft;
      case PipelineLogChainState.skippedOrUndone:
        return AppTokens.surfaceBase;
      case PipelineLogChainState.completed:
        return AppTokens.surfaceBase;
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
