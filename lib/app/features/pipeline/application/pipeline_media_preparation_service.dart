import 'package:tgsorter/app/services/media_preparation_service.dart';

class PipelineMediaPreparationService {
  const PipelineMediaPreparationService({
    required MediaPreparationService mediaPreparation,
  }) : _mediaPreparation = mediaPreparation;

  final MediaPreparationService _mediaPreparation;

  Future<MediaPreparationResult> preparePlayback({
    required MediaHandle handle,
  }) {
    return _mediaPreparation.preparePlayback(handle);
  }

  Future<MediaPreparationResult> preparePreview({required MediaHandle handle}) {
    return _mediaPreparation.preparePreview(handle);
  }
}
