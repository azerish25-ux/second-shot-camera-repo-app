# Phase 02 — pose mathematics and deterministic fixtures

Status: **COMPLETE for the arithmetic scope**. Phase 02's own criteria are met and
observed; it requires no physical-device evidence by its specification. Nothing
here is evidence about camera or tracking accuracy.

## Scope and prerequisites

- Phase specification: [phase 02](../phases/02-pose-math.md). Dependency: phase 00
  and the measurement vocabulary from [phase 01](phase-01-validation-protocol-report.md).
- Normative contract: [capture and coordinate contract](../architecture/capture-and-coordinates.md)
  (§2 spaces and transforms, §3 time and the accepted-frame ledger).
- Tested commit SHA: `3912918` on `main`. Evidence below.
- The bootstrap already shipped a working slice (`Vector3`, `Quaternion`,
  `RigidPose`, `PoseSample`, `PoseTrack`, `PoseComparator`) whose tests were
  implementation-adjacent. This checkpoint adds fixtures and sweeps that are
  **independent of the implementation** and closes the remaining contract gaps.
- Deliberately excluded: any retake matching algorithm (nearest-point matching is
  explicitly rejected by the phase), spatial indices, and any accuracy claim.

## Changes

- `Tests/SecondShotCoreTests/GoldenPoseFixtures.swift` (new) — hand-derived golden
  values, not values produced by the code under test:
  - literal quaternions for 90° about ±X, ±Y, Z written in `x, y, z, w` order and
    compared against the axis/angle initializer;
  - axis images from the rotation matrices (`R_y(90°)` maps `+X → −Z`, `+Z → +X`;
    `R_x(90°)` maps `+Y → +Z`, `+Z → −Y`; `R_z(90°)` fixes `+Z` and maps `+X → +Y`);
  - the composed product `q_x ∘ q_z = (0.5, −0.5, 0.5, 0.5)`, i.e. 120° about
    `(1, −1, 1)/√3`, derived term by term from the quaternion product formula,
    cross-checked against its effect on an actual point, with the other
    composition order shown to differ by exactly 120°;
  - the inverse of a literal pose (90° about +Y translated 1 m along +X) with the
    hand-computed inverse translation `(0, 0, −1)`;
  - a 3–4–5 distance (0.3 m / 0.4 m components → 0.5 m) and literal angle values.
- Seeded property sweeps with replayable seeds in every failure message:
  300 rotations preserving vector length, 300 composed-inverse point recoveries
  (including `pose ∘ pose⁻¹ = identity`), and 200 interpolated samples confined to
  their endpoint bounding box, within the endpoint separation and never exceeding
  the direct distance by more than floating-point noise.
- A zero-length-translation segment fixture: distinct timestamps at one position
  must keep the position fixed while still interpolating orientation along the
  shortest arc.
- `Tests/SecondShotCoreTests/*` — imports changed from `@testable` to plain
  `import SecondShotCore` (proving the tests need only the public API), and the
  single `try!` replaced with `try` on a throwing test, per the phase handoff
  checklist's "no forced unwraps".
- `project.yml` — new `SecondShotCoreTests` simulator unit-test bundle depending on
  the package product, added to the scheme, so the same arithmetic is compiled and
  run against the iOS SDK on the simulator, not only on the host toolchain.
- `scripts/ci/collect_results.py` — `SecondShotCoreTests` is now a required suite
  for evidence acceptance; `scripts/ci/check_repository.py` fails if `project.yml`
  stops referencing the core test target. Missing-suite coverage has its own test.
- `Sources/SecondShotCore` — **no** behavioral change. The phase-02 contract was
  already satisfied by the bootstrap types; only verification and coverage
  changed. This is stated explicitly because it means phase 02's completeness rests
  on the tests below rather than on new implementation.

## Observed verification

| Command / experiment | Environment | Result | Evidence |
| --- | --- | --- | --- |
| `swift test` | Linux x86_64, Swift 6.0.3 | 72 tests, 0 failures (10 new) | local run |
| `swift test` after switching to the public API | same | 72 tests, 0 failures | local run |
| Simulator suites on `3912918` | macos-26, Xcode 26.6, iPhone 17 simulator | **success** in 11m 20s (job itself 6m 20s after the ~5m queue). `Collect and validate evidence` passed while now requiring three suites, so the core, app and UI bundles all ran with no skips. | [run 40366004501](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40366004501) |
| Repository checks on `3912918` | ubuntu runner | **success** | [run 40366004536](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions/runs/40366004536) |

Contract-to-test mapping:

| Phase-02 requirement | Where it is verified |
| --- | --- |
| Finite components, non-zero quaternion norm, non-negative elapsed, known convention | `testNonFiniteValuesAreRejected`, `testDegenerateQuaternionIsRejected`, `testNegativeAndNonFiniteSamplesAreRejected` |
| Normalization, conjugation, composition, vector rotation, rigid inverse/composition with documented order | `testAxisAngleConstructionMatchesLiteralQuaternions`, `testCompositionIsNotCommutative`, `testCompositionOrderIsVisibleOnAnActualPoint`, `testInverseRoundTrip` |
| Translation error in meters, shortest-arc angle, `q`/`−q` equivalence, degrees only at presentation | `testHandComputedDistanceAndAngleValues`, `testQuaternionSignEquivalence`, `testOppositeQuaternionRepresentationHasZeroError` |
| 0/90/180° cases | `testQuarterTurnIsNinetyDegrees`, `testHalfTurnIsOneHundredEightyDegrees`, `testNinetyAndOneHundredEightyDegreeRotations` |
| Timestamp-bracketed interpolation, shortest path, near-collinear fallback | `testInterpolationEndpointsAreRecordedSamples`, `testInterpolationMidpoint`, `testInterpolationRotatesAlongShortestArc`, `testSlerpTakesShortestPathForOppositeSigns` |
| No extrapolation; duplicate/descending timestamps rejected | `testOutOfRangeRequestFailsInsteadOfExtrapolating`, `testDuplicateAndDescendingTimestampsAreRejected` |
| Worst-tracking propagation instead of averaging | `testInterpolationKeepsWorstTrackingState` |
| Explicit origin/epoch/take/provenance identity; typed failure on mixing | `testMixedOriginEpochTakeAndProvenanceAreRejected`, `testMixedOriginsAreRejected`, `testUntrackedProvenanceCannotClaimTrackedPoses` |
| Oversized input rejected before allocation | `testEmptyAndOversizedTracksAreRejectedBeforeAllocation`, `testLargeNonuniformFixtureRemainsQueryable` (4,000 samples, non-uniform cadence) |
| Property-style sweeps preserving seeds | `testSeededRotationsPreserveVectorLength`, `testSeededComposedInversesRecoverPoints`, `testSeededInterpolationStaysBetweenRecordedEndpoints` |
| Unit formatting at the presentation boundary | `Tests/SecondShotAppTests/AppFormattingTests.swift` (cm/degrees/clock/percent) |
| Invalid input cannot display a precise-tracking claim | `testTrackingThatIsNotPreciseCannotProduceADeviation`, `testInterpolationKeepsWorstTrackingState`, UI journey `demo.tracking.interrupt` |

Failure found and fixed: `testCompositionOrderIsVisibleOnAnActualPoint` failed
first. The implementation was right and the hand derivation was wrong — I had
assumed `q_z ∘ q_x` maps `+X` to `−Z`, when `concatenating` applies its argument
first, so `+X → +Y`. The expectation was corrected with the derivation written
into the test, and the same test now also asserts the 120° separation as a golden
value.

## What this does not prove

- No camera, lens, AR-session or tracking-accuracy evidence. All thresholds here
  are Double-arithmetic tolerances (1e-9 for pure-core round trips), not
  millimetre or degree claims about physical behaviour.
- The estimated deviation produced by `PoseComparator` is an internal geometric
  difference, not independent ground truth for a device run.
- Interpolation lookup is a binary search over an ascending array; correctness is
  exercised by the 4,000-sample fixture, but **no timing measurement** was taken,
  so no performance claim is made.
- The `guard span > 0 else { return before }` branch inside interpolation is
  defensive: with duplicate timestamps rejected at construction, it is not
  reachable from a valid track and is not covered by a test.
- UI-side verification of unit formatting and the unavailable-tracking state is
  app-level, not core-level; it does not validate physical tracking quality.

## Gate decision

- Phase-02 acceptance checklist: conventions and independently checked golden
  values exist; invalid-input and mixed-origin tests pass without forced unwraps;
  tests pass on the pushed SHA with recorded counts; the bootstrap-versus-new work
  is separated above; the coordinating agent committed and pushed.
- Outcome: **COMPLETE** for arithmetic and data handling. No threshold changed.
- Next dependent phase: [phase 03](../phases/03-lifecycle-state-machine.md).

## Handoff and publication

- First executable next task: phase 03's production lifecycle — states, declarative
  effects, operation IDs/generations, stale-result rejection and the injected-clock
  rules.
- Blocker: none for phase 03. Physical evidence remains blocked until phase 07.
- Commit `3912918` pushed to `main` (`2cc8af4..3912918`), server head verified.
