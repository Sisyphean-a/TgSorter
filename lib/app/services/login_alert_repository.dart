import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';

abstract class LoginAlertRepositoryPort {
  Future<List<TelegramLoginAlert>> load();
  Future<void> save(List<TelegramLoginAlert> entries);
}

class LoginAlertRepository implements LoginAlertRepositoryPort {
  LoginAlertRepository(this._prefs);

  static const String _recordsKey = 'telegram_login_alerts_json';

  final SharedPreferences _prefs;

  @override
  Future<List<TelegramLoginAlert>> load() async {
    final encoded = _prefs.getString(_recordsKey);
    if (encoded == null || encoded.isEmpty) {
      return const <TelegramLoginAlert>[];
    }
    final raw = jsonDecode(encoded) as List<dynamic>;
    return raw
        .map(
          (item) => TelegramLoginAlert.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(List<TelegramLoginAlert> entries) {
    final encoded = jsonEncode(
      entries.map((item) => item.toJson()).toList(growable: false),
    );
    return _prefs.setString(_recordsKey, encoded);
  }
}
