import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/tdlib_modern_wire.dart';

void main() {
  test('forwarding to the main chat leaves the modern topic unset', () {
    final existing = <String, dynamic>{
      '@type': 'forwardMessages',
      '@extra': 'pending',
      'chat_id': 120,
      'message_thread_id': 0,
      'message_ids': [50, 51],
    };
    final outgoing = adaptModernRequest(existing);

    expect(outgoing['topic_id'], isNull);
    expect(outgoing, isNot(contains('message_thread_id')));
    expect(outgoing['message_ids'], [50, 51]);
    expect(outgoing['@extra'], 'pending');
    expect(existing['message_thread_id'], 0);
  });

  test('modern TDLib translates a removed legacy link preview request', () {
    final preview = GetWebPagePreview(
      text: const FormattedText(text: 'https://telegram.org', entities: []),
    );
    final original = Map<String, dynamic>.from(preview.toJson('request'));
    final request = adaptModernRequest(original);
    expect(request['@type'], 'getLinkPreview');
    expect(request['@extra'], 'request');
    expect(request['text']['text'], 'https://telegram.org');
    expect(original['@type'], 'getWebPagePreview');
  });
}
