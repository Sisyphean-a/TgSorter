import 'package:get/get.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';

abstract class PipelineSettingsProvider {
  Rx<AppSettings> get settingsStream;
  AppSettings get currentSettings;
  CategoryConfig getCategory(String key);
}
