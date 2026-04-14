import 'package:tgsorter/app/services/skipped_message_repository.dart';

abstract class SkippedMessageRestorePort {
  SkippedMessageWorkflow get workflow;

  Future<void> reloadAfterSkippedRestore({int? sourceChatId});
}
