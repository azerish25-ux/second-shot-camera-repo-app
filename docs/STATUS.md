# Verified implementation status

Last updated: 2026-10-26. This file separates delivered foundation work from the
planned product. Read the linked run/report evidence before making a claim.

## Current checkpoint

The phase-00 foundation is implemented and pushed to `main`. Repository checks
pass for the current commit; the iOS Simulator workflow result is recorded below
only after it was observed on the public run page.

- Implementation commits: `dd65b67`, `1f2fa23`, `201acb5`. The passing run tests the exact head `201acb5`; the documentation update follows in a separate commit.
- [Phase 00 report](reports/phase-00-foundation-report.md).
- Repository checks: [run 40288461886](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40288461886) — success.
- iOS Simulator CI: [run 40288461737](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40288461737) — **success** in 8m 42s: unsigned simulator build, Swift core tests, app unit tests and UI journeys, no skips, evidence collector accepted both suites and the screenshot attachments.

### Local verification on this development host

This session runs on Linux x86_64 with Swift 6.0.3 and Python 3.12.3, and has no
Xcode or SwiftUI SDK. These checks were executed locally; none of them compile
the SwiftUI application.

| Command | Result |
| --- | --- |
| `swift test` | 62 core tests, 0 failures |
| `swiftc -parse` over app/test sources | syntax-only parse succeeded; not a build |
| `python3 -B scripts/ci/check_repository.py` | passed |
| `python3 -B -m unittest discover -s scripts -p 'test_*.py'` | 32 tests, 0 failures |

## Implemented in this checkpoint

- Pure-Swift geometry: `Vector3`, `Quaternion` (`x,y,z,w`), `RigidPose`, with
  typed rejection of non-finite values, degenerate rotations and mixed origins.
- `PoseSample`/`PoseTrack` validation, timestamp-bracketed linear + spherical
  interpolation, and no extrapolation past recorded time.
- Shortest-arc pose comparison in meters/degrees with tracking and origin guards.
- Deterministic guidance cues in the camera frame, with a safe reset instruction
  for large overshoot instead of a backwards-walking cue.
- A pure session reducer for the demo journey with idempotent stop, typed illegal
  transitions, interruption effects and no synthetic success on failure.
- A labelled synthetic SwiftUI studio: library, reference, guidance with tracking
  loss/resume, review modes, and an explicit export-unavailable explanation.
- XcodeGen project specification, two pinned GitHub Actions workflows, simulator
  selection and evidence collection with their own tests.

## Not implemented / not demonstrated

Live camera recording; AR tracking; world-map persistence or relocalization;
project storage; real-footage alignment; video export; audio capture; StoreKit;
signed device builds; TestFlight; App Store submission; physical repeatability or
demand evidence. The demo requests no camera, microphone or analytics access.

## Phase status

| Scope | Status | Evidence / remaining work |
| --- | --- | --- |
| 00 — Foundation | PARTIAL | Implementation, repository checks and iOS Simulator CI pass on `201acb5`; screenshot content review and durable artifact archival outstanding |
| 01–23 — Product implementation | PLANNED | Specifications only; phase 01 is the next executable task after G0 |
| G0 — Reproducible foundation | OPEN | Automated simulator evidence passed; visual screenshot review remains |
| G1 — Capture integrity | BLOCKED_DEVICE | No capture implementation and no physical-device experiment |
| G2 — Useful retakes | BLOCKED_DEVICE | Depends on G1 and a held-out user study |
| G3/G4 — Beta/release | NOT_STARTED | No signing credentials, distribution or release approval requested |

## Next task

Inspect the `ios-evidence-<SHA>` artifact for the passing commit, review its
screenshots against the [screen specifications](design/SCREEN_SPECIFICATIONS.md),
close G0 if they hold up, then execute [phase 01](phases/01-product-validation.md)
before writing any camera or AR feature.
