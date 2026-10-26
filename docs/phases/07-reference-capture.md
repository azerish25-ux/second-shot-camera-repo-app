# Phase 07 — synchronized reference capture and early hardware gate

**Status:** PLANNED. **Dependencies:** phases 02–06 and the preregistered phase-01 protocol. **Evidence:** hardware gate not run.

## Outcome

Save a playable reference movie with a trustworthy frame-to-pose ledger. This phase is an **early engineering feasibility gate**: it proves whether the chosen capture path is usable enough to continue. It does not prove guided-retake accuracy or product usefulness; those remain the separate phase-15 gate.

## Implementation tasks

1. Implement a `ReferenceRecorder` and `MovieWriter` under `Sources/SecondShotApp/Capture/`. ARKit owns the rear camera. Consume `ARFrame.capturedImage` and corresponding metadata; do not start a competing rear-camera `AVCaptureSession`.
2. Select a device-supported, tested SDR configuration, initially targeting 1080p/30 where available. Record actual dimensions, nominal cadence, encoded cadence, pixel format, color metadata, orientation, lens/configuration, and intrinsics. Format changes end the take; never label upscaled output native 4K.
3. At the first accepted frame establish `t0`. Convert source elapsed time to rational media PTS using an explicit timescale and rounding policy. Keep source timestamps and encoded PTS in a ledger. Use actual timestamps, not `frameIndex / nominalFPS`, because frames can arrive irregularly or be dropped.
4. Write through an availability-aware AVAssetWriter adapter. Respect readiness/backpressure, bound pending buffers, record rejected frames, and fail explicitly on append/finalization errors. Current Apple APIs evolve; retain an iOS-17-compatible implementation path and document deprecation decisions.
5. Preserve source pixels and orientation correctly without burning the guidance HUD into originals. A thumbnail may be a derivative. Complete the asset, validate readability, then publish its completed storage manifest atomically.
6. If audio is enabled, prefer researching ARKit's `providesAudioData` and audio-sample delegate path. Preserve sample PTS and validate its mapping to the video clock; do not assume shared epochs. Require permission, handle route changes, and present silent capture explicitly. A separately owned microphone-only path needs an ADR and evidence, never a second rear-camera owner.
7. On Stop, background, tracking loss, or resource failure, finalize once or mark the asset incomplete. A later retry is a new take and writer. Never overwrite the last good reference to hide an unsuccessful replacement.

## Automated verification

Use synthetic pixel buffers with visible frame numbers and a known moving pattern. Assert encoded dimensions/orientation, monotonic PTS, exact sample-ledger correspondence, dropped-frame accounting, end-of-stream handling, and finalization-before-publication. Inject disk-full, writer backpressure, cancellation, and timestamp discontinuities. Simulator media tests verify the writer, not sensor synchronization.

## Early physical gate

On at least two supported iPhones, including a non-LiDAR model, record twenty short takes per device across the documented baseline scenes. Include portrait/landscape where supported, a static textured subject, a near/far parallax scene, low-light/low-texture failure cases, and intentional safe interruptions.

Provisional pass targets: every completed take is playable with correct orientation; every encoded video frame maps to its captured pose sample; no undetected timestamp reversal, origin change, writer failure, or recording-after-Stop; drop rate under 1% in the stated baseline conditions. If audio is in scope, measure flash/clap alignment at start/end and target residual audiovisual error no greater than one selected video-frame interval. Report method and uncertainty.

## Decision and handoff

Record device model/OS, exact commit, configuration, scene IDs, all attempt outcomes, error counts, and private evidence references in a sanitized phase report. Do not upload identifiable media/maps to public CI artifacts.

- [ ] Automated writer and ledger tests pass on the pushed SHA.
- [ ] Hardware matrix and all failed attempts are included.
- [ ] Gate is explicitly PASS, FAIL, or BLOCKED_DEVICE, with reviewer sign-off.
- [ ] Failed capture evidence blocks dependent production claims; independent UI may continue.
- [ ] Missing device access is never replaced by simulator success.

Primary references: [frame timestamps](https://developer.apple.com/documentation/arkit/arframe/timestamp), [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter), and [ARKit audio delivery](https://developer.apple.com/documentation/arkit/arconfiguration/providesaudiodata).
