import 'package:get/get.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

class SettingsController extends GetxController {
  SettingsController(this._repository);

  final SettingsRepository _repository;
  final Rx<AppSettings> settings = AppSettings.defaults().obs;

  @override
  void onInit() {
    super.onInit();
    settings.value = _repository.load();
  }

  CategoryConfig getCategory(String key) {
    return settings.value.categories.firstWhere((item) => item.key == key);
  }

  Future<void> saveCategory({
    required String key,
    required String name,
    required String chatIdRaw,
  }) async {
    final chatId = int.tryParse(chatIdRaw.trim());
    final updated = settings.value.updateCategory(
      CategoryConfig(
        key: key,
        name: name.trim().isEmpty ? '未命名分类' : name.trim(),
        targetChatId: chatId,
      ),
    );
    settings.value = updated;
    await _repository.save(updated);
  }
}
