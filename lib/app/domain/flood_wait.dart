int? parseFloodWaitSeconds(String message) {
  final floodWaitPattern = RegExp(r'FLOOD_WAIT_(\d+)', caseSensitive: false);
  final floodMatch = floodWaitPattern.firstMatch(message);
  if (floodMatch != null) {
    return int.tryParse(floodMatch.group(1) ?? '');
  }

  final plainPattern = RegExp(r'(\d+)\s*seconds?', caseSensitive: false);
  final plainMatch = plainPattern.firstMatch(message);
  return int.tryParse(plainMatch?.group(1) ?? '');
}
