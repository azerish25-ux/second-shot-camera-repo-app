# Second Shot — instructions for every implementation agent

## Mission and current truth

Build a focused, premium iPhone tool that records a short camera move and helps
someone repeat it using spatial guidance. The product is **Second Shot** (working
title; the original concept was called Second Pass). This is not a robotic motion
control system and must never promise exact camera repetition or guaranteed income.

This repository starts with a simulator-safe **synthetic Demo Studio**, a small
tested pure-Swift domain core, CI, and an implementation specification. Demo data
is not camera footage, an AR measurement, or evidence of real-world accuracy.
Read `docs/STATUS.md` for the verified implementation state. Planned features
remain planned even if their documentation is detailed.

## Mandatory reading order

1. This file, then `README.md` and `docs/STATUS.md`.
2. `docs/PRODUCT_BRIEF.md`, `docs/ROADMAP.md`, and `docs/ACCEPTANCE_GATES.md`.
3. The assigned file in `docs/phases/` and its stated prerequisite evidence.
4. Relevant architecture, design, testing, and workflow documents linked there.
5. `docs/WORKING_AGREEMENT.md` before modifying or publishing work.

If a referenced file has not been written yet during bootstrap, flag it to the
coordinating agent. Do not invent its requirements or claim a gate has passed.

## Repository and branch discipline

- Repository: `azerish25-ux/second-shot-camera-repo-app`.
- Work on **main only**, unless the owner explicitly changes that instruction.
- Preserve unrelated user changes. No force pushes, history rewrites, destructive
  resets, bulk deletions, new branches, or invented author identities.
- Check the remote head before publishing; reconcile concurrent work without
  overwriting it. Only the coordinating agent commits and pushes parallel work.
- Make small coherent commits, push each checkpoint, and verify the remote SHA.
- Never commit credentials, signing certificates, provisioning profiles, real
  customer footage, private room maps, derived build output, or large test media.
- Never use a successful workflow file parse as evidence that tests passed.

## Architecture constraints

- Native SwiftUI, iPhone first; minimum iOS 17 for the initial foundation.
- `Sources/SecondShotCore`: pure Swift domain logic; no UIKit/ARKit/AVFoundation.
- `Sources/SecondShotApp`: UI and platform adapters. Keep expensive work off the
  main actor and inject capabilities, clocks, tracking, storage, and export seams.
- `Tests/SecondShotCoreTests`: deterministic domain tests.
- `Tests/SecondShotUITests`: accessibility-ID-based simulator journeys.
- Local-first project packages under Application Support; no account, server,
  advertising SDK, cloud AI, or third-party analytics in the MVP baseline.
- ARKit owns the rear-camera capture path. Do not assume a second independent
  AVCaptureSession can simultaneously own that same camera. Validate an
  ARFrame-buffer/AVAssetWriter path and optional separate microphone capture.
- AR world coordinates: right-handed, meters, camera forward -Z; matrix storage
  column-major; serialized quaternion order x/y/z/w. Every take records its origin
  identity, timestamps, lens/intrinsics and tracking validity. Never mix origins.
- Keep original media immutable. Registration is optional, nondestructive and
  confidence-gated. A global homography does not solve general 3D parallax.
- No universal 4K, LiDAR, HDR, frame-rate or precision claims; probe capabilities.

## Testing and evidence policy

- GitHub-hosted macOS runners run Xcode's **iOS Simulator**, not a remote physical
  iPhone. Build/unit/UI/accessibility flows may run there; AR accuracy cannot.
- Simulator mode uses deterministic synthetic inputs and labels them on screen.
  Never silently substitute fake tracking for a failing physical-device session.
- Validate real camera capture, tracking, relocalization, audio synchronization,
  parallax, thermal behavior and spatial precision on consented physical devices.
- The early phase-07 hardware feasibility gate precedes claims that the capture
  path works. Phase 15 is the separate useful-retake product proof gate.
- Gate failure is a valid result: stop dependent work or execute a documented
  bounded pivot. Do not relax thresholds after seeing failures without recording
  the change, reason and new experiment.
- CI failures must remain failures: no `|| true`, `continue-on-error`, test disabling,
  fabricated screenshots, skipped suites disguised as success, or retries that
  hide deterministic defects. Cleanup may be best-effort with explicit logging.
- Attach logs, test counts, screenshots, xcresult bundles and exact commit/device
  identifiers. State unrun tests and missing hardware clearly.

## UI/UX and user safety

- Follow `docs/design/`: refined graphite/paper-white interface with a restrained
  cyan guidance accent, amber caution, and red reserved for recording/stop.
- Respect Dynamic Type, VoiceOver, Reduce Motion, safe areas and 44-point targets.
- Tracking status must be redundant text + shape, not color alone. Stale data
  must not look accurate; keep Stop/Cancel reachable throughout a capture.
- No instructions to walk backwards, cross roads, use stairs, or ignore obstacles.
  Do not make safety promises based on the app's incomplete view of the world.
- Explain permissions in context; deny gracefully and keep a truthful demo usable.

## Phase execution contract

Before coding: identify the smallest vertical slice, read current implementation,
list acceptance tests, and record assumptions. Then implement, test, inspect actual
simulator evidence, and independently review the diff. Update `docs/STATUS.md`
and add a concise report using `docs/templates/PHASE_REPORT.md`.

A phase is COMPLETE only when its explicit acceptance checks and prerequisite
gates have evidence. If physical evidence is missing, mark BLOCKED_DEVICE (or
PARTIAL with the missing gate), not COMPLETE. Documentation alone is not delivery.

End each handoff with: changed files; commands and observed results; evidence
paths/URLs; unresolved risks; exact next action; commit SHA and push confirmation.
Never say 'production ready', 'fully tested', 'all done', or 'will earn $1k/month'
unless the corresponding claims are actually supported (income is never promised).

## Authority boundaries

The setup request authorizes repository implementation/docs and normal CI runs.
It does not authorize App Store submission, a paid service, purchases, signing-key
creation, production analytics, public beta invitations or monetization changes
without the owner's later approval. Future release jobs must be manual and gated.
Read-only or approval-required environments must be respected; request the proper
tool permission instead of bypassing a denial.
