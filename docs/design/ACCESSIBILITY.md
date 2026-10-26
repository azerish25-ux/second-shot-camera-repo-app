# Accessibility acceptance and verification

Status: requirements, not an accessibility certification. Passing UI tests alone
does not establish usability with assistive technologies or physical-camera
guidance. Document observed limitations honestly.

## Semantic interaction

Prefer native Button, Slider, Toggle, NavigationStack, and sheet behavior. Custom
controls expose a concise label, value, traits, and supported actions. A geometric
path is not hundreds of separately focusable segments: give it a useful summary
and accessible controls for the information it conveys. Decorative grid lines,
shadows, and repeating thumbnails are hidden from the accessibility tree.

Names describe the action, not the icon: “Stop reference recording,” not “Square.”
The demo announces “Synthetic demo” in its screen summary and keeps that mode
discoverable throughout. Do not append an announcement to every rendered frame.
Tracking loss and capture completion deserve a single concise state announcement;
minor pose changes do not. Preserve focus when a value changes, and deliberately
move it only when a new task or blocking error is presented.

Suggested focus order for capture: mode/source, tracking summary, primary
instruction, capture state, Stop/Record, optional details, Cancel. Stop remains
reachable when a warning appears. Review's adjustable divider announces a useful
value such as “Reference 50 percent, retake 50 percent.” Provide stepwise adjustment
without precision dragging.

## Type, touch, and layout

Support every Dynamic Type size without clipping essential text or hiding actions.
At accessibility sizes, collapse multi-column layouts and replace inline telemetry
rows with stacked labeled values. Long localized labels and right-to-left layouts
must not invert the meaning of the actual recorded spatial coordinates.

Targets are at least 44×44pt by project policy. Measure hit regions, not only icon
bounds. Sliders, scrubbers, path details, and close controls need equivalent
non-gesture actions. Library, review, export, settings, and demo flows must support
Keyboard/Switch Control operation when implemented. Be explicit that independent spatial capture
for every disability is not yet established; recruit appropriate testers before
making such a claim.

## Appearance and sensory alternatives

Use at least 4.5:1 contrast for normal text and 3:1 for large text or essential
non-text indicators as the repository's acceptance targets. Check light, dark,
Increase Contrast, and composited camera overlays. These thresholds are design
criteria, not a claim of formal standards certification.

Tracking state has redundant text and shape. Loss of tracking removes the valid
marker rather than simply changing cyan to amber. Audio-off and haptic-off modes
retain all essential information. Honor Reduce Motion and Reduce Transparency:
opaque panel alternatives must preserve legibility; no camera-facing blur is
needed to communicate status. Inspect Brightness/low-light legibility on hardware
without claiming the app can override system accessibility settings.

## Test matrix

| Check | Simulator/automation evidence | Physical/manual evidence |
| --- | --- | --- |
| Names, roles, enabled state | XCUI identifiers, labels, values, deterministic journeys | VoiceOver reads coherent meaning |
| Large text/layout | Small and large phone screenshots at standard and largest text | Real touch reach and readability |
| Contrast | Computed opaque-token ratios and rendered-image inspection | Camera overlays over varied live scenes |
| Reduce Motion | Deterministic settings injection and no looping decorative animation | System setting respected in a real session |
| Tracking loss | Synthetic stale/lost events and visible unavailable state | Real loss/interruption announcement timing |
| Alternative input | Keyboard paths and adjustable-action tests where supported | Switch Control, VoiceOver, one-handed operation |
| Purchase/export errors | Simulated pending, cancel, denied, failure states | Actual platform prompts without unsolicited purchases |

Accessibility IDs identify elements for tests; they are not substitutes for spoken
labels. Tests must not assume translated text as a locator. Synthetic UI tests may
assert that Stop is reachable, but cannot prove whether a person walking with a
camera can safely use it. Use a supervised, consented physical test for that
question and record limitations.

## Exit checklist for any screen

- [ ] Primary task succeeds without relying on a hidden gesture or color alone.
- [ ] Largest text preserves content and every necessary action.
- [ ] VoiceOver order, announcement frequency, and recovery are manually reviewed.
- [ ] Small/large screens, orientation, light/dark, and long labels are inspected.
- [ ] Essential status survives Reduce Motion, Transparency, and sensory opt-outs.
- [ ] Evidence identifies commit, scenario, OS/device, settings, and remaining gaps.

Primary references:
[Apple accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility),
[SwiftUI accessibility modifiers](https://developer.apple.com/documentation/SwiftUI/View-Accessibility),
and [testing system accessibility features](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app).
