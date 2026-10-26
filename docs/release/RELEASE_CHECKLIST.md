# Second Shot release checklist

**Status: NOT EXECUTED.** This checklist is a gate record, not a claim of readiness.
Do not pre-check items because a phase document exists. See
[phase 21](../phases/21-testflight-beta.md),
[phase 22](../phases/22-app-store-release.md) and
[device validation](../testing/DEVICE_VALIDATION.md).

## Candidate identity and authority

- [ ] Owner approved the intended action: signed build, beta distribution,
      submission and public release are recorded separately.
- [ ] Exact candidate SHA is on `main`; version/build number and release scope are
      recorded. No forced history change or unrelated modifications are included.
- [ ] Owner-confirmed bundle ID, team, account role and App Store Connect record
      match the app. Working title/name clearance is resolved.
- [ ] Actual protected GitHub environment approval rules are verified; a YAML
      environment name is not accepted as proof of protected release authority.
- [ ] No unapproved paid service, ad campaign, signing-key creation, public beta
      invitation or live purchase is needed to complete this release.

## Engineering evidence

- [ ] Required static, domain, simulator and UI jobs passed for this exact SHA;
      run URLs, test counts, failures and limitations are recorded.
- [ ] Real screenshot artifacts were inspected at small/large widths and standard/
      accessibility text sizes, including error states. No fabricated screenshots.
- [ ] Gate 07 captured real video/pose integrity; gate 15 demonstrated bounded
      product usefulness under a frozen protocol. Redacted reports are linked.
- [ ] Each offered device/format combination has appropriate physical evidence.
      Optional 4K, HDR, higher frame rates and LiDAR are not assumed supported.
- [ ] Signed-build smoke tests covered fresh install, update, permissions,
      interruption, relocalization, reference/retake, export and project reopening.
- [ ] Sources survive cancellation, low storage and failure. Migration/backward-
      compatibility decisions and a recovery procedure were exercised.
- [ ] No known source-data loss, origin mixing, false-valid tracking, silent export
      failure, unsafe cue, material security issue or inaccessible critical action
      remains unresolved.

## Privacy, legal and commercial truth

- [ ] Data inventory matches the final binary, dependencies and user-visible
      behavior. Collection/backup/user sharing distinctions are accurate.
- [ ] Purpose strings, entitlements, privacy manifests and required-reason API
      declarations were reviewed against current Apple requirements.
- [ ] App Store privacy, age-rating and export-compliance answers have a factual
      basis and owner approval; missing business/legal information is not invented.
- [ ] Live public privacy and support URLs exist and work; their contact details
      belong to the owner and retention language matches the implementation.
- [ ] Third-party code/media/font licenses are respected. Marketing participants
      and locations have the necessary consent; private room maps are not public.
- [ ] Proposed Pro price/SKU/free-tier rules were approved. If commerce ships,
      verified purchase, pending/cancel, restore, refund/revocation and unavailable
      store behavior passed local tests and the authorized sandbox/device checks.
- [ ] No test entitlement or synthetic purchase override can unlock production
      features. StoreKit configuration reflects a non-consumable, not a disguised
      subscription. Existing projects remain readable during entitlement errors.

## Archive and upload

- [ ] Selected compiler/SDK meets Apple's current upload requirements. At the
      2026-10-26 documentation check, this is Xcode 26+ with iOS 26+ SDK; recheck
      [current requirements](https://developer.apple.com/news/upcoming-requirements/).
      Minimum deployment OS and simulator runtime are separate concepts.
- [ ] Signing uses authorized encrypted secrets and scoped temporary keychain/
      profile files. Credentials, receipts and private media are absent from logs,
      source, summaries and artifacts; cleanup behavior is verified.
- [ ] Archive provenance, build number, toolchain version and debug symbols are
      recorded. The uploaded binary derives from the reviewed source.
- [ ] Upload completed and App Store Connect processing status was checked.
      An HTTP upload acknowledgment is not processing/review success.
- [ ] Beta/review requirements and export-compliance issues were resolved without
      assuming publication. Tested install behavior matches the distributed build.

## Listing and release decision

- [ ] Screenshots, previews, description, supported devices and optional purchases
      match actual behavior. Synthetic demo imagery is clearly distinguished.
- [ ] Claims exclude robotic precision, automatic general-parallax correction,
      universal camera formats and revenue guarantees. Known limitations are clear.
- [ ] Review notes provide a reproducible bounded workflow and explain hardware
      needs; account credentials are supplied only if an actual account feature
      exists. No fictitious reviewer login is invented.
- [ ] Owner approved the final submission. Record Apple's resulting status; do not
      conflate queued, in-review, approved, released and available storefront states.
- [ ] Public release is deliberate and owner-controlled, never automatic on a push.
      Support ownership, incident response and migration-safe update plans are set.
- [ ] Archive important redacted acceptance evidence before CI artifact retention
      expires. Record durable location, access restrictions and consent deadlines.

## Release record to complete

| Field | Required observed value |
| --- | --- |
| Candidate commit / version / build | Not yet assigned |
| CI run and observed test counts | Not yet run for a release candidate |
| Gate 07 / gate 15 reports | Not yet available |
| Tested physical device and format matrix | Not yet available |
| Owner approvals | Not yet granted for distribution |
| App Store Connect build / review status | Not yet submitted |
| Public storefront confirmation | Not released |
| Known limitations and support owner | To be approved |

Any unchecked mandatory item blocks the corresponding action. Complete useful
independent work, report the exact blocker and request appropriate owner direction.
Do not turn missing evidence into a checkbox exception merely to ship.
