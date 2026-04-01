class TdResponseReadError implements Exception {
  const TdResponseReadError(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class TdResponseReader {
  static String readString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw TdResponseReadError('Missing required string at $key');
  }

  static int readInt(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is int) {
      return value;
    }
    throw TdResponseReadError('Missing required int at $key');
  }

  static bool readBool(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is bool) {
      return value;
    }
    throw TdResponseReadError('Missing required bool at $key');
  }

  static List<dynamic> readList(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is List<dynamic>) {
      return List<dynamic>.unmodifiable(value);
    }
    throw TdResponseReadError('Missing required list at $key');
  }

  static Map<String, dynamic> readMap(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(value.cast<String, dynamic>());
    }
    throw TdResponseReadError('Missing required map at $key');
  }
}
