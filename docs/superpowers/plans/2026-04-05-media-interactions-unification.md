# Media Interactions Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade message preview interactions for video, image, link, and audio into one coherent media interaction system with Windows-first external file actions.

**Architecture:** Keep the existing message viewer and preview routing, then add a shared media shell, capability-driven actions, and specialized fullscreen/gallery surfaces for rich interactions. Reuse the current media preparation callbacks and keep new failures local to the preview UI.

**Tech Stack:** Flutter, GetX state flow, `video_player`, `just_audio`, `url_launcher`, widget tests

---

### Task 1: Shared Media Action Infrastructure

**Files:**
- Create: `lib/app/shared/presentation/widgets/message_media_actions.dart`
- Create: `lib/app/shared/presentation/widgets/message_media_shell.dart`
- Create: `lib/app/shared/presentation/widgets/platform_file_actions.dart`
- Test: `test/widgets/message_media_actions_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests for:
- capability-driven action visibility
- platform file action availability
- stable shell action rendering

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
flutter test test/widgets/message_media_actions_test.dart
```

- [ ] **Step 3: Implement minimal shared action infrastructure**

Add:
- a unified media action model
- a reusable shell with top action area and optional footer/status area
- Windows-first platform file action helpers with clean fallback behavior

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
flutter test test/widgets/message_media_actions_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/app/shared/presentation/widgets/message_media_actions.dart lib/app/shared/presentation/widgets/message_media_shell.dart lib/app/shared/presentation/widgets/platform_file_actions.dart test/widgets/message_media_actions_test.dart
git commit -m "feat: add shared media interaction shell"
```

### Task 2: Video Interaction Upgrade

**Files:**
- Create: `lib/app/shared/presentation/widgets/message_preview_video.dart`
- Create: `lib/app/shared/presentation/widgets/message_preview_video_fullscreen.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_media.dart`
- Test: `test/widgets/message_preview_video_test.dart`

- [ ] **Step 1: Write the failing tests**

Cover:
- inline video action bar
- fullscreen entry and exit
- speed toggle
- loop toggle
- open original file / copy path availability

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
flutter test test/widgets/message_preview_video_test.dart
```

- [ ] **Step 3: Implement minimal video upgrade**

Refactor video preview out of `message_preview_media.dart` and add:
- richer inline controls
- fullscreen overlay
- shared action model integration
- Windows-first file actions

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
flutter test test/widgets/message_preview_video_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/app/shared/presentation/widgets/message_preview_video.dart lib/app/shared/presentation/widgets/message_preview_video_fullscreen.dart lib/app/shared/presentation/widgets/message_preview_media.dart test/widgets/message_preview_video_test.dart
git commit -m "feat: upgrade video preview interactions"
```

### Task 3: Image Gallery Upgrade

**Files:**
- Create: `lib/app/shared/presentation/widgets/message_preview_image_gallery.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_media.dart`
- Test: `test/widgets/message_preview_image_gallery_test.dart`

- [ ] **Step 1: Write the failing tests**

Cover:
- click-to-open image gallery
- multi-image navigation
- index display
- file action availability

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
flutter test test/widgets/message_preview_image_gallery_test.dart
```

- [ ] **Step 3: Implement minimal image gallery**

Add:
- lightbox dialog
- `InteractiveViewer` zoom/pan
- multi-image pager
- shared shell/action integration

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
flutter test test/widgets/message_preview_image_gallery_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/app/shared/presentation/widgets/message_preview_image_gallery.dart lib/app/shared/presentation/widgets/message_preview_media.dart test/widgets/message_preview_image_gallery_test.dart
git commit -m "feat: add image gallery interactions"
```

### Task 4: Link and Audio Upgrade

**Files:**
- Modify: `lib/app/shared/presentation/widgets/message_preview_link.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_audio.dart`
- Test: `test/widgets/message_preview_link_test.dart`
- Test: `test/widgets/message_preview_audio_test.dart`

- [ ] **Step 1: Write the failing tests**

Cover:
- link action buttons and expanded details
- audio progress display and speed controls
- file actions for audio

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
flutter test test/widgets/message_preview_link_test.dart test/widgets/message_preview_audio_test.dart
```

- [ ] **Step 3: Implement minimal link and audio enhancement**

Add:
- explicit link actions
- expandable detail area
- richer audio row controls and current state display
- shared shell/action integration

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
flutter test test/widgets/message_preview_link_test.dart test/widgets/message_preview_audio_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/app/shared/presentation/widgets/message_preview_link.dart lib/app/shared/presentation/widgets/message_preview_audio.dart test/widgets/message_preview_link_test.dart test/widgets/message_preview_audio_test.dart
git commit -m "feat: enhance link and audio interactions"
```

### Task 5: Regression Integration

**Files:**
- Modify: `test/widgets/message_viewer_card_test.dart`
- Modify: `test/pages/pipeline_mobile_view_test.dart`

- [ ] **Step 1: Write or extend regression tests**

Cover:
- existing media preparation callbacks still fire
- message card still renders and switches correctly
- richer media UI does not block primary preview behavior

- [ ] **Step 2: Run targeted regression tests**

Run:
```bash
flutter test test/widgets/message_viewer_card_test.dart test/pages/pipeline_mobile_view_test.dart
```

- [ ] **Step 3: Adjust implementation only if regressions surface**

Keep fixes constrained to preview interaction code.

- [ ] **Step 4: Run targeted regression tests again**

Run:
```bash
flutter test test/widgets/message_viewer_card_test.dart test/pages/pipeline_mobile_view_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add test/widgets/message_viewer_card_test.dart test/pages/pipeline_mobile_view_test.dart
git commit -m "test: add media interaction regression coverage"
```

### Task 6: Full Verification

**Files:**
- Modify: only if verification exposes defects

- [ ] **Step 1: Run focused interaction suite**

Run:
```bash
flutter test test/widgets/message_media_actions_test.dart test/widgets/message_preview_video_test.dart test/widgets/message_preview_image_gallery_test.dart test/widgets/message_preview_link_test.dart test/widgets/message_preview_audio_test.dart test/widgets/message_viewer_card_test.dart test/pages/pipeline_mobile_view_test.dart
```

- [ ] **Step 2: Run full repository verification**

Run:
```bash
flutter test
```

- [ ] **Step 3: Fix any discovered issues**

Keep fixes scoped to media interaction work.

- [ ] **Step 4: Re-run verification**

Run:
```bash
flutter test
```

- [ ] **Step 5: Commit final integration**

```bash
git add .
git commit -m "feat: unify media preview interactions"
```

