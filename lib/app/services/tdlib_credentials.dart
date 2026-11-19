class TdlibCredentials {
  const TdlibCredentials({required this.apiId, required this.apiHash});

  final int apiId;
  final String apiHash;

  static TdlibCredentials fromEnvironment() {
    const apiIdRaw = String.fromEnvironment('TDLIB_API_ID');
    const apiHash = String.fromEnvironment('TDLIB_API_HASH');
    final apiId = int.tryParse(apiIdRaw);
    if (apiId == null || apiHash.isEmpty) {
      throw StateError(
        '缺少 TDLib 凭据，请使用 --dart-define-from-file 传入 TDLIB_API_ID / TDLIB_API_HASH',
      );
    }
    return TdlibCredentials(apiId: apiId, apiHash: apiHash);
  }
}
