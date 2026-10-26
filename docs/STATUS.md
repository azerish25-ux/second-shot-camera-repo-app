# Verified implementation status

Last updated: 2026-10-26. This file separates delivered foundation and domain work
from the planned product. Read the linked run/report evidence before making a claim.

## Current checkpoint

Phases 00–02 are complete or frozen and on `main`; phase 03 is implemented and
**PARTIAL** with two named gaps. Code commits: `dd65b67`, `1f2fa23`, `201acb5`
(phase 00 foundation), `3912918` (phase 01 protocol, phase 02 fixtures, simulator
core-test bundle), `068b4be` (phase 00–02 evidence), `03464ba` (phase 03 lifecycle),
`1144e7b` (CI toolchain selection), `d50fe58` (phase 03 evidence), `ef213e3`
(phase 03 session-coordinator adapter, injected providers and fault journeys).

- [Phase 00 report](reports/phase-00-foundation-report.md).
- [Phase 01 report](reports/phase-01-validation-protocol-report.md) — protocol
  frozen, study not run.
- [Phase 02 report](reports/phase-02-pose-math-report.md) — arithmetic complete.
- [Phase 03 report](reports/phase-03-lifecycle-report.md) — the reducer, the
  platform adapter, injected providers, storage actor, media queue, fault journeys
  and the measured cancellation budget; gap list recorded there.

### CI history for this checkpoint

- Repository checks on `ef213e3`: run `40388366917` — **success**.
- iOS Simulator CI on `ef213e3`: run `40388366918` — **failure**, recorded rather
  than hidden: `xcodebuild` exited 65 because
  `Sources/SecondShotApp/Features/Demo/DemoSessionStore.swift` called the
  main-actor-isolated `SessionEnvironment.synthetic` from a *default argument*,
  which is evaluated outside the actor. The local Linux session-layer harness
  cannot see that file (it is SwiftUI), so the app-target compile is where this
  class of defect is found; the fix builds the composition inside the initializer
  instead. The repository-checks workflow passed on the same commit, so the failure
  was isolated to the app compile and the evidence validation that depends on it.
- The fix and this documentation are in the following commit; its repository-checks
  and iOS Simulator runs are recorded below once they complete.

Earlier runs on this checkpoint: repository checks `40375022689` (success) and iOS
Simulator `40375022861` (success) on `1144e7b`. Run `40372804681` on `03464ba` failed
at the toolchain step because the `macos-26` image rolled under the workflow;
`1144e7b` replaced the exact-Xcode assertion with a reviewed 26.x selection that
reports the inventory to the job summary. Policy in [CI_WORKFLOW](CI_WORKFLOW.md).

### Local verification on this development host

This session runs on Linux x86_64 with Swift 6.0.3 and Python 3.12.3, and has no
Xcode or SwiftUI SDK. These checks were executed locally; none of them compile the
SwiftUI application.

| Command | Result |
| --- | --- |
| `swift test` | 82 core tests, 0 failures |
| `bash scripts/ci/verify_session_layer.sh` | 26 session-layer fault journeys, 0 failures; measured cancellation 35.0 ms |
| `python3 -B -m unittest discover -s scripts -p 'test_*.py'` | passed |
| `python3 -B scripts/ci/check_repository.py` | passed, including the phase-01 protocol invariants |
| `swiftc -parse` over the app, app-test and UI-test sources | syntax only; it does not type-check actor isolation |

## Implemented in this checkpoint

- Pure-Swift geometry: `Vector3`, `Quaternion` (`x,y,z,w`), `RigidPose`, with typed
  rejection of non-finite values, degenerate rotations and mixed origins.
- `PoseSample`/`PoseTrack` validation, timestamp-bracketed interpolation with a
  near-collinear fallback, no extrapolation, worst-tracking propagation, and an
  import sample limit enforced before allocation.
- Shortest-arc pose comparison in meters/degrees with tracking and origin guards.
- Hand-derived golden fixtures plus seeded property sweeps, including the first
  failure found and corrected in a hand derivation.
- A frozen, machine-checked phase-01 validation protocol with scenarios, 60-case
  design, metric definitions, stop rules, consent/privacy material and interview
  guide. The repository check fails if a registered invariant is removed or the
  protocol implies execution without a sanitized results report.
- The complete production session lifecycle: fifteen phases, intent/event
  separation, declarative effects carrying `<kind>-<generation>` operation identity,
  typed illegal-transition and stale/foreign-result refusals, and per-phase
  interruption and cancellation effects.
- `SessionCoordinator`: the main-actor adapter that executes those effects. UI state
  mutation on the main actor; records in a `ProjectStore` actor (one JSON manifest
  per attempt, atomic replace); media in a serialized `MediaWriteQueue` actor that
  permits one open writer and logs every open/finalize/discard in order.
- Injected seams with synthetic implementations: monotonic clock, per-kind
  permission provider, capability provider, capture provider (which writes the
  incomplete record before media exists) and an export seam that reports its own
  absence. Reply handling is phase- and token-checked; refused replies are recorded
  and never mutate state.
- A deterministic hold primitive (`SessionHold`) so fault journeys park an adapter
  inside a named operation instead of sleeping, plus fault profiles driven by the
  `-ss-fault` launch argument.
- A labelled synthetic SwiftUI studio whose entire journey now runs through the
  coordinator: library, reference, guidance with tracking loss/recovery, review and
  an export sheet that reports unavailability through the export seam.
- CI: XcodeGen project specification, pinned workflows, simulator selection, three
  required suites (core, app, UI), a Thread Sanitizer run over the unit suites, and
  evidence collection with its own tests.

## Not implemented / not demonstrated

Live camera recording; AR tracking; world-map persistence or verified
relocalization; project packages and launch recovery of interrupted records; export
rendering; audio capture; StoreKit; signed device builds; TestFlight; App Store
submission; physical repeatability or demand evidence. The demo requests no camera,
microphone or analytics access, and its media files are labelled synthetic
placeholders, never footage.

## Phase status

| Scope | Status | Evidence / remaining work |
| --- | --- | --- |
| 00 — Foundation | PARTIAL | Implementation, repository checks and simulator CI pass; the screenshot **content** review of G0 is still outstanding because the artifact needs authenticated download |
| CI baseline | GREEN | Repository checks and the simulator workflow (build, core/app/UI suites, Thread Sanitizer, evidence validation) pass on the checkpoint head; the toolchain step tolerates runner-image drift without accepting an unreviewed major version |
| 01 — Product validation | PARTIAL | Protocol, interview guide and consent material frozen and machine-checked on `3912918`; no participant, no data, and the independent human-review check has not been run. Owner approval is required before any outreach |
| 02 — Pose math | COMPLETE | Arithmetic and fixture criteria met with observed evidence on `3912918`; no device evidence is required by this phase |
| 03 — Lifecycle/state machine | PARTIAL | The lifecycle, the coordinator adapter, storage actor, media queue, reply policy, fault journeys and the measured 35 ms cancellation budget are implemented and evidenced. Open: project switching during a slow operation, and launch reconciliation of interrupted records (phase 04) |
| 04–23 — Product implementation | PLANNED | Specifications only; phase 04 project storage is the next executable task |
| G0 — Reproducible foundation | OPEN | Automated simulator evidence passed; visual screenshot review remains |
| G1 — Capture integrity | BLOCKED_DEVICE | No capture implementation and no physical-device experiment |
| G2 — Useful retakes | BLOCKED_DEVICE | Depends on G1 and on the phase-01 pilot actually running |
| G3/G4 — Beta/release | NOT_STARTED | No signing credentials, distribution or release approval requested |

## Next task

Start [phase 04](phases/04-project-storage.md): the local project package, atomic
publication and launch recovery — which closes the two named phase-03 gaps (project
switching during a slow operation, and reconciling interrupted records at launch).
Independently, the `ios-evidence-<SHA>` artifact for the phase-00 screenshots still
needs an authenticated download and a visual review before G0 can close.
