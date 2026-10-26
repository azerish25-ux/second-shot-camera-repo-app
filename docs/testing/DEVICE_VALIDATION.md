# Physical-device validation protocol

**Status: PLANNED — no physical-device result is recorded here.**

This is the operational protocol for Second Shot's hardware-dependent claims. The
bootstrap app and GitHub Actions synthetic demo do not satisfy it. Read
[acceptance gates](../ACCEPTANCE_GATES.md), [phase 07](../phases/07-reference-capture.md),
[phase 15](../phases/15-device-proof-gate.md) and
[performance/device support](../phases/18-performance-and-device-matrix.md).
If a linked phase is renamed during integration, update the link; never infer a
passed gate from a missing document.

## What each evidence class proves

| Evidence | Can establish | Cannot establish |
| --- | --- | --- |
| Pure-Swift fixtures | Mathematical/state/storage behavior on specified inputs | Camera calibration, drift, video synchronization |
| iOS Simulator journeys | Compiled app, navigation, synthetic fault UI, screenshots | Real AR tracking, tactile usability, heat, camera output |
| Instrumented real device | Observed capture/pose/video/thermal behavior for that run | General performance on every iPhone or scene |
| Controlled user pilot | Task usefulness under the registered protocol | Guaranteed repeatability, market demand or income |

Every report labels its evidence class. Imported fixture playback on a phone is
still fixture evidence, not a physical capture test.

## Authority, consent and safe setup

Obtain owner approval for signing/distribution and participant consent for the
experiment and any recording sharing. Do not invite testers or upload their media
as a side effect of implementing this protocol. Use an uncluttered, privately
controlled filming area. Move slowly on level ground; never ask someone to walk
backwards, use stairs, approach traffic or ignore obstacles to keep a reticle
centered. Use a spotter when the operator's attention is on the phone. Stop at any
participant request, unstable footing, unexpected heat or unreliable feedback.

Keep raw footage, world maps, audio, device identifiers and participant details in
an owner-approved restricted evidence location with a retention/deletion policy.
Commit only redacted summaries, synthetic reproductions and references that do
not reveal private files. A public GitHub Actions artifact is not appropriate for
personal room geometry or footage. Get separate permission for public marketing.

## Freeze the candidate before collecting results

Record the exact commit SHA, distribution build number, app version, compiler/SDK,
fixture/schema version, guide policy and enabled algorithms. Choose the supported
device/format matrix from observed capabilities. At minimum include an older
supported non-LiDAR phone, a newer non-LiDAR phone and a Pro-class phone when that
class is offered. LiDAR is optional; its presence does not certify more accurate
retakes. Identify model/OS/build precisely and record battery/thermal/storage
conditions. Do not hardcode future device marketing names into acceptance rules.

Freeze the phase-07 and phase-15 numeric thresholds and review rubric before the
held-out experiment. Preserve a separate tuning set. If the protocol changes,
version it, explain why and collect new held-out data; do not quietly reclassify
earlier failures. Phase 15 defines the canonical product-proof denominators and
thresholds; keep the acceptance-gates summary consistent with it. UI color
thresholds or a demo score cannot redefine success.

## Hardware integrity sequence — gate from phase 07

1. Start a clean, real session and verify the actual capability/lens/format used.
   Confirm the rear-camera owner and that a second independent capture session is
   not fighting ARKit for the camera. Exercise both approved audio and silent
   routes if audio ships.
2. Capture bounded 3–8 second reference moves. Inspect the finished movie,
   timestamp ledger, frame counts, pose validity, intrinsics and origin identity.
   Verify first/last frame, orientation and playable finalization. Plot timestamp
   spacing; callbacks merely arriving in order is not a synchronization proof.
3. Check audio/video correspondence with an observable event when audio is
   enabled. Record the method, precision and uncertainty. Compare observed
   results with the frozen phase-07 tolerance.
4. Exercise safe interruptions: cover the camera while stationary, background
   the app, change an audio route, deny permission, approach storage pressure and
   cancel at multiple points. Verify invalid segments remain invalid, Stop stays
   available and completed originals survive. Never fabricate environmental
   obstacles merely to test a safety message.
5. Restart/relocalize against the same scene, a significantly changed scene and
   an intentionally wrong location. Record timeout and refusal behavior. No
   wrong-origin pose must be accepted as a matched reference.

Any origin mixing, corrupted source, silent writer failure or fake valid-tracking
state blocks dependent capture claims immediately. Passing gate 07 proves only
the bounded capture pipeline, not useful human repeatability.

## Useful-retake experiment — gate from phase 15

Use the registered pilot: ten consenting creators, three short scenes and
guided/unguided conditions, yielding 60 predeclared evaluation cases: 30 guided
and 30 unaided. Each case permits at most two paired-shot attempts, so the study
can involve up to 120 actual attempts. Counterbalance condition order to reduce
learning bias. Include a textured near-planar scene, a foreground/background
depth-rich scene and a safely accessible mixed-texture scene. Freeze permitted
assistance and attempt limits before starting.

Count failures to start, retries, cancelled takes and missing exports. Report
first-attempt success and success within the two-attempt case budget separately,
with counts and denominators. The phase-15 70% guided-usefulness and 20-percentage-
point improvement thresholds use case rates, not successful exported clips;
the eight-of-ten usability criterion concerns each participant's first guided
flow. Do not discard poor scenes or operators to improve the result. Two reviewers
should evaluate output with condition hidden when feasible. Use the registered
rubric for useful match cuts: framing continuity, visible jumps, distortions,
crop cost and creator intent. Preserve reviewer disagreements and resolve them
transparently. Record flow-completion time and whether live developer coaching
was required.

The app's own pose estimates may diagnose relative error; they are not independent
ground truth. Use a calibrated independent reference only when claiming absolute
camera-position/orientation accuracy. For near-planar cases, use held-out image
landmarks to report reprojection error, and document the annotation method.
Report depth-rich scenes separately because one homography cannot remove general
3D parallax. A well-colored overlay is not output-quality evidence.

## Reliability and accessibility follow-through

Reopen every exported clip using an independent player and check the retained
originals. Test installation/update, Files sharing, permissions and recovery using
the signed candidate. Execute phase 18's repeated-take and sustained-session
benchmarks with actual heat/memory observations. Run VoiceOver, large text,
one-handed reach and disabled-audio/haptics trials with consented appropriate
testers. Record what cannot yet be validated rather than broadening claims.

## Minimum redacted result record

```json
{
  "protocolVersion": 1,
  "runID": "assigned-before-test",
  "evidenceClass": "physical-device",
  "commitSHA": null,
  "deviceModel": null,
  "osBuild": null,
  "captureFormat": null,
  "caseID": null,
  "condition": null,
  "sceneClass": null,
  "attemptNumber": null,
  "outcome": "NOT_RUN",
  "failureReason": null,
  "metricDefinitionsVersion": null,
  "reviewerDecision": null,
  "restrictedEvidenceReference": null
}
```

Populate real values only after observing them. Add explicit units and measurement
methods for metrics; do not replace unavailable measurements with zero. Store
participant contact/consent records separately from this technical summary.

## Decision and handoff

The owner/reviewer chooses continue, bounded pivot or stop using the registered
criteria and all denominators. A useful framing-assistant pivot needs its own
claim and experiment; it does not inherit a failed retake claim. Update STATUS
with `BLOCKED_DEVICE` while required data is absent, or a precise observed result
when it exists. Link the redacted report, exact SHA, tested modes, exclusions,
retention deadline and next experiment. Do not label the product production-ready
because a subset of the protocol succeeded.

Primary reference: [Apple ARKit tracking quality and session lifecycle](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality).
The protocol is an original engineering proposal, not an Apple certification.
