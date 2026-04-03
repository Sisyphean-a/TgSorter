import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

import 'session_query_gateway.dart';

class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(this._repository, this._sessions);

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;
  final Rx<AppSettings> _settings = AppSettings.defaults().obs;

  @override
  Rx<AppSettings> get settingsStream => _settings;

  @override
  AppSettings get currentSettings => _settings.value;

  @override
  void onInit() {
    super.onInit();
    _settings.value = _repository.load();
  }

  @override
  CategoryConfig getCategory(String key) {
    return _settings.value.categories.firstWhere((item) => item.key == key);
  }

  Future<List<SelectableChat>> listSelectableChats() {
    return _sessions.listSelectableChats();
  }
}
