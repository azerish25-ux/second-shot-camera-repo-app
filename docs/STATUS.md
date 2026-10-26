# Verified implementation status

Last updated: 2026-10-26. This file separates delivered foundation work from the
planned product. Read the linked run/report evidence before making a claim.

## Bootstrap in progress

The repository is being initialized with agent instructions, 24 phase plans,
architecture/design/testing/release contracts, a pure Swift core, a synthetic
SwiftUI demo and CI. During this bootstrap, **no test result is claimed yet**.
This section will be replaced with observed results after the first runs.

## Phase status

| Scope | Status | Evidence / remaining work |
| --- | --- | --- |
| 00 — Foundation | IN_PROGRESS | Code and workflow integration; G0 not yet observed |
| 01–23 — Product implementation | PLANNED | Detailed specifications do not implement features |
| G1 — Capture integrity | BLOCKED_DEVICE | No consented physical-device capture experiment |
| G2 — Useful retakes | BLOCKED_DEVICE | No implemented real retake or held-out user study |
| G3/G4 — Beta/release | NOT_STARTED | No signing credentials, distribution or release approval requested |

## Not implemented / not demonstrated

Live camera recording; real AR tracking; persisted world maps or projects; live
retake guidance; real-footage registration; video export; audio capture; StoreKit;
signed device builds; TestFlight; App Store submission; revenue or demand validation.

## Next task after G0

Execute [phase 01](phases/01-product-validation.md): freeze the bounded user task,
study/consent protocol and physical-device plan. Then expand the small starter
math/state fixtures to satisfy full [phase 02](phases/02-pose-math.md), rather than
skipping to monetization or claiming the synthetic demo validates the camera idea.
