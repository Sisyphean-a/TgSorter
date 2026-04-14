import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/services/login_alert_repository.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';
import 'package:tgsorter/app/services/telegram_login_alert_parser.dart';

class LoginAlertWorkbenchController extends GetxController {
  LoginAlertWorkbenchController({
    required Stream<Map<String, dynamic>> updates,
    required LoginAlertRepositoryPort repository,
    LoginAlertNowMs? nowMs,
  }) : _updates = updates,
       _repository = repository,
       _nowMs = nowMs ?? _defaultNowMs;

  static const int _maxEntries = 60;
  static const int _consumeWindowMs = 30 * 60 * 1000;

  final Stream<Map<String, dynamic>> _updates;
  final LoginAlertRepositoryPort _repository;
  final LoginAlertNowMs _nowMs;

  final entries = <TelegramLoginAlert>[].obs;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  void onInit() {
    super.onInit();
    unawaited(_restore());
    _subscription = _updates.listen(_handleUpdate);
  }

  Future<void> _restore() async {
    final restored = await _repository.load();
    final merged = <String, TelegramLoginAlert>{};
    for (final item in restored) {
      merged[item.identityKey] = item;
    }
    for (final item in entries) {
      merged[item.identityKey] = item;
    }
    entries.assignAll(_normalize(merged.values.toList(growable: false)));
  }

  void _handleUpdate(Map<String, dynamic> payload) {
    final parsed = TelegramLoginAlertParser.parse(payload, nowMs: _nowMs());
    if (parsed == null) {
      return;
    }
    final next = _merge(entries.toList(growable: false), parsed);
    entries.assignAll(next);
    unawaited(_repository.save(next));
  }

  List<TelegramLoginAlert> _merge(
    List<TelegramLoginAlert> current,
    TelegramLoginAlert incoming,
  ) {
    final working = current.toList(growable: true);
    final existingIndex = working.indexWhere(
      (item) => item.identityKey == incoming.identityKey,
    );
    if (existingIndex != -1) {
      return _normalize(working);
    }
    if (incoming.kind == TelegramLoginAlertKind.newLogin) {
      _markLatestCodeAsUsed(working, incoming);
    }
    working.add(incoming);
    return _normalize(working);
  }

  void _markLatestCodeAsUsed(
    List<TelegramLoginAlert> entries,
    TelegramLoginAlert loginAlert,
  ) {
    for (var index = 0; index < entries.length; index++) {
      final candidate = entries[index];
      if (candidate.kind != TelegramLoginAlertKind.code ||
          candidate.status != TelegramLoginAlertStatus.active) {
        continue;
      }
      final delta = loginAlert.receivedAtMs - candidate.receivedAtMs;
      if (delta < 0 || delta > _consumeWindowMs) {
        continue;
      }
      entries[index] = candidate.copyWith(
        status: TelegramLoginAlertStatus.used,
        consumedAtMs: loginAlert.receivedAtMs,
      );
      return;
    }
  }

  List<TelegramLoginAlert> _normalize(List<TelegramLoginAlert> source) {
    final deduped = <String, TelegramLoginAlert>{};
    for (final item in source) {
      final existing = deduped[item.identityKey];
      if (existing == null || item.receivedAtMs >= existing.receivedAtMs) {
        deduped[item.identityKey] = _applyStatus(item);
      }
    }
    final normalized = deduped.values.toList(growable: false)
      ..sort((left, right) => right.receivedAtMs.compareTo(left.receivedAtMs));
    if (normalized.length <= _maxEntries) {
      return normalized;
    }
    return normalized.take(_maxEntries).toList(growable: false);
  }

  TelegramLoginAlert _applyStatus(TelegramLoginAlert item) {
    if (item.kind != TelegramLoginAlertKind.code ||
        item.status == TelegramLoginAlertStatus.used) {
      return item;
    }
    final expired =
        _nowMs() - item.receivedAtMs >=
        TelegramLoginAlertTiming.codeExpiryWindowMs;
    return item.copyWith(
      status: expired
          ? TelegramLoginAlertStatus.expired
          : TelegramLoginAlertStatus.active,
    );
  }

  @override
  void onClose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.onClose();
  }
}
