# Screen specifications and state coverage

Status: **planned production screens**. The bootstrap scope contains only selected
synthetic demo journeys; consult [STATUS](../STATUS.md) for delivery evidence.
An accessibility ID listed here is an implementation
contract to add when that feature ships, not evidence of current functionality.

## 1. Library and Demo Studio

The opening screen is an editorial studio, not a dashboard. Show “Second Shot,”
a concise explanation, one sample card, and “Explore demo.” A reserved live
capture entry explains that device capture is not implemented in the scaffold.
The sample is a geometric schematic labeled “Synthetic demo,” never a stock
photograph that could be confused with output from the app.

In production, “New shot” becomes the main action; recent projects follow with
clear Reference ready / Retake ready / Exported / Needs attention labels. The
first empty library explains what the user will create and offers the demo. A
corrupt project displays its name and recovery/export options without blocking
access to healthy projects. Local loading uses a compact progress description;
do not show an empty library before loading finishes.

IDs: `library.demo.open`, `library.capture.open`, `library.settings.open`,
`library.project.<stable-id>`, `library.empty`, `library.loading`.

Demo contract: `demo.badge` persists across reference, guidance, and review.
Buttons use “Simulate reference” (`demo.reference.create`), “Start demo retake”
(`demo.retake.start`), and “Review demo” (`demo.review.open`). “Simulate tracking
loss” (`demo.tracking.interrupt`) and “Resume demo” (`demo.tracking.resume`)
exercise failure handling. Nothing silently requests a camera or creates real
media. Exiting a demo never deletes real projects.

## 2. Capability, explanation, and permissions

Before the first real capture, show the proposed short-move workflow and a
device capability summary. Separate supported, unavailable, and unverified
capabilities; “iPhone Pro” is not itself proof of a supported format. Camera
permission is requested only when the user chooses real capture. Explain the
purpose in one sentence before the native prompt. Microphone capture is optional
and has a separate choice; microphone denial must not disable silent capture.

Camera denied: explain how to change the permission and retain the demo entry.
Camera restricted: state that device policy may control access; do not repeatedly
prompt. Unsupported tracking: allow library/review/demo, but explain why guided
capture is unavailable. No fake fallback that renders plausible tracking numbers.

IDs: `capabilities.summary`, `permissions.camera.request`,
`permissions.microphone.toggle`, `permissions.settings.open`, `capabilities.demo`.

## 3. Setup and scene mapping

The live view occupies most of the screen. Show project name, capture format,
tracking state, and one practical instruction. Explain that a static, textured,
well-lit scene helps the experiment; the app does not certify that a space is
safe. Keep “Check the floor and your surroundings. Stop if unsafe.” available
without teaching backwards walking or suggesting roads or stairs.

Mapping readiness is based on actual adapter state, not elapsed time or a fake
progress percentage. If mapping is limited, explain the observed cause where
available. Camera occlusion or darkness should show a different message from
permission denial. Lens/format changes after mapping invalidate incompatible
setup and require explicit confirmation, not silent origin reuse.

IDs: `setup.tracking.status`, `setup.format`, `setup.reference.start`,
`setup.cancel`, `setup.help`.

## 4. Reference recording

Ready state shows the framing guide, selected format, and “Record reference.”
Recording state shows a solid red recording indicator, the word “Recording,”
monospaced elapsed time, and a large Stop control. Do not animate a countdown
unless the user selected one. If selected, support Cancel throughout it.

While recording, remove optional panels and disable incompatible settings with
a reason. Do not auto-switch lenses. A tracking-loss banner must explain whether
media is still being recorded and whether its pose data is unusable. After Stop,
show “Saving reference…” until durable save succeeds; only then show a reference
ready state. On a storage error, say what was saved and offer a bounded retry or
discard. Never promise a clip exists before the writer and project store confirm.

IDs: `reference.record`, `reference.stop`, `reference.elapsed`,
`reference.saving`, `reference.failure`, `reference.ready`.

## 5. Return to start and relocalization

Show a saved reference thumbnail with a distinct “Reference” label, not a fake
live camera overlay. The user can adjust overlay opacity through an accessible
slider. Display “Finding the saved scene…” while the adapter reconciles the world
map. An indefinite spinner is not an adequate recovery plan: explain that the
saved scene may no longer match and offer Retry, Record new reference, or Cancel.

Only show the start marker when the origin is verified. Origin mismatch makes
guidance unavailable. “Start position found” means estimated alignment to the
recorded origin; it does not mean exact camera reproduction. Preserve the original
reference when starting a new mapping attempt.

IDs: `relocalization.status`, `relocalization.opacity`, `relocalization.retry`,
`relocalization.newReference`, `relocalization.cancel`.

## 6. Guided retake

The cyan path is thin and spatially grounded. A target marker gives orientation
and the next useful position cue; avoid covering the subject. Show one primary
instruction at a time, such as “Shift left slightly” or “Hold here.” Detailed
position/angle differences are optional, include units, and remain estimates.
Time progress is visually separate from spatial alignment so “50% complete”
cannot be mistaken for a quality score.

Ready, recording, tracking-limited, tracking-lost, and finishing states have
different labels. On stale/lost tracking, remove directional instructions and
good-looking numbers immediately, keep Stop available, and show “Guidance
unavailable.” A stale marker must not continue moving along a synthetic path.
Feedback never instructs someone to hurry or ignore their surroundings.

IDs: `retake.guidance`, `retake.tracking.status`, `retake.progress`,
`retake.record`, `retake.stop`, `retake.metrics.details`.

## 7. Interruption and recovery

Use a persistent inline or full-state interruption view for call/background,
camera interruption, tracking loss, low storage, and thermal stop. State what
happened, what was preserved, and which next action is valid. These reasons must
not all collapse into “Something went wrong.” Tracking recovery cannot resume a
take across incompatible timestamps or origins without a recorded discontinuity.

Recovery is deliberate. “Try again” may start a new take; label it that way.
No automatic recording restart after returning to the app. Cancel stays available
and leads to the intact project. Do not put a paywall in a recovery path.

IDs: `capture.interruption.reason`, `capture.interruption.savedState`,
`capture.interruption.retry`, `capture.interruption.returnToProject`.

## 8. Review and comparison

Top hierarchy: project title, take pair, mode/source, then a large preview. Offer
Reference, Retake, Split, and Overlay using labeled controls. A moving divider
has a large handle and accessible alternatives. Playback uses a common timeline
only after the temporal correspondence is defined. Expose reference/retake time
offset and allow reset; never imply that matching durations proves alignment.

Keep originals intact. If registration is attempted, label Original versus
Adjusted, show crop/transform limitations, and expose reversible controls. Failed
or low-confidence alignment returns to originals with a clear reason. “Similar
framing” is preferable to “Perfect” or an unvalidated percentage. A small
diagnostics disclosure can show measured quantities and their limitations.

The bootstrap review states that the diagram is synthetic and export is not
implemented. Its export entry opens that explanation, not an empty share sheet.

IDs: `review.mode`, `review.play`, `review.scrubber`, `review.compare.divider`,
`review.alignment.toggle`, `review.offset`, `review.export.open`, `review.source`.

## 9. Export

Summarize exactly what will be produced: paired originals, supported comparison,
or match cut; resolution, orientation, duration, audio behavior, and destination.
Default to preserving originals. Show unsupported choices as unavailable with
reasons, not as selectable controls that fail later. Display any crop before
rendering. No claims of universal 4K/HDR or depth correction.

Export progress is determinate only if genuinely measurable; otherwise say
“Preparing” or “Rendering.” Cancellation releases temporary output and keeps the
project. Finish only after the destination accepts the operation; share-sheet
presentation is not proof that a user saved or published the file. Low space,
interrupted writing, and Photos denial each have an explicit path to Files or
another supported destination when appropriate.

IDs: `export.summary`, `export.destination`, `export.start`, `export.cancel`,
`export.progress`, `export.failure`, `export.completed`.

## 10. Settings, help, and proposed Pro unlock

Settings groups capture preferences, appearance/accessibility, storage, privacy,
help, and purchase management. Real device capabilities are read-only facts.
Provide a per-project size and a clear delete confirmation; distinguish deleting
a project from deleting separately exported copies.

Pro is a proposed one-time non-consumable unlock, not implemented commerce in
the scaffold. Future UI uses StoreKit-localized price and product description,
states exactly which features unlock, and includes Restore Purchases. Pending,
cancelled, unavailable, failed, and restored outcomes remain distinct. No fake
discount timer, preselected subscription, or paywall before the demo proves value.

IDs: `settings.appearance`, `settings.guidanceFeedback`, `settings.storage`,
`settings.privacy`, `pro.product`, `pro.purchase`, `pro.restore`, `pro.status`.

## Screenshot evidence matrix

| Scenario group | Required captures when implemented |
| --- | --- |
| Bootstrap demo | Library, synthetic reference, guidance, tracking-loss simulation, review |
| Permissions | Fresh explanation, denied, restricted/unsupported capability |
| Capture | Mapping, ready, recording, saving, lost tracking, storage failure |
| Relocalization | Finding scene, matched start, timeout, origin mismatch |
| Review/export | Original/split, low-confidence adjustment, progress, cancellation, failure |
| Accessibility | Small phone + largest text, light/dark, high contrast, RTL layout |

Use deterministic scenario inputs for simulator evidence and record their names.
Only consented real-device captures can demonstrate live viewfinder behavior.
Do not upload private room imagery to public artifacts without explicit consent.
