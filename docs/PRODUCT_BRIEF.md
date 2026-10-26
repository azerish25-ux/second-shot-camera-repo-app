# Product brief — Second Shot

Status: **product hypothesis / implementation specification**. Working name:
Second Shot; earlier concept name: Second Pass. Naming/trademark availability is
not established. Owner decisions may rename the product before distribution.

## One-sentence promise

Help an iPhone filmmaker record a short camera move and repeat it closely enough
to make a useful paired shot, with understandable guidance and honest limitations.

## Who and what to start with

The initial audience is independent mobile filmmakers and product-video creators
who already know why matching two takes is useful. They are not assumed to need
a full editor, social network, camera robot or automatic generative video tool.

The initial task: record a 3–8 second slow move around a small, static scene;
change one intended subject/prop; return to the recorded origin; follow a guided
retake; inspect the two takes and keep or reject them. Focus on shallow-depth,
well-lit, textured scenes where geometric differences are manageable. A match cut
or controlled wipe is a more defensible first output than invisible cloning in an
arbitrary moving scene.

Target examples: a product changes color between two passes; a desk setup changes
across a matched transition; a filmmaking student learns a repeatable move. These
are proposed use cases, not effects demonstrated by the bootstrap application.

## The experience

1. The library offers a first-run synthetic demo without asking for permissions.
2. Real capture checks device capabilities, explains camera access, and asks only
   for the permission needed for the user's next action. Audio is optional.
3. A setup view explains the bounded move, tracking requirements and clear-space
   safety; the app establishes an origin and saves a reference take.
4. The user returns to the start. Relocalization is a visible state, not a spinner
   that silently times out into fake guidance.
5. A restrained path/reticle shows position, direction and pace; tracking loss
   disables precision cues and keeps Stop reachable.
6. Review shows both originals, optional validated alignment, overlap/crop costs,
   and a choice to export, retry or discard without destroying the originals.

## Why this is differentiated enough to investigate

Camera-tracking apps already exist. CamTrackAR documents recording camera data
and exporting it to editing tools. MRMC's Tracker documents hand-recorded paths
for robotic systems. The hypothesis is that a focused **human-guided second-take
workflow** can be useful at a much smaller scale than a professional motion rig.
Neither competitor listing nor absence of an identical search result proves a
market gap. Interview users and test competitor workflows in phase 01.

Source leads (reviewed 2026-10-26; recheck before positioning):

- https://apps.apple.com/us/app/camtrackar/id1502545167
- https://www.mrmoco.com/motion-control/control-accessories/mrmc-tracker-app/
- https://developer.apple.com/documentation/arkit/saving-and-loading-world-data
- https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality

## Non-negotiable limitations

- Human-guided moves are approximate; AR pose estimates have noise and drift.
- Translating the camera through a 3D scene changes parallax. One global image
  transform cannot make arbitrary viewpoints equivalent.
- The simulator can validate injected synthetic data and UI, not tracking quality.
- Supported recording formats differ by device, OS, AR configuration and thermal
  state. No universal 4K/HDR/60fps/LiDAR claim belongs in an early build.
- Short moves may still fail. Quality diagnostics and an honest retry are product
  features, not embarrassing conditions to hide.
- No automatic claim of a collision-free route; no backwards-walking coaching.

## Scope boundaries

MVP: one reference and one repeat take, optional muted video, local projects,
one stable lens, exposure/focus behavior validated for the selected AR pipeline,
clear guidance, synchronized review, honest raw-pair export, optional restrained
alignment, accessibility and crash recovery.

Not MVP: robot hardware, third-party gimbal control, Android, iPad-specific studio,
Vision Pro, multi-camera capture, arbitrary long takes, actor cloning guarantees,
generative filling, server rendering, social feeds, accounts, collaborative cloud
editing or an all-purpose nonlinear editor. Do not build these to avoid testing
the difficult core hypothesis.

## Commercial hypothesis, not a forecast

Test a usable free preview and a **USD 24.99 one-time, non-consumable Pro unlock**.
Price, included features, territory configuration and refund language must be
validated before StoreKit integration. Do not charge to discover that a device
cannot perform the core task. Existing project access and recovery must remain
available when entitlements cannot be refreshed offline.

Illustrative arithmetic only: at 24.99 USD and an assumed 15% platform commission,
48 new purchases yield 1,019.592 USD before taxes, refunds and operating costs.
At a hypothetical 3% download-to-purchase conversion this requires 1,600 new
downloads per month. Neither figure is evidence of demand. One-time sales are not
MRR and must be replenished each month. Commission eligibility and territory
terms must be checked when monetization is implemented.

## Validation questions and stop rules

- Can a person make a useful repeated take without an expert coaching them?
- Is the result materially better/easier than their existing manual workflow?
- Can the app tell the difference between a useful pair and a misleading match?
- Does a clear demo attract the target audience, and will any of them actually pay?
- Do acquisition and support costs leave positive contribution, without deceptive
  subscription tactics, fabricated results or unsupported performance promises?

Phase 07 gates capture integrity; phase 15 gates useful repeatability. If capture
fails, stop dependent AR claims and fix the measurement pipeline. If repeatability
fails but guidance helps framing, evaluate a bounded framing-assistant pivot with
new user evidence. If neither is useful, stop commercial scope rather than burying
the failure under more screens. See [acceptance gates](ACCEPTANCE_GATES.md).

## Design direction

The app should feel like a compact professional cinema instrument: clear view of
the scene, generous typography off-camera, disciplined telemetry on-camera,
graphite surfaces, paper-white content and restrained cyan guidance. A finished
screen must communicate what to do next and how much to trust the result. Beauty
must support this clarity. See [design specifications](design/README.md).
