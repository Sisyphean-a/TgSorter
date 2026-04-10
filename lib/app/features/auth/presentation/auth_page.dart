import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_error_panel.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';

part 'auth_proxy_config_card.dart';
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
  late final TextEditingController _proxyServerCtrl;
  late final TextEditingController _proxyPortCtrl;
  late final TextEditingController _proxyUsernameCtrl;
  late final TextEditingController _proxyPasswordCtrl;

  @override
  void initState() {
    super.initState();
    final proxy = _auth.currentProxySettings;
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
        appBar: const _AuthCompactAppBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final content = [
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
            final pagePadding = wide ? AppTokens.spaceLg : AppTokens.spaceSm;
            final sectionGap = wide ? AppTokens.spaceMd : AppTokens.spaceSm;
            return ListView(
              padding: EdgeInsets.all(pagePadding),
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
                  ..._stackedSections(content, sectionGap),
              ],
            );
          },
        ),
      );
    });
  }

  List<Widget> _stackedSections(List<Widget> content, double sectionGap) {
    return [content.first, SizedBox(height: sectionGap), content.last];
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
