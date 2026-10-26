# Implementation roadmap

Read [STATUS](STATUS.md) before selecting work. This is a **24-phase work queue**,
not a completed-feature list. A phase ends with evidence and a handoff, not merely
with its files being written. Every phase specification includes concrete tasks,
tests, failure behavior and acceptance criteria.

## Phase index

| ID | Phase specification | Main dependency | Exit evidence |
| --- | --- | --- | --- |
| 00 | [Foundation and CI](phases/00-foundation.md) | Owner authorization | G0: real simulator run and artifacts |
| 01 | [Product validation](phases/01-product-validation.md) | 00 | Bounded pilot, consent and falsifiable tests |
| 02 | [Pose math](phases/02-pose-math.md) | 01 | Golden math fixtures and rejection tests |
| 03 | [Lifecycle/state machine](phases/03-lifecycle-state-machine.md) | 02 | Legal/illegal transitions and cancellation tests |
| 04 | [Project storage](phases/04-project-storage.md) | 03 | Round-trip, migration and crash-recovery tests |
| 05 | [Device capabilities](phases/05-device-capabilities.md) | 03 | Real capability report and permission matrix |
| 06 | [AR tracking](phases/06-ar-tracking.md) | 02, 03, 05 | Device pose traces, loss behavior and no fake fallback |
| 07 | [Reference capture](phases/07-reference-capture.md) | 04, 06 | **G1: physical capture integrity** |
| 08 | [Relocalization](phases/08-relocalization.md) | G1 | Correct origin restoration or explicit rejection |
| 09 | [Path rendering](phases/09-path-rendering.md) | 02, 08 | Resampling math plus visible device guidance |
| 10 | [Guided retake](phases/10-guided-retake.md) | 03, 07, 09 | Temporal correspondence and retake capture |
| 11 | [Tracking recovery](phases/11-tracking-recovery.md) | 08, 10 | Interruptions do not corrupt or mix takes |
| 12 | [Review and time alignment](phases/12-review-and-time-alignment.md) | 04, 10, 11 | Synchronized immutable-original comparison |
| 13 | [Registration diagnostics](phases/13-registration-diagnostics.md) | 12 | Rejection of poor-overlap/parallax cases |
| 14 | [Video export](phases/14-video-export.md) | 12, 13 | Playable output, timing/orientation and cancellation tests |
| 15 | [Physical product proof](phases/15-device-proof-gate.md) | 07–14 | **G2: continue / narrow / stop decision** |
| 16 | [Production UI and accessibility](phases/16-production-ui-accessibility.md) | Design spec; G2 for final completion | Screen/state/device and assistive-tech evidence |
| 17 | [Library lifecycle](phases/17-library-and-project-lifecycle.md) | 04, 12, 14, 16 | Recovery, migration, import/delete/export ownership |
| 18 | [Performance and devices](phases/18-performance-and-device-matrix.md) | 15–17 | Measured thermal/memory/battery/device results |
| 19 | [Privacy, safety and localization](phases/19-privacy-safety-localization.md) | 16–18 | Audited permissions/manifests and pseudo-localized UI |
| 20 | [Pro unlock](phases/20-pro-unlock.md) | G2, 17, 19 + price approval | StoreKit sandbox purchase/restore/offline tests |
| 21 | [TestFlight beta](phases/21-testflight-beta.md) | 18–20 + signing authority | **G3: signed beta + external-use evidence** |
| 22 | [App Store release](phases/22-app-store-release.md) | G3 + owner approval | **G4: release checklist and explicit authorization** |
| 23 | [Launch and maintenance](phases/23-launch-and-maintenance.md) | 22 | Real operational/financial measurements and support loop |

## Execution order and allowed parallelism

The critical technical path is **domain → capture integrity → origin recovery →
guided retake → review/export → physical usefulness**. Finish small vertical slices
within that path, rather than implementing every protocol and empty screen first.

Design specifications, accessibility components, synthetic UI, documentation,
repository checks and fixture infrastructure may proceed in parallel with device
work. They must remain explicitly synthetic or provisional. A successful UI branch
of work never overrides a blocked camera/AR gate. Follow the repository's main-only
policy; parallelism means disjoint assignments, not feature branches by default.

The bootstrap includes a small slice of phases 02/03/16 to make tests and screenshots
possible. It does **not** mark those phases complete. Their full production contracts
remain in their own specifications.

## State vocabulary

| Status | Meaning |
| --- | --- |
| PLANNED | Scope defined, not implemented or not yet investigated |
| IN_PROGRESS | Work is active; acceptance criteria are not yet satisfied |
| PARTIAL | A named subset exists with evidence; remaining work listed |
| BLOCKED_DEVICE | Required real-device evidence is absent |
| BLOCKED_AUTHORITY | Signing, publishing, payment or access approval is missing |
| COMPLETE | All requirements and prerequisite gates have observed evidence |
| REJECTED / PIVOTED | Experiment failed or scope changed, with a recorded decision |

Do not turn a checklist green because code compiles. Reports must identify which
tests ran, what they prove, what they do not prove, and the next smallest action.

## Milestones

- **Foundation:** G0; runnable synthetic app, stable CI, agent-readable instructions.
- **Capture feasibility:** G1; real synchronized video/pose without silent corruption.
- **Retake usefulness:** G2; held-out people can produce bounded useful results.
- **Beta readiness:** G3; durable data, accessibility, privacy and signed real-device beta.
- **Release:** G4; approved metadata, supported SDK, tested commerce and release authority.

There are no calendar promises attached to these milestones. Availability of real
hardware, failed experiments, SDK compatibility and user evidence govern duration.
Read [acceptance gates](ACCEPTANCE_GATES.md) before advancing a milestone.

## Required output of every implementation phase

1. Reviewed implementation and tests, with failures kept visible.
2. A compact [phase report](templates/PHASE_REPORT.md) with exact commit evidence.
3. Current STATUS entries, including any blocked or unrun work.
4. A coherent commit pushed to main; server SHA verified.
5. One explicit next task, not an unsupported 'everything is complete' statement.
