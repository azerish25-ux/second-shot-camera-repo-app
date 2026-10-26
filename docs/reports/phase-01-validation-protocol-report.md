# Phase 01 — retake usefulness protocol

Status: **PARTIAL**. The protocol, interview guide and consent material are written,
frozen and machine-checked; the study itself has **not** run, and the independent
human-review check is outstanding.

## Scope and prerequisites

- Phase specification: [phase 01](../phases/01-product-validation.md). Gate
  dependency: phase 00 (G0 is still **open** pending the screenshot visual review).
- Tested commit SHA: `3912918` on `main`
  ([run evidence below](#observed-verification)).
- Implemented, not merely documented: the frozen protocol, the interview guide, the
  consent and data-handling draft, and repository checks that fail when a
  registered invariant disappears or when the protocol implies execution without a
  sanitized results report.
- Documented only: the pilot itself. No participant was contacted, recruited,
  consented, timed or recorded. No willingness-to-pay data exists.
- Deliberately excluded: recruitment, compensation, TestFlight invitations, any
  paid service, and any use of private footage. Those need owner approval under the
  [working agreement](../WORKING_AGREEMENT.md).

## Changes

- `docs/testing/phase-01-protocol.md` — protocol version 1, frozen 2026-10-26:
  falsifiable hypotheses, the three bounded scenarios (S1 lateral past a tabletop
  subject, S2 short forward reveal, S3 ≤90° arc around a static object), the
  60-case design (10 participants × 3 scenarios × 2 conditions, 30 per condition,
  ≤2 paired-shot attempts, counterbalanced order, practice round), metric
  definitions with case denominators, preregistered provisional targets, stop
  rules, required hardware/iOS versions, and the test seams later phases depend on.
- `docs/testing/interview-guide.md` — past-behaviour-first interview script, the
  agency/spend questions, the concept-reaction section, and a separate
  willingness-to-pay section that marks stated intent as intent.
- `docs/testing/consent-and-data-handling.md` — five separately recorded
  permissions, participant codes, restricted-evidence locations, retention
  windows, withdrawal route, safety script and an explicit rehearsal mode.
- `scripts/ci/check_repository.py` — the three documents are required files, their
  registered markers are checked against whitespace-normalized text, all three
  scenario rows must exist, and a protocol that stops stating "not executed" must
  link an existing sanitized results report.
- `scripts/test_check_repository.py` — six new tests covering the invariant
  markers, the missing scenario row, the execution-claim guard in both directions,
  and missing documents.
- `Tests/SecondShotCoreTests/GoldenPoseFixtures.swift` and the pose-math changes
  belong to [phase 02](phase-02-pose-math-report.md), committed together because
  the same verification run covers both.
- No app behaviour changed, so no simulator UI expectation changed. Assumption
  recorded explicitly: the synthetic **Tabletop arc** demo is *not* one of the
  study scenarios and cannot count as scenario evidence.

## Observed verification

| Command / experiment | Environment | Result | Evidence |
| --- | --- | --- | --- |
| `python3 -B -m unittest discover -s scripts -p 'test_*.py'` | Linux x86_64, Python 3.12.3 | 39 tests, 0 failures (6 new protocol tests) | local run |
| `python3 -B scripts/ci/check_repository.py` | same host | passed, including the new protocol invariants | local run |
| `swift test` | Linux x86_64, Swift 6.0.3 | 72 tests, 0 failures | local run |
| Repository checks workflow on `3912918` | GitHub Actions, ubuntu runner | **success** | [run 40366004536](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40366004536) |
| iOS Simulator workflow on `3912918` | GitHub Actions, macos-26 + Xcode 26.6 | **success** in 11m 20s: all 11 steps green, including evidence validation | [run 40366004501](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40366004501) |
| "Unfamiliar reader explains success/failure/inconclusive from the protocol alone" | human review | **not run** | phase-01 acceptance item, still open |

Failed attempts and fixes in this step:

1. The new checker immediately failed `docs/testing/phase-01-protocol.md` for a
   missing `07-reference-capture.md` reference. That was a real gap — the header
   cited G1 only through the gates summary — so the document was corrected rather
   than the check weakened, and phase 07 is now linked explicitly.
2. The first version of the checker treated "not executed" as an unconditional
   required marker, which would have made the execution path unreachable. It was
   restructured so the document must either state it is unexecuted **or** link an
   existing sanitized results report; both branches now have tests.

## What this does not prove

- Required but unrun: the entire pilot, the interview set, and the phase-15
  usefulness measurement. No denominator exists yet.
- No demand, willingness-to-pay, retention or income evidence; the targets in the
  protocol are provisional project criteria, not capabilities.
- G1 and G2 remain untouched. Capture integrity still needs the phase-07 physical
  experiment, and product usefulness needs the phase-15 study.
- The scenario set is a safety-conscious subset of the product's eventual scope:
  slow, short, level-ground moves only. It deliberately does not test difficult
  parallax, low light or occlusion, which phase 15 lists as hard negatives.
- Repository checks prove document structure and link integrity. They cannot prove
  the protocol is scientifically adequate, only that its registered content is
  intact.

## Gate decision

- No gate applies to this phase. Acceptance evidence so far: scenario IDs,
  sample size, baseline, measurement definitions, stop rules, privacy handling and
  both gate references are present and machine-checked; the hardware/versions
  requirement is recorded; synthetic labelling stays asserted in the UI journey.
- Outcome: **continue** with independent engineering work (phases 02–05 are not
  device-gated), and hold the pilot at *owner review* rather than treating the
  written protocol as a passed validation.
- No threshold was changed; none has been measured yet.

## Handoff and publication

- First executable next task: [phase 03](../phases/03-lifecycle-state-machine.md)
  — the production lifecycle, effects and staleness rules, since phases 02–05 are
  pure-domain or simulator work that does not need the pilot.
- Blocker requiring owner input: approval of the protocol and consent wording,
  and the decision to contact participants at all. Until then the study stays
  unexecuted and `docs/STATUS.md` keeps phase 01 at PARTIAL.
- Commit `3912918` pushed to `main` (`2cc8af4..3912918`); the first push attempt
  was rejected with a transient 403 and succeeded on retry with the server
  confirming the new head.
- Working tree: clean apart from this report and the STATUS update that follow in
  the evidence commit.
