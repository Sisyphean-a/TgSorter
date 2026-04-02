class ProxySettings {
  const ProxySettings({
    required this.server,
    required this.port,
    required this.username,
    required this.password,
  });

  static const ProxySettings empty = ProxySettings(
    server: '',
    port: null,
    username: '',
    password: '',
  );

  final String server;
  final int? port;
  final String username;
  final String password;

  bool get isConfigured => server.trim().isNotEmpty && (port ?? 0) > 0;

  ProxySettings sanitize() {
    final normalizedPort = port;
    return ProxySettings(
      server: server.trim(),
      port: normalizedPort != null && normalizedPort > 0 ? normalizedPort : null,
      username: username.trim(),
      password: password,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProxySettings &&
            server == other.server &&
            port == other.port &&
            username == other.username &&
            password == other.password;
  }

  @override
  int get hashCode => Object.hash(server, port, username, password);
}
