# Dynamic Categories And Message Browser Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert the app from fixed categories to dynamic target chats, add previous/next browsing over cached unprocessed messages, and verify classify/delete safety with tests.

**Architecture:** The implementation keeps TDLib as the single message source while moving the controller/UI from a single-message slot to a cached message browser. Settings become dynamic target-chat records keyed by local IDs, and both mobile and desktop layouts render category actions from the configured category list. Classification remains a two-step forward-then-delete flow, with tests making that ordering explicit.

**Tech Stack:** Flutter, Dart, GetX, shared_preferences, flutter_test, TDLib Dart bindings

---

### Task 1: Refactor category settings model

**Files:**
- Modify: `lib/app/models/category_config.dart`
- Modify: `lib/app/models/app_settings.dart`
- Modify: `lib/app/services/settings_repository.dart`
- Test: `test/services/settings_repository_test.dart`

**Step 1: Write the failing test**

- Add tests that assert:
  - default settings contain zero categories;
  - categories persist with `targetChatId` and `targetChatTitle`;
  - removing categories clears stale stored entries.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/settings_repository_test.dart`

Expected: FAIL because the repository and defaults still assume fixed A/B/C categories.

**Step 3: Write minimal implementation**

- Remove fixed default categories from `AppSettings.defaults()`.
- Update `CategoryConfig` to store `targetChatTitle` instead of free-form `name`.
- Teach `SettingsRepository` to serialize a dynamic category list and clean obsolete keys.

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/settings_repository_test.dart`

Expected: PASS

### Task 2: Refactor settings controller for dynamic categories

**Files:**
- Modify: `lib/app/controllers/settings_controller.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Test: `test/controllers/settings_controller_test.dart`

**Step 1: Write the failing test**

- Add tests that assert:
  - a new category can be added from a selected chat;
  - duplicate target chat IDs are rejected;
  - removing a category persists;
  - selectable chat labels do not need raw IDs in UI-facing data.

**Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/settings_controller_test.dart`

Expected: FAIL because the controller only updates fixed category slots.

**Step 3: Write minimal implementation**

- Add `addCategory`, `updateCategoryTarget`, and `removeCategory` methods.
- Keep key generation local to the controller.
- Preserve source chat and proxy behaviors.

**Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/settings_controller_test.dart`

Expected: PASS

### Task 3: Replace settings page fixed editors with dynamic category management

**Files:**
- Modify: `lib/app/pages/settings_page.dart`
- Possibly modify: `lib/app/pages/settings_common_editors.dart`
- Test: `test/widgets/settings_page_test.dart`

**Step 1: Write the failing test**

- Add widget tests that assert:
  - the page shows zero categories by default;
  - tapping “新增分类” creates/selects a category;
  - configured rows display chat titles only, without appended chat IDs;
  - categories can be removed.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/settings_page_test.dart`

Expected: FAIL because the UI still renders three fixed category editors.

**Step 3: Write minimal implementation**

- Replace `_CategoryEditor` loop with a dynamic category list.
- Add an “新增分类” button and remove button per row.
- Render dropdown labels from chat title only.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/settings_page_test.dart`

Expected: PASS

### Task 4: Introduce cached previous/next browsing in the pipeline controller

**Files:**
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Modify: `lib/app/models/pipeline_message.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Test: `test/controllers/pipeline_controller_test.dart`

**Step 1: Write the failing test**

- Add tests that assert:
  - initial fetch loads a message cache and selects index 0;
  - next/previous move through cached messages without classifying;
  - classify removes the current item and selects the next cached item;
  - skip advances without mutating Telegram state;
  - no-category state leaves classify unavailable.

**Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/pipeline_controller_test.dart`

Expected: FAIL because the controller only manages a single `currentMessage`.

**Step 3: Write minimal implementation**

- Add cached browser state and current index management.
- Add `showPreviousMessage` and `showNextMessage`.
- Extend the gateway with page-based history fetch support or equivalent browser-friendly fetch calls.

**Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/pipeline_controller_test.dart`

Expected: PASS

### Task 5: Update TDLib service for paged browsing and classify/delete safety

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/services/td_message_dto.dart`
- Test: `test/services/telegram_service_test.dart`

**Step 1: Write the failing test**

- Add tests that assert:
  - history fetch can return a page of pipeline messages for browsing;
  - `classifyMessage` does not call delete when forward fails;
  - `classifyMessage` does not call delete when forward returns zero messages;
  - `classifyMessage` deletes only after a valid forwarded message exists.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/telegram_service_test.dart`

Expected: FAIL because the service does not yet expose page-based browser semantics and safety is not fully locked by tests.

**Step 3: Write minimal implementation**

- Add or reuse paged history fetch methods returning ordered browser messages.
- Keep explicit forward-then-delete ordering.
- Tighten guardrails around empty forward results.

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/telegram_service_test.dart`

Expected: PASS

### Task 6: Render dynamic actions and previous/next controls in pipeline views

**Files:**
- Modify: `lib/app/pages/pipeline_mobile_view.dart`
- Modify: `lib/app/pages/pipeline_desktop_view.dart`
- Modify: `lib/app/pages/pipeline_desktop_panels.dart`
- Test: `test/widgets/pipeline_page_test.dart`

**Step 1: Write the failing test**

- Add widget tests that assert:
  - dynamic category buttons render from settings;
  - no-category empty state is shown when none exist;
  - previous/next controls are present and call controller actions;
  - chat IDs are not shown in action labels.

**Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/pipeline_page_test.dart`

Expected: FAIL because the current layout still assumes fixed A/B/C buttons and no browser controls.

**Step 3: Write minimal implementation**

- Replace fixed rows with `Wrap`.
- Add previous/next buttons around the message browser controls.
- Remove batch action coupling to category `a`; hide or redesign batch if it no longer fits the dynamic model.

**Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/pipeline_page_test.dart`

Expected: PASS

### Task 7: Run focused and broad verification

**Files:**
- Test: `test/services/settings_repository_test.dart`
- Test: `test/controllers/settings_controller_test.dart`
- Test: `test/controllers/pipeline_controller_test.dart`
- Test: `test/services/telegram_service_test.dart`
- Test: `test/widgets/settings_page_test.dart`
- Test: `test/widgets/pipeline_page_test.dart`

**Step 1: Run focused tests**

Run:

```bash
flutter test test/services/settings_repository_test.dart
flutter test test/controllers/settings_controller_test.dart
flutter test test/controllers/pipeline_controller_test.dart
flutter test test/services/telegram_service_test.dart
flutter test test/widgets/settings_page_test.dart
flutter test test/widgets/pipeline_page_test.dart
```

Expected: PASS

**Step 2: Run broader regression tests**

Run: `flutter test`

Expected: PASS
