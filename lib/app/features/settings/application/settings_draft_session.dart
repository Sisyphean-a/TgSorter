import 'package:get/get.dart';
import 'package:tgsorter/app/models/app_settings.dart';

class SettingsDraftSession {
  SettingsDraftSession(AppSettings initial)
    : saved = initial.obs,
      draft = initial.obs,
      isDirty = false.obs;

  final Rx<AppSettings> saved;
  final Rx<AppSettings> draft;
  final RxBool isDirty;

  void replace(AppSettings next) {
    saved.value = next;
    draft.value = next;
    isDirty.value = false;
  }

  void update(AppSettings next) {
    draft.value = next;
    isDirty.value = draft.value != saved.value;
  }

  void discard() {
    draft.value = saved.value;
    isDirty.value = false;
  }

  void commit() {
    saved.value = draft.value;
    isDirty.value = false;
  }
}
