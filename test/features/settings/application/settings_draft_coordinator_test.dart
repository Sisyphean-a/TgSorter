import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/models/app_settings.dart';

void main() {
  test('update marks draft dirty until discard', () {
    final coordinator = SettingsDraftCoordinator(AppSettings.defaults());

    coordinator.update(coordinator.draft.value.updateForwardAsCopy(true));

    expect(coordinator.isDirty.value, isTrue);
    coordinator.discard();
    expect(coordinator.isDirty.value, isFalse);
  });

  test('replace and commit keep saved and draft aligned', () {
    final coordinator = SettingsDraftCoordinator(AppSettings.defaults());
    final loaded = AppSettings.defaults().updateForwardAsCopy(true);

    coordinator.replace(loaded);
    coordinator.update(
      loaded.updateBatchOptions(batchSize: 9, throttleMs: 800),
    );
    coordinator.commit();

    expect(coordinator.saved.value, coordinator.draft.value);
    expect(coordinator.saved.value.batchSize, 9);
    expect(coordinator.isDirty.value, isFalse);
  });
}
