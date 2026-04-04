import 'package:tgsorter/app/models/classify_operation_log.dart';

abstract class PipelineLogsPort {
  List<ClassifyOperationLog> get logsSnapshot;
}
