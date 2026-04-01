# Dynamic Categories And Message Browser Design

**Goal:** Replace the fixed three-category workflow with dynamic target chats, add safe in-memory previous/next browsing for unprocessed messages, and keep classify/delete ordering explicit and test-guarded.

## Summary

The current pipeline assumes exactly three categories (`a/b/c`) and treats the current message as a single mutable slot. That makes the UI rigid and prevents safe previous/next preview navigation. The settings UI also leaks target chat IDs into the main label, which is noisy and not useful for normal operation.

This design changes the app to:

- store zero or more dynamic target chat categories;
- use the selected chat title as the category label;
- render dynamic category buttons with adaptive layout;
- preload a small in-memory window of messages so users can browse previous/next before classifying;
- keep transfer safety strict: forwarding must succeed and return a target message before deletion is attempted.

## Data Model

- `CategoryConfig` becomes a dynamic target-chat record rather than a fixed named slot.
- `AppSettings.defaults()` starts with zero categories.
- Each category stores:
  - stable local key
  - `targetChatId`
  - `targetChatTitle`
- The previous free-form category name is removed.

## Settings UX

- Remove the old fixed A/B/C editors.
- Show a list of configured categories.
- Each row displays only the target chat title.
- Each row supports changing the bound chat or removing the category.
- Add an “新增分类” action that creates a new category by choosing from selectable chats.
- Prevent duplicate target-chat categories so the same destination is not shown twice.
- Keep source chat selection unchanged.
- Chat dropdown labels no longer append raw chat IDs.

## Pipeline UX

- Replace fixed 3-button rows with dynamic `Wrap`-based action buttons on both mobile and desktop.
- If there are no categories, show an empty-state hint instead of empty buttons.
- Keep skip / undo / retry controls, but remove any assumption that batch always targets category `a`.
- Disable classify actions while processing or offline, same as today.

## Previous / Next Browsing

- Replace the single-message fetch model with an in-memory browser state:
  - a cached ordered message list
  - the current visible index
  - a cursor for fetching more history when near the tail
- Initial load fetches a small page of messages from TDLib.
- “下一条” advances the visible index without mutating Telegram state.
- “上一条” decrements the visible index if a prior cached message exists.
- When the visible index approaches the end of the cache, fetch and append the next page.
- Classification removes the current message from the cache after TDLib confirms success, then selects the next available cached item.
- “跳过当前” becomes a convenience alias for advancing to the next cached message.

## Safety Guarantees

- The service must never call `deleteMessages` unless:
  - `forwardMessages` returned successfully, and
  - the result includes at least one forwarded target message.
- Failures remain explicit; no fallback delete behavior is introduced.
- Tests will lock in:
  - forward failure => no delete
  - empty forward result => no delete
  - successful forward with target message => delete allowed

## Testing

- Update settings repository/controller tests for dynamic zero-default categories.
- Add pipeline controller tests for:
  - previous/next browsing
  - classify removing the current cached item
  - empty category state
- Add telegram service tests for classify/delete safety.
- Update widget tests for dynamic category button rendering.
