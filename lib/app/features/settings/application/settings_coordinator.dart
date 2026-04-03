import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

import 'session_query_gateway.dart';

class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(this._repository, this._sessions);

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;

  @override
  Rx<AppSettings> get settingsStream => throw UnimplementedError();

  @override
  AppSettings get currentSettings => throw UnimplementedError();

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();
}
