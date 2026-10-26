# Architecture map

This directory specifies the **intended production system**. The bootstrap only
implements a pure Swift domain seed and a synthetic SwiftUI journey. See
[STATUS](../STATUS.md) for delivered behavior.

## Dependency boundaries

| Layer | Path | Can depend on | Must not own |
| --- | --- | --- | --- |
| Domain | `Sources/SecondShotCore` | Swift/Foundation | UI, camera, AR sessions, files, global clocks |
| UI | `Sources/SecondShotApp` | SwiftUI + injected services | Heavy frame processing or sensor lifecycle |
| Tracking/capture adapters | Future app submodules | ARKit/AVFoundation | UI navigation or commercial entitlement decisions |
| Storage/export adapters | Future app submodules | Foundation/AVFoundation/Photos as needed | Unrequested uploads or mutation of original media |
| Verification | `Tests`, `scripts/ci` | Deterministic fixtures/test doubles | Replacing production failure with synthetic success |

An interface exists to define a testable boundary, not to disguise an unimplemented
feature. Production adapter types should be introduced by their phase, not as a
forest of empty protocols in bootstrap.

## Read next

- [Capture, coordinates and clocks](capture-and-coordinates.md): camera ownership,
  poses, maps, identity, timestamp conversion and frame ledgers.
- [Alignment and export](alignment-and-export.md): correspondence, immutable media,
  diagnostics, geometric limitations, audio and failure-safe output.
- [Full lifecycle](../phases/03-lifecycle-state-machine.md) and
  [project storage](../phases/04-project-storage.md).

## Key decisions

1. **SwiftUI, native frameworks, iPhone first.** iOS 17 is the initial deployment
   floor, not a claim all later capabilities are available there. Probe APIs and
   keep release SDK requirements distinct from deployment minimums.
2. **Local-first.** Project packages live under app Application Support. No cloud
   backend/accounts/analytics/AI API is needed to test the core hypothesis.
3. **Single rear-camera owner.** ARKit camera buffers and poses share an auditable
   timeline. Verify audio support/time mapping; do not run a competing rear-camera
   capture session and hope the device supports it.
4. **Separate synthetic and real inputs.** Simulator demo data is deliberately
   explicit. Hardware failure cannot silently switch the active take to fixtures.
5. **Immutable originals and quality gates.** Review, timing edits, alignment and
   export are derived recipes. Invalid tracking is not a near-zero error score.
6. **Generated Xcode project.** `project.yml` plus a pinned generator is the source
   of truth. Keep generated projects/build artifacts out of commits.
7. **Commerce/release deferred.** A one-time purchase is a validated later decision,
   not a reason to bypass the physical proof gate. Signing/publication is manual.

## Change procedure

A change to coordinates, time bases, project schema, camera ownership, supported
devices, export promises or privacy boundaries requires a short architecture
decision: context, options, selected contract, migration, tests and evidence. Keep
it beside the relevant document or under `docs/architecture/decisions` when needed;
do not create speculative decisions without an actual engineering trade-off.
