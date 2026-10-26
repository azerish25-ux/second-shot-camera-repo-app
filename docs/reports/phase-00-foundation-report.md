# Phase 00 — reproducible foundation and simulator evidence

Status: **PARTIAL** — implementation and automated checks pass, including a
successful simulator build and nonempty unit/UI suites with exported screenshot
attachments. The screenshot content review is still outstanding, so G0 is not
closed yet.

## Scope and prerequisites

- Phase specification and gate dependencies: [phase 00](../phases/00-foundation.md), gate [G0](../ACCEPTANCE_GATES.md).
- Exact tested commits on `main`: `dd65b67` (first implementation), `1f2fa23`
  (CI installer fix), `201acb5` (store-test journey fix).
- Implemented: a pure-Swift domain core with deterministic tests, a labelled
  synthetic SwiftUI studio (library → reference → guidance → tracking loss/resume
  → review → export explanation), an XcodeGen project spec, simulator CI with
  evidence validation, and repository checks with their own tests.
- Deliberately excluded: camera/microphone permissions, ARKit sessions, media
  recording, persistent projects, image registration, video export, StoreKit,
  TestFlight and any physical-device claim.

## Changes

- `Sources/SecondShotCore`: `Vector3`, `Quaternion`, `RigidPose`, validated
  `PoseSample`/`PoseTrack` with timestamp-bracketed interpolation, shortest-arc
  pose comparison with origin/tracking guards, one-at-a-time guidance cues, and a
  pure session reducer with typed illegal transitions.
- `Sources/SecondShotApp`: adaptive graphite/paper design tokens, schematic
  top-down path drawing, library, demo reference, guidance, review and export
  explanation, plus an about sheet. Every screen states that data is synthetic.
- `Tests/SecondShotCoreTests`: 62 deterministic tests including quaternion sign
  equivalence, noncommutative composition, malformed input, mixed origins and a
  4,000-sample fixture.
- `Tests/SecondShotAppTests`, `Tests/SecondShotUITests`: store journey tests and
  XCTest screenshots over the demo flow, including the unavailable-guidance state
  and the export explanation.
- `project.yml`, `.github/workflows/*`, `scripts/ci/*`: pinned XcodeGen and action
  SHAs, read-only workflow permissions, dynamic simulator selection, log/status
  preservation and evidence validation (nonempty suites, zero skips, screenshots).

## Observed verification

| Command / experiment | Environment | Result / counts | Exact evidence |
| --- | --- | --- | --- |
| `swift test` | Linux x86_64, Swift 6.0.3 | 62 core tests, 0 failures | local run, `dd65b67`+ |
| `swiftc -parse` over app and test sources | Linux x86_64, Swift 6.0.3 | syntax parses; no type checking | local run |
| `python3 -B scripts/ci/check_repository.py` | Linux, Python 3.12.3 | pass | local run |
| `python3 -B -m unittest discover -s scripts -p 'test_*.py'` | Linux, Python 3.12.3 | 32 tests, 0 failures | local run |
| Repository checks workflow | GitHub Actions `ubuntu-24.04`, run 40288461886 | Success on `201acb5` | https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40288461886 |
| iOS Simulator CI attempt 1 | `macos-26`, run 40286925250, commit `dd65b67` | Failed: XcodeGen install exited 126 (release archive nests `bin/xcodegen`) | https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40286925250 |
| iOS Simulator CI attempt 2 | `macos-26`, run 40287185385, commit `1f2fa23` | Failed: app compiled and UI tests ran, but 2 store-test path expectations were wrong | https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40287185385 |
| iOS Simulator CI attempt 3 | `macos-26`, run 40288461737, commit `201acb5` | **Success** in 8m 42s: unsigned simulator build, Swift + XCTest unit/UI suites, zero failures and zero skips, both suites present, ≥5 screenshot images exported (enforced by the collector) | https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40288461737 |

The workflow runner is the only iOS compiler available to this session (Linux
host, no Xcode, no authenticated GitHub CLI). Failures were diagnosed from the
public run page and the `::error::` annotations the workflow emits; raw job logs
and downloaded artifacts were not accessible here.

## What this does not prove

- No physical iPhone has run the app. AR tracking, camera output, exposure,
  audio sync, thermal behaviour and real-world repeatability are untested.
- No visual review of the screenshot attachments was possible from this
  environment. The evidence collector verifies that at least five image
  attachments exist, not that each screen is unclipped or well composed. The
  `ios-evidence-201acb53bb4ffdbefbc2e5269b334303528c7184` artifact is retained
  for 14 days for that review.
- Passing simulator unit tests do not establish that the SwiftUI layout is
  premium at every Dynamic Type size, in every locale, or with assistive
  technology enabled. Those remain manual review items.
- No media, project persistence or export exists, so none of those claims appear
  in the app or documentation.

## Gate decision

Automated G0 evidence is green on `201acb5`: real simulator build, both suites
passed without skips, and the evidence collector accepted the screenshots and
test tree. G0 stays **open** because the screenshots have not been visually
inspected against the design specification and no owner has archived the
artifact durably. Continue foundation work; do not start camera/AR claims before
G0 closes.

## Handoff and publication

- First executable next task: download `ios-evidence-201acb53bb4ffdbefbc2e5269b334303528c7184`,
  review the screenshot attachments against
  [screen specifications](../design/SCREEN_SPECIFICATIONS.md), then close G0 and
  execute [phase 01](../phases/01-product-validation.md).
- Blocker requiring owner input: artifact download/viewing authority; no physical
  device is required for phase 00.
- Commits: `dd65b67`, `1f2fa23`, `201acb5`, pushed to `main`; server SHA verified
  by `cloud_git` output for each push. This report is committed in the following
  documentation commit.
- Working tree: only source, tests, scripts and documentation are committed;
  `.build`, generated project, `artifacts` and `.tools` are ignored.
