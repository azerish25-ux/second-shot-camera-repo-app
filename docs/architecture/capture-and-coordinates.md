# Capture, coordinate, and time contracts

**Status:** normative implementation design, not a claim that these adapters already exist. Read `docs/STATUS.md` for observed implementation evidence. This contract supports phases 02–08 and must stay consistent with alignment/export work. All thresholds below are project policies requiring measurement, not Apple accuracy guarantees.

## 1. Boundaries and ownership

`Sources/SecondShotCore` owns pure value models, transitions, validation, interpolation, and error calculations. It cannot import ARKit, UIKit, AVFoundation, or platform buffers. `Sources/SecondShotApp` owns camera/AR adapters, media writing, permissions, file storage, and the UI. Protocols allow deterministic synthetic sources to exercise the same domain transitions.

One ARKit session owns rear-camera imagery. Apple documents that ARKit manages its own camera pipeline. Do not add a separate session competing for that camera to obtain higher resolution. The proposed pipeline consumes a frame's image and its corresponding pose together, sends bounded media work to an owned writer, and emits a lightweight UI snapshot. Actual supported combinations must pass the phase-07 device gate.

Optional audio should first use the documented ARKit configuration/delegate route. Permission, route changes, timestamp mapping, and interoperability with the writer still require validation. An independent microphone-only adapter is a separately reviewed fallback, not an assumed requirement.

## 2. Spaces, units, and transforms

| Space | Meaning | Contract |
| --- | --- | --- |
| `W` | Current AR world estimate | Right-handed, meters, gravity-aligned; validity tied to a tracking epoch |
| `R` | Persisted reference-anchor frame | Stable project identity; recovered through the corresponding anchor/map |
| `C` | Camera optical frame | Right-handed; view direction is negative Z; independent of screen orientation |
| `I` | Original image pixels | Captured pixel dimensions and intrinsics; never assumed equal to portrait UI size |
| `V` | Viewport points | Rendering-only orientation, crop, aspect ratio, and safe-area transform |

Name transforms `destinationFromSource`. With column vectors, `worldFromCamera` maps a camera-local point into `W`. The stored pose is:

`referenceFromCamera = inverse(worldFromReference) * worldFromCamera`

Composition order is not interchangeable. Serialize matrices column-major, and quaternions as `x,y,z,w`. Distances are meters in storage; angles are radians internally where appropriate and degrees only in explicit presentation fields. Include a convention version rather than relying on a comment inside one implementation.

Use the reference anchor's current resolved transform when mapping the current world's samples to `R`. A new session/reset produces a new `trackingEpoch`; it does not authorize reuse of old world coordinates. The persistent `referenceOriginID`, map-file ID, AR anchor ID, and current session/epoch ID are distinct fields. Reject mixed-origin comparisons unless an explicit validated transformation bridges them.

The preview's image-to-screen transform is not a world-space rotation. Portrait/landscape changes, cropped aspect-fill preview, and encoded orientation must be tested separately. A pixel correspondence after homography is not proof of matching 3D viewpoints.

## 3. Time and accepted-frame ledger

Preserve `ARFrame.timestamp` as raw source-clock seconds. At the first accepted frame in a take, record `t0` and compute elapsed capture time from source timestamps, never from callback arrival or calendar time. The writer converts elapsed time into rational `CMTime` with recorded timescale/rounding policy. Do not use a nominal frame index as elapsed time.

Each accepted encoded frame needs a ledger entry with take/sample ID, original source timestamp, elapsed time, media PTS value/timescale, tracking epoch, reference origin, and quality. Every dropped/rejected frame is accounted for separately. Keep metadata and movie acceptance transactional enough that a completed manifest cannot advertise unknown correspondence.

Audio sample buffers retain their original PTS. Do not assume an audio/video common epoch solely because both are seconds. Verify the supported clock relationship and conversion, then measure residual alignment with visible/audible events near both ends of a take. Record conversion parameters and uncertainty; reject discontinuities rather than hide them with sample stretching.

Calendar dates are for library display and audit records only. A clock change or time-zone change cannot alter a take's timeline. Retake/reference time correspondence is a later alignment mapping; two takes beginning at elapsed zero are not automatically synchronized in action.

## 4. Sample and manifest fields

A versioned sample minimally carries `sampleID`, `takeID`, provenance (`synthetic`, `deviceAR`, or `importedUntracked`), source clock/timestamp, elapsed time, pose, intrinsics, dimensions, convention version, reference origin ID, epoch, and tracking state/reason. Normalize invalid/missing information explicitly; do not invent an identity transform or zero deviation.

The take manifest adds selected camera configuration, actual codec/color/orientation metadata, audio status, source/accepted/dropped counts, writer outcome, completeness, and relative file references. Original movies and source metadata remain immutable. Derivatives store algorithm/version/source hashes and can be discarded without losing originals.

Apply schema size limits and path validation before decoding/importing arbitrary projects. Spatial maps and reference images reveal private surroundings and receive the same care as footage. Keep normal logs content-free; raw device evidence is private unless separate informed permission permits publication.

## 5. Resource and failure policies

Bound every queue by frames/bytes and document ownership of retained pixel buffers. A slow writer produces backpressure and visible diagnostics, not unbounded retained `ARFrame`s. Avoid unsafe `Sendable` promises; copy numeric values across actors and keep platform buffers in a reviewed ownership boundary.

Tracking loss, stale frames, camera failure, backgrounding, invalid timestamps, low storage, or writer failure ends/incompletes the active take under the lifecycle policy. Stop is always reachable. Never silently swap in synthetic frames on a physical device. A new attempt uses a new writer and operation ID; callbacks from cancelled attempts cannot publish completion.

`normal` tracking is an estimator state, not verified physical precision. Display an estimated deviation only when provenance, tracking validity, reference identity, and time correspondence are valid. Invalid values disappear behind clear guidance rather than freeze as a reassuring green number.

## 6. Verification boundaries

Core/simulator tests verify math, schema, transitions, generated-buffer encoding, error handling, and UI. Real iPhones must verify AR capture, supported formats, exposure/focus behavior, world-map restoration, audiovisual synchronization, thermal behavior, and usable repeat shots. Phase 07 is the early capture gate; phase 15 is product usefulness. Neither can be replaced by screenshots or fabricated recordings.

## Primary source register

Reviewed during repository setup, 2026-10-26. Recheck API availability against the selected SDK before implementation; source pages can evolve.

- [ARConfiguration and camera ownership](https://developer.apple.com/documentation/arkit/arconfiguration)
- [World tracking coordinate conventions](https://developer.apple.com/documentation/arkit/understanding-world-tracking)
- [Gravity alignment](https://developer.apple.com/documentation/arkit/arconfiguration/worldalignment-swift.enum/gravity)
- [Frame image, camera, and timestamp](https://developer.apple.com/documentation/arkit/arframe)
- [Optional ARKit audio](https://developer.apple.com/documentation/arkit/arconfiguration/providesaudiodata)
- [Saved-world restoration](https://developer.apple.com/documentation/arkit/saving-and-loading-world-data)
- [Tracking lifecycle](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality)
- [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [Capability-dependent 4K format](https://developer.apple.com/documentation/arkit/arconfiguration/recommendedvideoformatfor4kresolution)

Source API descriptions establish available mechanisms. The queue, schema, privacy, numerical tolerance, and gate rules above are Second Shot design decisions requiring their own tests.
