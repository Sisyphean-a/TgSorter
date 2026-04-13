import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/application/settings_page_draft_session.dart';
import 'package:tgsorter/app/models/app_settings.dart';

void main() {
  test('页面草稿从已保存设置派生且放弃后恢复原值', () {
    final session = SettingsPageDraftSession();
    final saved = AppSettings.defaults();

    session.open(route: SettingsRoute.forwarding, savedSettings: saved);
    session.updateFetchDirection(MessageFetchDirection.oldestFirst);

    expect(session.savedSettings.value.fetchDirection, MessageFetchDirection.latestFirst);
    expect(session.draftSettings.value.fetchDirection, MessageFetchDirection.oldestFirst);
    expect(session.isDirty.value, isTrue);

    session.discard();

    expect(session.draftSettings.value.fetchDirection, MessageFetchDirection.latestFirst);
    expect(session.isDirty.value, isFalse);
  });
}
