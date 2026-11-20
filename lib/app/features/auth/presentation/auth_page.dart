import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_error_panel.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';

part 'auth_stage_card.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({required this.auth, required this.errors, super.key});

  final AuthCoordinator auth;
  final AppErrorController errors;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthCoordinator get _auth => widget.auth;
  AppErrorController get _errors => widget.errors;

  late final TextEditingController _phoneCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _passwordCtrl;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController();
    _codeCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stage = _auth.stage.value;
      final isLoading = _auth.loading.value;
      final canRetry =
          stage == AuthStage.loading && _auth.startupError.value != null;
      return AppShell(
        appBar: const _AuthCompactAppBar(),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(AppTokens.spaceSm),
              children: [
                AppErrorPanel(controller: _errors),
                AnimatedSwitcher(
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
                if (canRetry) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  OutlinedButton(
                    onPressed: isLoading ? null : _auth.retryStartup,
                    child: const Text('重试连接'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _AuthCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AuthCompactAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    return Material(
      color: colors.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'TgSorter',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
