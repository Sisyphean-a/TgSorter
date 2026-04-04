import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_restart_policy.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

class SettingsPersistenceService {
  SettingsPersistenceService(
    this._repository, {
    SettingsRestartPolicy? restartPolicy,
  }) : _restartPolicy = restartPolicy ?? SettingsRestartPolicy();

  final SettingsRepository _repository;
  final SettingsRestartPolicy _restartPolicy;

  AppSettings load() => _repository.load();

  Future<bool> saveDraft(SettingsDraftCoordinator draft) async {
    final previous = draft.saved.value;
    final next = draft.draft.value;
    final shouldRestart = _restartPolicy.shouldRestart(previous, next);
    await _repository.save(next);
    draft.commit();
    return shouldRestart;
  }
}
