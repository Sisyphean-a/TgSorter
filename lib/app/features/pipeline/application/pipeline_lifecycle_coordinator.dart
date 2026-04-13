import 'dart:async';

import 'package:tgsorter/app/models/app_settings.dart';

import 'pipeline_recovery_service.dart';
import 'pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';

class PipelineLifecycleCoordinator {
  PipelineLifecycleCoordinator({
    required PipelineRuntimeState state,
    required PipelineSettingsReader settings,
    required PipelineRecoveryService recovery,
    required Future<void> Function() onFetchNext,
    required void Function() onResetPipeline,
  }) : _state = state,
       _recovery = recovery,
       _onFetchNext = onFetchNext,
       _onResetPipeline = onResetPipeline {
    _lastFetchDirection = settings.currentSettings.fetchDirection;
    _lastSourceChatId = settings.currentSettings.sourceChatId;
  }

  final PipelineRuntimeState _state;
  final PipelineRecoveryService _recovery;
  final Future<void> Function() _onFetchNext;
  final void Function() _onResetPipeline;

  bool _isAuthorized = false;
  MessageFetchDirection? _lastFetchDirection;
  int? _lastSourceChatId;
  bool _pendingAutoFetchAfterLoad = false;

  void updateConnection(bool isReady) {
    _state.isOnline.value = isReady;
    tryAutoFetchNext();
  }

  void updateAuthorization(bool isReady) {
    if (!isReady) {
      _onResetPipeline();
      _pendingAutoFetchAfterLoad = false;
    }
    _isAuthorized = isReady;
    tryAutoFetchNext();
  }

  void handleSettingsChanged(AppSettings settings) {
    final directionChanged = settings.fetchDirection != _lastFetchDirection;
    final sourceChanged = settings.sourceChatId != _lastSourceChatId;
    _lastFetchDirection = settings.fetchDirection;
    _lastSourceChatId = settings.sourceChatId;
    if (!directionChanged && !sourceChanged) {
      return;
    }
    _onResetPipeline();
    if (_state.loading.value) {
      _pendingAutoFetchAfterLoad = true;
      return;
    }
    tryAutoFetchNext();
  }

  void handleFetchCompleted() {
    if (!_pendingAutoFetchAfterLoad || _state.loading.value) {
      return;
    }
    _pendingAutoFetchAfterLoad = false;
    tryAutoFetchNext();
  }

  void tryAutoFetchNext() {
    if (!_isAuthorized || !_state.isOnline.value || _state.loading.value) {
      return;
    }
    if (!_recovery.isCompleted) {
      _triggerTransactionRecoveryIfNeeded();
      return;
    }
    if (_state.currentMessage.value != null) {
      return;
    }
    unawaited(_onFetchNext());
  }

  void _triggerTransactionRecoveryIfNeeded() {
    if (_recovery.isRunning || _recovery.isCompleted) {
      return;
    }
    unawaited(_recoverPendingTransactions());
  }

  Future<void> _recoverPendingTransactions() async {
    await _recovery.recoverPendingTransactionsIfNeeded();
    if (_recovery.isCompleted) {
      tryAutoFetchNext();
    }
  }
}
