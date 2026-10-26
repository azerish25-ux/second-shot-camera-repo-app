# Phase 21 — signed builds and an approved TestFlight beta

**Status:** PLANNED. This phase requires later owner authorization and credentials. Repository setup does not authorize distribution or tester invitations.

## Outcome and dependencies

Move from unsigned simulator evidence to a traceable signed build that consented testers can install on real iPhones. Depend on phases 15–20, the [device-validation protocol](../testing/DEVICE_VALIDATION.md), a clean CI result for the exact candidate commit and an owner-approved beta plan. Internal engineering builds may be used earlier for hardware work, but they must not be described as a completed public beta.

GitHub Actions' macOS runner can archive an iOS app when signing is configured. It is not an iPhone, and an archive/upload success does not prove that TestFlight processing, review, installation or real recording works. Read the current pins and evidence rules in [CI_WORKFLOW](../CI_WORKFLOW.md); those unsigned simulator jobs do not perform this phase. No paid runner is required by this plan; any new paid service needs approval.

## Implementation work

1. Gather the owner-confirmed bundle ID, developer team, App Store Connect app record, signing approach and authorized distribution account. Missing values are blockers, not placeholders that agents may invent. Check current upload requirements: as verified on 2026-10-26, Apple requires Xcode 26 or later with an iOS 26-or-later SDK for uploads; recheck before execution. The deployment target can remain iOS 17 if supported by the chosen SDK.
2. Add a separate future `.github/workflows/testflight.yml` using `workflow_dispatch`, not push, pull-request or a timer. Require an exact full commit SHA input, validate its syntax and ancestry on `main`, and verify its CI and gate evidence before introducing secrets. Avoid interpolating unchecked user inputs into shell commands.
3. Require a protected GitHub environment with an actual owner approval rule. A YAML `environment:` name does not by itself enforce review. Confirm repository settings and restrict workflow permissions. Do not give fork builds signing material or reuse untrusted build artifacts as a release archive.
4. Configure signing materials through the normal encrypted secret mechanism after explicit owner approval. Use temporary, scoped keychain/profile locations, mask values and remove them in a cleanup step. Never echo encoded certificates or keys; never put secrets in source, job summaries, screenshots or artifact bundles.
5. Archive and export the reviewed source with the selected supported Xcode, recording version, build number, SDK and commit. Establish a unique monotonically increasing build-number policy without secretly changing source branches. Record archive provenance and available debug symbols. Upload only after a second deliberate release decision if the workflow separates build and upload.
6. Verify the build appears in App Store Connect and finishes processing. Resolve signing/export-compliance errors using the actual response; repeated blind uploads are not verification. Supply beta test instructions, known limitations, privacy contact and supported device criteria before invitations.
7. Begin with a small consented cohort representing the device matrix. Owner approval is required before sending email invitations or publishing a public link. Include clear instructions for safe bounded filming and optional sharing of redacted diagnostics; testers are not obliged to share personal rooms or footage.

## Tests and acceptance

CI validates workflow structure and archive prerequisites without secrets. Dry-run mode must stop before signing/upload, report missing requirements and never masquerade as release success. On real devices verify first install, update from the prior beta, permission denial, a reference/retake/export journey and restore behavior where applicable.

Acceptance requires an exact-SHA archive, App Store Connect processing confirmation, observed installation on at least two distinct supported device classes, and linked consented beta findings. External testing may require Apple's review; pending review is not a successful invitation/availability claim. Apple's current beta-build lifetime must be checked when planning ongoing testing.

## Failure and handoff

For failed signing or authorization, stop and request owner action; do not extract credentials from another workflow. For a bad beta, stop further distribution and prepare a new fixed build, preserving user project migration compatibility. Record tester count, install/build evidence, known defects and whether each result is local, simulator, sandbox or device-derived. Never expose tester addresses in the repository.

Primary sources: [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds), [current requirements](https://developer.apple.com/news/upcoming-requirements/), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/). Check again at implementation and distribution time.
