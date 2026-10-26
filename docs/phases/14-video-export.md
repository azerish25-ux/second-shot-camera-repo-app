# Phase 14 — dependable, nondestructive video export

**Status: PLANNED.**

**Dependencies:** validated stored media, [review/time alignment](12-review-and-time-alignment.md), and [registration refusal rules](13-registration-diagnostics.md) when an aligned output is requested. Read [the export contract](../architecture/alignment-and-export.md).

## Outcome and scope

Deliver useful files the creator can open in another editor: original-take sharing, synchronized comparison, and a simple user-controlled match cut. An optional aligned derivative is available only when its plan remains valid. Begin with a tested SDR H.264 path; do not advertise universal 4K, HDR, ProRes, 60 fps, or optical-flow frame creation. A Photos save or share action is explicit, never automatic.

## Implementation work

1. Add `ExportRequest`, `ExportPlan`, `ExportProgress`, and `ExportReceipt` under `Sources/SecondShotCore/Export/`. Include source IDs/fingerprints, output mode, trim/time mapping, native orientation, render size, target rate, crop, chosen audio source, and any accepted registration-plan identifier.
2. Implement `Sources/SecondShotApp/Export/ExportService.swift` with a bounded serial export queue, cancellation, and dependency-injected filesystem/media adapters. Use AVFoundation composition/export or an asset reader/writer renderer as appropriate; do not rerender originals merely to share them.
3. Preflight source readability, valid overlap, supported codecs, writable destination, and adequate free storage. Estimate scratch space conservatively and repeat disk-error handling during writing; a successful preflight cannot guarantee the disk stays available.
4. Normalize orientation once and explicitly choose output dimensions. Carry crop transforms and valid-region bounds through the full-resolution rendering pipeline. Reject invalid pixels rather than stretching edges or inventing content without disclosure.
5. Define an SDR-first color policy. Preserve declared color metadata; unsupported HDR input must be refused with a clear explanation or explicitly tone-mapped using a separately verified path. Never reinterpret PQ/HLG samples as SDR by changing labels alone.
6. Use media presentation times, not a frame counter, to drive video and audio mapping. Preserve source audio for raw sharing; for composites offer reference, retake, or muted audio. Do not mix two unsynchronized microphones by default. Changing the time offset must move the selected audio consistently.
7. Write to a unique owned temporary output, finish successfully, reopen and validate it, then publish atomically. Only after publication show success and offer Files/Photos/share. Cancellation or failure removes only that job's scratch files, not source takes or previous exports.

## Recovery and UI contract

Progress can be indeterminate during preparation; do not show “100% saved” when the encoder merely accepted its final frame. Surface a typed error with retry and original-sharing fallback. App termination leaves a recoverable job record; on next launch clean verified orphan scratch files safely and never resume an unknown writer blindly. Photos authorization denial retains the exported local file. Every receipt records actual format, dimensions, duration, frame rate policy, audio choice, and processing version.

## Verification and provisional acceptance

- [ ] Deterministic rendered fixtures verify orientation in both directions, aspect ratio, frame numbers, time-offset sign, trim endpoints, audio pulse position, and metadata.
- [ ] Fault injection covers missing/corrupt media, no overlap, unsupported format, disk-full midwrite, user cancellation, duplicate destination names, and termination before publication.
- [ ] Simulator UI tests verify progress, cancel, failure, original fallback, and success only after the completion result. The share sheet requires no fake success callback.
- [ ] Physical playback in Photos and one independent editor validates decoding, visible orientation, and audio. Proposed A/V error target: within one output frame on controlled pulse fixtures, measured rather than asserted.
- [ ] Proposed baseline performance target: an 8-second 1080p comparison exports within 30 seconds without unbounded memory growth. Record device, thermal state, and actual duration; failing this target does not justify concealing format changes.

## Evidence and handoff

Save exported synthetic samples as CI artifacts, validation logs, cancellation cleanup results, and consented device measurements. No real customer media is committed. Commit the verified renderer and tests together, list unsupported format combinations, and hand the exact candidate build to [phase 15](15-device-proof-gate.md).

## Primary references

- [Apple: AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter).
- [Apple: AVAssetExportSession](https://developer.apple.com/documentation/avfoundation/avassetexportsession). Select APIs available on the deployment target; isolate newer SDK alternatives behind availability checks.
