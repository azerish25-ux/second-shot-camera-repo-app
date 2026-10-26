# Phase 08 — restore a reference without mixing coordinate spaces

**Status:** PLANNED. **Dependencies:** phase-07 hardware feasibility gate and phases 02–06. **Evidence:** no saved-world restoration proven.

## Outcome and exclusions

Let a user return to a recorded reference in the same environment while preserving the meaning of its coordinates. A new AR session does not automatically share the previous session's origin. Loading a world-map file is an attempt to restore spatial context, not proof of successful alignment. Moving to a different room must never appear as a successful zero-error retake.

## Implementation tasks

1. Add a `ReferenceMapStore` and `RelocalizationCoordinator` under `Sources/SecondShotApp/Capture/`. Persist a securely archived map only after suitable world-mapping state, together with the reference anchor ID, map ID, convention/schema version, configuration metadata, and an optional private visual start-point cue.
2. Keep map availability separate from take completeness. A video can be valid while its map is unsuitable for persistent restoration; the UI must state whether the reference can only be reused during the current uninterrupted session.
3. Load through `ARWorldTrackingConfiguration.initialWorldMap` using a deliberate state transition. Clear obsolete renderer state, wait for appropriate tracking and the expected reference anchor, then resolve `worldFromReference` in the restored world. Only then transform new camera samples into the stored reference frame.
4. Require matching reference identity and compatible camera/lens/intrinsics policy. Different physical lenses or a changed recording configuration need a documented recalibration path or a new reference. File UUID equality alone does not prove physical correspondence.
5. Show an actionable start-view guide: “Return to the original area and match this view,” with progress, Cancel, and a finite timeout. Initial timeout target is 20 seconds, with a user-initiated retry; never keep an unbounded spinner or claim that restoration always succeeds.
6. On timeout, corrupted map, missing anchor, or persistent limited tracking, offer retry, current-session-only use if genuinely valid, or create a new reference. Preserve the old project. A generic reset must invalidate comparisons until its coordinate relationship is re-established.
7. Record a structured restoration attempt with map/reference IDs, tracking epochs, duration, reason, and outcome. Exclude room imagery, feature points, and exact spatial data from normal logs and public evidence.

## Invariants

Spatial comparison is permitted only between samples transformed into the same reference frame. Restoring the expected anchor and obtaining normal tracking are necessary conditions, not an absolute-accuracy guarantee. Any additional visual consistency check is evidence with its own uncertainty; do not translate it into a fake centimeter confidence score.

Reference coordinates are immutable. If the restored map changes the current world estimate, resolve the current anchor transform and recompute the world-to-reference conversion; never rewrite the original trajectory to force an apparent match.

## Verification

**Core/simulator:** map absent; wrong reference ID; unsupported schema; missing anchor; timeout; cancellation; restored anchor after cancellation; reset mid-restoration; and a valid coordinate bridge with known transforms. Assert that all uncertain states suppress spatial correction cues.

**Device:** same-session return, app relaunch in the same scene, changed lighting, moved furniture, largely blank walls, and an intentionally different room. Repeat at least ten same-scene attempts per device and publish the complete success/time distribution, not only best cases. Wrong-room attempts must never be marked ready by the application's readiness checks.

Provisional target: at least 8 of 10 ordinary same-scene attempts restore within the chosen timeout on each baseline device. Failure prompts a bounded improvement or a documented same-session-only MVP; it is not permission to loosen the readiness definition secretly.

## Handoff checklist

- [ ] Map/privacy/schema decisions and readiness predicate reviewed.
- [ ] Simulator cancellation/mismatched-origin tests pass.
- [ ] Physical attempt ledger and limitations recorded with exact commit/device IDs.
- [ ] Failure cases preserve the original and offer a working recovery action.
- [ ] Coordinator commits/pushes; next phase receives only validated reference-space samples.

Primary references: [saving and loading world data](https://developer.apple.com/documentation/arkit/saving-and-loading-world-data) and [tracking lifecycle and indefinite relocalization](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality).
