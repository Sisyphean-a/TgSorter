import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';

Future<void> undoWithFeedback(
  BuildContext context,
  PipelineCoordinator pipeline,
) {
  return pipeline.undoLastStep(
    onUnavailable: () => ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法撤销：当前没有可撤销的成功操作'))),
  );
}
