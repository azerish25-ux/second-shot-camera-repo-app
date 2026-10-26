# Design system — precision without clutter

Status: production target. The initial scaffold may implement a subset. Colors below
are design targets for semantic assets, not permission to hard-code every view.

## Appearance and color

Use a graphite studio appearance for the camera stage and a fully usable adaptive
light appearance for library, review, settings, and dialogs. Camera chrome can
remain dark to protect the viewfinder, but must respect contrast preferences.
Native sheets and controls should use system semantic backgrounds and labels.

| Semantic token | Dark target | Light target | Purpose |
| --- | --- | --- | --- |
| `canvas` | `#111315` | `#F7F5EF` | Main background |
| `surface` | `#1C2025` | `#FFFFFF` | Cards and opaque HUD backing |
| `surfaceRaised` | `#292F35` | `#E8EBEB` | Selected or elevated panel |
| `textPrimary` | `#F5F1E8` | `#171A1D` | Reading and actions |
| `textSecondary` | `#B6BBC1` | `#505960` | Metadata, never disabled-state camouflage |
| `guideAccent` | `#7DE8F2` | `#006B78` | Planned path and selection |
| `caution` | `#F2BE63` | `#805600` | Tracking uncertainty and recovery |
| `recording` | `#FF6969` | `#B42332` | Active recording/stop indication |
| `separator` | System separator | System separator | Quiet boundaries |

Primary, secondary, and cyan text against the opaque canvas have approximate
sRGB contrast ratios of 16.52/9.64/13.03:1 in dark and 16.03/6.55/5.71:1 in light.
These computations do **not** validate translucent controls over arbitrary camera
frames. Camera text needs an opaque or measured high-contrast scrim. Test the
composited result over white walls, black scenes, and patterned backgrounds.

Red is not the brand accent and must never suggest that a synthetic demo is
recording a real camera. Native destructive confirmations retain platform
semantics. Cyan is not a success grade: “tracking available” still needs text,
while “tracking lost” changes the marker shape and adds an explicit message.

## Typography and spacing

Use the system typeface. Headlines may use a restrained semibold weight; body
copy stays regular. No external font dependency is needed. All sizes below mean
the base semantic style, not a fixed frame that prevents Dynamic Type growth.

| Role | SwiftUI style | Behavior |
| --- | --- | --- |
| Library hero | `largeTitle`, semibold | At most two lines at default size; wraps freely when enlarged |
| Screen title | `title2`, semibold | Native navigation where appropriate |
| Card title | `headline` | Never truncate a short project title before metadata |
| Body/instruction | `body` | Readable sentence case; 17pt baseline |
| Metadata | `subheadline` | Secondary information; no essential tiny text |
| Timer/offset | `body.monospacedDigit()` | Reserve stable width; include unit or spoken unit |
| Persistent mode badge | `caption`, semibold | Scales and remains readable; never color-only |

Use a base spacing scale of 4, 8, 12, 16, 24, 32, and 48pt. Standard page margins
are 24pt, reduced to 16pt on compact widths. Card content padding is 20pt; card
corners are 20pt; small status capsules use 8–12pt. Borders are one physical
pixel where purely decorative. Essential state outlines need sufficient contrast
and may be 2pt. Prefer spacing to excessive separators.

Primary buttons have a minimum 52pt visual height and expandable text height.
Every target is at least 44×44pt; capture Stop should be at least 56×56pt. Leave
8pt or more between neighboring actions. Never place a destructive action next
to Record without spatial separation and a confirmation stage.

## Components and contracts

| Component | Required content/behavior | Avoid |
| --- | --- | --- |
| `ModeBadge` | Text plus icon: Synthetic demo / Experimental capture | A glowing dot with no meaning |
| `ProjectCard` | Title, mode/source, duration, date, status, tappable preview | Fake thumbnail presented as footage |
| `TrackingStatus` | Stable/lost/relocalizing text, distinct shape, freshness | Old good values after tracking is lost |
| `MetricChip` | Named quantity, unit, synthetic qualifier when relevant | A single unexplained “accuracy %” |
| `PrimaryAction` | Verb naming actual effect; disabled reason nearby | “Continue” when it begins recording or charges money |
| `CaptureControl` | Ready/recording/stopping states and accessible Stop | Switching button identity without spoken feedback |
| `InlineIssue` | What failed, what remains saved, one next action | Error code alone or repeated modal alerts |
| `ComparisonControl` | Reference/retake labels and alternative discrete buttons | Swipe-only discovery |

Use SF Symbols by supported names, not copied glyph codepoints. Candidate names:
`camera`, `viewfinder`, `play.fill`, `pause.fill`, `stop.fill`, `arrow.uturn.backward`,
`exclamationmark.triangle`, `square.and.arrow.up`, and `gearshape`. Verify names on
the minimum OS. Symbols supplement labels, not replace safety-critical words.

## Composition and responsive behavior

Portrait library uses one column on compact phones: title, single hero project,
primary action, then recent work. Wider layouts can use two project columns only
when labels retain useful width. Capture prioritizes the live view: top status,
one short center instruction, and bottom/right action rail within safe areas.
Never cover more than the necessary portion of the view with telemetry.

Landscape capture moves controls to a side rail without rotating recorded media
metadata mid-take. At accessibility sizes, offer a simplified instruction panel;
secondary graphs collapse into a user-opened details view. Review respects media
aspect ratio and shows pillar/letterboxing instead of stretching the image.

## Source guidance

- [Apple UI design tips](https://developer.apple.com/design/tips/): touch targets,
  content fitting, and legibility.
- [Apple SwiftUI fonts](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text):
  scalable fonts and scaled metrics.
- [Apple accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility):
  contrast, adaptable appearance, and redundant feedback.

The palette, dimensions, component taxonomy, and composition above are Second
Shot's proposed design decisions, not an Apple certification.
