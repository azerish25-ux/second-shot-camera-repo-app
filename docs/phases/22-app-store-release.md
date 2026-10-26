# Phase 22 — honest App Store submission and controlled release

**Status:** PLANNED. No submission or publication is authorized by the bootstrap task.

## Outcome and dependencies

Prepare an evidence-backed release candidate whose description matches what real devices can do. Depend on all applicable earlier phases, a passed phase-15 product-proof gate, phase-18 supported-device results and a completed approved beta. Use the [release checklist](../release/RELEASE_CHECKLIST.md) as the operational record. A green workflow, complete documentation or an uploaded archive cannot substitute for these gates.

The core product claim is approximate guidance for repeating short camera moves. Do not market robotic precision, universal 4K, automatic elimination of 3D parallax or guaranteed cinematic results. If hardware evidence supports only a more limited framing/transition assistant, change the product and listing accordingly before charging anyone.

## Implementation and preparation

1. Freeze a candidate commit and version on `main`; preserve a reproducible reference to the exact tested source. Read [CI_WORKFLOW](../CI_WORKFLOW.md), recheck the selected Xcode/SDK against Apple's current upload requirements and ensure all promised device modes remain supported by the binary. Do not assume the simulator runtime is the App Store SDK requirement.
2. Review the final archive's entitlements, purpose strings, privacy manifests, dependencies, Info.plist, icons, launch behavior and licensing notices. Complete App Store privacy, age rating and export-compliance questionnaires from actual implementation and owner-provided business information. Ask for missing legal/trader/contact details rather than inventing answers.
3. Create real screenshots and preview clips from the candidate. Show only implemented features and supported UI states. Demo or illustrative imagery must be labeled as such and must not imply successful physical tracking. Keep raw personal recordings out of the repository and obtain permission for subjects and locations used in marketing media.
4. Write concise listing copy with a concrete use case, bounded operating conditions, supported-device information, optional purchase terms and safety limitations. Confirm that “Second Shot” and any visual assets can be used; the working title has not been cleared as a trademark. Have the owner approve the final name and commercial claims.
5. Ensure the in-app Pro product, free/paid descriptions, restore function, price display and review configuration match. If commerce is deferred, remove all purchase claims from the release scope rather than leaving a broken paywall. Do not promise future paid features as if available now.
6. Provide App Review notes explaining the live hardware-dependent journey, how the truthful synthetic demo differs, permission requirements and how to reproduce key features safely. There are no account credentials to invent because the baseline has no user account system. If the product later changes, document the necessary review access accurately.
7. Use the manual approved release path from phase 21. Submission, answering review questions, accepting legal agreements and public release are distinct actions requiring appropriate authority. Choose an owner-controlled release option; a push to `main` must never publish the app automatically.

## Verification and acceptance

Run the complete simulator suite on the candidate and inspect its visual artifacts. Repeat a real-device smoke test from the signed distribution build, not merely a Debug build: new install, permissions, capture, interruption, review, export, project reopen and purchase restore when included. Verify public support/privacy URLs and localizations. Ensure test-only entitlements and unconditional fake-Pro switches are absent from Release.

Acceptance requires no known data-loss, security or false-success defect; no unexplained app-originated collection; a validated device/format matrix; documented remaining limitations; and a signed owner release decision linked to the candidate SHA. Review approval and a live storefront listing are separate evidence fields. Do not mark the phase complete when a submission is merely queued.

## Recovery and handoff

If Apple rejects the build, preserve the rejection text privately and fix the identified cause with a new reviewed commit. Do not remove diagnostics or disable tests to conceal the problem. If a release defect threatens user media, stop rollout where available, publish accurate support guidance and prepare a migration-safe update. Store-level rollback is not equivalent to instantly replacing every installed binary.

Primary references checked 2026-10-26: [submission preparation](https://developer.apple.com/app-store/submitting/), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [upload requirements](https://developer.apple.com/news/upcoming-requirements/), [privacy details](https://developer.apple.com/app-store/app-privacy-details/). Recheck policy and SDK requirements at the actual release date.
