# Media Interactions Unification Design

**Date:** 2026-04-05
**Status:** Draft approved in conversation, written for implementation review
**Scope:** Message preview interactions for video, image, link, and audio content

---

## Goal

Upgrade the current message preview system into a complete media interaction layer that feels coherent, feature-complete, and visually stronger, while preserving the existing message workspace layout and primary classify/skip flow stability.

The target for this round is:

1. Stronger in-app preview interactions
2. Consistent external actions
3. Windows-first desktop completeness
4. Graceful fallback on other platforms

This work must be delivered in one implementation round instead of as scattered incremental widget tweaks.

---

## Non-Goals

This round does **not** include:

1. An embedded web browser
2. A new page-level media workspace
3. System sharing flows
4. Save-as/export pipelines
5. Rebuilding the overall message viewer page structure

The message card and pipeline layout stay in place. The enhancement is focused on the preview and interaction layer.

---

## Constraints

1. Keep the existing `MessageViewerCard` and preview entry flow intact
2. Reuse current media preparation flows instead of inventing a second download/playback path
3. Preserve current behavior when local files are not ready
4. Avoid introducing blocking loading states that hide already-visible content
5. Favor Windows-complete file actions, with explicit feature gating or graceful hiding elsewhere

---

## Product Direction

The requested direction is:

1. `All-in` media enhancement scope
2. `Balanced unified` interaction style
3. `Windows-first` completeness

That means the UI should stay visually controlled by default, then reveal richer controls when the user interacts. It should not become a dense tool panel at rest, and it should not become a fully immersive separate media application either.

The experience should feel like one system, not four unrelated preview widgets.

---

## Interaction Principles

### 1. Keep the current page skeleton

The workspace structure already works. The enhancement should happen inside the preview area, not by redesigning the whole pipeline page.

### 2. Separate preview state from interaction state

Examples:

- Preview state:
  - file missing
  - preparing
  - ready
  - local error
  - fullscreen open
- Interaction state:
  - toolbar visible
  - menu open
  - scrubbing
  - zooming
  - speed changed

These must not be compressed into one or two booleans, otherwise the UI will regress into the same kind of incorrect loading behavior that previously affected the first visible message.

### 3. Use one shared interaction vocabulary

Across all media types, the system should consistently support a common action model where applicable:

- open preview
- fullscreen
- open externally
- open original file
- reveal in system
- copy path or link
- more actions

Each media type may add specialized controls, but the user should not have to learn a completely different interaction pattern for each one.

### 4. External action failures stay local

If opening a file, launching a browser, or copying a path fails, the media card should show local feedback only. These failures should not pollute global app error state.

---

## Target Experience By Media Type

### Video

Video should support both fast inline control and a stronger fullscreen mode.

Inline video should provide:

1. play / pause
2. 10 second seek backward / forward
3. progress scrubbing
4. current position and duration
5. speed selection
6. mute / volume
7. loop toggle
8. fullscreen entry
9. external actions

Fullscreen video should provide:

1. immersive playback surface
2. a cleaner control bar
3. inherited playback position and state from inline preview
4. exit fullscreen
5. speed and volume controls
6. open file / reveal file / copy path actions

When the local file is not ready, the video preview must continue to use the current preparation pipeline. The UI should simply make the state clearer and the action more intentional.

### Image

Images should move from static preview to lightbox-style viewing.

Required interactions:

1. click to open preview
2. zoom
3. drag to pan
4. multi-image navigation
5. current index display
6. original file actions

Image fallback states should remain visually structured even when the local file is missing.

### Link

Link cards should evolve from “tap whole card to open browser” into a richer preview surface.

Required interactions:

1. main open-in-browser action
2. copy link action
3. expand details action
4. stronger visual hierarchy for site, title, description, and preview image
5. stable skeleton when preview imagery is absent

The card should still be easy to use, but not limited to one all-or-nothing tap target.

### Audio

Audio should become a real compact player instead of a simple trigger button.

Required interactions:

1. play / pause
2. progress bar
3. current position and duration
4. playback speed
5. clearer active-track state
6. track switching for albums
7. open / reveal / copy path actions

Audio does not need fullscreen in this round.

### Unified Interaction Layer

All preview surfaces should support:

1. a shared media shell
2. contextual toolbar behavior
3. a more-actions menu
4. unified loading treatment
5. unified local error treatment
6. consistent tooltip and affordance language

---

## Architecture

### Keep existing entry points, add a shared interaction layer

The current preview pipeline already selects and renders media by message type. That routing should stay in place. The change is to insert a shared interaction layer between the preview content and the outer message card.

### Proposed structural split

#### Existing files that remain, but change responsibility

1. `lib/app/shared/presentation/widgets/message_preview_media.dart`
   - becomes a thinner entry and routing layer
   - delegates actual video and image interaction logic out to focused widgets

2. `lib/app/shared/presentation/widgets/message_preview_audio.dart`
   - stays as audio entry point
   - upgraded into a richer player surface

3. `lib/app/shared/presentation/widgets/message_preview_link.dart`
   - stays as link entry point
   - upgraded into a richer card with explicit actions

#### New shared interaction files

1. `lib/app/shared/presentation/widgets/message_media_shell.dart`
   - common container for toolbar, status region, content frame, local error display, and action affordances

2. `lib/app/shared/presentation/widgets/message_media_actions.dart`
   - defines a unified action model for preview surfaces
   - allows each media type to declare which actions are available

3. `lib/app/shared/presentation/widgets/platform_file_actions.dart`
   - platform-aware helpers for open file / reveal file / copy path
   - Windows-first capability surface

#### New media-specific presentation files

1. `lib/app/shared/presentation/widgets/message_preview_video.dart`
   - focused inline video preview implementation

2. `lib/app/shared/presentation/widgets/message_preview_video_fullscreen.dart`
   - fullscreen presentation for video only

3. `lib/app/shared/presentation/widgets/message_preview_image_gallery.dart`
   - lightbox, zoom, pan, multi-image navigation

Audio may remain in one file unless complexity justifies a secondary controls file during implementation.

---

## Data and State Flow

### Existing media preparation stays authoritative

The current playback/prepare callbacks remain the source of truth for preparing local media. The new preview UI does not replace the underlying media preparation path.

### View-local interaction state

Each enhanced preview owns its own transient UI state, such as:

- toolbar visibility
- scrubbing
- selected speed
- zoom transform
- fullscreen open
- expanded details

These states should stay local to the preview widget or dialog layer, not be promoted into pipeline coordinator state.

### Shared playback state handoff

Video fullscreen must inherit enough state from inline preview to feel continuous:

1. active media path
2. playback position
3. play / pause state
4. speed
5. loop setting

However, it should not inherit transient card-only UI details such as whether the inline toolbar was visible.

### Capability-driven action visibility

Buttons should be shown based on actual capability, not optimistic assumptions.

Examples:

1. no local path -> hide file actions
2. unsupported platform -> hide reveal/open-system action
3. invalid URL -> hide browser action

This avoids dead controls and reduces noisy failure handling.

---

## Platform Behavior

### Windows

Windows is the priority platform for completeness. It should support:

1. open local file
2. reveal file in system shell
3. copy local path
4. stronger desktop-style hover/tool affordances

### Android and other platforms

The UI should not regress. Unsupported features should be hidden or downgraded cleanly.

Examples:

1. if revealing a file in system shell is not supported, do not render that action
2. keep browser open and copy-link actions where available
3. preserve media playback and preview features even if file-system actions are reduced

---

## Visual Direction

The visual style should stay aligned with the current app, but become more deliberate.

### Shared visual rules

1. controlled default density
2. clearer elevation and borders for active media surfaces
3. stronger overlay treatment for interactive media
4. consistent iconography and action grouping
5. no giant always-visible toolbars

### Interaction reveal pattern

Recommended behavior:

1. compact by default
2. reveal controls on hover, focus, tap, or fullscreen
3. preserve key actions even when overlays fade

This supports both desktop efficiency and richer media presentation without overwhelming the workspace.

---

## Error Handling

### Local preview errors

Local media failures should stay within the preview surface:

1. failed video init
2. bad local file
3. browser open failure
4. file action failure

The preview should show:

1. readable error copy
2. retry or alternate action where sensible
3. no escalation to app-wide error state

### Existing global flow errors remain untouched

Pipeline/auth/settings error handling already serves higher-level workflows. This media round should not re-route local interaction failures into those systems.

---

## Testing Strategy

### Logic tests

Add focused tests for:

1. action availability mapping
2. platform capability gating
3. file-action fallback behavior

### Widget tests

Add or expand tests covering:

1. video inline controls
2. fullscreen entry / exit
3. image lightbox open and image navigation
4. link action buttons
5. audio controls and active track state
6. more-actions menu rendering

### Regression coverage

Explicitly verify that:

1. media not ready still triggers the existing preparation callback
2. preview enhancement does not break message card rendering
3. pipeline message switching still updates immediately
4. classify / skip flow is unaffected by richer preview widgets

### Full-suite verification

Run complete `flutter test` after the targeted suite passes.

---

## Implementation Risks

1. `message_preview_media.dart` is already doing too much, so refactoring must shrink responsibility rather than add more logic in place
2. fullscreen and inline video state can drift if controller handoff is designed poorly
3. platform file actions can become noisy if unsupported capabilities are not hidden up front
4. visual polish can accidentally create more blocking or loading overlays if state boundaries are not kept clean

The implementation should prefer smaller focused widgets and explicit capability checks to keep this manageable.

---

## Acceptance Criteria

This design is considered implemented successfully when:

1. video supports inline control plus fullscreen playback
2. images support immersive preview with navigation and zoom
3. links expose richer actions than a single card tap
4. audio behaves like a compact player, not only a fetch trigger
5. all media types share a coherent action pattern
6. Windows gets complete local-file actions
7. unsupported platforms degrade without broken controls
8. existing preview preparation and pipeline flow remain stable
9. targeted tests and full `flutter test` pass

