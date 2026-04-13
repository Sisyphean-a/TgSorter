import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';

void main() {
  test('默认停留在首页并支持进入详情页后返回', () {
    final controller = SettingsNavigationController();

    expect(controller.currentRoute.value, SettingsRoute.home);
    expect(controller.currentTitle, '设置');
    expect(controller.canPop.value, isFalse);

    controller.goTo(SettingsRoute.common);

    expect(controller.currentRoute.value, SettingsRoute.common);
    expect(controller.currentTitle, '通用');
    expect(controller.canPop.value, isTrue);

    controller.backToHome();

    expect(controller.currentRoute.value, SettingsRoute.home);
    expect(controller.currentTitle, '设置');
    expect(controller.canPop.value, isFalse);
  });

  test('账号与会话页提供独立标题', () {
    final controller = SettingsNavigationController();

    controller.goTo(SettingsRoute.accountSession);

    expect(controller.currentTitle, '账号与会话');
    expect(controller.canPop.value, isTrue);
  });
}
