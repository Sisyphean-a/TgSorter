/// 官方 TDLib 源码提交；与 tool/build_tdlib_android.sh 一致。
const tdlibModernRevision = '03220f6b3043c6fd7785fbf0901d63f19ad19974';

/// 现有 Dart DTO 仍可供业务层使用；只在 TDLib JSON 边界转换。
Map<String, dynamic> adaptModernRequest(Map<String, dynamic> payload) {
  switch (payload['@type']) {
    case 'setTdlibParameters':
      return {...payload}
        ..remove('enable_storage_optimizer')
        ..remove('ignore_file_names');
    case 'forwardMessages':
      final thread = payload['message_thread_id'];
      return {
        ...payload,
        'topic_id': thread is int && thread != 0
            ? {'@type': 'messageTopicThread', 'message_thread_id': thread}
            : null,
      }..remove('message_thread_id');
    case 'getWebPagePreview':
      return {...payload, '@type': 'getLinkPreview'};
    case 'getWebPageInstantView':
      return {...payload, 'only_local': false}..remove('force_full');
    default:
      return payload;
  }
}
