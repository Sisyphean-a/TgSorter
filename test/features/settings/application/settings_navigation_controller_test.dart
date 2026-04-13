import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';

void main() {
  test('默认停留在首页并支持进入详情页后返回', () {
    final controller = SettingsNavigationController();

    expect(controller.currentRoute.value, SettingsRoute.home);
    expect(controller.currentTitle, '设置');
    expect(controller.canPop.value, isFalse);

    controller.goTo(SettingsRoute.forwarding);

    expect(controller.currentRoute.value, SettingsRoute.forwarding);
    expect(controller.currentTitle, '转发');
    expect(controller.canPop.value, isTrue);

    controller.backToHome();

    expect(controller.currentRoute.value, SettingsRoute.home);
    expect(controller.currentTitle, '设置');
    expect(controller.canPop.value, isFalse);
  });
}
