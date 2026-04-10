part of 'auth_page.dart';

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
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        '代理配置',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      children: [
        const SizedBox(height: AppTokens.spaceXs),
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
        const SizedBox(height: AppTokens.spaceSm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : onSaveAndRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('保存代理并重试启动'),
          ),
        ),
      ],
    );
  }
}
