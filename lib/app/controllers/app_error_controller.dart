import 'package:get/get.dart';

class AppErrorController extends GetxController {
  final currentError = RxnString();
  final errorHistory = <String>[].obs;

  void report({required String title, required String message}) {
    final line = _formatErrorLine(title, message);
    currentError.value = line;
    errorHistory.insert(0, line);
  }

  void clear() {
    currentError.value = null;
    errorHistory.clear();
  }

  String _formatErrorLine(String title, String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '[$hh:$mm:$ss] $title：$message';
  }
}
