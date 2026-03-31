import 'package:tgsorter/app/services/telegram_service.dart';

enum TdErrorKind { rateLimit, network, auth, permission, tdlib }

TdErrorKind classifyTdlibError(TdlibRequestException error) {
  if (error.code == 420 || error.code == 429) {
    return TdErrorKind.rateLimit;
  }
  if (_isAuthError(error)) {
    return TdErrorKind.auth;
  }
  if (error.code == 403) {
    return TdErrorKind.permission;
  }
  if (_isNetworkError(error.message)) {
    return TdErrorKind.network;
  }
  return TdErrorKind.tdlib;
}

bool _isAuthError(TdlibRequestException error) {
  if (error.code == 401) {
    return true;
  }
  final upper = error.message.toUpperCase();
  return upper.contains('PHONE_CODE') ||
      upper.contains('PASSWORD') ||
      upper.contains('AUTH');
}

bool _isNetworkError(String message) {
  final upper = message.toUpperCase();
  return upper.contains('NETWORK') ||
      upper.contains('TIMEOUT') ||
      upper.contains('CONNECTION') ||
      upper.contains('UNREACHABLE');
}
