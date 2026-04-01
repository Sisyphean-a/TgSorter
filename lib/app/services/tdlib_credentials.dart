class TdlibCredentials {
  const TdlibCredentials({
    required this.apiId,
    required this.apiHash,
    required this.proxyServer,
    required this.proxyPort,
    required this.proxyUsername,
    required this.proxyPassword,
  });

  final int apiId;
  final String apiHash;
  final String? proxyServer;
  final int? proxyPort;
  final String proxyUsername;
  final String proxyPassword;

  static TdlibCredentials fromEnvironment() {
    const apiIdRaw = String.fromEnvironment('TDLIB_API_ID');
    const apiHash = String.fromEnvironment('TDLIB_API_HASH');
    const proxyServerRaw = String.fromEnvironment('TDLIB_PROXY_SERVER');
    const proxyPortRaw = String.fromEnvironment('TDLIB_PROXY_PORT');
    const proxyUsername = String.fromEnvironment('TDLIB_PROXY_USERNAME');
    const proxyPassword = String.fromEnvironment('TDLIB_PROXY_PASSWORD');
    final apiId = int.tryParse(apiIdRaw);
    if (apiId == null || apiHash.isEmpty) {
      throw StateError(
        '缺少 TDLib 凭据，请使用 --dart-define-from-file 传入 TDLIB_API_ID / TDLIB_API_HASH',
      );
    }
    final proxyServer = proxyServerRaw.trim().isEmpty
        ? null
        : proxyServerRaw.trim();
    final proxyPort = proxyPortRaw.trim().isEmpty
        ? null
        : int.tryParse(proxyPortRaw);
    if (proxyServer != null && (proxyPort == null || proxyPort <= 0)) {
      throw StateError('TDLIB_PROXY_PORT 无效，启用代理时必须提供有效端口');
    }
    return TdlibCredentials(
      apiId: apiId,
      apiHash: apiHash,
      proxyServer: proxyServer,
      proxyPort: proxyPort,
      proxyUsername: proxyUsername,
      proxyPassword: proxyPassword,
    );
  }
}
