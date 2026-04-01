import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';

class AuthPage extends StatelessWidget {
  AuthPage({super.key});

  final AuthController controller = Get.find<AuthController>();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TgSorter 登录')),
      body: Obx(() {
        final stage = controller.stage.value;
        final isLoading = controller.loading.value;
        final startupError = controller.startupError.value;
        final errorHistory = controller.errorHistory;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '使用 TDLib Userbot 登录 Telegram',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              if (startupError != null) ...[
                Text(
                  startupError,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 12),
              ],
              if (errorHistory.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '错误历史',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.clearErrorHistory,
                      child: const Text('清空'),
                    ),
                  ],
                ),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ListView.separated(
                    itemCount: errorHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, index) => SelectableText(
                      errorHistory[index],
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (stage == AuthStage.waitPhone) ...[
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: '手机号（含国家码）'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => controller.submitPhone(phoneCtrl.text),
                  child: const Text('发送验证码'),
                ),
              ] else if (stage == AuthStage.waitCode) ...[
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: '验证码'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => controller.submitCode(codeCtrl.text),
                  child: const Text('提交验证码'),
                ),
              ] else if (stage == AuthStage.waitPassword) ...[
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: '两步验证密码'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => controller.submitPassword(passwordCtrl.text),
                  child: const Text('提交密码'),
                ),
              ] else ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Text('等待 TDLib 授权状态...'),
              ],
            ],
          ),
        );
      }),
    );
  }
}
