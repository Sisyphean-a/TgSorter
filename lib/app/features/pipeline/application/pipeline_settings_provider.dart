import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';

abstract class PipelineSettingsProvider implements PipelineSettingsReader {
  @override
  Rx<AppSettings> get settingsStream;

  @override
  AppSettings get currentSettings;

  @override
  CategoryConfig getCategory(String key);
}
