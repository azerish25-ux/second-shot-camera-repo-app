# Phase 23 — measured launch, support and sustainable iteration

**Status:** PLANNED. This document proposes an operating process; it does not schedule automations or authorize advertising spend.

## Outcome and dependencies

Learn whether real creators repeatedly obtain useful footage and willingly pay for the product. Depend on phase 22's approved release, support ownership and a known-good device/build baseline. Preserve privacy and media safety as the user base grows. Do not equate an attractive interface, downloads, social views, trial intent or one successful demo with a profitable business.

The original $1,000-per-month ambition is a hypothesis. With a $24.99 one-time price and an assumed 15% store commission, 48 new paid purchases yield approximately $1,020 before refunds, taxes and operating costs. This is arithmetic, not a demand forecast; actual commission eligibility and regional proceeds must be verified. It requires new customers each month and must not be labeled MRR.

## Implementation and operating work

1. Define a minimal funnel: relevant listing visits, first installs, first successful reference, first useful retake, first export and verified Pro purchasers. Use existing aggregate App Store reporting where possible. Any additional instrumentation needs a separate privacy/consent decision and a phase-19 update; never upload frames, room maps or fine-grained motion by default.
2. Separate product quality from acquisition metrics. Establish denominators for capture failures, rejected relocalizations, cancelled exports, confirmed crashes and support incidents. Report sample sizes, mode/device coverage and missing observations. A lack of reported crashes is not proof of a zero-crash product.
3. Recruit a small continuing advisory group through owner-approved outreach. Ask what they attempted, whether output was usable, which failure was confusing and whether they returned for another project. Collect adverse and neutral feedback as deliberately as enthusiastic feedback. Do not pay for positive reviews, gate review requests by satisfaction or fabricate testimonials.
4. Produce marketing demonstrations from real, reproducible candidate builds with permission to use the footage. Show the camera movement, guided retake and final result, including bounded conditions. Avoid presenting a manually composited professional production as a one-tap output the app cannot create.
5. Keep a short support playbook in `docs/release/`: reproduce on synthetic data first, request the minimum necessary diagnostics, preview what the user shares and state retention/deletion. Recover originals before recommending reinstalling the app; app deletion can remove the local project library.
6. Review current OS betas, new device capabilities and dependency/security updates in isolated testing. Keep `main` shippable and use small pushed checkpoints. Require the appropriate device smoke matrix for camera, timing, persistence and export changes; visual-only edits still need simulator/accessibility evidence.
7. Maintain a decision log for pricing, free-tier limits and feature requests. Evaluate potential additions against their effect on first useful retake and support complexity. Do not bolt on cloud AI, social features, subscriptions or broad SDK collection merely because acquisition is slow.

## Targets and experiments

Initial proposed launch window: four weeks, reviewed weekly by the owner. Compare at least two honest product demonstrations and measure listing-to-install and install-to-paid behavior using aggregate data. An illustrative 3% paid conversion would require about 1,600 installs per month for 48 purchases, but this is not a benchmark or a promised rate. Set a bounded time/spend budget before experiments; no paid campaign is implied by this plan.

Keep a first-30-day incident log. Proposed service target: acknowledge user-reported data loss within one business day when support coverage exists, and avoid promising round-the-clock support a solo developer cannot provide. Repeated tracking complaints trigger a fresh phase-15 study, not a lower confidence threshold hidden in code.

## Acceptance, recovery and handoff

Completion means the first operating review has actual cohort figures, a support record, known limitations, a cost/proceeds distinction and a documented continue/refine/pivot/stop decision. It does not require hitting the income target and does not end maintenance. If retention or paid conversion is weak, revise the specific value proposition before broadening scope.

Security exposure, project corruption or a systematic false-success state overrides growth work: stop further rollout where practical, protect user media and publish a reviewed fix. Archive the exact tested SHA and regression evidence. Hand off one prioritized next experiment, its falsifiable result, estimated effort and owner approval needs.

Primary reference: [App Store Connect analytics help](https://developer.apple.com/help/app-store-connect-analytics/). Verify actual reporting availability and definitions before interpreting launch data. Store reports and qualitative pilot observations measure different populations and must not be combined as if they were a single experiment.
