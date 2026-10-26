# Phase 13 — optional registration that knows when to refuse

**Status: PLANNED; experimental until physical evidence supports it.**

**Dependencies:** [phase 12](12-review-and-time-alignment.md), valid media/pose metadata, and an agreed holdout evaluation protocol. Read [alignment architecture](../architecture/alignment-and-export.md).

## Outcome and exclusions

Offer a conservative spatial-alignment preview for suitable shots while preserving access to originals. A global homography is appropriate only for constrained geometry, such as a plane or sufficiently rotation-dominated views. It cannot generally correct differing parallax, occlusion, rolling-shutter distortion, or independent moving subjects. No depth reconstruction, generative fill, face warping, or “perfect match” badge belongs in this MVP.

## Implementation work

1. Define `RegistrationCandidate`, `RegistrationDiagnostics`, and `RegistrationDecision` in `Sources/SecondShotCore/Review/`. Persist algorithm/configuration versions, source take IDs, time mapping, coordinate convention, transforms, valid region, evaluation measurements, and explicit refusal reasons.
2. Add `Sources/SecondShotApp/Review/RegistrationService.swift` as a cancellable worker. Start with translation-only alignment, then evaluate an optional homography. Apple's Vision homographic request supplies a perspective transform; do not assume it supplies a calibrated success probability or every feature/inlier statistic the product needs.
3. Let the person select a static-background region. Downsample analysis images consistently and carry the scale, crop, orientation, and pixel-origin transforms back to full-resolution coordinates. A matrix fitted inside a crop cannot be applied unchanged to the entire frame.
4. Evaluate candidates independently: check finite coefficients, numerical stability, projected-corner ordering, supported overlap, required crop, and residual error on held-out static landmarks or an independently specified image-grid check. Do not measure error solely on correspondences used to fit the model.
5. Detect contradictory foreground/background behavior and inadequate texture/overlap. Where diagnostics are insufficient, return `insufficientEvidence` rather than a false “good” result. Low residual on one background wall is not proof that a nearby person also aligns.
6. Compare the aligned preview against originals with a conspicuous toggle and crop-boundary preview. Registration remains opt-in for export. Temporal smoothing of estimated transforms needs separate stability tests; it must not turn rejected frames into plausible-looking accepted ones.

## Failure and data contract

Refusal reasons include unsupported input, changed lens/origin for pose analysis, insufficient overlap, texture ambiguity, unstable transform, high residual, parallax risk, excessive crop, and cancelled analysis. A failed candidate does not block exporting original takes. Reanalysis creates a new plan and leaves the old plan reproducible. Cache derived results by input fingerprints and algorithm version; invalidate them when time offset, crop, or selected source changes.

## Verification and provisional acceptance

- [ ] Pure tests check transform direction, crop/scale composition, singular matrices, reflected corners, identity mapping, and cancellation without stale UI updates.
- [ ] Synthetic fixtures include a textured plane with known transform, two depth layers under translation, moving foregrounds, low texture, repeated patterns, blur, and partial occlusion. The problematic fixtures must be refused or clearly marked uncertain.
- [ ] Proposed geometry targets: identity reprojection error below 0.25 pixel, known planar-transform median below 1 pixel at the fixture resolution, and no silently accepted out-of-bounds sampling.
- [ ] Proposed product limit: retain at least 85% of the configured output area; larger cropping requires explicit user acceptance or refusal. This limit is a starting policy, not a measured user preference.
- [ ] On physical holdout footage, report residual distribution and usable/refused counts for separate scene types. Never claim a measured success rate without its denominator and evaluation method.
- [ ] Simulator screenshots demonstrate both accepted synthetic alignment and refusal. Device screenshots alone do not prove geometric accuracy.

## Evidence and handoff

Attach parameter/configuration hashes, fixture definitions, raw-versus-aligned crops, measurements, and failure examples to the phase report. Keep personal footage outside git. Commit tests and refusal logic before enabling the feature by default anywhere. Proceed to [export](14-video-export.md) with originals as the safe fallback.

## Primary references

- [Apple: homographic image registration](https://developer.apple.com/documentation/vision/vnhomographicimageregistrationrequest).
- [OpenCV: homography geometry and its planar/pure-rotation restrictions](https://docs.opencv.org/4.x/d9/dab/tutorial_homography.html). This is a mathematical reference, not authorization to add an OpenCV dependency.
