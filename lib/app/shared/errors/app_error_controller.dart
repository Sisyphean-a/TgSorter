import 'package:get/get.dart';

import 'app_error_event.dart';

class AppErrorController extends GetxController {
  final currentError = RxnString();
  final errorHistory = <String>[].obs;

  final structuredCurrentError = Rxn<AppErrorEvent>();
  final structuredErrorHistory = <AppErrorEvent>[].obs;

  void reportEvent(AppErrorEvent event) {
    structuredCurrentError.value = event;
    structuredErrorHistory.insert(0, event);
    final formatted = formatAppErrorEvent(event);
    currentError.value = formatted;
    errorHistory.insert(0, formatted);
  }

  void report({
    required String title,
    required String message,
    AppErrorScope scope = AppErrorScope.runtime,
    AppErrorLevel level = AppErrorLevel.error,
  }) {
    reportEvent(
      AppErrorEvent(
        scope: scope,
        level: level,
        title: title,
        message: message,
      ),
    );
  }

  void clearCurrent() {
    structuredCurrentError.value = null;
    currentError.value = null;
  }

  void clear() {
    clearCurrent();
    structuredErrorHistory.clear();
    errorHistory.clear();
  }
}
