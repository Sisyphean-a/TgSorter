import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_session.dart';
import 'package:tgsorter/app/models/app_settings.dart';

void main() {
  test('update marks draft dirty until discard', () {
    final session = SettingsDraftSession(AppSettings.defaults());

    session.update(session.draft.value.updateForwardAsCopy(true));

    expect(session.isDirty.value, isTrue);
    session.discard();
    expect(session.isDirty.value, isFalse);
  });
}
