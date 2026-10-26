# Phase 18 — performance, battery, thermal behavior and device support

**Status:** PLANNED. All budgets below are initial engineering targets, not measured product claims.

## Outcome and dependencies

Make capture and guidance predictable on the least capable device the product will support. Depend on phases 07, 10, 14 and the physical product-proof gate in phase 15; final signoff also includes the completed UI/library behavior from phases 16–17. A green simulator test or a powerful development Mac cannot establish a phone's recording reliability, thermal limits, memory pressure or sensor latency.

Use capability-based modes. The default candidate to validate is a 1080p/30-fps recording path; 4K, high frame rates, HDR and LiDAR assistance are optional modes only after separate evidence. Minimum iOS 17 is a deployment decision, not proof that every device capable of installing it can perform every capture mode.

## Implementation work

1. Add an injectable performance/thermal service in `Sources/SecondShotApp/Diagnostics/`. Observe the operating system's thermal state and relevant interruptions. Keep raw camera data out of diagnostics and avoid introducing a remote telemetry SDK. Record redacted local counters and signposts that testers can deliberately export.
2. Bound pose, video-frame and audio queues. Establish backpressure and dropping policies separately: losing a video frame is not equivalent to inventing a pose timestamp. Persist missing-frame/invalid-tracking markers so review can explain degraded takes.
3. Profile the actual ARFrame-to-writer path, pixel-buffer retention, color conversion, pose serialization and guidance rendering. Reuse pools and avoid per-frame filesystem writes or synchronous thumbnails on the capture actor. Work on the smallest confirmed bottleneck first.
4. Keep display updates decoupled from capture timestamps. Lower decorative guide complexity before sacrificing source integrity. Never silently switch lens, resolution or frame rate during a take; if a mode cannot continue safely, end the segment with an explicit reason and preserve recoverable output.
5. Build a support matrix covering at least an older supported non-LiDAR phone, a newer standard phone and a LiDAR-equipped Pro phone if LiDAR features are offered. Include the oldest supported OS and a current supported OS on real hardware where available. Document exact device identifiers, software/build versions and tested format combinations, not labels such as “all iPhones.”
6. Add low-space, low-battery, foreground/background, external-audio-route and extended-session scenarios. A safety-critical decision must use observed state, not a synthetic “temperature” estimate inferred from elapsed time.

## Tests and provisional budgets

Unit-test the policy by injecting each thermal state, storage pressure, queue saturation and cancellation. Simulator UI tests verify the warning text, reachable Stop, disabled unavailable modes and recovery paths. They do not test heat or hardware throughput.

On each declared device class, run ten consecutive bounded reference/retake pairs, then a 15-minute mixed recording/review/export session. Keep movement safe and consistent. Report distributions and all failed attempts. Initial targets are: no app crash or corrupted saved project; less than 1% video-frame loss in the supported default mode; p95 pose-to-visible-guidance latency below 150 ms; and no unbounded memory growth across ten pairs. These targets complement, and must not weaken, phase 15's geometric/usability criteria. Instrumentation limitations must be disclosed; callback timing alone is not end-to-end display latency.

Measure cold/warm launch, peak memory, battery change, disk write volume, export duration and observed thermal state. Record ambient conditions and other relevant workload. Do not publish a universal battery-life estimate from one phone.

## Failure and release decisions

At serious thermal pressure, warn and reduce optional rendering; at critical pressure, end capture safely if the platform allows and explain recovery. Never hide the operating system's interruption behind a successful recording state. If the floor device misses budgets, either optimize, remove an optional mode or raise the support floor through an explicit product decision. Do not silently widen budgets after inspecting failures.

## Evidence and handoff

Store Instruments summaries, mode-by-device results, redacted traces, test dates, exact commit SHA and measurement method in a phase report linked from [device validation](../testing/DEVICE_VALIDATION.md). Keep original personal recordings outside the repository. Add regression tests for policy changes and update capability copy before declaring support.

Primary references, checked 2026-10-26: [ProcessInfo thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property), [MetricKit](https://developer.apple.com/documentation/metrickit). Recheck availability and behavior for the pinned SDK; neither API is itself an accuracy benchmark.
