# Verified implementation status

Last updated: 2026-10-26. This file separates delivered foundation and domain work
from the planned product. Read the linked run/report evidence before making a claim.

## Current checkpoint

Phases 00–02 are complete or frozen and on `main`; phase 03 is in progress.
Code commits: `dd65b67`, `1f2fa23`, `201acb5` (phase 00 foundation), `3912918`
(phase 01 protocol, phase 02 fixtures, simulator core-test bundle), `068b4be`
(phase 00–02 evidence), plus the phase-03 lifecycle commit recorded below.

- [Phase 00 report](reports/phase-00-foundation-report.md).
- [Phase 01 report](reports/phase-01-validation-protocol-report.md) — protocol
  frozen, study not run.
- [Phase 02 report](reports/phase-02-pose-math-report.md) — arithmetic complete.
- [Phase 03 report](reports/phase-03-lifecycle-report.md) — session model and
  interruption rules done; coordinator adapter outstanding.
- Repository checks on `068b4be`: [run 40368183164](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40368183164) — success.
- iOS Simulator CI on `068b4be`: [run 40368182795](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40368182795) — **success** in 4 m 49 s: all eleven steps green,
  including the evidence validator that now requires the core, app and UI suites.
  The equivalent runs on `3912918` also passed (simulator 11 m 20 s, repository
  checks 5 s).

### Local verification on this development host

This session runs on Linux x86_64 with Swift 6.0.3 and Python 3.12.3, and has no
Xcode or SwiftUI SDK. These checks were executed locally; none of them compile the
SwiftUI application.

| Command | Result |
| --- | --- |
| `swift test` | 79 core tests, 0 failures |
| `python3 -B -m unittest discover -s scripts -p 'test_*.py'` | 39 tests, 0 failures |
| `python3 -B scripts/ci/check_repository.py` | passed, including the phase-01 protocol invariants |

## Implemented in this checkpoint

- Pure-Swift geometry: `Vector3`, `Quaternion` (`x,y,z,w`), `RigidPose`, with typed
  rejection of non-finite values, degenerate rotations and mixed origins.
- `PoseSample`/`PoseTrack` validation, timestamp-bracketed interpolation with a
  near-collinear fallback, no extrapolation, worst-tracking propagation, and an
  import sample limit enforced before allocation.
- Shortest-arc pose comparison in meters/degrees with tracking and origin guards.
- Hand-derived golden fixtures (literal quaternions, rotation-matrix axis images,
  a hand-computed 120° composed product, a hand-computed rigid inverse) plus seeded
  property sweeps for length preservation, inverse recovery and interpolation
  boundedness — including the first failure found and corrected in a hand derivation.
- A frozen, machine-checked phase-01 validation protocol with scenarios, 60-case
  design, metric definitions, stop rules, consent/privacy material and interview
  guide. The repository check fails if a registered invariant is removed or the
  protocol implies execution without a sanitized results report.
- Deterministic guidance cues in the camera frame, and a pure session reducer for
  the demo journey with idempotent stop and typed illegal transitions.
- A labelled synthetic SwiftUI studio: library, reference, guidance with tracking
  loss/resume, review modes, and an explicit export-unavailable explanation.
- CI: XcodeGen project specification, pinned workflows, simulator selection,
  three required suites (core, app, UI) and evidence collection with its own tests.

## Not implemented / not demonstrated

Live camera recording; AR tracking; world-map persistence or relocalization;
project storage; real-footage alignment; video export; audio capture; StoreKit;
signed device builds; TestFlight; App Store submission; physical repeatability or
demand evidence. The whole production session lifecycle (phase 03) is still the
demo's reducer only. The demo requests no camera, microphone or analytics access.

## Phase status

| Scope | Status | Evidence / remaining work |
| --- | --- | --- |
| 00 — Foundation | PARTIAL | Implementation, repository checks and simulator CI pass; the screenshot **content** review of G0 is still outstanding because the artifact needs authenticated download |
| 01 — Product validation | PARTIAL | Protocol, interview guide and consent material frozen and machine-checked on `3912918`; no participant, no data, and the independent human-review check has not been run. Owner approval is required before any outreach |
| 02 — Pose math | COMPLETE | Arithmetic and fixture criteria met with observed evidence on `3912918`; no device evidence is required by this phase |
| 03 — Lifecycle/state machine | PARTIAL | Production phases, operation identity, staleness/foreign-project rejection, per-phase interruption and cancellation are implemented and unit-tested; the app-side coordinator with injected providers and the simulator fault journey are missing |
| 04–23 — Product implementation | PLANNED | Specifications only; phase 04 storage is the next executable task after the phase-03 adapter |
| G0 — Reproducible foundation | OPEN | Automated simulator evidence passed; visual screenshot review remains |
| G1 — Capture integrity | BLOCKED_DEVICE | No capture implementation and no physical-device experiment |
| G2 — Useful retakes | BLOCKED_DEVICE | Depends on G1 and on the phase-01 pilot actually running |
| G3/G4 — Beta/release | NOT_STARTED | No signing credentials, distribution or release approval requested |

## Next task

Finish [phase 03](phases/03-lifecycle-state-machine.md) by adding the
`SessionCoordinator` platform adapter — main-actor UI mutation, storage actor,
media queue, injected clock/permission/capability/frame providers, and token-safe
result handling — together with the simulator journeys for denied permission,
tracking loss and writer failure. Then start [phase 04](phases/04-project-storage.md)
(local project packages, atomic publication and launch recovery). Independently,
the `ios-evidence-<SHA>` artifact for the phase-00 screenshots still needs an
authenticated download and a visual review before G0 can close.
