import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/presentation/logs_screen.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';

void main() {
  testWidgets('renders grouped log chains with failure reason and filters', (
    tester,
  ) async {
    final port = _FakeLogsPort([
      _log(
        id: '1',
        messageId: 1001,
        createdAtMs: 1000,
        status: ClassifyOperationStatus.failed,
        reason: 'CHAT_WRITE_FORBIDDEN',
      ),
      _log(
        id: '2',
        messageId: 1001,
        createdAtMs: 2000,
        status: ClassifyOperationStatus.retrySuccess,
      ),
      _log(
        id: '3',
        messageId: 1002,
        createdAtMs: 3000,
        status: ClassifyOperationStatus.failed,
        reason: 'NETWORK',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LogsScreen(pipeline: port)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('操作日志'), findsNothing);
    expect(find.text('失败中'), findsWidgets);
    expect(find.byKey(const Key('logs-filter-bar')), findsOneWidget);
    expect(find.byKey(const Key('log-chain-row-1002_cat_200')), findsOneWidget);
    expect(find.text('消息 #1002'), findsOneWidget);
    expect(find.text('原因：NETWORK'), findsOneWidget);
    expect(find.text('消息 #1001'), findsOneWidget);
    expect(find.text('已恢复'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('log-filter-failedInProgress')));
    await tester.pumpAndSettle();

    expect(find.text('消息 #1002'), findsOneWidget);
    expect(find.text('消息 #1001'), findsNothing);
  });
}

class _FakeLogsPort implements PipelineLogsPort {
  _FakeLogsPort(this.logsSnapshot);

  @override
  final List<ClassifyOperationLog> logsSnapshot;
}

ClassifyOperationLog _log({
  required String id,
  required int messageId,
  required int createdAtMs,
  required ClassifyOperationStatus status,
  String? reason,
}) {
  return ClassifyOperationLog(
    id: id,
    categoryKey: 'cat',
    messageId: messageId,
    targetChatId: 200,
    createdAtMs: createdAtMs,
    status: status,
    reason: reason,
  );
}
