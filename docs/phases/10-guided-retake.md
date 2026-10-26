# Phase 10 — guided retakes without misleading precision

**Status: PLANNED — all tolerances below are provisional.**

**Dependencies:** phases 02, 03, 07, 08, and [09](09-path-rendering.md). A simulator can validate matching logic and interaction states; only physical devices can establish whether guidance is useful.

## Outcome and non-goals

Help a person return to the first camera pose and repeat a short, slow movement. Separate **rehearsal**, where the person may move at their own pace, from **timed retake**, where elapsed capture time determines the intended reference pose. Neither mode recreates robotic motion control. Do not add a single “accuracy percentage,” claims of centimeter precision, automatic actor cloning, or instructions to speed up into obstacles.

## Implementation work

1. Implement `GuidanceMatcher` in `Sources/SecondShotCore/Guidance/`. For rehearsal, search only a bounded neighborhood around prior progress with an explicit restart action. A self-crossing path must not jump to a later lap because it is spatially closer. Use position and orientation costs with documented units and configurable weights.
2. For timed recording, evaluate the reference at elapsed monotonic time from the confirmed recording epoch. Show timing deviation separately from position/orientation deviation. Do not secretly retime the recording or switch to unconstrained nearest-neighbor matching to make scores look better.
3. Express positional correction in the target camera's local axes: transform `targetPosition - currentPosition` by the inverse target rotation. Verify the sign of every right/left, up/down, and forward/backward cue with fixtures; ARKit camera forward is `-Z`.
4. Add `GuidancePolicy` for threshold hysteresis, stale-sample rejection, and cue prioritization. Initial research values may use a 3 cm position band, 3 degree angular band, and 0.5 second settling interval, but these are estimated-pose UI parameters—not independently measured physical accuracy.
5. Add `Sources/SecondShotApp/Guidance/GuidanceViewModel.swift` with an injected clock and tracker. Show one primary correction plus a calm orientation reticle. Update textual guidance at a readable cadence; never run a spoken direction queue that lags behind movement.
6. Keep “Rehearse,” “Start retake,” and “Stop” distinct. Optional haptics need an off switch and a device test for camera vibration; audio cues default off during microphone recording. Starting a take requires an explicit tap and valid tracking, never proximity alone.

## State and failure contract

Use the phase-03 reducer for preparing, returning to start, rehearsing, counting down, recording, finishing, and recovery. Every asynchronous result carries the active attempt/session identifier. A stale completion cannot start a new recording or overwrite a later attempt. Lens changes, origin mismatches, tracking loss, and missing timestamps block guidance and enter [phase-11 recovery](11-tracking-recovery.md). Store the original deviations and validity flags; never replace failures with zero error.

## Verification and provisional acceptance

- [ ] `GuidanceMatcherTests` include loops, repeated positions with different orientation, sudden reversal, pauses, uneven sampling, missing samples, and out-of-order input.
- [ ] Clock-controlled tests prove countdown cancellation, elapsed-time mapping, no branch jumps, and no cues from invalid or stale samples. Set the initial stale threshold to 250 ms and test both sides explicitly.
- [ ] Simulator journeys cover rehearsal, cancelled countdown, completed synthetic retake, and failure recovery with VoiceOver identifiers. No camera permission is requested by the synthetic provider.
- [ ] Device sessions check cue sign and usability in short, consented 3–8 second moves. At least two independent testers must understand the next action without developer explanation before the UI is considered usable.
- [ ] Guidance computation target: under 2 ms p95 at the agreed sample rate on the baseline device. Measure display and sensor latency separately; do not infer end-to-end latency from unit-test speed.

## Evidence and handoff

Attach the exact policy configuration, traces, screen recordings, failures, and observed timings to the phase report. Record why each tolerance was chosen and any change before rerunning the experiment. Commit a bounded vertical slice with tests, update status honestly, and hand over unresolved recovery cases. Passing synthetic tests is not completion of the physical guidance claim.
