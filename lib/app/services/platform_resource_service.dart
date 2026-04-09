class LocalResource {
  const LocalResource({required this.path});

  final String path;

  bool get hasPath => path.trim().isNotEmpty;
}

class ActionResult {
  const ActionResult({required this.success, this.message});

  final bool success;
  final String? message;
}

abstract interface class PlatformResourceService {
  Future<ActionResult> openResource(LocalResource resource);

  Future<ActionResult> revealResource(LocalResource resource);

  Future<ActionResult> copyPath(LocalResource resource);

  Future<ActionResult> openUrl(Uri url);
}
