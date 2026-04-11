import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class PipelineRecoveryPanel extends StatelessWidget {
  const PipelineRecoveryPanel({super.key, required this.pipeline});

  final PipelineCoordinator pipeline;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = pipeline.pendingRecoveryTransactions;
      if (items.isEmpty) {
        return const SizedBox.shrink();
      }
      final colors = AppTokens.colorsOf(context);
      return Container(
        key: const Key('pipeline-recovery-panel'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.warning.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(pipeline: pipeline, count: items.length),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TransactionTile(pipeline: pipeline, item: item),
              ),
          ],
        ),
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pipeline, required this.count});

  final PipelineCoordinator pipeline;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 8,
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '待人工核查事务 ($count)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () =>
                  unawaited(pipeline.recheckPendingRecoveryTransactions()),
              child: const Text('重新检查'),
            ),
            FilledButton.tonal(
              onPressed: () => unawaited(
                pipeline.markAllPendingRecoveryTransactionsResolved(),
              ),
              child: const Text('全部标记已核查'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.pipeline, required this.item});

  final PipelineCoordinator pipeline;
  final ClassifyTransactionEntry item;

  @override
  Widget build(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '源消息 ${item.sourceMessageIds.join(", ")} -> 目标会话 ${item.targetChatId}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '状态：${_stageLabel(item.stage)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
            if (item.lastError case final text? when text.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => unawaited(
                  pipeline.markPendingRecoveryTransactionResolved(item.id),
                ),
                child: const Text('标记已核查'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stageLabel(ClassifyTransactionStage stage) {
    switch (stage) {
      case ClassifyTransactionStage.created:
        return '待确认';
      case ClassifyTransactionStage.forwardConfirmed:
        return '待补删源消息';
      case ClassifyTransactionStage.sourceDeleteConfirmed:
        return '已完成';
      case ClassifyTransactionStage.needsManualReview:
        return '需要人工核查';
    }
  }
}
