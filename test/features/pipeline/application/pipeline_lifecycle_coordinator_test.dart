import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_recovery_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

void main() {
  test(
    'updateConnection triggers fetch only after authorization is ready',
    () async {
      var fetchCalls = 0;
      final lifecycle = PipelineLifecycleCoordinator(
        state: PipelineRuntimeState(),
        settings: _FakeSettingsReader(),
        recovery: _FakeRecoveryService(completed: true),
        onFetchNext: () async {
          fetchCalls++;
        },
        onResetPipeline: () {},
      );

      lifecycle.updateConnection(true);
      await Future<void>.delayed(Duration.zero);
      expect(fetchCalls, 0);

      lifecycle.updateAuthorization(true);
      await Future<void>.delayed(Duration.zero);
      expect(fetchCalls, 1);
    },
  );

  test(
    'settings change resets pipeline only when source or direction changes',
    () async {
      var didReset = false;
      var fetchCalls = 0;
      final lifecycle = PipelineLifecycleCoordinator(
        state: PipelineRuntimeState()..isOnline.value = true,
        settings: _FakeSettingsReader(),
        recovery: _FakeRecoveryService(completed: true),
        onFetchNext: () async {
          fetchCalls++;
        },
        onResetPipeline: () {
          didReset = true;
        },
      );

      lifecycle.updateAuthorization(true);
      await Future<void>.delayed(Duration.zero);
      fetchCalls = 0;

      lifecycle.handleSettingsChanged(_unchangedSettings());
      await Future<void>.delayed(Duration.zero);
      expect(didReset, isFalse);
      expect(fetchCalls, 0);

      lifecycle.handleSettingsChanged(_updatedSettings());
      await Future<void>.delayed(Duration.zero);
      expect(didReset, isTrue);
      expect(fetchCalls, 1);
    },
  );

  test('auto fetch waits recovery completion before fetching', () async {
    final recovery = _FakeRecoveryService(completed: false);
    var fetchCalls = 0;
    final lifecycle = PipelineLifecycleCoordinator(
      state: PipelineRuntimeState(),
      settings: _FakeSettingsReader(),
      recovery: recovery,
      onFetchNext: () async {
        fetchCalls++;
      },
      onResetPipeline: () {},
    );

    lifecycle.updateConnection(true);
    lifecycle.updateAuthorization(true);
    await Future<void>.delayed(Duration.zero);

    expect(recovery.recoverCalls, 1);
    expect(fetchCalls, 0);

    recovery.completeRecovery();
    await Future<void>.delayed(Duration.zero);

    expect(fetchCalls, 1);
  });

  test('authorization loss resets pipeline state immediately', () async {
    var resetCalls = 0;
    final lifecycle = PipelineLifecycleCoordinator(
      state: PipelineRuntimeState()..isOnline.value = true,
      settings: _FakeSettingsReader(),
      recovery: _FakeRecoveryService(completed: true),
      onFetchNext: () async {},
      onResetPipeline: () {
        resetCalls++;
      },
    );

    lifecycle.updateAuthorization(true);
    await Future<void>.delayed(Duration.zero);

    lifecycle.updateAuthorization(false);

    expect(resetCalls, 1);
  });
}

AppSettings _updatedSettings() {
  return const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: 9999,
    fetchDirection: MessageFetchDirection.oldestFirst,
    forwardAsCopy: false,
    batchSize: 2,
    throttleMs: 0,
    proxy: ProxySettings.empty,
  );
}

AppSettings _unchangedSettings() {
  return const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: 8888,
    fetchDirection: MessageFetchDirection.latestFirst,
    forwardAsCopy: true,
    batchSize: 9,
    throttleMs: 10,
    proxy: ProxySettings.empty,
  );
}

class _FakeSettingsReader implements PipelineSettingsReader {
  @override
  final settingsStream = const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: 8888,
    fetchDirection: MessageFetchDirection.latestFirst,
    forwardAsCopy: false,
    batchSize: 2,
    throttleMs: 0,
    proxy: ProxySettings.empty,
  ).obs;

  @override
  AppSettings get currentSettings => settingsStream.value;

  @override
  CategoryConfig getCategory(String key) {
    throw UnimplementedError();
  }
}

class _FakeRecoveryService extends PipelineRecoveryService {
  _FakeRecoveryService({required bool completed})
    : _completed = completed,
      super(
        recoveryGateway: _NoopRecoveryGateway(),
        errors: AppErrorController(),
      );

  bool _completed;
  int recoverCalls = 0;
  Completer<void>? _recoveryCompleter;

  @override
  bool get isCompleted => _completed;

  @override
  bool get isRunning => _recoveryCompleter != null;

  @override
  Future<void> recoverPendingTransactionsIfNeeded() async {
    recoverCalls++;
    _recoveryCompleter ??= Completer<void>();
    await _recoveryCompleter!.future;
  }

  void completeRecovery() {
    _completed = true;
    _recoveryCompleter?.complete();
    _recoveryCompleter = null;
  }
}

class _NoopRecoveryGateway implements RecoveryGateway {
  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    return ClassifyRecoverySummary.empty;
  }
}
