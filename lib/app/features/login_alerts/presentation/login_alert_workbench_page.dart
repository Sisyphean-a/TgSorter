import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/login_alerts/application/login_alert_workbench_controller.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class LoginAlertWorkbenchPage extends StatelessWidget {
  const LoginAlertWorkbenchPage({required this.controller, super.key});

  final LoginAlertWorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final colors = AppTokens.colorsOf(context);
      final entries = controller.entries;
      return ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          Text(
            '接码',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            '集中显示 Telegram 官方 777000 的验证码和新登录提醒，避免只在日志里一闪而过。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          if (entries.isEmpty)
            _EmptyState(colors: colors)
          else
            for (final item in entries) ...[
              _AlertCard(item: item),
              const SizedBox(height: AppTokens.spaceSm),
            ],
        ],
      );
    });
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final AppColorPalette colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Text(
          '当前还没有捕获到 777000 登录提醒。保持账号在线后，新设备发起登录会自动记录到这里。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.item});

  final TelegramLoginAlert item;

  @override
  Widget build(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _timeText(item.receivedAtMs),
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                _StatusChip(status: item.status),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              item.sourceLabel,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            if (item.kind == TelegramLoginAlertKind.code) ...[
              Text(
                item.code ?? '未识别验证码',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Text(item.text, style: textTheme.bodySmall),
            ] else ...[
              Text(
                item.deviceSummary ?? '新设备登录',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.location != null) ...[
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  item.location!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.spaceXs),
              Text(item.text, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  String _timeText(int value) {
    final dt = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TelegramLoginAlertStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    final background = switch (status) {
      TelegramLoginAlertStatus.active => colors.brandAccentSoft,
      TelegramLoginAlertStatus.used => colors.success.withValues(alpha: 0.16),
      TelegramLoginAlertStatus.expired => colors.warning.withValues(
        alpha: 0.16,
      ),
      TelegramLoginAlertStatus.info => colors.surfaceRaised,
    };
    final foreground = switch (status) {
      TelegramLoginAlertStatus.active => colors.brandAccent,
      TelegramLoginAlertStatus.used => colors.success,
      TelegramLoginAlertStatus.expired => colors.warning,
      TelegramLoginAlertStatus.info => colors.textMuted,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          _labelOf(status),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _labelOf(TelegramLoginAlertStatus value) {
    switch (value) {
      case TelegramLoginAlertStatus.active:
        return '待使用';
      case TelegramLoginAlertStatus.used:
        return '已使用';
      case TelegramLoginAlertStatus.expired:
        return '已过期';
      case TelegramLoginAlertStatus.info:
        return '提醒';
    }
  }
}
