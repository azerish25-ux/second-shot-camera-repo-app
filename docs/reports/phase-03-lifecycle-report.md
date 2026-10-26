# Phase 03 — lifecycle, effects, operation identity

Status: **PARTIAL**. The production lifecycle, the platform adapter that executes
its effects, the injected providers, the storage actor, the serialized media queue
and the fault journeys all exist and are evidenced. Two acceptance items remain
open and are named in [Residual gaps](#residual-gaps): project switching during a
slow operation, and launch reconciliation of persisted incomplete records (phase 04
owns project packages and recovery).

Nothing in this report is physical-device evidence. No camera, microphone, AR
session, sensor or real movie exists yet, and no accuracy or precision claim is made.

## Scope and prerequisites

- Phase specification: [phase 03](../phases/03-lifecycle-state-machine.md).
  Prerequisites: [phase 02](phase-02-pose-math-report.md) (complete),
  [capture contract](../architecture/capture-and-coordinates.md) §4–5.
- Implemented in this step: `SessionCoordinator` (main-actor state mutation), the
  storage actor, the media write queue, injected clock/permission/capability/capture/
  export seams with synthetic implementations, token-and-phase-checked reply
  handling, token-scoped abandonment, deterministic fault journeys in the app and UI
  suites, and a measured cancellation budget.
- Not implemented: ARKit/AVFoundation capture, world-map persistence and verified
  relocalization, launch-time reconciliation, project switching, export rendering.
- Not claimed: real interruption delivery, background/thermal behaviour, writer
  behaviour on a physical device, spatial precision, or that a simulation is a
  camera.

## What the coordinator now executes

The reducer stays pure and decides *what* should happen. `SessionCoordinator` is the
only place that mutates UI state, awaits adapters and feeds results back as events.
Every effect in `SessionEffect` is executed rather than carried as a value:

| Effect | Executed as | Reply |
| --- | --- | --- |
| `requestCapturePermission` | camera permission status, then a prompt only when undetermined | `permissionsResolved` |
| `prepareCapture` | capability probe, then `CaptureProviding.prepare()` | `capturePrepared` / `preparationFailed` |
| `releaseCapturePreparation` | `releasePreparation()` (idempotent) | — |
| `startReferenceCapture` / `startRetakeCapture` | `startCapture(request)` which writes the incomplete record, opens exactly one writer and writes synthetic placeholder media | — (failure → `captureFailed`) |
| `stopReferenceCapture` / `stopRetakeCapture` | `finishCapture(token:)`: finalize the writer, commit the record, return the take | `referenceSaved` / `referenceFailed`, `retakeSaved` / `retakeFailed` |
| `discardReferenceCapture` / `discardRetakeCapture` | `abandonCapture(token:)`: close the writer, delete the media, remove the record | — |
| `preserveIncompleteTake` | `preserveCapture(token:)` plus an incomplete record write | — |
| `beginRelocalization` / `cancelRelocalization` | adapter relocalization call | `relocalized` / `relocalizationFailed` |
| `startGuidance` / `stopGuidance` | records the reference being guided | — |
| `beginExport` / `cancelExport` | export seam (currently `UnavailableTakeExport`) | `exportFinished` / `exportFailed` |
| `stopSensors` | `stopSensors()` | — |

Isolation: UI state lives on the main actor, records in a `ProjectStore` actor
(one JSON manifest per attempt, written with an atomic replace), media work in a
`MediaWriteQueue` actor that permits exactly one open writer and logs every open,
finalize and discard in order. The clock, permissions, capabilities, capture and
export are protocols with synthetic implementations used by the app and by the
journeys; the real ARKit/AVFoundation implementations plug into the same seams.

### Reply policy

Every reply passes two checks before it may change anything:

1. **Phase and identity.** The coordinator only delivers a reply while the session
   still waits for that operation — the expected phase *and*, where the reducer
   minted one, the `<kind>-<generation>` token must still match.
2. **Ownership.** The export reply carries the project the adapter claims it
   exported; a reply for another project is refused by the reducer as a foreign
   project.

A refused reply is recorded in `droppedReplies` with a reason (`staleToken`,
`foreignProject`, `noLongerExpected`) and never mutated state. A transition that
cannot be explained by staleness or foreign ownership is recorded separately in
`unexpectedFailures`; every journey asserts that list stays empty, so a genuine
defect fails loudly instead of looking like a dropped reply.

A take whose reply is no longer wanted is never published. What happens to its media
and record depends on *why* the session moved on:

- **Interruption** (tracking loss, backgrounding, lock, thermal, camera denial):
  the attempt is preserved — writer closed, media kept, record written as
  `incomplete` — because recovery has something to reconcile.
- **Cancellation or a newer attempt**: the attempt is discarded by token, so it
  leaves neither an open writer nor a record nor a file behind, even when its writer
  had already finalized and committed before the cancellation arrived. Because the
  abandonment names the attempt, a late reply for an old attempt can never delete a
  newer attempt's work (asserted directly).

Cancel, interrupt and duplicate stops are idempotent, and a second stop while the
writer is finalizing issues no second writer command (asserted on the writer log).

### Cancellation budget, measured

Cancellation latency is measured with the injected monotonic clock from the intent
being accepted to the writer being closed and its resources released. The synthetic
adapters model device-representative costs per operation (abandon 30 ms, sensor stop
5 ms, writer finalize 55 ms, preparation 40 ms, start 25 ms, relocalization 120 ms),
so the measurement is the sum of the work the app actually awaited rather than a
constant.

| Path | Measured | Budget | Evidence |
| --- | --- | --- | --- |
| Cancel while recording a reference | **35.0 ms** | 200 ms | `testCancellationLatencyIsMeasuredWithTheInjectedClockAndInsideTheBudget` |
| Cancel while the writer is finalizing | **35.0 ms** | 200 ms | `testCancellingWhileFinalizingIsAlsoMeasuredInsideTheBudget` |

Honest limits: these are *modelled* adapter costs, not a measurement of iOS. The
arithmetic, the instrumentation and the assertion are real and deterministic, and
they would catch a coordinator that awaited more work than the budget allows. They
do not prove that a real `AVAssetWriter` closes within 200 ms on a device, which
needs phase 05–07 hardware evidence.

## Fault-journey coverage

All journeys run deterministically with no sleeps: `SessionHold` lets a journey park
an adapter inside a named operation (`permission`, `prepare`, `startCapture`,
`relocalize`, `finalize`, `export`), observe the session while that operation is in
flight, and release it. Every journey also asserts the terminal invariants: no open
writer, no adapter still parked, no unexplained transition, and — where applicable —
that no record or media file survives.

| Journey | Injected fault | Terminal invariant observed | Test (app suite) |
| --- | --- | --- | --- |
| Reference happy path | none | one record, `complete` only after the writer finalized; `incomplete` while recording; ordered writer log | `testReferenceJourneyExecutesEveryReducersEffectAndCommitsOneCompleteRecord` |
| Retake happy path | none | two committed records, review reachable, guidance bound to the saved reference | `testRetakeJourneyReachesReviewWithTwoCommittedRecords` |
| Duplicate stop while finalizing | held finalize | idempotent; writer finalized exactly once | `testARepeatedStopWhileFinalizingFinalizesTheWriterExactlyOnce` |
| Permission denied (permanent) | `permissionDenied` | interrupted as `cameraDenied`, code `permission-camera-denied`, no record/media/reference | `testPermanentCameraDenialStaysInterruptedAndNeverClaimsAReference` |
| Denied → granted via Settings return | `permissionDeniedThenGranted` + `applicationBecameActive()` | re-queried, `ready`, reference saved (`reference-take-3`) | `testDeniedCameraAccessIsRequeriedWhenTheAppReturnsToTheForeground` |
| Permanent refusal later granted | `permissions.grant(.camera)` + foreground | `ready`, reference saved | `testAccessGrantedAfterAPermanentRefusalIsPickedUpOnReturn` |
| Preparation failure then retry | `preparationFailure` (one-shot) | `failed` with `capture-prepare-unavailable`; retry reaches `ready` | `testPreparationFailureIsRecoverableAndReportsAContentFreeCode` |
| Writer-creation failure | media queue `writerCreation` | `failed` with `writer-create-1`; no record, no media, no writer | `testWriterCreationFailureEndsTheAttemptWithoutPublishingARecord` |
| Writer-finalize failure after capture | media queue `writerFinalize` | `failed` with `writer-finalize-2`; record `incomplete`, media kept, writer discarded | `testWriterFinalizeFailureLeavesOneIncompleteRecordAndNoOpenWriter` |
| Cancel before finalization | — | `idle`; no record, media or writer; `noLongerExpected` drop | `testCancellingWhileRecordingLeavesNoWriterNoMediaAndNoRecord` |
| Cancel after finalization | held finalize | `idle`; the committed record and file are both removed; `staleToken` drop | `testCancellingAfterTheWriterFinalizedLeavesNoRecordAndNoMedia` |
| Late reply after a new attempt started | held finalize + cancel + new attempt | reply refused; the new attempt's record and media intact | `testALateReplyForAnEndedAttemptIsIgnoredWhileANewAttemptIsRecording` |
| Tracking loss in requesting permission | held permission | not dispatched; path completes; no defect | `testTrackingLossWhileRequestingPermissionIsNotDispatched` |
| Tracking loss in preparing | held prepare | not dispatched; path completes; no defect | `testTrackingLossWhilePreparingIsNotDispatched` |
| Tracking loss in recording a reference | held startCapture | interrupted; attempt preserved `incomplete`; writer closed; never reviewable | `testTrackingLossWhileRecordingAReferencePreservesAnIncompleteAttempt` |
| Tracking loss in finalizing a reference | held finalize | take kept unpublished; record demoted to `incomplete` | `testTrackingLossWhileFinalizingAReferenceKeepsTheTakeUnpublished` |
| Tracking loss in recording a retake | held startCapture | ended; retake record `incomplete`; never reviewable; recovery explicit | `testTrackingLossWhileRecordingARetakeEndsTheAttemptAndIsNeverReviewable` |
| Tracking loss in finalizing a retake | held finalize | kept unpublished; `staleToken` drop | `testTrackingLossWhileFinalizingARetakeKeepsItUnpublished` |
| Tracking loss in relocalizing | held relocalize | ended; late `relocalized` dropped; saved reference survives | `testTrackingLossWhileRelocalizingEndsTheAttemptBeforeItStarts` |
| Tracking loss in exporting | held export | not dispatched; export path completes | `testExportReportsUnavailableThroughTheRealPathAndReturnsToReview` |
| `limited` tracking | `.limited` report | ends the attempt (`tracking-limited`); a later `normal` report never resumes it | `testLimitedTrackingEndsTheAttemptAndANormalReportNeverResumesIt` |
| Relocalization failure | adapter failure | `interrupted` as `sceneNotRecognized`; recovery deliberate; second attempt succeeds | `testRelocalizationFailureEndsTheAttemptWithoutGuidance` |
| Foreign-project export reply | exporter naming another project | refused as `foreignProject`; screen does not advance | `testAReplyForAnotherProjectIsRefusedInsteadOfAdvancingThisScreen` |
| Every fault profile ends clean | all six profiles | no open writer, no parked adapter, no unexplained transition | `testEveryJourneyEndsWithNoOpenWriterAndNoHeldAdapter` |

Simulator UI journeys inject the same faults through `-ss-fault <profile>` and assert
what a person sees: `Tests/SecondShotUITests/SessionFaultJourneyUITests.swift` covers
denied-then-granted permission (including a real background/foreground round trip),
a recoverable preparation failure, and writer-creation/finalize failures that must
never claim a reference. The existing demo journey continues to assert that an ended
attempt is not offered as reviewable and that export explains its own absence.

App-facing tests in `Tests/SecondShotAppTests/DemoSessionStoreTests.swift` check the
surface a person interacts with: elapsed capture time comes from the injected clock,
ending a journey leaves no scheduled update loop and no open writer, and every
adapter fault reaches the screen as a user-facing reason plus a content-free code.
Core tests in `Tests/SecondShotCoreTests/SessionStateMachineTests.swift` cover the
transition table, including the writer-creation failure path added in this step and
representative forbidden transitions.

## Observed verification

| Command / experiment | Environment | Result | Evidence |
| --- | --- | --- | --- |
| `swift test` | Linux x86_64, Swift 6.0.3 | 82 tests, 0 failures | local run |
| `bash scripts/ci/verify_session_layer.sh` | same host | 26 session-layer journeys, 0 failures; measured cancellation 35.0 ms on both paths | local run, printed by the latency tests |
| `python3 -B -m unittest discover -s scripts -p 'test_*.py'` | Python 3.12.3 | passed | local run |
| `python3 -B scripts/ci/check_repository.py` | same host | passed | local run |
| Repository checks on the pushed head | GitHub Actions, ubuntu runner | recorded in [STATUS](../STATUS.md) | run linked there |
| iOS Simulator workflow on the pushed head (compile + core/app/UI suites + evidence validation + Thread Sanitizer unit run) | macos-26, workflow-selected Xcode 26.x | recorded in [STATUS](../STATUS.md) | run linked there |

`scripts/ci/verify_session_layer.sh` assembles a throwaway Swift package from the
session-layer sources and the journey tests so those journeys can run on Linux before
CI reaches macOS. It exists because it found real defects in seconds that would
otherwise have surfaced only after a multi-minute simulator run; it does not compile
the SwiftUI app and is not a substitute for the simulator workflow.

Defects found and fixed while building this slice (none by weakening an assertion):

1. `OperationToken` was not `Hashable`, so an adapter could not index in-flight
   attempts by identity. It is now `Hashable` in the core, which is what lets a late
   cancellation still discard exactly its own attempt.
2. The media-queue fault was defined but never injected, so the writer-failure
   journeys silently exercised a healthy writer. The composition root now passes the
   profile's fault into the queue at construction.
3. `SessionHold` announced arrival before registering the release continuation, so a
   journey that released immediately after seeing the arrival could leave an adapter
   parked forever. Registration and announcement are now one synchronous step.
4. A local `record` variable shadowed the coordinator's own error-recording method.
5. A no-op `preserveIncompleteTake` for attempts whose writer was never created
   would have written an incomplete record for a take that never captured anything.
   Preservation is now gated on the capture path actually having begun.
6. One journey closed a hold point it never reached, which hung rather than failing
   and is exactly why the hold primitive is explicit.
7. Found by the simulator workflow, not locally: `DemoSessionStore` called the
   main-actor-isolated `SessionEnvironment.synthetic` from a *default argument*,
   which Swift evaluates outside the actor, so the app target did not compile while
   the whole session-layer harness stayed green. The composition is now built inside
   the initializer. Recorded because it marks the real boundary of the harness's
   coverage: an app-target isolation defect is only visible to the macOS build.

## Residual gaps

Named precisely, so PARTIAL is not a vague hedge:

1. **Project switching during a slow operation** is unexercised. The app has one
   demo project and no project switcher; what *is* evidenced is the operation
   identity and the foreign-project refusal that make switching safe.
2. **Launch reconciliation of persisted incomplete records** is not implemented.
   Phase 03 guarantees that a record cannot look complete before its writer
   finalized, and that an interrupted attempt is preserved as `incomplete`; the
   recovery pass that reconciles those records at launch belongs with the phase-04
   project package.
3. **Verified relocalization and tracking epochs** are not implemented. The reducer
   and the second attempt carry a new generation, `limited`/`unavailable` tracking
   ends an attempt, and `PoseTrack` refuses mixed origins and epochs from phase 02;
   the AR world-map epoch itself arrives with phases 05–07.
4. **The cancellation budget is modelled, not measured on a device** (see above).
5. **No concurrency finding is device evidence.** Thread Sanitizer runs the unit
   suites in CI; it says nothing about ARKit, AVFoundation or real interruption
   delivery.
6. **Everything is simulator-only.** G1 (capture integrity) and G2 (useful retakes)
   remain BLOCKED_DEVICE.

### Cross-actor transfer review

The spec asks for an explicit review of unsafe cross-actor transfer. What crosses an
actor boundary here is only value types conforming to `Sendable`: `SessionState`,
`SessionIntent`, `SessionEvent`, `SessionEffect`, `OperationToken`, `TakeID`,
`ProjectID`, `OperationID`, `CaptureRequest`, `CaptureCapabilities`, `SessionRecord`,
`MediaWriteEntry`, `ExportOutcome` and the `TrackingAvailability`/`TrackingReason`
enums. No buffer, pixel buffer, image, audio or AVAsset object crosses a boundary in
this phase because none exists yet. Shared mutable state is limited to three
`@unchecked Sendable` synthetic providers, each guarding its state with an `NSLock`,
and the app's own `SyntheticSessionClock`, which does the same. The coordinator never
sends a closure into an adapter, and no adapter calls back into the coordinator: a
result is returned from an awaited call and the coordinator decides what it means.

## Gate decision

- Acceptance for the adapter and journeys: every effect is executed; operation
  identity is honoured end to end; stale and foreign replies are dropped and
  asserted to be dropped; cancellation before and after finalization leaves no
  orphan; interruption in every busy phase ends the attempt and never resumes it;
  the cancellation budget is measured and inside 200 ms; no unbounded task, hidden
  recording or detached work remains (asserted by the ticker and writer invariants).
- Outcome: **continue**. Phase 03 stays **PARTIAL** with gaps 1–6 above.
- No threshold was relaxed. The 200 ms target is measured, not assumed.

## Handoff and publication

- Next executable task: [phase 04](../phases/04-project-storage.md) — the local
  project package, atomic publication and launch recovery that closes gaps 1 and 2.
- Then: phase 05 capability probing and probes on a physical device.
- Commits for this step: `ef213e3` (coordinator, providers, journeys, harness) and
  the documentation commit that carries this report. Both are on `main`; the head
  SHA and its green runs are recorded in [STATUS](../STATUS.md).
- Blocker: none from authority or hardware for phase 04. Physical-device evidence
  remains blocked until the capture path exists.
