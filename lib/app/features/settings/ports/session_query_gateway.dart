class SelectableChat {
  const SelectableChat({required this.id, required this.title});

  final int id;
  final String title;
}

/// Settings feature 依赖的最小会话查询能力接口（capability port）。
abstract class SessionQueryGateway {
  Future<List<SelectableChat>> listSelectableChats();
}
