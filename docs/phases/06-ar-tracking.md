# Phase 06 — AR session and pose recording

**Status:** PLANNED. **Dependencies:** phases 02–05. **Evidence:** no real tracking implementation or accuracy evidence assumed.

## Outcome and scope

Connect one real ARKit world-tracking session to the tested domain model. Capture a trace with provenance and quality flags while showing a truthful preview. Do not implement pose comparison across independent origins, claim exact positioning, or treat successful simulator UI as AR validation.

## Implementation tasks

1. Implement an `ARTrackingService` in `Sources/SecondShotApp/Capture/` behind the core frame-source protocol. Create and own one `ARSession`; choose gravity-aligned world tracking. Do not request geographic location merely to obtain a compass-aligned frame.
2. Build a preview adapter with a documented source-image-to-view transform. Camera-pixel coordinates, portrait screen points, and world meters are separate spaces. Rendering a camera preview must not mutate the stored pose or intrinsics.
3. On each frame callback, copy a small immutable record: sample ID, source timestamp, tracking epoch, reference-origin identity, camera pose, intrinsics, pixel dimensions, and normalized tracking state/reason. Keep ARKit objects out of `SecondShotCore`.
4. Preserve the frame's source timestamp; establish a per-take baseline later. Do not timestamp frames with callback arrival time or `Date()`. Track callback delays separately as performance diagnostics.
5. Define camera/world/reference transforms using the [coordinate contract](../architecture/capture-and-coordinates.md). Create a stable reference anchor only after acceptable tracking; distinguish that anchor identity from transient session IDs and map-file IDs.
6. Implement a bounded sample stream and buffer ownership policy. Do not retain an unbounded list of `ARFrame`/pixel buffers. Serialize necessary values promptly and throttle UI telemetry independently of sensor delivery.
7. Convert tracking-quality changes and delegate failures into state-machine events. On stale or limited tracking, remove confident correction cues, show a plain-language reason, and prevent a failed frame from appearing as a valid zero-error result.
8. Increment the tracking epoch on resets. A new epoch cannot reuse old world-space coordinates without successful restoration of the reference anchor/map relationship. Stop recording work before tearing down the session.

## Concurrency contract

Choose one documented delegate queue and transfer only safe copied values to actors. Platform buffers must remain inside an explicit bounded ownership boundary; do not add `@unchecked Sendable` merely to silence diagnostics. The main actor receives presentation snapshots, not per-pixel conversion work. Cancellation removes delegates/tasks and releases retained buffers.

## Verification

**Core/simulator:** replay synthetic normal/limited/unavailable/stale frames; empty stream; timestamp reversal; reset mid-trace; and mixed origin IDs. Assert the warning state appears and cannot show a successful alignment score. Confirm the synthetic provenance survives serialization.

**Device:** in a clear, textured, well-lit room record stationary and short controlled movement traces; then test low texture, dim lighting, temporary camera obstruction, rapid motion, and interruption. These are reliability probes, not invitations to move unsafely. Record the actual observations and configuration.

Provisional targets: stale telemetry is visibly invalid within 250 ms of the configured freshness limit; a 60-second diagnostic run has bounded buffer usage rather than growth proportional to retained frames; each accepted sample carries a valid origin and timestamp. Profile actual device results before adjusting targets.

## Failures and handoff

ARKit “normal” tracking is a state estimate, not a centimeter guarantee. Do not generate synthetic frames to keep the screen smooth when hardware stops delivering. Recovery may continue preview after tracking returns, but a take crossing an invalid epoch remains incomplete.

- [ ] Adapter boundaries, queue ownership, and teardown reviewed.
- [ ] Raw traces contain provenance, origin, time, and quality metadata.
- [ ] Simulator failure scenarios and physical tracking observations documented separately.
- [ ] No private room maps/images committed; sanitized metrics only.
- [ ] Coordinator pushes the reviewed checkpoint; phase-07 gate remains pending.

Primary references: [ARConfiguration](https://developer.apple.com/documentation/arkit/arconfiguration), [ARFrame](https://developer.apple.com/documentation/arkit/arframe), and [tracking lifecycle](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality).
