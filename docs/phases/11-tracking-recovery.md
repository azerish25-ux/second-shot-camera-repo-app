# Phase 11 — loss, interruptions, and honest recovery

**Status: PLANNED.**

**Dependencies:** phase-03 lifecycle contracts, phase-07 capture evidence, phase-08 map restoration, and [phase 10](10-guided-retake.md). Read [capture coordinates](../architecture/capture-and-coordinates.md).

## Outcome and exclusions

A person must understand when guidance is unavailable, retain recoverable original footage, and have a clear way to retry or leave. An interrupted recording is not invisibly resumed into one continuous take. This phase does not build background camera recording, guess a replacement world origin, or use synthetic data as a fallback on a real iPhone.

## Implementation work

1. Extend `Sources/SecondShotCore/Capture/` with typed interruption events: tracking unavailable, insufficient features, excessive motion, relocalizing, session interruption, permission change, media-write failure, camera change, and thermal stop. Keep domain errors independent of localized strings.
2. In `Sources/SecondShotApp/Capture/CaptureCoordinator.swift`, bind AR session delegate events to the reducer. Serialize recording and writer transitions. Stop accepting new frames before finishing or cancelling a writer; a delayed callback from an old session must be rejected by its epoch token.
3. On lost/limited tracking during a take, stop trustworthy guidance immediately and finalize the available recording when possible. Mark the take `incomplete` with a reason and validity timeline. Keep salvageable media, but exclude invalid spans from matching. Do not patch gaps with invented poses.
4. Add a recovery panel that explains the observed problem in plain language: for example, “Tracking lost. Return to the starting view or save this partial take.” Offer retry, keep partial recording, and exit. Use a conservative timeout for relocalization, initially 15 seconds, followed by an explicit restart option; never spin indefinitely.
5. Recovery of a compatible saved map may restore the reference coordinate frame. Resetting tracking without that map creates a new origin identity and a new attempt. Do not relabel new coordinates with the old UUID merely because the room looks similar.
6. Handle app backgrounding, navigation away, audio-route interruptions, storage exhaustion, and thermal escalation. Critical thermal state ends capture cleanly. A format/quality downgrade can apply to a subsequent take only after disclosure, not in the middle of a comparable reference/retake pair.

## Interaction and persistence contract

Stop/Cancel remains reachable in every state. Do not hide warning text under the user's thumb or depend on amber alone. Restore the project, not an active recording, after app relaunch. A partial file becomes visible in the library only after the store verifies that it can be opened; otherwise show an actionable failure without claiming the clip was saved. Preserve structured failure reasons for optional user-exported diagnostics without uploading camera frames or room maps.

Apple documents that relocalization may never succeed if the previous environment cannot be reconciled. Treat tracking returning to normal as a prerequisite, not proof of a pixel-accurate camera match.

## Verification and provisional acceptance

- [ ] Table-driven reducer tests cover every interruption in preparation, countdown, reference capture, retake, finalization, and review. Assert allowed transitions and absence of duplicate finalization.
- [ ] Inject races: cancellation during writer completion, an old session recovering after a new attempt starts, permission denial during retry, and a disk failure at the final frame.
- [ ] Simulator UI tests use deterministic events to verify warnings, retry, preserving a partial take, and exit. Every synthetic error remains labeled as a demonstration.
- [ ] Physical tests include app switching, interrupted audio, low-texture walls, rapid motion, and returning to a changed scene, without unsafe movement.
- [ ] Acceptance requires zero known cross-origin appends, zero stale “on target” cues during invalid tracking, no indefinite recovery UI, and no destruction of an existing complete take. Measure recovery latency; do not infer it from UI screenshots.

## Evidence and handoff

Save transition coverage, fault-injection logs, the exact device/OS/commit, partial-file reopen results, and consented device observations. Each failure remains in the denominator. Commit recovery with its tests; document remaining unsupported interruption cases before proceeding to [review](12-review-and-time-alignment.md).

## Primary reference

- [Apple: managing session life cycle and tracking quality](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality).
