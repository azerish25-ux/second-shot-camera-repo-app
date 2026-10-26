# Phase 01 — product validation and feasibility protocol

**Status:** PLANNED. **Dependencies:** phase 00 foundation and a readable demo. **Evidence:** none yet.

## Outcome

Turn the attractive idea into a falsifiable product hypothesis: a creator can repeat a short, slow camera move more usefully with Second Shot than with their existing manual method. The product is a guidance aid, not a motion-control robot. A good-looking synthetic demonstration is not evidence that the hypothesis is true.

This phase produces the experiment plan and recruitment material. It does not authorize contacting people, collecting personal data, taking payments, or publishing a beta without the owner's approval. It does not require a full editor, AI generation, cloud services, or a subscription.

## Implementation tasks

1. Write a dated protocol in `docs/testing/phase-01-protocol.md` covering the first target user: a solo short-form filmmaker or product-video creator who already makes repeated takes. Record competing workflows they actually use; do not substitute App Store ratings for demand. Keep the sanitized phase report under `docs/reports` per the working agreement.
2. Define three bounded scenes: a slow lateral move past a tabletop subject, a short forward reveal, and a small arc around a static object. Keep the route clear, on level ground, and visible to the operator. No stairs, road crossings, backward-walking instructions, or unsupervised obstacle courses.
3. Specify the comparison: ten participants each test three scenes in manual and guided conditions, giving 60 predeclared evaluation cases, 30 per condition. Each case permits at most two paired-shot attempts. Counterbalance order and provide an explicit practice round. Log every failed start and retry; report first-attempt success, two-attempt-budget case success, and total attempt counts separately for each condition. Missing output is a failure, not an exclusion. Keep lens, lighting, resolution, duration, and edit effort comparable.
4. Draft a lightweight interview guide: last repeated-shot problem, time spent fixing it, workaround used, current spending, expected output, and why they might reject this app. Ask about past behavior before showing the concept. Separate genuine willingness to pay from courtesy or excitement.
5. Define consent, storage, deletion date, withdrawal route, and permission to share each clip separately. Use participant codes; never commit faces, identifiable homes, raw footage, or world maps to this public repository.
6. Specify the test seams needed downstream: synthetic frame provenance in `Sources/SecondShotCore`, deterministic demo entry points in `Sources/SecondShotApp`, and stable accessibility identifiers in `Tests/SecondShotUITests`.

## Preregistered decisions

Record thresholds before testing and label them **provisional project targets**, not scientific constants. Align with phase 15: at least 8 of 10 approved participants complete their first guided reference-to-reviewed-output flow within ten minutes, with no more than two attempts per scene and no live developer coaching; at least 70% of the 30 guided cases produce a usable result within their two-attempt budget, improving the equivalent unaided-case success rate by at least 20 percentage points; no unsafe instruction or hidden tracking loss remains. These usefulness thresholds use case denominators, not attempt denominators. Disclose first-attempt success and total attempt counts for both conditions, timing distributions, later practice effects, and reviewer disagreement. These are small-sample product signals, not population estimates.

The early phase-07 gate answers whether capture is technically reliable. The separate phase-15 gate answers whether guided retakes are useful. Product proof cannot be claimed here or at phase 07. If the later guided outcome fails, consider a bounded pivot to framing/transition assistance; do not silently rename failure as exact replication.

## Verification

- **Repository/CI:** protocol includes scenario IDs, sample size, baseline, measurements, stop rules, privacy handling, and both gate references. Confirm demo flows remain labeled synthetic in screenshots.
- **Physical device:** no accuracy test is due yet; record the exact hardware and iOS versions required for later tests, including one non-LiDAR ARKit-capable device.
- **Human review:** someone unfamiliar with the concept can explain what success, failure, and inconclusive mean from the protocol alone.

## Risks and recovery

Recruitment bias, one spectacular cherry-picked video, inconsistent editing, and self-reported purchase intent can inflate confidence. Keep a complete attempt ledger and document exclusions before viewing results. A missing approved tester or device is `BLOCKED_DEVICE`/pending research, not a reason to fabricate evidence.

## Handoff checklist

- [ ] Protocol and interview/consent drafts reviewed; no external outreach implied.
- [ ] Hypotheses, baseline, targets, and stop rules versioned.
- [ ] All planned tests distinguish synthetic, physical, and human evidence.
- [ ] Report states the smallest next engineering experiment and unresolved assumptions.
- [ ] Coordinating agent reviews, commits, pushes, and records the remote SHA.

Read next: [phase 02](02-pose-math.md) and the [capture contract](../architecture/capture-and-coordinates.md).
