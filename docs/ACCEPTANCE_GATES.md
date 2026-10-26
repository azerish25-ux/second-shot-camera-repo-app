# Acceptance gates: what counts as proof

These gates are dependencies, not presentation milestones. Numeric targets below
are **provisional test criteria**, not measured product capability. Phase 01 must
freeze the applicable protocol before collecting results. A threshold change needs
a dated reason, prior failed result and a new experiment; never change it silently
to make an observed failure pass.

## G0 — reproducible foundation (phase 00)

Required: repository checks; pure Swift tests; generated Xcode project; unsigned
build; actual iOS Simulator unit/UI execution; no skipped suites disguised as a
pass; readable library, synthetic capture, interruption and review screenshots;
logs/toolchain information and xcresult artifacts; exact tested commit.

Pass means the **foundation works with synthetic data**. It does not mean a camera,
AR session, video export, purchase or physical experiment has been implemented.
If GitHub cannot schedule a runner or Actions is restricted, mark CI blocked and
report the missing permission/capacity. A YAML file alone is not G0.

## G1 — physical capture integrity (phase 07)

Prerequisites: phase-01 protocol, coordinate/time contracts, storage recovery,
permissions and real AR tracking. Phase 07's proposed minimum is two supported
physical iPhone models and twenty reference takes per model; the exact devices,
sample counts and conditions belong in the phase report.

Provisional acceptance plan:

- At least twenty bounded 3–8 second reference recordings per model across a
  textured indoor scene and difficult-light/low-texture scenarios; difficult cases
  may reject. Use phase 07's complete matrix, not only hand-selected success takes.
- Every accepted video frame has an auditable source timestamp, origin and pose
  association; dropped/invalid samples remain detectable in a frame ledger.
- Persisted timestamps are monotonic. Timestamp/origin discontinuities end a take
  rather than silently concatenating incompatible data.
- Playback duration agrees with the accepted-frame timeline within one output
  frame after a documented conversion/rounding policy.
- If audio is included, offset/drift is measured and bounded by the frozen protocol;
  if not, the UI/export truthfully says muted. An unverified mic path cannot pass.
- Permission denial, backgrounding, writer failure, tracking loss and storage errors
  produce clear failure/recovery states, not a corrupt project marked complete.

G1 is **not** a repeatability-accuracy gate. It proves the recording/measurement
pipeline is meaningful enough to attempt later guidance. If no device is available,
record BLOCKED_DEVICE and continue only independent synthetic/design work.

## G2 — useful repeated shots (phase 15)

Prerequisites: guided capture, interruption recovery, synchronized review, quality
diagnostics, nondestructive export and a held-out operator/scene protocol.

Define 'useful' before the study: a pair that supports the proposed match-cut or
controlled-wipe task with acceptable crop/misalignment, judged from actual output
by a reviewer who is not told which workflow produced it. 'Visually cool' is not
an error metric, and pixel residual alone is not perceived usefulness.

Suggested protocol inputs (freeze/justify in phase 01 and phase 15):

- At least ten target users, with separate training and held-out trials; include
  users who did not design the app. Counterbalance guided and unguided conditions
  over three scenes: sixty predeclared evaluation cases, each with a reference
  and a budget of up to two paired-shot attempts. Log all actual takes/retries.
- Bounded scenes/moves spanning supported use and deliberate hard negatives:
  close foreground, deep parallax, blank walls, reflections, low light and occlusion.
- Provisional target: at least 70% of guided cases produce an independently judged
  useful result within the attempt budget, with at least a twenty-percentage-point
  improvement over unguided cases. At least eight of ten participants complete
  the intended flow within ten minutes with at most two attempts per scene and
  no live developer coaching. Report first-attempt and budgeted-case success
  separately, every failure/retry and predeclared exclusions. Phase 15 defines
  the canonical denominators. These targets are not current product capabilities.
- No attempt with known invalid origin or lost/stale tracking is presented as a
  valid precise match. Measure false-confidence cases explicitly.
- Compare app guidance with the baseline for time, attempts, success, discomfort,
  understandable instructions and willingness to pay. Record confidence limits
  and sampling limitations; this small study does not prove market-wide demand.

Possible outcomes: **continue**, **narrow the supported task**, **pivot to a simpler
framing assistant**, or **stop**. Keep failed trials and the reasoning. Do not sell
the original exact-repeat story if evidence supports only rough framing guidance.

## G3 — signed beta readiness (phase 21)

Requires physical G2 evidence, repeatable project recovery, performance/device
matrix, accessibility, privacy/manifest audit, accurate supported-device copy,
StoreKit sandbox evidence if monetization is present, and owner-approved signing
and tester distribution. A simulator .app cannot be installed as an iPhone beta.

Signing secrets belong in an approved secret manager/environment, never git or
logs. Distribution must be manual, least-privilege and separately approved.
The setup request does not authorize invitations, uploads or spending.

## G4 — public release readiness (phase 22)

Complete the [release checklist](release/RELEASE_CHECKLIST.md), recheck current
Apple SDK/submission requirements, validate the exact signed release build, supply
truthful screenshots/privacy/commerce information and obtain explicit release
approval. No automatic store submission or rollout occurs on a push to main.

## Evidence hierarchy and storage

Use exact commit SHAs, run URLs, device/OS/build IDs, test counts and artifact names.
CI logs/screenshots prove only their test scenario. Physical-video evidence needs
consent and owner-approved private retention; do not commit room scans, faces,
private interiors, exports or signing data to this public repository.

Summarize anonymized results under `docs/reports` with links/access conditions.
Record artifact retention dates. Never fabricate or regenerate a screenshot to
masquerade as the output of a simulator or physical device.
