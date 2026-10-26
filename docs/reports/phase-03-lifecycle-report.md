# Phase 03 — lifecycle, effects, operation identity

Status: **PARTIAL**. The production session model, its effects, cancellation and
staleness rules are implemented and tested, and the app's synthetic demo now drives
that real path. The platform `SessionCoordinator` adapter and injected-provider
fault journeys are still missing.

## Scope and prerequisites

- Phase specification: [phase 03](../phases/03-lifecycle-state-machine.md).
  Prerequisites: [phase 02](phase-02-pose-math-report.md) (complete),
  [capture contract](../architecture/capture-and-coordinates.md) §4–5.
- Tested commit: recorded in [STATUS](../STATUS.md) and in the run table below.
- Implemented: the complete production state vocabulary, intent/event separation,
  declarative effects carrying operation identity, deterministic operation tokens,
  stale-result and foreign-project rejection, per-phase interruption effects,
  cancellation before and after writer finalization, permission and preparation
  failure paths, and the engine-facing UI that renders them.
- Deliberately not implemented: the app-side `SessionCoordinator` actor graph
  (main-actor UI mutation, storage actor, media queue, injected clocks,
  permissions, capabilities and frame sources), the simulator fault-injection
  journey through injected providers, and any measurement of the 200 ms
  cancellation target.
- Not claimed: real capture, real interruption delivery, background, thermal or
  AVAssetWriter behaviour. Those belong to phases 05–07 and the G1 device gate.

## Changes

`Sources/SecondShotCore/Session/SessionStateMachine.swift` was replaced by the
production lifecycle (one machine, not a second parallel one):

- `SessionPhase` now has the fifteen specified states: `idle`,
  `requestingPermission`, `preparing`, `ready`, `recordingReference`,
  `finalizingReference`, `referenceAvailable`, `relocalizing`, `guiding`,
  `recordingRetake`, `finalizingRetake`, `reviewing`, `exporting`, `interrupted`,
  `failed`. `referenceReady` was renamed to `referenceAvailable` to match the
  specification vocabulary, and `InterruptionReason` gained `deviceLocked`.
- `SessionState` carries the project, both take identities, the in-flight
  `OperationToken`, the attempt `generation`, the exported take and a content-free
  diagnostic code. Starting work mints `<kind>-<generation>`; abandoning work
  advances the generation and drops the token.
- `SessionIntent` (user) and `SessionEvent` (adapter) are separate vocabularies.
  Only the reducer turns a fact into a state change.
- `SessionEffect` is declarative and carries the identity it belongs to
  (`startReferenceCapture(token:)`, `stopRetakeCapture(token:)`,
  `beginExport(token:takeID:)`, …), so an adapter can never act on behalf of a
  superseded operation.
- New typed refusals: `staleOperation(expected:received:)`,
  `foreignProject(expected:received:)`, `permissionNotGranted` alongside the
  existing illegal-transition/event and missing-reference errors. A result whose
  token does not match the in-flight operation is refused, and an event that
  cannot be valid in the current phase is refused as an illegal event; both keep
  the state unchanged instead of degrading into a success.
- Interruption is allowed from every busy or preparation phase but never from
  `idle`, `referenceAvailable`, `interrupted` or `failed`, and it always stops
  exactly the work of that phase (`releaseCapturePreparation`, `stopReferenceCapture`,
  `cancelRelocalization`, `stopGuidance`, `cancelExport`, `preserveIncompleteTake`,
  `stopSensors`).
- Export completion is accepted only for the open project; a foreign result is a
  typed failure, so another project's export cannot advance this screen.

App and tests:

- `Sources/SecondShotApp/Features/Demo/DemoSessionStore.swift` now plays the
  adapter role with synthetic replies: permission, preparation, reference capture,
  relocalization, retake, review and the interruption path all go through the same
  transitions real adapters will use. It never touches a camera, sensor or
  permission API, and `isTrackingLost` is derived from the reducer instead of being
  a separate flag that could disagree with the phase.
- `Sources/SecondShotApp/Features/Demo/DemoGuidanceView.swift` renders three
  distinct action sets: ready (start a retake), guiding (stop/review plus the
  synthetic fault), and interrupted (recovery plus discard).
- `Tests/SecondShotCoreTests/SessionStateMachineTests.swift` was rewritten around
  the production vocabulary and now covers the happy path, idempotent repeats,
  permission denial, preparation failure, writer failure, stale results in two
  shapes, foreign-project export, export failure, per-phase interruption effects,
  cancellation before and after finalization, and out-of-order callbacks.
- `Tests/SecondShotAppTests/DemoSessionStoreTests.swift` and
  `Tests/SecondShotUITests/DemoStudioUITests.swift` follow the corrected rule.

Behaviour correction worth recording: the earlier demo *paused* a retake when
tracking was lost and then resumed into the same take. Phase 03 forbids pausing and
resuming inside one movie, so tracking loss now ends the attempt, keeps it
incomplete, removes it from review, and offers deliberate recovery to the saved
reference plus a fresh attempt. The simulator journey now asserts that an ended
attempt is **not** offered as a reviewable take.

## Observed verification

| Command / experiment | Environment | Result | Evidence |
| --- | --- | --- | --- |
| `swift test` | Linux x86_64, Swift 6.0.3 | 79 tests, 0 failures | local run |
| `python3 -B -m unittest discover -s scripts -p 'test_*.py'` | Python 3.12.3 | 39 tests, 0 failures | local run |
| `python3 -B scripts/ci/check_repository.py` | same host | passed | local run |
| `swiftc -parse` over app and app/UI test sources | Swift 6.0.3 | syntax parse only, not a build | local run |
| Repository checks on `1144e7b` | GitHub Actions, ubuntu runner | **success** | [run 40375022689](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40375022689) |
| iOS Simulator workflow on `1144e7b` (compile + core/app/UI suites) | macos-26, workflow-selected Xcode 26.x | **success**: all steps green, including the evidence validator that requires the core, app and UI suites | [run 40375022861](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40375022861) |

Two infrastructure failures were found and fixed inside this step, and both are
part of the record rather than rewritten away:

1. `03464ba` failed the iOS Simulator workflow at step 3 in 18 seconds: the runner
   no longer matched the hardcoded exact-Xcode assertion. The immediately preceding
   run on `3912918` had passed that same step, so the `macos-26` image rolled under
   the workflow between 17:14 and 17:53 with no repository change. The pin was
   replaced by a deliberate selection: prefer `Xcode_26.6.app`, otherwise the newest
   installed `Xcode_26*.app`, export the choice to later steps, and fail with the
   full `/Applications` inventory if no 26.x exists. The inventory, the selected
   path and the failure diagnostics are now written to the job summary, so a future
   drift is diagnosable from the public run page instead of requiring a log download.
2. The evidence validator (`collect_results.py`) had to be checked against the new
   bundle: it now requires `SecondShotCoreTests` alongside the app and UI suites, so
   a green run means all three suites really executed.

The exact Xcode build selected on `1144e7b` is recorded in that run's job summary.
This environment has no browser and no authenticated `gh`, so the summary text could
not be read back; the conclusion itself was verified from the run's completion state
and per-step conclusions via the public API.

Failures found and fixed while building this slice (all in the new test code, none
by weakening the implementation):

1. Operation identities are minted as `<kind>-<generation>`; the first tests
   expected a bare kind and failed. The helper now asserts the documented shape.
2. A late writer result arriving while the phase no longer accepts that event is an
   *illegal event*; a late result arriving while a newer attempt is in flight is a
   *stale operation*. The test now asserts both refusals separately instead of
   expecting only one.
3. Two test state literals used argument order that does not match the initializer,
   and one test applied `.state` twice.

## What this does not prove

- No real adapter exists yet: nothing here has opened a camera, an AR session, a
  writer or a file. The effects are values the app does not execute.
- No injected-provider simulation: permission denial, tracking loss and writer
  failure are exercised as *events* in tests and replayed synchronously by the demo
  store, not delivered by real OS or hardware services.
- The 200 ms cancellation-response target is unmeasured. Nothing about cancellation
  latency, buffer release, thermal behaviour, battery cost or background rules has
  been observed.
- No concurrency diagnostics: the reducer is pure and single-threaded; actor
  isolation, unsafe buffer transfer and race detection belong to the missing
  coordinator work.
- Interruptions arriving *during* finalization preserve the take as incomplete but
  cannot yet be shown to keep the original file intact; that needs phase 04 storage
  and phase 07 device evidence.
- The passing simulator run proves the app compiles and the updated journeys pass on
  a simulator. It cannot prove device interruption delivery, background or thermal
  behaviour, and it says nothing about real capture.
- Project switching during a slow operation is covered only through the operation
  generation and the export project guard. There is no multi-project coordinator
  yet, so a full "switch while exporting" journey has not been exercised.

## Gate decision

- Acceptance for the model: every allowed transition has a test; representative
  forbidden transitions throw; double taps, out-of-order callbacks, cancellation
  before and after writer finalization, and interruption during each busy phase are
  covered; no unbounded tasks or hidden recordings exist, because no effect is
  executed yet.
- Outcome: **continue**, phase 03 remains **PARTIAL** until the coordinator,
  injected providers and the simulator fault journey exist.
- No threshold changed. The 200 ms responsiveness target is retained as a target to
  measure, not a claimed result.

## Handoff and publication

- First executable next task: implement `Sources/SecondShotApp/Session/SessionCoordinator.swift`
  as a `@MainActor` adapter that consumes the reducer's effects, isolates storage to
  an actor, injects clock/permission/capability/frame providers, and drops results
  whose token no longer matches. Then add the simulator journey for denied
  permission, tracking loss and writer failure through those injected providers.
- After that: [phase 04](../phases/04-project-storage.md) (package, atomic
  publication and recovery).
- Blocker: none from authority or hardware for the remaining phase-03 work.
