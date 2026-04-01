import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/widgets/app_error_panel.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('TgSorter 登录')),
      body: Obx(() {
        final stage = _auth.stage.value;
        final isLoading = _auth.loading.value;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('使用 TDLib Userbot 登录 Telegram', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            AppErrorPanel(controller: _errors),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            _buildAuthSection(stage, isLoading),
          ],
        );
      }),
    );
  }

  Widget _buildAuthSection(AuthStage stage, bool isLoading) {
    if (stage == AuthStage.waitPhone) {
      return _ActionCard(
        title: '手机号登录',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: '手机号（含国家码）'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : () => _auth.submitPhone(_phoneCtrl.text),
              child: const Text('发送验证码'),
            ),
          ],
        ),
      );
    }
    if (stage == AuthStage.waitCode) {
      return _ActionCard(
        title: '输入验证码',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: '验证码'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : () => _auth.submitCode(_codeCtrl.text),
              child: const Text('提交验证码'),
            ),
          ],
        ),
      );
    }
    if (stage == AuthStage.waitPassword) {
      return _ActionCard(
        title: '输入两步验证密码',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: '两步验证密码'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : () => _auth.submitPassword(_passwordCtrl.text),
              child: const Text('提交密码'),
            ),
          ],
        ),
      );
    }
    return const _ActionCard(
      title: '连接状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 12),
          Text('等待 TDLib 授权状态...'),
        ],
      ),
    );
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
    return _ActionCard(
      title: '代理配置',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: serverCtrl,
            decoration: const InputDecoration(labelText: '代理服务器'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: portCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '代理端口'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: usernameCtrl,
            decoration: const InputDecoration(labelText: '代理用户名（可选）'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordCtrl,
            decoration: const InputDecoration(labelText: '代理密码（可选）'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading ? null : onSaveAndRetry,
            child: const Text('保存代理并重试启动'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
