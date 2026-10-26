# Second Shot

**Make the same move. Twice.**

An iPhone-first creative camera project: capture a short camera movement, return
to its starting frame, and use spatial guidance to make a second, approximately
matching take. Review the pair and export useful material for match cuts, product
reveals, and constrained visual-effects work.

> **Foundation, not a finished camera app.** The initial application is a clearly
> labeled, deterministic **Synthetic Demo Studio**. It does not record video, run
> live AR, correct parallax, or export footage. The documentation describes the
> intended product; [STATUS](docs/STATUS.md) records what is actually implemented.

## Start here

| Reader | Read first |
| --- | --- |
| Implementation agent | [AGENTS.md](AGENTS.md) → [current status](docs/STATUS.md) → [roadmap](docs/ROADMAP.md) |
| Product/design | [Product brief](docs/PRODUCT_BRIEF.md) → [design system](docs/design/README.md) |
| Engineer | [Architecture](docs/architecture/README.md) → [CI workflow](docs/CI_WORKFLOW.md) |
| Tester/release owner | [Acceptance gates](docs/ACCEPTANCE_GATES.md) → [device validation](docs/testing/DEVICE_VALIDATION.md) |

There are **24 ordered phase specifications (00–23)**. Each defines dependencies,
implementation tasks, tests, failure behavior, evidence, and handoff criteria.
They are a work queue, not a claim that the features already exist.

## What the foundation is designed to exercise

- A premium SwiftUI library and synthetic reference → retake → review journey.
- Deterministic pose-error calculations with quaternion sign equivalence,
  malformed-input rejection, tracking validity, time and origin checks.
- Explicit tracking interruption and recovery states; no fake success on failure.
- Unit and UI tests on GitHub-hosted macOS with an iOS Simulator.
- Screenshot attachments, logs, toolchain inventory and xcresult evidence.
- Markdown/link and CI-helper tests without requiring a local Mac.

See [STATUS](docs/STATUS.md) for the latest observed results and commit-specific
workflow evidence. A planned workflow is not a passing workflow.

## Run locally on a Mac

Use the Xcode and XcodeGen versions in [CI_WORKFLOW](docs/CI_WORKFLOW.md).

```sh
swift test
bash scripts/ci/install_xcodegen.sh
.tools/xcodegen/bin/xcodegen generate --spec project.yml
open SecondShot.xcodeproj
```

Choose the **SecondShot** scheme and an available iPhone Simulator. The generated
Xcode project is intentionally ignored; `project.yml` is its source of truth.
The pure-Swift core can be tested separately with `swift test` on a compatible
Swift toolchain. The SwiftUI app requires Apple's SDKs.

## GitHub Actions development loop

1. Work on `main`, read the assigned phase, and implement a small vertical slice.
2. Run available local checks and review the diff. Commit and push the checkpoint.
3. Open [Actions](https://github.com/azerish25-ux/second-shot-camera-repo-app/actions).
4. Inspect **Repository checks** and **iOS Simulator CI** for that exact commit.
5. Download evidence; inspect screenshots and test failures, not just the green badge.
6. Fix failures, push, and update the phase report and status with observed facts.

Unsigned simulator builds require no Apple signing secret. The default workflows
do not upload to TestFlight, spend money on services, or publish an App Store build.

**Simulator is not a physical-device substitute.** It cannot validate AR tracking,
camera sensor output, real relocalization, audio/video drift, scene-dependent
registration, physical precision, heat, or useful handheld repeatability. Those
remain explicit device gates. GitHub Actions is the main development/test workflow,
not evidence that a camera prototype works in the real world.

## Product guardrails

- Short, slow, safe moves first; approximate guidance, never robotic precision.
- Original media is immutable; alignment is optional and uncertainty is visible.
- No account or cloud backend in the MVP. No advertising or generative-AI dependency.
- iPhone-first, native SwiftUI; iOS 17 minimum for the foundation, capability-gated
  capture formats rather than universal 4K/HDR/LiDAR promises.
- Local files and explicit consent; no room maps or personal footage in this repo.
- Proposed one-time Pro purchase, only after useful-retake validation. A revenue
  target is a hypothesis, not guaranteed earnings or recurring revenue.

## Project map

| Path | Responsibility |
| --- | --- |
| `Sources/SecondShotCore` | Platform-independent domain and synthetic fixtures |
| `Sources/SecondShotApp` | SwiftUI shell; later camera/AR/storage/export adapters |
| `Tests/SecondShotCoreTests` | Repeatable correctness tests |
| `Tests/SecondShotUITests` | Simulator user journeys and screenshot evidence |
| `scripts/ci` | Tool setup, simulator selection, validation and evidence |
| `docs/phases` | Detailed implementation queue |
| `docs/design` | Tokens, screen states, motion and accessibility |
| `docs/architecture` | Coordinate, capture, alignment and export contracts |
| `docs/testing`, `docs/release` | Physical proof and release checklists |

## Contributing and ownership

Follow [AGENTS.md](AGENTS.md) and the [working agreement](docs/WORKING_AGREEMENT.md).
Do not introduce a new branch or force-push. A public repository is not by itself
an open-source license: no redistribution license is granted here until the owner
chooses one. Dependencies retain their respective licenses.
