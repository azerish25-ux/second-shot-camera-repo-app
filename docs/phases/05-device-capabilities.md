# Phase 05 — capabilities, permissions, and safe entry

**Status:** PLANNED. **Dependencies:** phases 03–04. **Evidence:** no physical-device capability matrix yet.

## Outcome

Make every capture option reflect the device and the user's actual permission choices. A simulator is a deterministic demo environment, not an AR-capable iPhone. The app must never turn a failing live session into synthetic tracking without the user explicitly choosing Demo Studio.

## Implementation tasks

1. Add a capability-report model in `Sources/SecondShotCore/Capabilities/` and a platform probe in `Sources/SecondShotApp/Capabilities/`. Include runtime mode, OS version, AR world-tracking support, available capture formats, optional depth support, microphone authorization, and photo-export authorization. Store capability reasons, not just booleans.
2. Inject `CapabilityProvider` and `PermissionProvider` into the session coordinator. Select the synthetic provider at a clear simulator/test entry point. Unsupported physical devices receive a truthful explanation and may explicitly open the demo.
3. Evaluate `ARWorldTrackingConfiguration.isSupported` and enumerate the configuration's supported video formats. Treat advertised resolution/FPS/HDR as candidates; phase 07 still must prove that the complete recording pipeline works. LiDAR is not a default requirement and must not be inferred from “Pro” in a device name.
4. Implement a staged permission journey: camera permission only on entering live capture; microphone permission only after opting into audio; Photos add-only access only if the chosen save route requires it. File sharing should not demand access to the user's entire photo library.
5. Add purpose strings to the app's configuration and a human-readable explanation immediately before the system prompt. Handle not-determined, denied, restricted, and authorized states separately. Provide Settings navigation when relevant, never repeated prompt loops.
6. Probe camera controls through documented ARKit-supported configuration access, with availability checks. A lock control is enabled only when the hardware/API and capture test support it. Present automatic exposure/focus honestly when locking is unavailable. Avoid arbitrary settings that degrade feature tracking.
7. Define a format selection policy: prefer a tested modest SDR baseline, retain the exact selected dimensions/cadence, and explain fallback. No upscaled “4K,” hidden lens switching, or assumed compatibility of every camera mode with world tracking.

## UX and data contract

Capability reports must not contain device serial numbers, advertising identifiers, GPS, or private scene content. Permission denial leaves the reference and library untouched. “No microphone access” means a visibly silent recording or an explicit blocked action according to the selected mode, never an apparently successful audio recording.

Show the distinction between **unsupported hardware**, **permission denied**, **temporarily unavailable**, and **not implemented in this build**. These are different user problems with different recovery actions. The foundation's planned Live Capture card must keep its honest explanation until this phase and capture adapters are implemented.

## Verification

- **Core:** table-test every capability/permission combination and fallback policy. Future/unknown authorization values fail safely.
- **Simulator UI:** test first-use, denied, restricted, microphone off, explicit demo selection, and return from Settings through injected responses. The demo must cause zero camera/microphone prompts.
- **Hardware:** record observed reports on at least one non-LiDAR and one LiDAR-equipped supported iPhone, with exact iOS/build versions. Test revocation in Settings, microphone denial, another app interrupting the camera, and a supported format absent from an older device.
- **Privacy review:** every requested permission has a current feature requiring it; no unused location or broad photo permission exists.

## Acceptance, recovery, and handoff

All permission branches must reach a stable screen with an appropriate next action. Missing hardware evidence is a blocked physical subtask. Tests must verify behavior, not merely that strings appear in `Info.plist`.

- [ ] Capability report schema and observed device matrix attached.
- [ ] Unsupported controls disabled with a reason; no universal quality claims.
- [ ] Permissions and fallback UI pass actual simulator journeys.
- [ ] Physical observations and unrun combinations explicitly separated.
- [ ] Coordinator reviews, commits, pushes, and records the next adapter task.

Primary references: [ARKit support and permission checks](https://developer.apple.com/documentation/arkit/verifying_device_support_and_user_permission), [supported video formats](https://developer.apple.com/documentation/arkit/arconfiguration/supportedvideoformats), and [configurable camera device](https://developer.apple.com/documentation/arkit/arconfiguration/configurablecapturedeviceforprimarycamera).
