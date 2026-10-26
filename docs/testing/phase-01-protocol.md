# Phase 01 — retake usefulness validation protocol

**Status: DRAFTED, NOT EXECUTED.** No participant has been contacted, no consent has
been collected and no result exists. Field work needs explicit owner approval
([working agreement](../WORKING_AGREEMENT.md)). This document is the phase-01
deliverable: a falsifiable plan, not evidence that the product works.

- Protocol version: **1**, frozen 2026-10-26 **before** any data collection.
- Decision owner: repository owner. The coordinating agent drafts; the owner
  approves outreach, compensation and publication.
- Operational detail for the same study lives in
  [DEVICE_VALIDATION](DEVICE_VALIDATION.md); this file owns the hypothesis,
  scenarios, cases, metrics and stop rules.
- Gates that this phase does **not** pass: G1 — physical capture integrity
  ([phase 07](../phases/07-reference-capture.md), summary in
  [ACCEPTANCE_GATES](../ACCEPTANCE_GATES.md)) and G2 — useful repeated shots
  ([phase 15](../phases/15-device-proof-gate.md), which holds the canonical
  denominators).

## 1. Hypothesis and falsification

**H1 (primary).** For short, slow camera moves over a static or slowly moving
subject, a creator who repeats the move with Second Shot's guidance produces an
independently judged *useful* result more often than with their own unaided
method, within the same two-attempt budget.

**H0.** Guided and unaided conditions produce the same case success rate within
the attempt budget.

**H2.** A first-time participant completes the guided reference → reviewed-output
flow within ten minutes, with no live developer coaching.

**Falsified when:** the guided budgeted case rate exceeds the unaided rate by
fewer than 20 percentage points, or the guided rate is below 70%, or any safety
or false-confidence presentation occurs. Falsification narrows or stops the
claim (§8) — it is never renamed into success.

Rate metrics use **case denominators**, never attempt or exported-clip
denominators. A case whose output is missing counts as a failure, not an
exclusion.

## 2. Target user and competing workflows

First segment: a solo short-form or product-video creator who already shoots
repeated takes of a static scene (tabletop product, food, craft, small set).

Before the concept is shown, record what the participant actually does today to
repeat a move:

- re-shooting the whole scene from memory,
- taking many takes and picking the closest,
- tripod/marks: tape on the floor, tripod feet, stand-in object,
- existing rigid motion tools (slider, jib, gimbal motion path, robot rig),
- hiring a second operator or a DP,
- fixing framing later in edit (crop, warp stabilizer, speed ramps),
- accepting the mismatch and re-writing the shot.

The unaided condition of this study **is** that personal method, with the
participant's own tools allowed. App Store ratings, review counts or the
existence of competing apps are not demand evidence and are recorded only as
market context. Current spend and time costs per workaround are baseline data,
not proof of willingness to pay.

## 3. Scenarios (S1–S3)

Three bounded moves, chosen to span the near-planar to depth-rich range. All are
static-subject moves with a short travel, so any repeatability claim stays modest
and safety is easy to hold.

| ID | Move | Duration | Scene class | Travel / geometry | Safety preconditions |
| --- | --- | --- | --- | --- | --- |
| S1 | Slow lateral move past a tabletop subject | 4 s ± 1 s | Textured near-planar (poster/painted wall behind) | ~0.5 m sideways, subject 0.6–1.0 m away | Level floor, clear route, no trip hazards |
| S2 | Short forward reveal | 3 s ± 1 s | Depth-rich (foreground object, receding background) | ~0.6 m forward toward the subject | Level floor, both feet stay under the operator |
| S3 | Small partial arc around a static object | 5 s ± 1 s | Mixed texture, mild reflections allowed | ≤90° arc, waist-high object, radius ≥ 0.8 m | Stable footing, arc fully visible to the operator |

Safety rules for every scenario, and for both conditions:

- Operator moves slowly, on level clear ground, on a route they can see.
- **Never** instruct walking backwards, using stairs, crossing or approaching
  roads, or centering a reticle by ignoring obstacles.
- No unsupervised obstacle course; a spotter is present when the operator's
  attention is on the phone.
- Stop immediately on request, unstable footing, unexpected heat or feedback
  that looks unreliable.
- An unsafe instruction is a study-level failure: it is reported and stops
  dependent work (§8), not smoothed into a note.

Scene setup is recorded (subject, background, lighting, approximate distances),
but raw scene photos of private interiors stay in the restricted evidence area.

## 4. Design, cases and attempt budget

- **10 consenting participants** (`P01`–`P10`), at least three of whom did not
  help design or discuss the app.
- Every participant attempts all three scenarios in both conditions.
- **60 predeclared evaluation cases** = 3 scenarios × 2 conditions × 10
  participants: **30 guided and 30 unaided**.
- A case is a reference shot plus one reproduction, with **at most two
  paired-shot attempts**. Up to 120 actual attempts can therefore occur.
- **Counterbalancing:** condition order alternates by participant (odd
  participants guided-first, even unaided-first); scenario order rotates so no
  scenario is always first. Every leg gets a **practice round on a non-scored
  setup** before its first scored case.
- **Frozen assistance:** no live developer coaching. Only scripted setup text,
  the app's own on-screen guidance, and neutral answers ("do whatever you would
  normally do"). Any coaching is logged and the case is reported as coached; it
  is never silently dropped.
- **Comparability:** identical device, lens, lighting, resolution, duration and
  edit-effort budget across conditions. The exact capture format is recorded.
- Attempts are logged whether or not they produce output, including failed
  starts, retries, cancelled takes and abandoned flows.

## 5. Measurements (definitions frozen before data)

| Metric | Definition | Unit | Denominator | Source |
| --- | --- | --- | --- | --- |
| `firstAttemptSuccessRate(condition)` | cases whose **first** reproduction attempt is judged useful | proportion | cases in that condition | reviewer rubric + ledger |
| `budgetedCaseSuccessRate(condition)` | cases judged useful within the two-attempt budget | proportion | cases in that condition | reviewer rubric + ledger |
| `improvementPP` | guided − unaided budgeted rate | percentage points | — | derived |
| `attemptsPerCase` | actual attempts per case, including failed starts | count | cases | ledger |
| `missingOutputCases` | cases with no usable output | count | cases, counted as failure | ledger |
| `coachedCases` | cases needing live developer help | count | cases | observer notes |
| `flowCompletionSeconds` | first guided reference → reviewed output, uncached | seconds | participants | observer timing |
| `falseConfidenceCases` | invalid origin, lost/stale tracking, or unavailable guidance presented as a precise match | count | cases (target 0) | app status + observer |
| `safetyEvents` | unsafe instruction or unsafe operator action | count (target 0) | sessions | observer |

**Usefulness judgement.** Two reviewers rate each output using the phase-15
rubric (framing continuity, visible jumps, distortion/crop cost, creator
intent), with the condition hidden where feasible. Both reviewers rate the same
outputs; disagreements are preserved, then resolved by a documented rule
(predeclared majority or explicit adjudication), and the count of unresolved
cases is reported. The app's own pose numbers may diagnose relative error but
are **not** independent ground truth for accuracy.

Reported with every rate: counts, denominators, the number of participants,
practice effects, coaching incidents, exclusions **decided before seeing
results**, and the fact that this is a small-sample product signal, not a
population estimate. No significance claims.

## 6. Preregistered provisional targets

These are project targets fixed before testing and consistent with
[ACCEPTANCE_GATES](../ACCEPTANCE_GATES.md) G2 and phase 15. They are not
capabilities and must not be relaxed after seeing results.

1. ≥ **8 of 10** participants complete their first guided
   reference-to-reviewed-output flow within ten minutes, ≤ 2 attempts per
   scenario, no live developer coaching.
2. ≥ **70%** of the 30 guided cases produce a useful result within the
   two-attempt budget.
3. Guided budgeted success ≥ unaided rate **+ 20 percentage points**.
4. **Zero** unsafe instructions and **zero** false-confidence presentations.
5. The unaided baseline is reported in full. If the participant's own method
   already reaches ≥ 70%, target 3 cannot support the claim and the outcome is
   *narrow* or *stop*, not *continue*.

## 7. Consent, privacy and evidence handling

Summarized here; the operative document is
[consent and data handling](consent-and-data-handling.md).

- Participant codes only. Faces, homes, private interiors, raw footage, audio,
  world maps, device identifiers and contact records **never** enter this public
  repository or a GitHub Actions artifact.
- Raw media is stored only in the owner-approved restricted location, with a
  recorded retention/deletion date (default: raw media deleted within 30 days of
  the analysis freeze).
- Consent for the experiment and consent for public/marketing use are
  **separate** and revocable.
- Withdrawal at any time without giving a reason, including deletion of already
  collected media.
- Only sanitized results are committed, under `docs/reports`, using the redacted
  record shape from [DEVICE_VALIDATION](DEVICE_VALIDATION.md).

## 8. Decision and stop rules

| Observation | Decision |
| --- | --- |
| All targets met, zero safety/false-confidence events | **Continue** to the guided-capture path (phase 09–11) |
| Guided ≥ 70% but improvement < 20 pp, or only some scenarios are useful | **Narrow** to framing/transition assistance; restate the claim and run a new experiment |
| Guided ≤ unaided, any safety event, or repeated false-confidence presentations | **Stop** dependent guided work; retain failed trials |
| Fewer than 8 usable participants, or > 20% of cases lost to equipment/consent problems | **Inconclusive**; report as inconclusive, never as success |

Protocol changes after data collection bump the version, carry a dated reason,
and invalidate pooled data. This phase cannot pass G1 or G2: G1 needs the
phase-07 device experiment and G2 needs this study plus the capture and
review/export pipeline.

## 9. Hardware and versions required by later phases

- Product minimum OS for the initial foundation: **iOS 17**.
- Simulator (CI) runs exercise the app, navigation and synthetic states only.
  A simulator is never AR-capable evidence.
- Phase 07 / G1 matrix must include at least one supported **non-LiDAR**
  ARKit-capable iPhone (mandatory), one additional supported model, and a
  Pro-class device when that class is offered. LiDAR presence proves nothing
  about accuracy and is optional.
- Each device run records model, OS build, Xcode/SDK, capability report and
  selected format. Acceptance rules must not hardcode marketing names or invent
  a future device.

## 10. Test seams this protocol depends on

| Seam | Where it lives now | How it is checked today |
| --- | --- | --- |
| Synthetic provenance | `PoseProvenance.synthetic`, `PoseTrack.isSynthetic`, `DemoStudio.isSynthetic` | Core tests reject tracked claims for untracked provenance |
| Deterministic demo entry | `library.demo.open` into the fixed "Tabletop arc" scene (`DemoStudio`) | UI journey asserts the entry, the fixed scene and the demo badge |
| Stable accessibility identifiers | `Sources/SecondShotApp` views (`demo.badge`, `retake.guidance`, `review.source`, …) | Repository check fails on any UI-test query no view defines |
| Synthetic labelling in evidence | `demo.badge` on library, reference and guidance screens | Simulator journey attaches screenshots after asserting the badge |

Standing rule: a real device session must never silently substitute synthetic
frames, and demo output must never be presented as device evidence. Demo
scenarios (S1–S3 above) are **not** the synthetic Tabletop arc scene; the demo
proves the app runs, nothing about retake usefulness.

## Version log

| Version | Date | Change | Reason |
| --- | --- | --- | --- |
| 1 | 2026-10-26 | Protocol, scenarios, cases, metrics, targets and stop rules frozen before data collection | Phase 01 deliverable |

Read next: [interview guide](interview-guide.md), [consent and data handling](consent-and-data-handling.md),
[phase 02](../phases/02-pose-math.md).
