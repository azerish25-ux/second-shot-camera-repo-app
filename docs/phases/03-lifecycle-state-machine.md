# Phase 03 — lifecycle, effects, and concurrency

**Status:** PLANNED. **Dependencies:** phases 01–02. **Evidence:** none for the complete capture lifecycle.

## Outcome

Make capture behavior explainable and testable before attaching real sensors. One state machine owns the user's session; adapters execute bounded effects and return typed results. The current synthetic demo is not a complete production lifecycle. Future AR, recording, file IO, and export work must not each invent independent booleans that can disagree.

## Implementation tasks

1. Define production states in `Sources/SecondShotCore/Session/`: idle, requesting permission, preparing, ready, recording reference, finalizing reference, reference available, relocalizing, guiding, recording retake, finalizing retake, reviewing, exporting, interrupted, and failed. Use associated data to carry the relevant project/take/operation IDs.
2. Model user intents and adapter events separately. User intents include start/stop/cancel, select reference, retry, and delete. Adapter events include permissions resolved, tracking changed, writer finished/failed, app backgrounded, disk low, and export completed.
3. Implement a pure transition function that produces a new state plus declarative effects. Add typed rejection for illegal transitions. Repeated Stop/Cancel is idempotent; “export completed” cannot advance a different project's screen.
4. Implement a `SessionCoordinator` platform adapter under `Sources/SecondShotApp/Session/`. Isolate UI mutation to the main actor, file operations to a storage actor, and bounded media work to its documented queue. Inject clocks, permissions, capabilities, and frame sources.
5. Assign every asynchronous operation an ID and generation. Drop stale results after cancellation, project changes, or session resets. Cancellation must release buffers, stop sensor delivery where appropriate, and preserve an explicitly incomplete take when recovery is useful.
6. Define lifecycle rules for lock, background, incoming interruption, camera denial, thermal limit, and user exit. MVP recordings do not continue secretly in the background. Do not “pause” and resume inside one movie with discontinuous timestamps; finalize and create a new segment/take unless a separately tested segmentation feature is designed.

## Contracts

The UI renders state; it cannot claim a saved movie until the writer has completed and storage has committed its manifest. The app must distinguish `tracking unavailable`, `tracking limited`, and `frame stale`. UI time comes from a monotonic injected clock. Wall-clock changes must not move the recording timeline.

An interrupted retake must not look complete. Preserve the original reference and offer a clear retry/review/delete choice. A retry creates a new operation generation and, if AR was reset, a new tracking epoch requiring verified relocalization before comparisons.

## Verification

- **Core:** test every allowed transition and representative forbidden transitions; double taps; out-of-order callbacks; cancellation before/after writer finalization; interruption during each busy state; and switching projects during a slow operation.
- **Simulator UI:** launch deterministic demo states, inject denied permissions and tracking loss, verify visible text and reachable Stop/Cancel controls, and confirm review never opens with missing media marked successful.
- **Concurrency:** use deterministic fake actors with delayed completions rather than sleeps. Run thread/race diagnostics supported by the CI toolchain and review unsafe cross-actor object transfer explicitly.
- **Physical device:** actual OS interruption delivery belongs to phases 05–07 and later resilience work. Passing fake-event tests does not prove hardware behavior.

Provisional responsiveness target: a UI cancellation is acknowledged within 200 ms; expensive cleanup can continue with a visible state. Measure and revise with evidence, not by weakening the assertion when a test fails.

## Recovery and handoff

Crash recovery must not infer that `recording` means a valid playable asset exists. Reconcile persisted incomplete records on launch. Errors must include a user-safe action and a diagnostic code without private room or media content.

- [ ] Transition table and explicit illegal transitions reviewed.
- [ ] Stale results cannot affect a newer operation.
- [ ] No unbounded tasks, hidden recordings, or detached work with lost ownership.
- [ ] CI logs, deterministic scenarios, and unresolved device cases recorded.
- [ ] Coordinator commits/pushes a coherent checkpoint after review.
