part of 'auth_page.dart';

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
  final AuthCoordinator auth;

  @override
  Widget build(BuildContext context) {
    return _buildBody();
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
