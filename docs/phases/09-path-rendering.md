# Phase 09 — a readable, truthful spatial path

**Status: PLANNED — specification, not implemented capability.**

**Dependencies:** phases 02–08; phase-07 physical capture evidence is required before evaluating a live overlay. Synthetic rendering work may proceed independently, visibly labeled as a demo. Read [the alignment contract](../architecture/alignment-and-export.md) and [acceptance gates](../ACCEPTANCE_GATES.md).

## Outcome and boundaries

Turn a valid recorded camera trajectory into an understandable guide: a restrained cyan path, a next-position target, and a distinct orientation indicator. The guide represents where the camera was, not a safe walking route or a promise that a second recording will align. Keep people looking at their surroundings; never instruct walking backwards, using stairs, or ignoring obstacles. Do not add obstacle avoidance, arbitrary map alignment, or LiDAR requirements in this phase.

## Implementation work

1. Add a pure-Swift `PathSampler` under `Sources/SecondShotCore/Guidance/`. Accept timestamped poses with one `referenceOriginID`; reject nonfinite values, nonincreasing timestamps, invalid rotations, and mixed origins. Preserve gaps and invalid tracking intervals explicitly.
2. Interpolate position linearly and normalized orientation with shortest-arc quaternion SLERP. Handle nearly identical rotations and the equivalent `q`/`-q` representation. Clamp only an explicitly requested preview time; never silently extrapolate a live target past the recording.
3. Create a display-only decimator that preserves endpoints, sharp turns, and important orientation changes. Keep full-rate samples for analysis. Test retained geometry against the original trajectory; changing display density must not change matching results.
4. Add `Sources/SecondShotApp/Guidance/PathOverlay.swift` and a platform adapter for camera-to-view projection. Use the active viewport, orientation, and camera intrinsics; do not assume portrait pixel coordinates equal SwiftUI points. Recalculate on size changes, not by swapping width and height until a picture looks correct.
5. Render only a short look-ahead segment. Clip points behind the camera and near the projection singularity; break lines across invalid spans. Provide an edge indicator with text when the next target is offscreen instead of drawing an implausible ribbon through the viewer.
6. Offer a nonanimated target and reduced visual density for Reduce Motion. Use shape, line pattern, and text in addition to color. Keep Stop/Cancel visible above all overlays.

## Contracts and failure behavior

The renderer consumes immutable `PathDisplaySnapshot` values containing an origin identity, sample time range, tracking quality, selected target, and validity reasons. It must not mutate the recording, choose a different origin, or decide that tracking is reliable. A lost or stale pose hides precise directional cues and shows the explicit recovery state. Do not keep a green-looking target frozen over a moving preview.

Store path geometry in the persistent reference-anchor frame, using right-handed meters with camera forward along `-Z`, quaternions as `x, y, z, w`, and column-major matrices. The live renderer resolves the reference anchor into the current AR world before projection. Never treat a previous session's world coordinates as current. Projection adapters convert the resolved geometry into viewport coordinates.

## Verification and provisional acceptance

- [ ] `Tests/SecondShotCoreTests/PathSamplerTests.swift` covers endpoints, straight lines, a U-turn, self-crossing paths, zero motion, antipodal quaternions, duplicate timestamps, gaps, and malformed input.
- [ ] A synthetic fixture has reproducible output across 100 evaluations; decimation stays within its configured geometric bound and never bridges an invalid span.
- [ ] Simulator UI tests cover portrait/landscape layout, large text, Reduce Motion, and offscreen-target messaging. Their screenshots retain the synthetic-data label.
- [ ] Real-device inspection checks targets anchored at several orientations and distances; record any visible sliding rather than dismissing it as cosmetic.
- [ ] Proposed overlay budget: under 4 ms p95 CPU work per update on the agreed baseline device, measured with Instruments. This is a target, not an observed result or a universal hardware claim.

## Evidence and handoff

Save test counts, fixture identifiers, runner/SDK versions, actual screenshots, and a device overlay recording in the consented evidence location. Report rendering error separately from AR tracking error. Commit the implementation and its tests together; the handoff names unresolved projection cases and the next task in [phase 10](10-guided-retake.md). Update the phase report and status only after evidence exists.

## Primary API reference

- [Apple: ARCamera projection and imaging parameters](https://developer.apple.com/documentation/arkit/arcamera). Check API availability against the pinned SDK and iOS 17 deployment target before adopting newer replacements.
