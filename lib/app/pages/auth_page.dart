import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/widgets/app_error_panel.dart';
import 'package:tgsorter/app/widgets/app_shell.dart';
import 'package:tgsorter/app/widgets/brand_app_bar.dart';
import 'package:tgsorter/app/widgets/status_badge.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AuthController _auth = Get.find<AuthController>();
  final AppErrorController _errors = Get.find<AppErrorController>();
  final SettingsController _settings = Get.find<SettingsController>();

  late final TextEditingController _phoneCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _proxyServerCtrl;
  late final TextEditingController _proxyPortCtrl;
  late final TextEditingController _proxyUsernameCtrl;
  late final TextEditingController _proxyPasswordCtrl;

  @override
  void initState() {
    super.initState();
    final proxy = _settings.settings.value.proxy;
    _phoneCtrl = TextEditingController();
    _codeCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _proxyServerCtrl = TextEditingController(text: proxy.server);
    _proxyPortCtrl = TextEditingController(text: proxy.port?.toString() ?? '');
    _proxyUsernameCtrl = TextEditingController(text: proxy.username);
    _proxyPasswordCtrl = TextEditingController(text: proxy.password);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _proxyServerCtrl.dispose();
    _proxyPortCtrl.dispose();
    _proxyUsernameCtrl.dispose();
    _proxyPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stage = _auth.stage.value;
      final isLoading = _auth.loading.value;
      return AppShell(
        appBar: BrandAppBar(
          title: 'TgSorter',
          subtitle: '安全登录',
          badges: [
            StatusBadge(label: _stageLabel(stage), tone: _stageTone(stage)),
            StatusBadge(
              label: isLoading ? '提交中' : '等待操作',
              tone: isLoading
                  ? StatusBadgeTone.warning
                  : StatusBadgeTone.neutral,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final content = [
              _AuthIntroCard(
                stage: stage,
                isLoading: isLoading,
                child: AnimatedSwitcher(
                  duration: AppTokens.medium,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _AuthStageCard(
                    key: ValueKey(stage),
                    stage: stage,
                    isLoading: isLoading,
                    phoneCtrl: _phoneCtrl,
                    codeCtrl: _codeCtrl,
                    passwordCtrl: _passwordCtrl,
                    auth: _auth,
                  ),
                ),
              ),
              _ProxyConfigCard(
                serverCtrl: _proxyServerCtrl,
                portCtrl: _proxyPortCtrl,
                usernameCtrl: _proxyUsernameCtrl,
                passwordCtrl: _proxyPasswordCtrl,
                loading: isLoading,
                onSaveAndRetry: () => _auth.saveProxyAndRetry(
                  server: _proxyServerCtrl.text,
                  port: _proxyPortCtrl.text,
                  username: _proxyUsernameCtrl.text,
                  password: _proxyPasswordCtrl.text,
                ),
              ),
            ];
            return ListView(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              children: [
                AppErrorPanel(controller: _errors),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: content.first),
                      const SizedBox(width: AppTokens.spaceMd),
                      Expanded(child: content.last),
                    ],
                  )
                else
                  ..._stackedSections(content),
              ],
            );
          },
        ),
      );
    });
  }

  List<Widget> _stackedSections(List<Widget> content) {
    return [
      content.first,
      const SizedBox(height: AppTokens.spaceMd),
      content.last,
    ];
  }

  String _stageLabel(AuthStage stage) {
    switch (stage) {
      case AuthStage.waitPhone:
        return '等待手机号';
      case AuthStage.waitCode:
        return '等待验证码';
      case AuthStage.waitPassword:
        return '等待密码';
      case AuthStage.ready:
        return '已就绪';
      case AuthStage.unsupported:
        return '状态未知';
      case AuthStage.loading:
        return '连接中';
    }
  }

  StatusBadgeTone _stageTone(AuthStage stage) {
    switch (stage) {
      case AuthStage.waitPhone:
      case AuthStage.waitCode:
      case AuthStage.waitPassword:
        return StatusBadgeTone.accent;
      case AuthStage.ready:
        return StatusBadgeTone.success;
      case AuthStage.unsupported:
        return StatusBadgeTone.danger;
      case AuthStage.loading:
        return StatusBadgeTone.warning;
    }
  }
}

class _AuthIntroCard extends StatelessWidget {
  const _AuthIntroCard({
    required this.stage,
    required this.isLoading,
    required this.child,
  });

  final AuthStage stage;
  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AuthPanel(
      title: '使用 TDLib Userbot 登录 Telegram',
      subtitle: '登录流程保持简洁，代理与验证码操作集中在同一页面。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTokens.brandAccentSoft,
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              border: Border.all(color: AppTokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: AppTokens.spaceSm),
                  Expanded(
                    child: Text(
                      _helperText(stage, isLoading),
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          child,
        ],
      ),
    );
  }

  String _helperText(AuthStage stage, bool isLoading) {
    if (isLoading) {
      return '正在与 TDLib 同步状态，请保持当前页面开启。';
    }
    switch (stage) {
      case AuthStage.waitPhone:
        return '先输入带国家码的手机号，验证码会发送到 Telegram 官方客户端。';
      case AuthStage.waitCode:
        return '输入收到的验证码，提交后会自动继续下一步。';
      case AuthStage.waitPassword:
        return '如果账号开启了两步验证，这里继续输入密码完成登录。';
      case AuthStage.ready:
        return '授权完成后会自动跳转到分类工作台。';
      case AuthStage.unsupported:
        return '当前授权状态暂未识别，请查看错误面板确认原因。';
      case AuthStage.loading:
        return '等待 TDLib 返回授权阶段，页面会自动更新。';
    }
  }
}

class _AuthStageCard extends StatelessWidget {
  const _AuthStageCard({
    super.key,
    required this.stage,
    required this.isLoading,
    required this.phoneCtrl,
    required this.codeCtrl,
    required this.passwordCtrl,
    required this.auth,
  });

  final AuthStage stage;
  final bool isLoading;
  final TextEditingController phoneCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController passwordCtrl;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return _AuthPanel(
      title: _titleFor(stage),
      subtitle: _subtitleFor(stage),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (stage) {
      case AuthStage.waitPhone:
        return _AuthActionColumn(
          field: TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(labelText: '手机号（含国家码）'),
          ),
          buttonLabel: '发送验证码',
          onPressed: isLoading ? null : () => auth.submitPhone(phoneCtrl.text),
        );
      case AuthStage.waitCode:
        return _AuthActionColumn(
          field: TextField(
            controller: codeCtrl,
            decoration: const InputDecoration(labelText: '验证码'),
          ),
          buttonLabel: '提交验证码',
          onPressed: isLoading ? null : () => auth.submitCode(codeCtrl.text),
        );
      case AuthStage.waitPassword:
        return _AuthActionColumn(
          field: TextField(
            controller: passwordCtrl,
            decoration: const InputDecoration(labelText: '两步验证密码'),
            obscureText: true,
          ),
          buttonLabel: '提交密码',
          onPressed: isLoading
              ? null
              : () => auth.submitPassword(passwordCtrl.text),
        );
      case AuthStage.ready:
      case AuthStage.unsupported:
      case AuthStage.loading:
        return const _AuthLoadingState();
    }
  }

  String _titleFor(AuthStage stage) {
    switch (stage) {
      case AuthStage.waitPhone:
        return '手机号登录';
      case AuthStage.waitCode:
        return '输入验证码';
      case AuthStage.waitPassword:
        return '输入两步验证密码';
      case AuthStage.ready:
        return '连接状态';
      case AuthStage.unsupported:
        return '授权状态';
      case AuthStage.loading:
        return '连接状态';
    }
  }

  String _subtitleFor(AuthStage stage) {
    switch (stage) {
      case AuthStage.waitPhone:
        return '先完成手机号验证，再进入后续授权。';
      case AuthStage.waitCode:
        return '验证码通常来自 Telegram 官方客户端。';
      case AuthStage.waitPassword:
        return '仅在账号开启两步验证时需要。';
      case AuthStage.ready:
        return '授权完成后会自动跳转。';
      case AuthStage.unsupported:
        return '当前状态不在预期流程内。';
      case AuthStage.loading:
        return '等待 TDLib 授权状态...';
    }
  }
}

class _ProxyConfigCard extends StatelessWidget {
  const _ProxyConfigCard({
    required this.serverCtrl,
    required this.portCtrl,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.onSaveAndRetry,
  });

  final TextEditingController serverCtrl;
  final TextEditingController portCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final Future<void> Function() onSaveAndRetry;

  @override
  Widget build(BuildContext context) {
    return _AuthPanel(
      title: '代理配置',
      subtitle: '当网络受限或连接异常时，先更新代理再重试启动。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: serverCtrl,
            decoration: const InputDecoration(labelText: '代理服务器'),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          TextField(
            controller: portCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '代理端口'),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          TextField(
            controller: usernameCtrl,
            decoration: const InputDecoration(labelText: '代理用户名（可选）'),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          TextField(
            controller: passwordCtrl,
            decoration: const InputDecoration(labelText: '代理密码（可选）'),
            obscureText: true,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          FilledButton.icon(
            onPressed: loading ? null : onSaveAndRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('保存代理并重试启动'),
          ),
        ],
      ),
    );
  }
}

class _AuthActionColumn extends StatelessWidget {
  const _AuthActionColumn({
    required this.field,
    required this.buttonLabel,
    required this.onPressed,
  });

  final Widget field;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: AppTokens.spaceMd),
        FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
      ],
    );
  }
}

class _AuthLoadingState extends StatelessWidget {
  const _AuthLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(),
        SizedBox(height: AppTokens.spaceMd),
        Text('等待 TDLib 授权状态...'),
      ],
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTokens.textMuted,
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            child,
          ],
        ),
      ),
    );
  }
}
