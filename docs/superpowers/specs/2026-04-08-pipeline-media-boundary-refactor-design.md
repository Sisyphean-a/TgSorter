# Pipeline Media Boundary Refactor Design

**Date:** 2026-04-08
**Status:** Draft approved in conversation, written for implementation review
**Scope:** Pipeline media playback, media-group presentation, navigation availability, and platform capability boundaries

---

## Goal

Refactor the current pipeline media stack so that media playback, media-group presentation, navigation availability, and platform-specific capability handling are governed by clear, non-leaky boundaries.

This round must solve the current failure pattern:

1. Platform capabilities are not centrally encapsulated
2. Media state is too coarse and video-biased
3. UI, coordinator, service, and platform helpers all infer overlapping state
4. Fixes often patch one layer while another layer keeps the old assumptions

The target architecture is:

1. Application layer owns pipeline session state and media session state
2. Service layer owns media preparation, playback capability, and platform resource actions
3. UI consumes unified view models and emits intent-based actions only
4. Media groups become first-class session objects instead of loosely merged preview fields

---

## Product Direction

The approved product direction for this refactor is:

1. Two-layer split:
   - application layer owns current item, navigation, and action availability
   - service layer owns download, playback, platform capability, and platform differences
2. Capability-tiered implementation with unified semantics:
   - upper layers always express the same intent vocabulary
   - lower layers may resolve that intent as inline playback, external open, or unsupported
   - UI semantics, button meaning, and error treatment remain consistent
3. Absorb the most valuable idea from a full preview-block redesign:
   - media groups become explicit session objects with active item, availability, and actions
   - but this round does not rewrite the whole preview model into a brand-new block system

---

## Non-Goals

This round does **not** include:

1. Rebuilding all preview rendering into a full block-renderer architecture
2. Replacing `PipelineMessage` with a brand-new domain model everywhere
3. Redesigning the overall pipeline page layout
4. Adding new end-user media features unrelated to boundary cleanup
5. Supporting every future platform equally in this round

The purpose of this refactor is not cosmetic cleanup. It is boundary repair and state-model correction.

---

## Current Problems

### 1. Shared runtime state is too wide

`PipelineRuntimeState` currently mixes:

1. current item and cache
2. navigation availability
3. loading and processing state
4. media preparation state
5. online state
6. remaining-count state

Multiple application services mutate the same state bucket directly. This makes local fixes unsafe because state ownership is ambiguous.

### 2. Media preparation state is too coarse

Current media state is effectively inferred from:

1. `videoPreparing`
2. `preparingMessageIds`
3. preview kind checks
4. whether local paths happen to be present

This is too coarse for media groups and too specific to video naming. Audio and grouped media are forced into the wrong abstraction.

### 3. Media preparation returns the wrong shape

The media-preparation flow currently returns refreshed `PipelineMessage` objects, which means the application layer must:

1. re-read refreshed message content
2. merge updated media fields back into the current grouped preview
3. maintain async correctness when current item changes

This leaks message projection concerns into media-session orchestration.

### 4. Navigation availability leaks from unrelated state

The current `canShowNext` logic depends partly on `remainingCount`. That means navigation availability is coupled to a count-oriented fetch estimate instead of a dedicated navigation model.

### 5. UI still decides too much

Current widgets still decide:

1. which `messageId` should be prepared
2. whether a missing local path means “still preparing” or “not available”
3. which file actions should render on which platform
4. whether retry behavior belongs inside the widget

That leaves UI patches unable to close the entire chain.

### 6. Platform capability is split across unrelated helpers

Platform behavior is currently spread across:

1. TDLib media preparation services
2. playback initializer functions called from startup
3. widget-level platform file actions

This means upper layers do not receive a single, stable capability model.

---

## Architectural Decision

### 1. Application layer owns session state and intent dispatch

The application layer will own:

1. which pipeline item is current
2. whether previous / next / classify / skip / undo are available
3. which media item inside a group is active
4. the request state of the current media session
5. the unified action set that UI should expose

The application layer will no longer infer platform support or call platform helpers directly.

### 2. Service layer owns capability resolution

The service layer will own:

1. preparing preview resources
2. preparing playback resources
3. resolving playback capability for the current platform
4. executing open / reveal / copy-path / open-link actions

The service layer will return stable capability and result objects instead of forcing the application layer to infer meaning from local file paths.

### 3. Media groups become session objects

The current preview content remains the content source of truth, but grouped media will gain an explicit session state projection:

1. active media item
2. item-level availability
3. session-level request state
4. available actions
5. failure state

This is the most valuable structural idea from a full block-based redesign, adopted without rewriting the entire content model.

---

## Target State Model

### Pipeline Session State

`PipelineSessionState` becomes the application-layer state for the pipeline workflow:

```dart
class PipelineSessionState {
  final List<PipelineMessage> items;
  final int currentIndex;
  final bool loading;
  final bool processing;
  final bool isOnline;
  final int? remainingCount;
  final bool remainingCountLoading;
  final NavigationAvailability navigation;
}
```

Responsibilities:

1. current pipeline item identity
2. cache ownership
3. workflow loading / processing state
4. online state
5. remaining-count display data
6. normalized navigation availability

### Navigation Availability

Navigation availability becomes explicit:

```dart
class NavigationAvailability {
  final bool canShowPrevious;
  final NextAvailability next;
}

enum NextAvailability {
  cached,
  fetchable,
  none,
}
```

`canShowNext` should be derived from `next != NextAvailability.none` at the VM layer, not stored as a separate truth source.

This removes the current ambiguity between:

1. next item already cached
2. next item not cached but still fetchable
3. truly no next item

### Media Session State

`MediaSessionState` becomes the application-layer state for the currently visible media group:

```dart
class MediaSessionState {
  final int? groupMessageId;
  final int? activeItemMessageId;
  final MediaRequestState requestState;
  final Map<int, MediaItemSessionState> items;
  final MediaGroupActions actions;
  final MediaFailure? failure;
}

enum MediaRequestState {
  idle,
  preparing,
  ready,
  failed,
}
```

Responsibilities:

1. current group identity
2. current active media item identity
3. session-level request state
4. group-level actions already filtered by capability
5. session-level failure reporting

### Media Item Session State

Each media item in the current group gets independent state:

```dart
class MediaItemSessionState {
  final int messageId;
  final MediaItemKind kind;
  final MediaAvailability previewAvailability;
  final MediaAvailability playbackAvailability;
  final PlaybackState playbackState;
  final LocalResource? previewResource;
  final LocalResource? playbackResource;
}

enum MediaAvailability {
  missing,
  preparing,
  ready,
  unavailable,
  failed,
}

enum PlaybackState {
  idle,
  loading,
  playing,
  paused,
}
```

This separates:

1. preview readiness
2. playback readiness
3. runtime playback state
4. external-action resource identity

These are currently blurred together behind local-path checks and a single preparing flag.

---

## Target Interfaces

### Application Controllers

The application layer should expose two focused controller surfaces.

#### Pipeline Session Controller

```dart
abstract interface class PipelineSessionController {
  Future<void> fetchNext();
  Future<void> navigatePrevious();
  Future<void> navigateNext();
  Future<void> skipCurrent({required String source});
  Future<bool> classify(String categoryKey);
  Future<void> undoLast();
  Future<void> retryNextFailed();
}
```

#### Media Session Controller

```dart
abstract interface class MediaSessionController {
  Future<void> selectItem(int messageId);
  Future<void> requestPreview(int messageId);
  Future<void> requestPlayback(int messageId);
  Future<void> performAction(MediaAction action);
}
```

#### Intent Objects

```dart
sealed class MediaAction {
  const MediaAction();
}

class OpenInApp extends MediaAction {
  const OpenInApp({required this.messageId});
  final int messageId;
}

class OpenExternally extends MediaAction {
  const OpenExternally({required this.messageId});
  final int messageId;
}

class RevealInFolder extends MediaAction {
  const RevealInFolder({required this.messageId});
  final int messageId;
}

class CopyPath extends MediaAction {
  const CopyPath({required this.messageId});
  final int messageId;
}

class OpenLink extends MediaAction {
  const OpenLink({required this.url});
  final Uri url;
}
```

UI should emit these intent-level actions instead of calling preparation, file-opening, or platform-aware helpers directly.

### Service-Layer Ports

#### Media Preparation Service

```dart
abstract interface class MediaPreparationService {
  Future<MediaPreparationResult> preparePreview(MediaHandle handle);
  Future<MediaPreparationResult> preparePlayback(MediaHandle handle);
}
```

Responsibilities:

1. trigger TDLib preview or playback preparation
2. refresh the relevant source message only when needed
3. return structured readiness results

It must not return a refreshed `PipelineMessage`.

#### Playback Capability Service

```dart
abstract interface class PlaybackCapabilityService {
  Future<void> initialize();
  PlaybackCapabilitySnapshot snapshot();
}

class PlaybackCapabilitySnapshot {
  final bool canInlineVideo;
  final bool canInlineAudio;
  final bool canFullscreenVideo;
}
```

Responsibilities:

1. initialize playback runtime
2. report supported inline/fullscreen playback modes
3. centralize capability matrix instead of scattering platform checks

#### Platform Resource Service

```dart
abstract interface class PlatformResourceService {
  Future<ActionResult> openResource(LocalResource resource);
  Future<ActionResult> revealResource(LocalResource resource);
  Future<ActionResult> copyPath(LocalResource resource);
  Future<ActionResult> openUrl(Uri url);
}

class ActionResult {
  final bool success;
  final String? message;
}
```

Responsibilities:

1. open files
2. reveal files in the system shell
3. copy paths
4. open links
5. return action results without embedding `BuildContext` or widget feedback logic

### Media Handle

To prevent the upper layers from passing loose file IDs and paths everywhere, the application layer should use a focused media handle:

```dart
class MediaHandle {
  final int groupMessageId;
  final int itemMessageId;
  final MediaItemKind kind;
  final String? previewPath;
  final String? playbackPath;
  final int? previewFileId;
  final int? playbackFileId;
}
```

This allows service-layer code to stay media-focused without depending directly on UI models.

---

## Projection and View-Model Strategy

### Preserve `PipelineMessage` as content model

This round should not replace `PipelineMessage` everywhere.

`PipelineMessage` remains:

1. the message-group content model
2. the unit used by pipeline fetch, classify, and undo flows
3. the source used to render message preview content

### Add a dedicated media-session projector

Introduce a projector that derives `MediaSessionState` from:

1. the current `PipelineMessage`
2. current service capability snapshots
3. latest preparation results
4. active item identity

This creates a clean separation:

1. `PipelineMessage` is the content model
2. `MediaSessionState` is the interaction model

That avoids a full model rewrite while still moving media groups into first-class session semantics.

### Unified UI view models

UI should consume view models, not raw application state pieces:

```dart
class PipelineScreenVm {
  final PipelineMessage? currentMessage;
  final NavigationVm navigation;
  final WorkflowVm workflow;
  final MediaSessionVm media;
}
```

The desktop view and mobile view should both rely on the same computed VM semantics instead of rebuilding enable/disable rules separately.

---

## Target Runtime Flow

### 1. Entering or changing the current pipeline item

When the current item changes:

1. `PipelineSessionController` updates `PipelineSessionState`
2. the media-session projector creates a new `MediaSessionState`
3. the active item is initialized deterministically
4. optional preview warm-up may be requested through `MediaSessionController.requestPreview`

UI must not own the “current active media item” truth source for a group viewer.

### 2. User requests playback

When playback is requested:

1. UI emits `requestPlayback(messageId)`
2. application layer resolves the `MediaHandle`
3. application layer marks that item and session as preparing
4. `MediaPreparationService.preparePlayback(handle)` executes
5. service layer returns a structured result:
   - resource ready
   - external-only fallback
   - unavailable
   - failed
6. application layer updates `MediaSessionState`
7. UI renders from session state only

### 3. User requests file or link actions

When a user requests open / reveal / copy / open-link:

1. UI emits an intent-level `MediaAction`
2. application layer resolves the correct `LocalResource` or URL
3. `PlatformResourceService` performs the action
4. application layer translates `ActionResult` into local UI feedback or error events

Widgets must not call platform helpers directly.

### 4. User switches active item inside a media group

When the user changes the active media item:

1. UI emits `selectItem(messageId)`
2. application layer updates `activeItemMessageId`
3. media VM updates accordingly
4. pipeline navigation stays unchanged

This removes the current split between local dialog page state and the actual media-session truth source.

---

## Migration Strategy

### Phase 1: Introduce state and service seams

1. Add new state objects and enums
2. Add service interfaces and adapters over current implementations
3. Add a media-session projector
4. Keep current preview content model intact

Goal:

1. no behavior loss
2. begin routing all new logic through explicit seams

### Phase 2: Refactor application orchestration

1. Shrink `PipelineCoordinator` into session-level orchestration
2. move media-session logic behind a clearer controller / service boundary
3. stop returning refreshed `PipelineMessage` from media-preparation paths
4. stop exposing video-specific preparing semantics as the main media state

Goal:

1. session state ownership becomes explicit
2. async merge logic no longer lives in the wrong layer

### Phase 3: Refactor UI inputs and actions

1. build unified `PipelineScreenVm`
2. route desktop and mobile views through shared enable/disable semantics
3. replace direct platform checks and direct file-helper calls with intent callbacks
4. move media widgets to session-driven rendering

Goal:

1. UI no longer decides platform capability or preparation semantics
2. desktop and mobile no longer drift in navigation rules

### Phase 4: Simplify and delete obsolete wiring

1. remove legacy `videoPreparing`-centric state
2. remove widget-level platform helper dependencies
3. delete merge code that exists only to compensate for old service contracts
4. collapse obsolete adapter glue once all callers are migrated

Goal:

1. no parallel old/new media state models remain in production code

---

## Testing Strategy

### Application-layer tests

Add or update tests that prove:

1. pipeline navigation availability distinguishes `cached`, `fetchable`, and `none`
2. media-session state transitions are correct for grouped media
3. switching active item does not affect pipeline navigation
4. request failures become media-session failure state, not global state corruption
5. navigation away and back preserves prepared session state correctly

### Service-layer tests

Add or update tests that prove:

1. media-preparation services return structured readiness results
2. playback capability snapshots are platform-normalized
3. platform resource actions return stable success/failure results
4. media preparation no longer requires returning refreshed `PipelineMessage`

### UI tests

Add or update tests that prove:

1. desktop and mobile consume the same navigation semantics
2. widgets render action availability from VM input, not platform checks
3. grouped media selection follows session state instead of local ad-hoc state
4. unavailable and failed media actions are rendered consistently across media types

### Regression targets

The following regressions must stay covered:

1. prepared media survives navigation away and back
2. stale async media updates do not overwrite a newer current item
3. media-group actions still operate on the correct message IDs
4. link actions remain available even when preview imagery is missing

---

## Risks and Controls

### Risk 1: Temporary dual-state confusion during migration

Control:

1. introduce new state shapes first
2. route one responsibility at a time
3. delete obsolete state as soon as callers are migrated

### Risk 2: UI regressions during VM migration

Control:

1. preserve existing rendering structure where possible
2. change data inputs before changing visuals
3. pin desktop and mobile behavior with focused tests

### Risk 3: Service boundary churn breaks current media preparation

Control:

1. start by adapting current implementations behind the new interfaces
2. only simplify internals after tests prove the new contracts

### Risk 4: Over-expansion into a full preview rewrite

Control:

1. keep `PipelineMessage` intact this round
2. only introduce the session projector and state model needed to stop boundary leaks
3. postpone broader content-model redesign

---

## Acceptance Criteria

This refactor is complete when all of the following are true:

1. media preparation state is no longer represented primarily by `videoPreparing`
2. navigation availability is derived from an explicit navigation model, not from ad-hoc boolean combinations
3. UI does not perform platform checks to decide media/file actions
4. media preparation services return capability/readiness results instead of refreshed `PipelineMessage`
5. desktop and mobile use the same navigation and media-action semantics
6. grouped media has an explicit active-item session state owned outside local widget state
7. platform file/link actions are provided by a service-layer capability, not a widget helper

---

## Summary

The refactor should not be treated as a widget cleanup or a service rename. It is a boundary correction:

1. application layer owns session state
2. service layer owns capability resolution
3. UI renders view models and emits intent
4. media groups become explicit session objects

That is the minimum structural shift required to stop the current pattern where local fixes repair one layer while old assumptions continue leaking from another.
