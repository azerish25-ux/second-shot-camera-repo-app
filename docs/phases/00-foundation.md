# Phase 00 — reproducible foundation and simulator evidence

Status: **IN_PROGRESS during bootstrap**. The final observed state is authoritative
in [STATUS](../STATUS.md), not inferred from the presence of this specification.
Prerequisites: owner authorization for this repository and normal GitHub Actions.

## Objective and boundary

Give future agents a small runnable system, reliable verification loop and precise
work queue. Do not implement an entire speculative camera product before validating
its hardest assumption. The bootstrap must be honest about synthetic inputs.

Deliver a native iPhone SwiftUI shell with a premium library, labeled Demo Studio,
reference/retake/review navigation, interruption recovery and an explicit unavailable
real-export state. Domain code should demonstrate coordinate error calculations,
input validation and legal transitions independently of UIKit or ARKit.

## Implementation tasks

1. Write root AGENTS, product brief, roadmap, gate definitions, working agreement,
   phase reports and status; create every phase 01–23 with testable acceptance.
2. Define design tokens, screen states, motion/accessibility behavior, architecture
   contracts, physical evidence and release requirements.
3. Create `Package.swift`, `Sources/SecondShotCore` and deterministic tests. Reject
   nonfinite input, invalid quaternions, different origins and unreliable tracking.
4. Create `Sources/SecondShotApp` and UI tests using semantic accessibility IDs.
   Synthetic poses are visibly labeled and never request camera/microphone access.
5. Specify targets in `project.yml`; generate the project with pinned XcodeGen.
   Do not commit an independently hand-edited generated Xcode project.
6. Implement repository and simulator workflows with read-only workflow permissions,
   no signing secrets, verified toolchain, dynamic simulator selection, clear errors
   and evidence uploaded on failure as well as success.
7. Run actual remote CI, inspect logs/test results/screenshots, fix regressions and
   record exact tested SHAs. Push checkpoints and verify the remote branch head.

## Automated tests and failure cases

Exercise zero/NaN poses, quaternion q/-q equivalence, different origin identities,
limited tracking, stale timestamps and invalid transition attempts. UI tests must
visit library → synthetic reference → guidance → interruption/resume → review and
the truthful no-real-footage export explanation. Capture screenshots with XCTest
attachments, and test accessible navigation with larger text where feasible.

CI-helper tests must cover missing/malformed simulator inventory, no available
iPhone runtime, deterministic selection, and documentation/link validation.
Missing Xcode or a runtime should fail with actionable inventory, not select a
different unknown platform silently. Failed xcodebuild must remain failed after
log piping and artifact upload. The test reporter must not accept an empty suite.

## Acceptance and evidence

G0 requires a real unsigned simulator build and nonempty passing unit/UI suites,
readable screenshots, saved logs/environment metadata/xcresult, validated docs,
and an exact remote commit/run URL. Inspect screenshots for clipped or misleading
content; successful tests alone do not establish visual quality.

Hardware requirements are explicitly **not satisfied** here. No live capture,
spatial accuracy, real audio/video, export, purchase or public release is claimed.
If scheduling or authorization prevents remote execution, leave G0 incomplete,
record what checks did run, and name the remaining blocker.

## Handoff

Update STATUS and a foundation report using the report template. Include test
counts, run and artifact URLs, known limitations, and remote SHA. All intended
files must be committed and pushed to main; no generated build directories or
private data should remain in git. The next step is phase 01, followed by full
domain/capture validation—not a 'finished app' announcement.
