# Working agreement

## Before a session

Read AGENTS, STATUS, the roadmap and the exact phase. Inspect `git status --short
--branch`, the latest remote main and any incoming changes. Identify the scope,
acceptance tests, file ownership, prerequisite gates and evidence available.
Distinguish a request to plan or diagnose from authorization to implement or ship.

## Implement one coherent slice

Write the smallest change that produces a user-observable or independently tested
result. Keep domain math, state transitions and IO adapters separate. Introduce
protocols when they enable a test boundary, not as speculative abstraction. Prefer
native frameworks and simple local data. No package merely to save five lines.

Use explicit errors and cancellation. Invalid pose input, stale tracking, failure
to relocalize or writer errors must not become an identity transform, empty success
or green quality indicator. Write regression tests before accepting a fix.

## Parallel work

The coordinating agent assigns disjoint file sets. All contributors read the same
contracts. Contributors report discrepancies early and do not rewrite shared files
unilaterally. Only the coordinator stages, commits and publishes the integrated
tree. After integration, run tests that cross the boundaries between contributors.

## Verification tiers

1. Static checks: formatting, local links, manifests, project generation, shell and
   Python checks. This proves syntax/structure only.
2. Deterministic tests: pure math, state machines, stored formats and injected IO.
3. Simulator tests: real app binary on iOS Simulator, actual button navigation,
   accessible labels, layout screenshots and failures with synthetic providers.
4. Physical-device experiments: actual camera, AR, audio, storage pressure and
   thermal behavior. Capture the exact device, OS, build, conditions and data.
5. Human usefulness and release: held-out operators, support, signing, compliance
   and explicit owner approval. Earlier tiers do not imply this tier passed.

## Commit / push loop

Review `git diff --check` and the scoped diff; avoid generated files and secrets.
Stage only task-owned files. Use a concise message such as `feat(core): reject
cross-origin pose comparison` or `docs(phase-08): specify relocalization recovery`.
Publish to main without force, then verify the server's new head. If main changed,
inspect it and integrate safely; do not overwrite another contributor's work.

Check the exact commit's Actions runs. Inspect failures and artifact screenshots.
Never weaken assertions, skip a suite, hide an exit code or swap synthetic inputs
into production to get a green badge. Infrastructure problems are reported as
infrastructure problems; they do not prove app correctness.

## Evidence and status updates

Update `docs/STATUS.md` only with observed facts. A test result includes command,
commit, environment, test count, pass/fail and evidence URL/path. A device result
additionally includes hardware model, OS build, scene conditions and consented
data location. Missing evidence means planned, partial or blocked—not complete.

Use [the phase-report template](templates/PHASE_REPORT.md). Keep a concise report
per completed milestone under `docs/reports`; do not create a diary per tool call.
Do not commit raw personal media, xcresult bundles, installed tooling or large
artifacts. Actions artifacts are short-lived; archive important acceptance evidence
in an owner-approved durable location and record retention/consent constraints.

## Review and stop conditions

Review accuracy claims, privacy changes, dependencies, asynchronous lifecycles and
error states as carefully as screenshots. Stop for missing authority, protected
workflows, secrets or paid services; ask the owner rather than bypassing controls.
Stop dependent feature work when a gate fails, while independent documentation,
fixtures and UI improvements may continue with clearly stated limitations.

## End-of-session handoff

Report: what changed; what actually ran; results; what did not run; exact artifact
URLs; commit and remote SHA; remaining risks; and the first executable next task.
Do not imply continued background work or monitoring unless separately configured
and requested. No App Store submission or paid purchase is part of bootstrap.
