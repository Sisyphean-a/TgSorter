import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';

class AuthPage extends StatelessWidget {
  AuthPage({super.key});

  final AuthController controller = Get.find<AuthController>();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TgSorter 登录')),
      body: Obx(() {
        final stage = controller.stage.value;
        final isLoading = controller.loading.value;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('使用 TDLib Userbot 登录 Telegram', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              if (stage == AuthStage.waitPhone) ...[
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: '手机号（含国家码）'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : () => controller.submitPhone(phoneCtrl.text),
                  child: const Text('发送验证码'),
                ),
              ] else if (stage == AuthStage.waitCode) ...[
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: '验证码'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : () => controller.submitCode(codeCtrl.text),
                  child: const Text('提交验证码'),
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
