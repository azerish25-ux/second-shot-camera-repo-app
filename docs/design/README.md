# Second Shot design specification

Status: **proposed production design**, not a claim that these screens exist.
The bootstrap's UI scope is a synthetic Demo Studio only. Read
[the implementation status](../STATUS.md) for actual availability and observed
test results before assessing feature coverage.

## Product character

Second Shot should feel like a small, beautifully made filmmaking instrument:
precise, calm, and inviting to experiment with. Its distinctive visual is a thin
cyan camera path against a quiet live view, with legible framing and timing cues.
The interesting object is the user's shot, not the app's chrome. No decorative
radar, fake lens readouts, random technical numbers, glitch effects, or invented
accuracy scores.

Working promise: **Record a move. Find it again. Make another take.** Never use
“exactly repeat,” “robotic precision,” or “perfect match.” A visually attractive
path is not evidence that a shot can be successfully repeated.

## Read and implement in this order

1. [Design system](DESIGN_SYSTEM.md): appearance, typography, layout, components.
2. [Screen specifications](SCREEN_SPECIFICATIONS.md): hierarchy, actions, states,
   stable accessibility IDs, and evidence targets.
3. [Interaction and motion](INTERACTION_AND_MOTION.md): gestures, transitions,
   feedback, interruption, and safe guidance behavior.
4. [Accessibility](ACCESSIBILITY.md): acceptance checks and test matrix.

Implementation belongs in `Sources/SecondShotApp`; pure presentation decisions
must not change pose math, timestamps, permissions, or recording state. Establish
reusable tokens and components before duplicating custom styling across screens.
Native navigation, permission dialogs, share sheets, and purchase confirmations
retain their platform behavior.

## Three different truth levels

| Experience | Required visible description | Evidence it can provide |
| --- | --- | --- |
| Demo Studio | “Synthetic demo”; schematic path, not camera footage | Navigation, layout, state transitions, accessibility |
| Device prototype | “Experimental capture”; real capability and tracking state | Capture feasibility, only for the recorded device/run |
| Released product | Accurate supported-feature copy after gates pass | Only the tested and released feature set |

Simulator screenshots cannot be repurposed as proof of physical tracking. Initial
demo controls simulate the workflow explicitly; unfinished features open an
honest explanation, never a success toast or fabricated export.

## Phase and gate mapping

As defined in [the roadmap](../ROADMAP.md), tokens, accessibility components, and
synthetic UI may proceed independently of hardware work. G0 proves only the
synthetic foundation. Device capture must satisfy G1; useful retakes must satisfy
G2. Full phase-16 production UI completion depends on G2 and the underlying real
flows, even if every planned screen has a polished synthetic preview. G3/G4
separately govern signed beta and release. See [acceptance gates](../ACCEPTANCE_GATES.md).
No design approval overrides a blocked physical or publication gate.

## Design review handoff

Every implemented screen needs screenshots at small and large widths, standard
and accessibility text sizes, and its failure state. Review the actual rendered
image, not just a green test. Save exact commit and scenario names with evidence.
Record deviations here or in a phase report; do not silently reduce accessibility
requirements to fit a preferred composition.
