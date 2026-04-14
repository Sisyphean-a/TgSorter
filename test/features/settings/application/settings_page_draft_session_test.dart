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

    expect(
      session.savedSettings.value.fetchDirection,
      MessageFetchDirection.latestFirst,
    );
    expect(
      session.draftSettings.value.fetchDirection,
      MessageFetchDirection.oldestFirst,
    );
    expect(session.isDirty.value, isTrue);

    session.discard();

    expect(
      session.draftSettings.value.fetchDirection,
      MessageFetchDirection.latestFirst,
    );
    expect(session.isDirty.value, isFalse);
  });

  test('页面草稿遇到非法数值输入时抛出显式错误而不是静默纠正', () {
    final session = SettingsPageDraftSession();
    final saved = AppSettings.defaults();

    session.open(route: SettingsRoute.forwarding, savedSettings: saved);

    expect(
      () => session.updateBatchOptions(batchSize: 0, throttleMs: -1),
      throwsArgumentError,
    );
    expect(session.draftSettings.value.batchSize, saved.batchSize);
    expect(session.draftSettings.value.throttleMs, saved.throttleMs);

    expect(
      () => session.updateMediaLoadOptions(
        backgroundConcurrency: 0,
        retryLimit: -1,
        retryDelayMs: -1,
      ),
      throwsArgumentError,
    );
    expect(
      session.draftSettings.value.mediaBackgroundDownloadConcurrency,
      saved.mediaBackgroundDownloadConcurrency,
    );
    expect(session.draftSettings.value.mediaRetryLimit, saved.mediaRetryLimit);
    expect(
      session.draftSettings.value.mediaRetryDelayMs,
      saved.mediaRetryDelayMs,
    );

    session.open(route: SettingsRoute.connection, savedSettings: saved);

    expect(
      () => session.updateProxy(
        server: '127.0.0.1',
        port: 'abc',
        username: '',
        password: '',
      ),
      throwsArgumentError,
    );
    expect(session.draftSettings.value.proxy, saved.proxy);
  });

  test('页面草稿可以单独更新媒体加载参数', () {
    final session = SettingsPageDraftSession();
    final saved = AppSettings.defaults();

    session.open(route: SettingsRoute.forwarding, savedSettings: saved);
    session.updateMediaLoadOptions(
      backgroundConcurrency: 3,
      retryLimit: 2,
      retryDelayMs: 800,
    );

    expect(session.isDirty.value, isTrue);
    expect(session.draftSettings.value.mediaBackgroundDownloadConcurrency, 3);
    expect(session.draftSettings.value.mediaRetryLimit, 2);
    expect(session.draftSettings.value.mediaRetryDelayMs, 800);
  });
}
