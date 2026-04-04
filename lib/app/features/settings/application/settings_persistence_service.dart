import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

class SettingsPersistenceService {
  SettingsPersistenceService(this._repository);

  final SettingsRepository _repository;

  AppSettings load() => _repository.load();

  Future<void> saveDraft(SettingsDraftCoordinator draft) async {
    final next = draft.draft.value;
    await _repository.save(next);
    draft.commit();
  }
}
