# Pipeline Media Boundary Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor pipeline media playback, media-group presentation, navigation availability, and platform capability wiring so state ownership and platform differences no longer leak across UI, coordinator, service, and widget helpers.

**Architecture:** Keep `PipelineMessage` as the content model, add explicit pipeline/media session state plus a projector, and move media preparation, playback capability, and platform resource actions behind service interfaces that return structured results instead of refreshed grouped messages. Desktop and mobile views should consume the same VM semantics and emit intent-level media actions only.

**Tech Stack:** Flutter, Dart, GetX, TDLib adapter/services, `video_player`, `video_player_media_kit`, `just_audio`, `url_launcher`, `flutter_test`

---

### Task 1: Introduce Explicit Pipeline and Media Session Models

**Files:**
- Create: `lib/app/features/pipeline/application/pipeline_session_state.dart`
- Create: `lib/app/features/pipeline/application/media_session_state.dart`
- Create: `lib/app/features/pipeline/application/pipeline_screen_view_model.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_runtime_state.dart`
- Modify: `test/features/pipeline/application/pipeline_navigation_service_test.dart`
- Create: `test/features/pipeline/application/media_session_state_test.dart`

- [ ] **Step 1: Write the failing navigation-availability test**

```dart
test('navigation availability distinguishes cached fetchable and none', () {
  final state = PipelineRuntimeState();
  final service = PipelineNavigationService(state: state);

  state.remainingCount.value = 5;
  service.replaceMessages(<PipelineMessage>[fakePipelineMessage(id: 101)]);

  expect(state.navigation.value.next, NextAvailability.fetchable);

  service.appendUniqueMessages(<PipelineMessage>[fakePipelineMessage(id: 102)]);
  expect(state.navigation.value.next, NextAvailability.cached);

  state.remainingCount.value = 1;
  service.syncNavigationState();
  expect(state.navigation.value.next, NextAvailability.cached);

  unawaited(service.showNext());
  service.syncNavigationState();
  expect(state.navigation.value.next, NextAvailability.none);
});
```

- [ ] **Step 2: Write the failing media-session projection test**

```dart
test('media session tracks active item and per-item availability', () {
  final message = PipelineMessage(
    id: 21,
    messageIds: const <int>[21, 22],
    sourceChatId: 8888,
    preview: const MessagePreview(
      kind: MessagePreviewKind.video,
      title: 'album',
      mediaItems: [
        MediaItemPreview(
          messageId: 21,
          kind: MediaItemKind.video,
          previewPath: 'C:/thumb-1.jpg',
        ),
        MediaItemPreview(
          messageId: 22,
          kind: MediaItemKind.video,
        ),
      ],
    ),
  );

  final session = MediaSessionState.fromMessage(message);

  expect(session.groupMessageId, 21);
  expect(session.activeItemMessageId, 21);
  expect(
    session.items[21]?.previewAvailability,
    MediaAvailability.ready,
  );
  expect(
    session.items[22]?.previewAvailability,
    MediaAvailability.missing,
  );
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/pipeline/application/pipeline_navigation_service_test.dart test/features/pipeline/application/media_session_state_test.dart`

Expected: FAIL with missing `NavigationAvailability`, `NextAvailability`, and `MediaSessionState` symbols.

- [ ] **Step 4: Add the new state models and runtime storage**

```dart
// lib/app/features/pipeline/application/pipeline_session_state.dart
enum NextAvailability { cached, fetchable, none }

class NavigationAvailability {
  const NavigationAvailability({
    required this.canShowPrevious,
    required this.next,
  });

  final bool canShowPrevious;
  final NextAvailability next;

  bool get canShowNext => next != NextAvailability.none;
}
```

```dart
// lib/app/features/pipeline/application/media_session_state.dart
enum MediaRequestState { idle, preparing, ready, failed }
enum MediaAvailability { missing, preparing, ready, unavailable, failed }
enum PlaybackState { idle, loading, playing, paused }

class MediaItemSessionState {
  const MediaItemSessionState({
    required this.messageId,
    required this.kind,
    required this.previewAvailability,
    required this.playbackAvailability,
    required this.playbackState,
    this.previewPath,
    this.playbackPath,
  });

  final int messageId;
  final MediaItemKind kind;
  final MediaAvailability previewAvailability;
  final MediaAvailability playbackAvailability;
  final PlaybackState playbackState;
  final String? previewPath;
  final String? playbackPath;
}
```

```dart
// lib/app/features/pipeline/application/pipeline_runtime_state.dart
class PipelineRuntimeState {
  final currentMessage = Rxn<PipelineMessage>();
  final navigation = Rx<NavigationAvailability>(
    const NavigationAvailability(
      canShowPrevious: false,
      next: NextAvailability.none,
    ),
  );
  final mediaSession = Rxn<MediaSessionState>();
  final loading = false.obs;
  final processing = false.obs;
  final isOnline = false.obs;
  final remainingCount = RxnInt();
  final remainingCountLoading = false.obs;

  final List<PipelineMessage> cache = <PipelineMessage>[];
  int currentIndex = -1;
}
```

- [ ] **Step 5: Run tests to verify the new models pass**

Run: `flutter test test/features/pipeline/application/pipeline_navigation_service_test.dart test/features/pipeline/application/media_session_state_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/app/features/pipeline/application/pipeline_session_state.dart \
  lib/app/features/pipeline/application/media_session_state.dart \
  lib/app/features/pipeline/application/pipeline_screen_view_model.dart \
  lib/app/features/pipeline/application/pipeline_runtime_state.dart \
  test/features/pipeline/application/pipeline_navigation_service_test.dart \
  test/features/pipeline/application/media_session_state_test.dart
git commit -m "refactor(pipeline): add explicit pipeline and media session state"
```

### Task 2: Introduce Structured Media Capability Services

**Files:**
- Create: `lib/app/services/media_preparation_service.dart`
- Create: `lib/app/services/playback_capability_service.dart`
- Create: `lib/app/services/platform_resource_service.dart`
- Create: `lib/app/services/default_playback_capability_service.dart`
- Create: `lib/app/services/default_platform_resource_service.dart`
- Modify: `lib/app/services/telegram_media_service.dart`
- Modify: `lib/app/services/audio_playback_initializer.dart`
- Modify: `lib/app/services/video_playback_initializer.dart`
- Modify: `lib/main.dart`
- Modify: `test/features/pipeline/application/pipeline_media_refresh_service_test.dart`
- Create: `test/services/default_playback_capability_service_test.dart`
- Create: `test/services/default_platform_resource_service_test.dart`

- [ ] **Step 1: Write the failing structured media-preparation test**

```dart
test('preparePlayback returns a structured result instead of PipelineMessage', () async {
  final service = PipelineMediaRefreshService(
    mediaPreparation: _FakeMediaPreparationService.videoReady(),
  );

  final result = await service.preparePlayback(
    handle: const MediaHandle(
      groupMessageId: 21,
      itemMessageId: 21,
      kind: MediaItemKind.video,
      playbackFileId: 1001,
    ),
  );

  expect(result.status, MediaPreparationStatus.ready);
  expect(result.playbackPath, '/tmp/video.mp4');
});
```

- [ ] **Step 2: Write the failing platform capability tests**

```dart
test('playback capability snapshot is centralized', () async {
  final service = DefaultPlaybackCapabilityService(
    platform: TargetPlatform.windows,
  );

  final snapshot = service.snapshot();

  expect(snapshot.canInlineVideo, isTrue);
  expect(snapshot.canInlineAudio, isTrue);
  expect(snapshot.canFullscreenVideo, isTrue);
});
```

```dart
test('platform resource service returns failed result for invalid url', () async {
  final service = DefaultPlatformResourceService();
  final result = await service.openUrl(Uri.parse('mailto:bad'));

  expect(result.success, isFalse);
  expect(result.message, isNotEmpty);
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/pipeline/application/pipeline_media_refresh_service_test.dart test/services/default_playback_capability_service_test.dart test/services/default_platform_resource_service_test.dart`

Expected: FAIL with missing service classes and the old `PipelineMediaRefreshService` contract.

- [ ] **Step 4: Add the new service contracts and default adapters**

```dart
// lib/app/services/media_preparation_service.dart
enum MediaPreparationStatus { ready, externalOnly, unavailable, failed }

class MediaHandle {
  const MediaHandle({
    required this.groupMessageId,
    required this.itemMessageId,
    required this.kind,
    this.previewPath,
    this.playbackPath,
    this.previewFileId,
    this.playbackFileId,
  });

  final int groupMessageId;
  final int itemMessageId;
  final MediaItemKind kind;
  final String? previewPath;
  final String? playbackPath;
  final int? previewFileId;
  final int? playbackFileId;
}

class MediaPreparationResult {
  const MediaPreparationResult({
    required this.status,
    this.previewPath,
    this.playbackPath,
    this.message,
  });

  final MediaPreparationStatus status;
  final String? previewPath;
  final String? playbackPath;
  final String? message;
}
```

```dart
// lib/app/services/playback_capability_service.dart
class PlaybackCapabilitySnapshot {
  const PlaybackCapabilitySnapshot({
    required this.canInlineVideo,
    required this.canInlineAudio,
    required this.canFullscreenVideo,
  });

  final bool canInlineVideo;
  final bool canInlineAudio;
  final bool canFullscreenVideo;
}
```

```dart
// lib/app/services/platform_resource_service.dart
class ActionResult {
  const ActionResult({required this.success, this.message});

  final bool success;
  final String? message;
}
```

- [ ] **Step 5: Adapt startup and media preparation callers**

```dart
// lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final playbackCapability = DefaultPlaybackCapabilityService.detect();
  await playbackCapability.initialize();
  // existing error wiring remains unchanged
  runApp(const BootstrapApp(init: registerAppBindings));
}
```

```dart
// lib/app/services/telegram_media_service.dart
Future<MediaPreparationResult> preparePlayback({
  required int sourceChatId,
  required int messageId,
}) async {
  final message = await _reader.loadMessage(sourceChatId, messageId);
  final content = message.content;
  await _mediaDownloadCoordinator.preparePlayback(content);
  final refreshed = await _reader.refreshMessage(
    sourceChatId: sourceChatId,
    messageId: messageId,
  );
  final preview = refreshed.preview;
  return MediaPreparationResult(
    status: MediaPreparationStatus.ready,
    previewPath: preview.localVideoThumbnailPath,
    playbackPath: preview.localVideoPath,
  );
}
```

- [ ] **Step 6: Run tests to verify the service boundary passes**

Run: `flutter test test/features/pipeline/application/pipeline_media_refresh_service_test.dart test/services/default_playback_capability_service_test.dart test/services/default_platform_resource_service_test.dart`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/app/services/media_preparation_service.dart \
  lib/app/services/playback_capability_service.dart \
  lib/app/services/platform_resource_service.dart \
  lib/app/services/default_playback_capability_service.dart \
  lib/app/services/default_platform_resource_service.dart \
  lib/app/services/telegram_media_service.dart \
  lib/main.dart \
  test/features/pipeline/application/pipeline_media_refresh_service_test.dart \
  test/services/default_playback_capability_service_test.dart \
  test/services/default_platform_resource_service_test.dart
git commit -m "refactor(services): centralize media capability contracts"
```

### Task 3: Refactor Application Orchestration Around Session State

**Files:**
- Create: `lib/app/features/pipeline/application/media_session_projector.dart`
- Create: `lib/app/features/pipeline/application/pipeline_media_session_controller.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_navigation_service.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_media_refresh_service.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `lib/app/core/di/pipeline_module.dart`
- Modify: `test/features/pipeline/application/pipeline_media_controller_test.dart`
- Modify: `test/features/pipeline/application/pipeline_coordinator_test.dart`

- [ ] **Step 1: Write the failing media-session controller test**

```dart
test('requestPlayback marks session preparing then ready for targeted item', () async {
  final state = PipelineRuntimeState();
  state.currentMessage.value = _groupVideoMessage();
  state.mediaSession.value = MediaSessionState.fromMessage(_groupVideoMessage());
  final controller = PipelineMediaSessionController(
    state: state,
    projector: const MediaSessionProjector(),
    mediaPreparation: _FakeMediaPreparationService.videoReady(),
  );

  await controller.requestPlayback(22);

  expect(state.mediaSession.value?.activeItemMessageId, 22);
  expect(state.mediaSession.value?.requestState, MediaRequestState.ready);
  expect(
    state.mediaSession.value?.items[22]?.playbackAvailability,
    MediaAvailability.ready,
  );
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/pipeline/application/pipeline_media_controller_test.dart test/features/pipeline/application/pipeline_coordinator_test.dart`

Expected: FAIL with missing `PipelineMediaSessionController`, `MediaSessionProjector`, and outdated coordinator/media-controller expectations.

- [ ] **Step 3: Add the projector and media-session controller**

```dart
// lib/app/features/pipeline/application/media_session_projector.dart
class MediaSessionProjector {
  const MediaSessionProjector();

  MediaSessionState project(PipelineMessage? message, {int? activeItemMessageId}) {
    if (message == null) {
      return const MediaSessionState.empty();
    }
    return MediaSessionState.fromMessage(
      message,
      activeItemMessageId: activeItemMessageId,
    );
  }
}
```

```dart
// lib/app/features/pipeline/application/pipeline_media_session_controller.dart
class PipelineMediaSessionController {
  PipelineMediaSessionController({
    required PipelineRuntimeState state,
    required MediaSessionProjector projector,
    required PipelineMediaRefreshService mediaPreparation,
  }) : _state = state,
       _projector = projector,
       _mediaPreparation = mediaPreparation;

  final PipelineRuntimeState _state;
  final MediaSessionProjector _projector;
  final PipelineMediaRefreshService _mediaPreparation;
}
```

- [ ] **Step 4: Update navigation and coordinator to use explicit session state**

```dart
// lib/app/features/pipeline/application/pipeline_navigation_service.dart
void syncNavigationState() {
  _state.navigation.value = NavigationAvailability(
    canShowPrevious: _state.currentIndex > 0,
    next: _resolveNextAvailability(),
  );
}
```

```dart
// lib/app/features/pipeline/application/pipeline_coordinator.dart
Future<void> navigateNext() async {
  final inFlight = _showNextTask;
  if (inFlight != null) {
    await inFlight;
    return;
  }
  final task = _navigateNextInternal();
  _showNextTask = task;
  try {
    await task;
  } finally {
    if (identical(_showNextTask, task)) {
      _showNextTask = null;
    }
  }
}
```

- [ ] **Step 5: Replace old merge-heavy media refresh flow**

```dart
// lib/app/features/pipeline/application/pipeline_media_refresh_service.dart
Future<MediaPreparationResult> preparePlayback({
  required MediaHandle handle,
}) {
  return _mediaPreparation.preparePlayback(handle);
}
```

```dart
// lib/app/features/pipeline/application/pipeline_media_controller.dart
@Deprecated('Use PipelineMediaSessionController instead')
class PipelineMediaController {
  // shrink this file to a compatibility shell, then delete in Task 5
}
```

- [ ] **Step 6: Run tests to verify the application orchestration passes**

Run: `flutter test test/features/pipeline/application/pipeline_media_controller_test.dart test/features/pipeline/application/pipeline_coordinator_test.dart test/features/pipeline/application/pipeline_navigation_service_test.dart`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/app/features/pipeline/application/media_session_projector.dart \
  lib/app/features/pipeline/application/pipeline_media_session_controller.dart \
  lib/app/features/pipeline/application/pipeline_navigation_service.dart \
  lib/app/features/pipeline/application/pipeline_media_refresh_service.dart \
  lib/app/features/pipeline/application/pipeline_media_controller.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  lib/app/core/di/pipeline_module.dart \
  test/features/pipeline/application/pipeline_media_controller_test.dart \
  test/features/pipeline/application/pipeline_coordinator_test.dart
git commit -m "refactor(pipeline): move media orchestration to session controller"
```

### Task 4: Migrate Desktop and Mobile UI to Unified VM and Intent Actions

**Files:**
- Modify: `lib/app/shared/presentation/widgets/message_viewer_card.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_content.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_media.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_audio.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_video.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_image_gallery.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_panels.dart`
- Modify: `test/pages/pipeline_mobile_view_test.dart`
- Modify: `test/pages/pipeline_layout_test.dart`

- [ ] **Step 1: Write the failing mobile-view VM test**

```dart
testWidgets('mobile view disables next button from navigation VM only', (tester) async {
  final vm = PipelineScreenVm(
    message: MessagePreviewVm(
      content: PipelineMessage(
        id: 1,
        messageIds: const <int>[1],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.text,
          title: 'hello',
        ),
      ),
      media: MediaSessionVm.empty(),
    ),
    navigation: const NavigationVm(
      canShowPrevious: false,
      canShowNext: false,
    ),
    workflow: const WorkflowVm(
      processingOverlay: false,
      online: true,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PipelineMobileView.fromVm(
          vm: vm,
          onNavigateNext: () async {},
          onNavigatePrevious: () async {},
          onMediaAction: (_) async {},
          onClassify: (_) async => false,
          onSkip: () async {},
          onUndo: () async {},
        ),
      ),
    ),
  );

  final button = tester.widget<OutlinedButton>(find.text('下一条'));
  expect(button.onPressed, isNull);
});
```

- [ ] **Step 2: Write the failing widget action-routing test**

```dart
testWidgets('message viewer forwards intent-level playback request', (tester) async {
  int? requestedId;
  final vm = MessagePreviewVm(
    content: PipelineMessage(
      id: 21,
      messageIds: const <int>[21],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
        mediaItems: [
          MediaItemPreview(messageId: 21, kind: MediaItemKind.video),
        ],
      ),
    ),
    media: MediaSessionVm(
      activeItemMessageId: 21,
      requestState: MediaRequestState.idle,
      items: const {
        21: MediaItemVm(
          messageId: 21,
          kind: MediaItemKind.video,
          canPlay: true,
        ),
      },
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MessageViewerCard(
        vm: vm,
        processing: false,
        onMediaAction: (action) {
          if (action case OpenInApp(:final messageId)) {
            requestedId = messageId;
          }
        },
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('message-video-play')));
  expect(requestedId, 21);
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/pages/pipeline_mobile_view_test.dart test/pages/pipeline_layout_test.dart`

Expected: FAIL with missing `PipelineScreenVm` inputs and outdated widget constructor contracts.

- [ ] **Step 4: Move desktop/mobile views to a single VM contract**

```dart
// lib/app/features/pipeline/presentation/pipeline_mobile_view.dart
return Obx(() {
  final vm = pipeline.screenVm.value;
  return MessageViewerCard(
    vm: vm.message,
    processing: vm.workflow.processingOverlay,
    onMediaAction: pipeline.performMediaAction,
  );
});
```

```dart
// lib/app/features/pipeline/presentation/pipeline_desktop_view.dart
Map<Type, Action<Intent>> _buildActionMap(PipelineScreenVm vm) {
  return {
    _PreviousIntent: CallbackAction<_PreviousIntent>(
      onInvoke: (_) => vm.navigation.canShowPrevious
          ? _fire(pipeline.navigatePrevious)
          : null,
    ),
  };
}
```

- [ ] **Step 5: Move preview widgets to session-driven rendering**

```dart
// lib/app/shared/presentation/widgets/message_preview_content.dart
if (vm.media.items.isEmpty) {
  return MessagePreviewText(vm: vm);
}

return MessagePreviewMedia(
  session: vm.media,
  onMediaAction: onMediaAction,
);
```

```dart
// lib/app/shared/presentation/widgets/message_preview_audio.dart
final item = session.activeItem;
final canReveal = item?.actions.canReveal ?? false;
```

- [ ] **Step 6: Run UI tests to verify desktop and mobile semantics pass**

Run: `flutter test test/pages/pipeline_mobile_view_test.dart test/pages/pipeline_layout_test.dart`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/app/shared/presentation/widgets/message_viewer_card.dart \
  lib/app/shared/presentation/widgets/message_preview_content.dart \
  lib/app/shared/presentation/widgets/message_preview_media.dart \
  lib/app/shared/presentation/widgets/message_preview_audio.dart \
  lib/app/shared/presentation/widgets/message_preview_video.dart \
  lib/app/shared/presentation/widgets/message_preview_image_gallery.dart \
  lib/app/features/pipeline/presentation/pipeline_mobile_view.dart \
  lib/app/features/pipeline/presentation/pipeline_desktop_view.dart \
  lib/app/features/pipeline/presentation/pipeline_desktop_panels.dart \
  test/pages/pipeline_mobile_view_test.dart \
  test/pages/pipeline_layout_test.dart
git commit -m "refactor(ui): consume unified pipeline and media view models"
```

### Task 5: Remove Legacy Media Wiring and Run Regression Verification

**Files:**
- Modify: `lib/app/features/pipeline/application/pipeline_runtime_state.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Delete: `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- Modify: `lib/app/shared/presentation/widgets/platform_file_actions.dart`
- Modify: `test/features/pipeline/application/pipeline_media_controller_test.dart`
- Modify: `test/services/media_download_coordinator_test.dart`
- Modify: `test/integration/auth_pipeline_flow_test.dart`
- Modify: `test/app/pipeline_ports_architecture_test.dart`

- [ ] **Step 1: Write the failing architecture regression test**

```dart
test('pipeline UI no longer depends on widget-level platform file actions', () async {
  final source = await File(
    'lib/app/shared/presentation/widgets/message_preview_audio.dart',
  ).readAsString();

  expect(source.contains('PlatformFileActions'), isFalse);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/app/pipeline_ports_architecture_test.dart test/integration/auth_pipeline_flow_test.dart`

Expected: FAIL while legacy media controller and widget-level platform helper references still exist.

- [ ] **Step 3: Delete legacy media state and compatibility wiring**

```dart
// lib/app/features/pipeline/application/pipeline_runtime_state.dart
class PipelineRuntimeState {
  final currentMessage = Rxn<PipelineMessage>();
  final navigation = Rx<NavigationAvailability>(
    const NavigationAvailability(
      canShowPrevious: false,
      next: NextAvailability.none,
    ),
  );
  final mediaSession = Rxn<MediaSessionState>();
  final loading = false.obs;
  final processing = false.obs;
  final isOnline = false.obs;
  final remainingCount = RxnInt();
  final remainingCountLoading = false.obs;
  final List<PipelineMessage> cache = <PipelineMessage>[];
  int currentIndex = -1;
}
```

```dart
// remove these fields everywhere
- final videoPreparing = false.obs;
- final preparingMessageIds = <int>{}.obs;
```

- [ ] **Step 4: Move `PlatformFileActions` behind the service boundary**

```dart
// lib/app/shared/presentation/widgets/platform_file_actions.dart
@Deprecated('Use PlatformResourceService instead')
class PlatformFileActions {
  const PlatformFileActions._();
}
```

```dart
// lib/app/shared/presentation/widgets/message_preview_audio.dart
await onMediaAction(
  const RevealInFolder(messageId: 21),
);
```

- [ ] **Step 5: Run the focused regression suite**

Run: `flutter test test/features/pipeline/application test/services test/pages/pipeline_mobile_view_test.dart test/pages/pipeline_layout_test.dart test/app/pipeline_ports_architecture_test.dart test/integration/auth_pipeline_flow_test.dart --timeout=60s`

Expected: PASS

- [ ] **Step 6: Run formatter and final full verification**

Run: `dart format lib test docs/superpowers/plans/2026-04-08-pipeline-media-boundary-refactor.md`

Expected: files formatted without error

Run: `flutter test --timeout=60s`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/app/features/pipeline/application/pipeline_runtime_state.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  lib/app/shared/presentation/widgets/platform_file_actions.dart \
  test/features/pipeline/application/pipeline_media_controller_test.dart \
  test/services/media_download_coordinator_test.dart \
  test/integration/auth_pipeline_flow_test.dart \
  test/app/pipeline_ports_architecture_test.dart
git rm lib/app/features/pipeline/application/pipeline_media_controller.dart
git commit -m "refactor(pipeline): remove legacy media wiring"
```
