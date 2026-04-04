import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

class SettingsPersistenceService {
  SettingsPersistenceService(this._repository);

  final SettingsRepository _repository;

  AppSettings load() => _repository.load();

  Future<void> save(AppSettings next) async {
    await _repository.save(next);
  }
}
