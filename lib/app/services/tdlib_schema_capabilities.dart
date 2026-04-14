enum TdlibAddProxyMode { flatArgs, nestedProxyObject }

class TdlibSchemaCapabilities {
  const TdlibSchemaCapabilities({
    required this.addProxyMode,
    this.supportsGetWebPagePreview = true,
  });

  final TdlibAddProxyMode addProxyMode;
  final bool supportsGetWebPagePreview;
}
