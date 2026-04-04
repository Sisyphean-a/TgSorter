import 'package:get/get.dart';

import 'package:tgsorter/app/shared/errors/app_error_event.dart';

class AppErrorController extends GetxController {
  final currentError = RxnString();
  final errorHistory = <String>[].obs;

  final structuredCurrentError = Rxn<AppErrorEvent>();
  final structuredErrorHistory = <AppErrorEvent>[].obs;

  void reportEvent(AppErrorEvent event) {
    structuredCurrentError.value = event;
    structuredErrorHistory.insert(0, event);
    final line = formatAppErrorEvent(event);
    currentError.value = line;
    errorHistory.insert(0, line);
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

  void clear() {
    structuredCurrentError.value = null;
    structuredErrorHistory.clear();
    currentError.value = null;
    errorHistory.clear();
  }
}
