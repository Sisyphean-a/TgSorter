enum TdlibAddProxyMode { flatArgs, nestedProxyObject }

class TdlibSchemaCapabilities {
  const TdlibSchemaCapabilities({required this.addProxyMode});

  final TdlibAddProxyMode addProxyMode;
}
