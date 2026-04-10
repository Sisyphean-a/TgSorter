# Tagging Workbench And Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable message workbench framework, rename the current workbench to forwarding workbench, add a tagging workbench that edits original Telegram messages, and redesign settings into Telegram-style forwarding/tagging/common sections.

**Architecture:** Extract shared message browsing, paging, preview, media, navigation, and status behavior from `pipeline` into reusable workbench components while keeping forwarding-specific logs/retry/undo in the forwarding action layer. Add a tagging action layer that uses TDLib `editMessageText` and `editMessageCaption` against freshly loaded messages.

**Tech Stack:** Flutter, GetX, SharedPreferences, TDLib Dart package, flutter_test.

---

## File Structure

- Modify: `lib/app/models/app_settings.dart`
  - Add tagging settings fields and semantic getters for forwarding, tagging, common.
- Create: `lib/app/models/tag_config.dart`
  - Immutable tag and tag group config models.
- Create: `lib/app/features/settings/domain/forwarding_settings.dart`
  - Forwarding settings view model extracted from current workflow settings.
- Create: `lib/app/features/settings/domain/tagging_settings.dart`
  - Tagging source chat and tag group settings.
- Create: `lib/app/features/settings/domain/common_settings.dart`
  - Common proxy and shortcut settings.
- Modify: `lib/app/services/settings_repository.dart`
  - Persist tag source chat and default tag group while retaining existing forwarding keys.
- Create: `lib/app/features/settings/application/tag_settings_service.dart`
  - Normalize, validate, add, remove, and reorder tags.
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`
  - Add tag source and tag group draft update methods.
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
  - Replace current collapsible card grouping with Telegram-style list sections.
- Create: `lib/app/features/settings/presentation/settings_list_section.dart`
  - Reusable section title, list row, divider components.
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
  - Split content into forwarding, tagging, and common sections.
- Create: `lib/app/features/settings/presentation/tag_group_editor.dart`
  - Default tag group editor.
- Modify: `lib/app/features/shell/presentation/main_shell_destination.dart`
  - Add `forwardingWorkbench` and `taggingWorkbench`, rename old workspace label.
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
  - Add the tagging workbench screen to the `IndexedStack`.
- Create: `lib/app/features/workbench/application/message_workbench_state.dart`
  - Shared current message, cache, navigation, loading, processing, media state.
- Create: `lib/app/features/workbench/application/message_workbench_controller.dart`
  - Shared lifecycle, feed, media, navigation orchestration.
- Create: `lib/app/features/workbench/presentation/message_workbench_view.dart`
  - Shared desktop/mobile workbench layout shell.
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
  - Keep forwarding-specific action behavior and delegate shared browse behavior where practical.
- Modify: `lib/app/features/pipeline/presentation/pipeline_page.dart`
  - Rename user-facing workbench title.
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
  - Use shared workbench view or align with extracted action panel.
- Modify: `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
  - Use shared workbench view or align with extracted action tray.
- Create: `lib/app/features/tagging/ports/tagging_gateway.dart`
  - Port for applying a tag to the original message.
- Create: `lib/app/features/tagging/application/tagging_coordinator.dart`
  - Tagging workbench controller that uses the shared workbench and tagging gateway.
- Create: `lib/app/features/tagging/application/tag_append_service.dart`
  - Pure tag append and duplicate detection logic.
- Create: `lib/app/features/tagging/application/tag_target_selector.dart`
  - Pure logic for selecting which message in a media group receives the caption edit.
- Create: `lib/app/features/tagging/presentation/tagging_page.dart`
  - Tagging workbench screen and app bar.
- Create: `lib/app/features/tagging/presentation/tag_action_group.dart`
  - Tag button group.
- Create: `lib/app/services/telegram_tagging_service.dart`
  - TDLib implementation of tag edit behavior.
- Modify: `lib/app/services/telegram_service.dart`
  - Implement and register `TaggingGateway`.
- Modify: `lib/app/services/td_message_dto.dart`
  - Parse `can_be_edited` and expose enough content details for tag editing.
- Modify: `lib/app/core/di/app_bindings.dart`
  - Register `TaggingGateway`.
- Create: `lib/app/core/di/tagging_module.dart`
  - Register `TaggingCoordinator`.
- Modify: `lib/app/core/di/pipeline_module.dart`
  - Adjust forwarding coordinator bindings after shared workbench extraction.
- Add/modify tests under `test/models`, `test/services`, `test/features/settings`, `test/features/tagging`, `test/features/workbench`, and `test/pages`.

---

## Chunk 1: Settings And Tag Models

### Task 1: Add tag config models

**Files:**
- Create: `lib/app/models/tag_config.dart`
- Test: `test/models/tag_config_test.dart`

- [ ] **Step 1: Write failing tests**

Cover:
- `TagConfig.normalizeName('#摄影') == '摄影'`
- empty tag throws `ArgumentError`
- tag with whitespace throws `ArgumentError`
- duplicate normalized tag in a group throws `StateError`

Run:

```bash
flutter test test/models/tag_config_test.dart
```

Expected: FAIL because `tag_config.dart` does not exist.

- [ ] **Step 2: Implement immutable models**

Create:

```dart
class TagConfig {
  const TagConfig({required this.name});
  final String name;
  String get displayName => '#$name';
}

class TagGroupConfig {
  const TagGroupConfig({required this.key, required this.title, required this.tags});
  final String key;
  final String title;
  final List<TagConfig> tags;
}
```

Add normalization helpers without mutating inputs. Keep functions below 50 lines.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/models/tag_config_test.dart
```

Expected: PASS.

### Task 2: Add semantic settings sections

**Files:**
- Modify: `lib/app/models/app_settings.dart`
- Create: `lib/app/features/settings/domain/forwarding_settings.dart`
- Create: `lib/app/features/settings/domain/tagging_settings.dart`
- Create: `lib/app/features/settings/domain/common_settings.dart`
- Modify: `lib/app/features/settings/domain/workflow_settings.dart`
- Modify: `lib/app/features/settings/domain/connection_settings.dart`
- Modify: `lib/app/features/settings/domain/shortcut_settings.dart`
- Test: `test/models/app_settings_shortcut_test.dart`
- Test: `test/features/settings/application/settings_draft_coordinator_test.dart`

- [ ] **Step 1: Write failing tests**

Add assertions for:
- defaults include `tagSourceChatId == null`
- defaults include one default tag group
- `copyWith` updates tagging fields
- equality/hashCode include tagging fields

Run:

```bash
flutter test test/models/app_settings_shortcut_test.dart test/features/settings/application/settings_draft_coordinator_test.dart
```

Expected: FAIL because new fields do not exist.

- [ ] **Step 2: Implement settings fields**

Add to `AppSettings`:

```dart
final int? tagSourceChatId;
final List<TagGroupConfig> tagGroups;
```

Add getters:

```dart
ForwardingSettings get forwarding => ForwardingSettings(...);
TaggingSettings get tagging => TaggingSettings(...);
CommonSettings get common => CommonSettings(...);
```

Keep old direct getters for existing callers during the migration.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/models/app_settings_shortcut_test.dart test/features/settings/application/settings_draft_coordinator_test.dart
```

Expected: PASS.

### Task 3: Persist tagging settings

**Files:**
- Modify: `lib/app/services/settings_repository.dart`
- Test: `test/services/settings_repository_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests for:
- default tag source chat is null
- saving/loading `tagSourceChatId`
- saving/loading default group tags
- existing forwarding keys still load unchanged

Run:

```bash
flutter test test/services/settings_repository_test.dart
```

Expected: FAIL because repository does not persist tagging settings.

- [ ] **Step 2: Implement persistence**

Add keys:

```dart
static const _tagSourceChatIdKey = 'tag_source_chat_id';
static const _tagDefaultGroupTagsKey = 'tag_default_group_tags';
```

Use `StringList` for default tags. Keep old forwarding keys as-is.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/services/settings_repository_test.dart
```

Expected: PASS.

### Task 4: Add tag settings draft service

**Files:**
- Create: `lib/app/features/settings/application/tag_settings_service.dart`
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`
- Test: `test/features/settings/application/tag_settings_service_test.dart`
- Test: `test/features/settings/application/settings_coordinator_test.dart`

- [ ] **Step 1: Write failing tests**

Cover:
- update tag source chat draft
- add tag to default group
- remove tag from default group
- duplicate tag rejects
- `#摄影` stores as `摄影`

Run:

```bash
flutter test test/features/settings/application/tag_settings_service_test.dart test/features/settings/application/settings_coordinator_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement service and coordinator methods**

Add methods:

```dart
void updateTagSourceChatDraft(int? chatId)
void addDefaultTagDraft(String rawName)
void removeDefaultTagDraft(String name)
```

Throw explicit errors for invalid tags.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/features/settings/application/tag_settings_service_test.dart test/features/settings/application/settings_coordinator_test.dart
```

Expected: PASS.

---

## Chunk 2: TDLib Tag Editing

### Task 5: Parse editability and formatted text for editing

**Files:**
- Modify: `lib/app/services/td_message_dto.dart`
- Test: `test/services/td_wire_message_parser_test.dart`

- [ ] **Step 1: Write failing tests**

Add parser coverage for:
- `can_be_edited: true`
- message text content preserves formatted text
- message photo/video/document/audio caption preserves formatted text

Run:

```bash
flutter test test/services/td_wire_message_parser_test.dart
```

Expected: FAIL because `TdMessageDto.canBeEdited` is missing.

- [ ] **Step 2: Implement DTO field**

Add:

```dart
final bool canBeEdited;
```

Read from payload with explicit type handling. If missing in tests where old fixtures omit it, use `false` only for fixture compatibility if TDLib can omit it; otherwise update fixtures to include it.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/services/td_wire_message_parser_test.dart
```

Expected: PASS.

### Task 6: Implement pure tag append logic

**Files:**
- Create: `lib/app/features/tagging/application/tag_append_service.dart`
- Test: `test/features/tagging/application/tag_append_service_test.dart`

- [ ] **Step 1: Write failing tests**

Cover:
- `'' + 摄影 => '#摄影'`
- `'hello' + 摄影 => 'hello #摄影'`
- `'hello #摄影' + 摄影 => unchanged + alreadyExists`
- `'#摄影师' + 摄影` must still allow `#摄影` if exact token is absent

Run:

```bash
flutter test test/features/tagging/application/tag_append_service_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement service**

Return a result object:

```dart
class TagAppendResult {
  const TagAppendResult({required this.text, required this.changed});
  final String text;
  final bool changed;
}
```

Use token boundary matching instead of simple `contains`.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/features/tagging/application/tag_append_service_test.dart
```

Expected: PASS.

### Task 7: Select media-group edit target

**Files:**
- Create: `lib/app/features/tagging/application/tag_target_selector.dart`
- Test: `test/features/tagging/application/tag_target_selector_test.dart`

- [ ] **Step 1: Write failing tests**

Cover:
- single text message selects text edit
- single photo/video/document/audio selects caption edit
- media group selects first editable message with non-empty caption
- media group with no caption selects first editable caption-capable message
- group with no editable message throws `StateError`

Run:

```bash
flutter test test/features/tagging/application/tag_target_selector_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement selector**

Define a small result:

```dart
enum TagEditKind { text, caption }

class TagEditTarget {
  const TagEditTarget({required this.messageId, required this.kind, required this.currentText});
  final int messageId;
  final TagEditKind kind;
  final String currentText;
}
```

Selector input should be a list of `TdMessageDto`, not UI preview models.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/features/tagging/application/tag_target_selector_test.dart
```

Expected: PASS.

### Task 8: Implement Telegram tagging gateway

**Files:**
- Create: `lib/app/features/tagging/ports/tagging_gateway.dart`
- Create: `lib/app/services/telegram_tagging_service.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/core/di/app_bindings.dart`
- Test: `test/services/telegram_tagging_service_test.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: Write failing tests**

Cover:
- text message sends `EditMessageText`
- media caption sends `EditMessageCaption`
- existing tag returns unchanged without edit request
- no editable message throws
- TDLib edit failure propagates

Run:

```bash
flutter test test/services/telegram_tagging_service_test.dart test/services/telegram_service_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement service**

Service responsibilities:
- call `GetMessage` for each `messageId`
- select edit target
- append tag
- if unchanged, return a result with `changed == false`
- call `EditMessageText` or `EditMessageCaption`
- return refreshed `PipelineMessage` or enough data for coordinator to refresh through existing `refreshMessage`

Do not swallow TDLib errors.

- [ ] **Step 3: Register gateway**

`TelegramService` implements `TaggingGateway`, delegating to `TelegramTaggingService`.

- [ ] **Step 4: Verify**

Run:

```bash
flutter test test/services/telegram_tagging_service_test.dart test/services/telegram_service_test.dart
```

Expected: PASS.

---

## Chunk 3: Shared Workbench Framework

### Task 9: Extract shared workbench state and feed controller

**Files:**
- Create: `lib/app/features/workbench/application/message_workbench_state.dart`
- Create: `lib/app/features/workbench/application/message_workbench_controller.dart`
- Move or adapt logic from:
  - `lib/app/features/pipeline/application/pipeline_runtime_state.dart`
  - `lib/app/features/pipeline/application/pipeline_feed_controller.dart`
  - `lib/app/features/pipeline/application/pipeline_navigation_service.dart`
- Test: `test/features/workbench/application/message_workbench_controller_test.dart`
- Existing tests:
  - `test/features/pipeline/application/pipeline_feed_controller_test.dart`
  - `test/features/pipeline/application/pipeline_navigation_service_test.dart`
  - `test/features/pipeline/application/pipeline_runtime_state_test.dart`

- [ ] **Step 1: Write failing shared workbench tests**

Cover:
- initial page load uses injected source chat reader
- append more messages works
- skip removes current message
- current message updates media session

Run:

```bash
flutter test test/features/workbench/application/message_workbench_controller_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Extract without changing forwarding behavior**

Keep the public behavior of `PipelineCoordinator` intact while delegating shared operations to the new workbench controller.

- [ ] **Step 3: Run old and new tests**

Run:

```bash
flutter test test/features/workbench/application/message_workbench_controller_test.dart test/features/pipeline/application/pipeline_feed_controller_test.dart test/features/pipeline/application/pipeline_navigation_service_test.dart test/features/pipeline/application/pipeline_runtime_state_test.dart
```

Expected: PASS.

### Task 10: Keep forwarding action isolated

**Files:**
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_action_service.dart`
- Modify: `lib/app/features/pipeline/ports/pipeline_settings_reader.dart`
- Test: `test/features/pipeline/application/pipeline_action_service_test.dart`
- Test: `test/features/pipeline/application/pipeline_coordinator_test.dart`

- [ ] **Step 1: Write or update tests**

Confirm:
- forwarding still uses forwarding source chat
- classification still forwards and removes current message
- undo and retry still work
- logs still write only forwarding operations

Run:

```bash
flutter test test/features/pipeline/application/pipeline_action_service_test.dart test/features/pipeline/application/pipeline_coordinator_test.dart
```

Expected: FAIL until settings reader and workbench extraction are wired.

- [ ] **Step 2: Implement forwarding reader**

Add a forwarding-specific settings reader or methods so forwarding does not accidentally use `tagSourceChatId`.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/features/pipeline/application/pipeline_action_service_test.dart test/features/pipeline/application/pipeline_coordinator_test.dart
```

Expected: PASS.

---

## Chunk 4: Tagging Workbench

### Task 11: Add tagging coordinator

**Files:**
- Create: `lib/app/features/tagging/application/tagging_coordinator.dart`
- Create: `lib/app/core/di/tagging_module.dart`
- Modify: `lib/app/core/di/app_bindings.dart`
- Test: `test/features/tagging/application/tagging_coordinator_test.dart`
- Test: `test/app/cross_feature_ports_di_test.dart`

- [ ] **Step 1: Write failing tests**

Cover:
- uses `tagSourceChatId`
- exposes current message through shared workbench
- applies a tag and refreshes current message
- existing tag does not remove current message
- TDLib failure reports error and keeps current message

Run:

```bash
flutter test test/features/tagging/application/tagging_coordinator_test.dart test/app/cross_feature_ports_di_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement coordinator**

Coordinator should expose:

```dart
Future<void> fetchNext()
Future<void> showPreviousMessage()
Future<void> showNextMessage()
Future<void> skipCurrent()
Future<void> applyTag(String tagName)
```

Do not include forwarding undo/retry/batch methods.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/features/tagging/application/tagging_coordinator_test.dart test/app/cross_feature_ports_di_test.dart
```

Expected: PASS.

### Task 12: Add tagging workbench UI

**Files:**
- Create: `lib/app/features/workbench/presentation/message_workbench_view.dart`
- Create: `lib/app/features/tagging/presentation/tag_action_group.dart`
- Create: `lib/app/features/tagging/presentation/tagging_page.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_page.dart`
- Test: `test/pages/tagging_page_test.dart`
- Test: `test/pages/pipeline_layout_test.dart`
- Test: `test/pages/pipeline_mobile_view_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover:
- tag buttons show `#摄影`
- clicking tag calls `applyTag`
- no forwarding undo/retry/batch buttons on tagging page
- forwarding page still shows category buttons
- mobile narrow layout does not overflow

Run:

```bash
flutter test test/pages/tagging_page_test.dart test/pages/pipeline_layout_test.dart test/pages/pipeline_mobile_view_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement shared view and tag UI**

Keep the main preview unframed beyond functional workbench panels. Use compact spacing and stable button dimensions.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/pages/tagging_page_test.dart test/pages/pipeline_layout_test.dart test/pages/pipeline_mobile_view_test.dart
```

Expected: PASS.

### Task 13: Add shell navigation entry

**Files:**
- Modify: `lib/app/features/shell/presentation/main_shell_destination.dart`
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
- Test: `test/pages/main_shell_page_test.dart`

- [ ] **Step 1: Write failing shell test**

Expected labels:
- 转发工作台
- 标签工作台
- 设置
- 日志

Run:

```bash
flutter test test/pages/main_shell_page_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement shell changes**

Inject `TaggingCoordinator` into `MainShellPage` and add `TaggingScreen` to the stack.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/pages/main_shell_page_test.dart
```

Expected: PASS.

---

## Chunk 5: Telegram-Style Settings UI

### Task 14: Build reusable settings list components

**Files:**
- Create: `lib/app/features/settings/presentation/settings_list_section.dart`
- Modify: `lib/app/theme/app_tokens.dart`
- Modify: `lib/app/theme/app_theme.dart`
- Test: `test/widgets/app_shell_theme_test.dart`

- [ ] **Step 1: Write focused widget tests**

Cover:
- section title renders above rows
- rows use dividers, not card nesting
- row trailing text truncates without overflow

Run:

```bash
flutter test test/widgets/app_shell_theme_test.dart
```

Expected: FAIL if assertions are added for new list styling.

- [ ] **Step 2: Implement components**

Use list rows with `InkWell` or compact form controls. Reduce card radius to 8 or below for new settings components. Avoid broad decorative gradients in settings.

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/widgets/app_shell_theme_test.dart
```

Expected: PASS.

### Task 15: Rebuild settings screen into three sections

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Create: `lib/app/features/settings/presentation/tag_group_editor.dart`
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: Write failing settings page tests**

Cover:
- shows `转发区设置`
- shows `标签区设置`
- shows `通用设置`
- tag source chat editor exists
- default tag group editor can add/remove `摄影`
- old section labels `工作流` and `分类` no longer drive layout
- bottom save/discard behavior remains

Run:

```bash
flutter test test/pages/settings_page_test.dart
```

Expected: FAIL.

- [ ] **Step 2: Implement UI**

Move existing editors into the new list sections:
- source chat, fetch direction, forward mode, batch, prefetch, categories under forwarding
- tag source chat and default tag group under tagging
- proxy, chat reload, shortcut bindings under common

- [ ] **Step 3: Verify**

Run:

```bash
flutter test test/pages/settings_page_test.dart
```

Expected: PASS.

---

## Chunk 6: Full Verification

### Task 16: Static analysis and targeted tests

**Files:**
- No new files.

- [ ] **Step 1: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 2: Run focused tests**

Run:

```bash
flutter test test/models test/services test/features/settings test/features/tagging test/features/workbench test/pages test/widgets
```

Expected: PASS.

- [ ] **Step 3: Run full test suite**

Run:

```bash
flutter test
```

Expected: PASS.

### Task 17: Manual smoke check

**Files:**
- No new files.

- [ ] **Step 1: Run app**

Run:

```bash
flutter run -d windows
```

Expected: app launches.

- [ ] **Step 2: Smoke test flows**

Verify:
- drawer shows four destinations
- forwarding workbench still forwards as before
- tagging workbench loads from tag source chat
- clicking a tag updates message text/caption
- existing tag does not duplicate
- settings save/discard still works

- [ ] **Step 3: Stop app**

Stop the Flutter run session after the check.
