# Interaction, motion, and feedback

Status: intended behavior. Production capture and export depend on implementation
phases and physical-device gates. The synthetic demo uses explicit simulated
actions and never silently switches to a real session.

## State precedes animation

UI renders the domain state; animation must not determine whether a recording
started, a file saved, a map matched, or an export succeeded. Dispatch one intent
per action, disable duplicate submissions while work is pending, and preserve
Cancel/Stop where the operation allows it. Completion feedback follows confirmed
state, not a timer that happens to finish.

Suggested phases of interaction are prepare, reference, recover origin, retake,
review, and export. Navigation is reversible when no destructive work is pending.
Leaving capture while recording requires an explicit stop/save decision. Returning
from background never automatically resumes recording. A new AR origin creates a
new capture segment; it does not cosmetically continue the old path.

## Motion language

| Interaction | Default treatment | Reduce Motion treatment |
| --- | --- | --- |
| Button feedback | Native pressed state; brief opacity/color feedback | Same nonspatial feedback |
| Card/details disclosure | 180–240ms ease-out; modest expansion | Instant layout or short crossfade |
| Library to review | Native navigation; media retains context | Respect system transition preference |
| Start marker ready | One brief emphasis, no pulsing loop | Text + shape changes only |
| Recording state | Immediate text/timer/solid indicator | Same; no flash required |
| Lost tracking | Immediate removal of stale guides | Same; safety state is never delayed |
| Export completion | One checkmark after confirmed result | Static checkmark and announcement |

Durations are design targets, not latency claims. Do not introduce springy camera
HUD bounce, spinning rooms, moving wallpaper, scan-line shimmer, or endless path
particles. All informative motion must have text/shape alternatives. Animations
are interruptible and never block a user's next valid action.

The actual camera image and sensor-derived marker updates are functional content;
Reduce Motion does not mean freezing them while showing stale guidance. Instead,
remove decorative interpolation and offer simpler 2D instructions. If tracking
is unavailable, the correct behavior is an unavailable state, not an animation
that suggests progress.

## Gestures and accessible equivalents

Horizontal scrub controls time; vertical scroll moves the surrounding page. Avoid
an invisible full-screen pan gesture that steals scrolling. A comparison divider
has a visible handle and a 44pt minimum interactive region, plus labeled preset
buttons or accessibility adjustment actions. Reset remains available.

Pinch-to-zoom is a review convenience, never the only way to inspect content.
Do not allow pinch to silently switch capture lenses. Long-press menus may expose
secondary actions, but essential actions also appear in visible buttons or
standard menus. Swipe-to-delete is optional and recoverable/confirmed; accidental
touches must not remove the user's source footage.

## Guidance prioritization

Render only the most useful correction at one time. The guidance controller owns
thresholds, hysteresis, and cooldowns; the view must not invent its own conflicting
thresholds. Express direction relative to the documented camera/user frame.
Cap presentation refresh independently of capture sampling so recording does not
depend on how often labels redraw. Announcements occur on meaningful state
changes, not every frame or every millimeter.

No gamified score should pressure the user to move faster or keep recording in an
unsafe situation. Never instruct walking backwards, crossing traffic, negotiating
stairs, or treating the app as obstacle avoidance. Encourage short rehearsed
moves in a clear area and stopping when uncertain. Stop remains visually stable
as other controls change; critical warnings do not cover it.

## Haptics, sound, and microcopy

Default to silent guidance during recording. Haptic vibration can affect a held
camera and sound can leak into recorded audio; validate both before enabling them
in a capture mode. An optional pre-take readiness cue must have a visual equivalent.
Do not use sound or vibration as the only indicator of tracking failure.

Use concrete verbs and preserve agency: “Record reference,” “Stop and save,”
“Record new take,” “Keep originals,” “Try alignment,” and “Cancel export.” Errors
say what remains intact. For example: “Guidance was lost. Your video is still
recording; position data is unavailable.” That copy is valid only if the current
capture policy actually continues media recording; otherwise state that recording
stopped. Bind messages to the true capture state.

Reference: [Apple motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion)
and [SwiftUI Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion).
