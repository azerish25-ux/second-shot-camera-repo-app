# GitHub Actions and iOS Simulator workflow

## What the workflow proves

`iOS Simulator CI` generates an Xcode project, compiles the real iOS application,
executes pure Swift tests and XCTest UI journeys, and exports screenshots taken
by XCTest. It is not a remotely controlled iPhone and does not verify AR tracking,
camera fidelity, audio synchronization, spatial accuracy or thermal behavior.
Every synthetic screen and evidence manifest must preserve that distinction.

`Repository checks` independently runs inexpensive structural/documentation checks
and unit tests for the CI helpers on Linux. Passing this job alone is **not** an
iOS build result. A workflow file merely existing is not proof it ran.

Both workflows run on pushes to `main`, pull requests targeting `main`, or manual
dispatch. Pull-request support does not change the owner's main-only development
policy. They use read-only repository permissions, no signing secrets, no purchases,
no release upload, and no external deployment. Checkout does not persist credentials.

## Reviewed baseline and reproducibility

Checked against upstream metadata on **2026-10-26**:

| Item | Repository pin / behavior |
| --- | --- |
| Hosted runner | `macos-26`, standard runner label; no paid large-runner requirement |
| Xcode | Prefers `/Applications/Xcode_26.6.app`; falls back to the newest installed `Xcode_26*.app` and fails if none exists |
| SDK/runtime | Record selected SDK; discover the newest installed compatible iOS runtime and an available iPhone |
| Deployment target | iOS 17.0; testing a current runtime is not minimum-OS coverage |
| Swift language mode | Swift 5 for the initial foundation; compiler version recorded |
| XcodeGen | 2.46.0 ZIP, verified SHA-256 before execution |
| checkout | `11d5960a326750d5838078e36cf38b85af677262` (v4 reference checked) |
| upload-artifact | `ea165f8d65b6e75b540449e92b4886f43607fa02` (v4 reference checked) |
| Project | `project.yml` generates ignored `SecondShot.xcodeproj` and `.generated/` |
| Scheme | `SecondShot` with `SecondShotCoreTests`, `SecondShotAppTests` and `SecondShotUITests` |

Hosted images evolve; the label is not an immutable OS image. Environment manifests
record the actual image/Xcode/SDK. Missing Xcode or simulators is an infrastructure
failure, not permission to silently switch to a beta, download many gigabytes, use
a paid runner or claim device coverage. Review upstream metadata, update the pin
in a small commit, and rerun. App Store SDK rules must be rechecked separately at
release even when this simulator baseline uses Xcode 26.

**Toolchain selection and drift.** Observed on 2026-10-26: two runs on the same
`macos-26` label passed at 17:14 and failed at 17:53 in the old exact-version step,
with no repository change in between — the image rolled under the workflow. The
step now selects `Xcode_26.6.app` when present, otherwise the newest installed
`Xcode_26*.app`, exports that `DEVELOPER_DIR` to later steps, and writes the full
`/Applications` inventory plus the actual `xcodebuild`/SDK/Swift versions into the
job summary. A drift therefore shows up as a warning with evidence instead of an
unexplained failure. It still fails, with the inventory attached, when no Xcode 26.x
exists: running on an unreviewed major version is never automatic. The 26.x series
floor is a project decision — Xcode 16.3+ is the compatibility floor for modern
xcresult attachment export and Swift 5.9+ for the package — not a claim of tested
older-Xcode support or eligibility for a current App Store submission.

The bootstrap deliberately avoids Homebrew upgrades, mutable dependency versions,
remote Swift packages and opaque caching. XcodeGen's official binary ZIP digest is
`4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`.
The installer retains the accompanying setting presets; copying the executable
alone is insufficient. Update version, URL, digest and these notes together.

## Running without a personal Mac

1. Implement a bounded phase and run the cross-platform checks below where possible.
2. Commit and push to `main`; open the repository's **Actions** tab.
3. Select the workflow run for the **exact pushed SHA**, not an older green run.
4. Expand failed steps, read raw logs, and download `ios-evidence-<SHA>`.
5. Inspect actual screenshot attachments against the design spec. Fix code or tests
   as warranted; do not replace screenshots with renderings or weaken assertions.
6. Record run URL, SHA, test counts, screenshot review and untested conditions in
   [STATUS](STATUS.md) and the phase report.

Optional CLI for an already authenticated, authorized GitHub CLI environment:

```bash
gh run list --repo azerish25-ux/second-shot-camera-repo-app --branch main
gh run view RUN_ID --repo azerish25-ux/second-shot-camera-repo-app --log-failed
gh run download RUN_ID --repo azerish25-ux/second-shot-camera-repo-app --name ios-evidence-COMMIT_SHA
```

`RUN_ID` and `COMMIT_SHA` are placeholders to replace with observed values. A
pending/cancelled run is not a pass. Main pushes cancel superseded runs to bound
cost; wait for the final revision's run. There is no unattended recurring schedule.

## Reproducing the checks

Any machine with Python 3.10+:

```bash
python3 -B scripts/ci/check_repository.py
python3 -B -m unittest discover -s scripts -p 'test_*.py' -v
```

The structural checker checks all 24 phase files, required entry documents,
repository-relative Markdown link targets, JSON/plists and immutable action pins.
It does not validate remote links, Markdown anchors, every YAML rule or Swift code.
Proposed future implementation paths in plans should be code spans, not links to
files that do not yet exist. Do not add empty files to satisfy link checks.

On a Mac with the reviewed Xcode installed:

```bash
export DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer  # or the newest installed Xcode 26.x
export SECOND_SHOT_EXPECTED_XCODE=26.6
python3 -B scripts/ci/capture_environment.py
bash scripts/ci/install_xcodegen.sh
.tools/xcodegen/bin/xcodegen generate --spec project.yml
swift test --enable-code-coverage
bash scripts/ci/run_simulator_tests.sh
python3 -B scripts/ci/collect_results.py
```

Use a fresh ignored result directory for a second local run: Xcode refuses to
overwrite an existing xcresult bundle. Move the existing `artifacts/ios` directory
to an explicitly named local archive rather than deleting evidence. Local Mac
commands require appropriate filesystem/network permissions; ask for those rather
than bypassing a restricted environment.

## Evidence and failure behavior

The simulator run has a 35-minute job limit. Xcode test execution has per-test
timeouts, simulator selection is deterministic, and test parallelization is off
to reduce contention. No sleeps are used to guess when a UI screen is ready;
XCTest waits for identified controls before taking `.keepAlways` screenshots.

Artifacts (14-day retention) include:

- `environment.json`: commit, runner image, Xcode/compiler/SDK and host architecture;
- `runtimes.json`, `devices.json`, `simulator.json`, `boot.log`;
- `swift-test.log`, `xcodebuild.log`, `SecondShot.xcresult` with coverage and test data;
- `test-summary.json`, `test-tree.json` proving nonzero passing tests and both suites;
- `screenshots-and-attachments/`, `attachment-export.log`, `collection.json`.

Upload is attempted even after failure. If setup failed before tests, collection
explicitly records that no xcresult exists. This diagnostic step cannot turn the
failed build into a pass. Nonzero failures, skips, missing required suites or an
empty test run fail validation. Missing screenshot evidence after otherwise
successful tests also fails. If tests already failed, attachment-export problems
remain explicit diagnostics without obscuring the earlier failure.
Cancelled jobs or runner loss may prevent upload; report that absence honestly.

Do not rerun repeatedly to bury a deterministic error. Distinguish infrastructure
failure (missing runtime, runner outage) from source/test failure, preserve the
first run, and explain any targeted retry. Do not use `continue-on-error`, delete
failing tests, or replace physical validation with synthetic runs.

## Extension points

Keep this baseline small until it is green. Add a second small-screen/landscape/
Dynamic Type simulator matrix in phase 16, minimum-OS coverage in phase 18, and
StoreKit-local tests in phase 20. Those additions should produce separate evidence
identities rather than claiming coverage from one screen size. Signed TestFlight
and App Store jobs are future manual, owner-approved jobs with protected environments;
they are intentionally absent from this unsigned setup.

## Primary references

- [GitHub runner image manifest](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
- [XcodeGen 2.46.0 release](https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0)
- [XcodeGen project specification](https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/ProjectSpec.md)
- [Apple command-line tool reference](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference)
- [Apple xcresulttool changes](https://developer.apple.com/documentation/xcode-release-notes/xcode-16_3-release-notes)
- [Apple simulator versus physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Apple: ARKit is not available in Simulator](https://developer.apple.com/documentation/arkit/placing-objects-and-handling-3d-interaction)

Primary sources describe capabilities; only this repository's actual run artifacts
demonstrate what happened for a particular revision.
