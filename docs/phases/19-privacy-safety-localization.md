# Phase 19 — privacy, security, safe use and localization

**Status:** PLANNED.

## Outcome and dependencies

Ship a comprehensible local-first tool with a small, reviewable data surface. Depend on phases 04–08, 14 and 16–18. Coordinate privacy declarations with phase 22, but do not postpone discovery of unexpected collection until submission. This phase does not authorize a server, analytics vendor, new account system, public footage upload or broader permissions.

The baseline processes video, audio when explicitly enabled, camera poses and world maps on the device. That is not automatically the same as “nothing ever leaves the phone”: system backup, user-selected sharing, StoreKit and optional support diagnostics each need an accurate explanation. Never promise zero data collection without auditing the final binary and all dependencies.

## Implementation work

1. Create a data inventory recording each field/asset, purpose, storage location, retention, recipients and deletion path. Treat raw recordings, thumbnails and AR world maps as sensitive. Document operating-system backups separately from app-operated synchronization; no private cloud transport is introduced by this phase.
2. Request camera permission when the user chooses live capture. Ask for microphone access only when enabling sound; permit a documented silent workflow if sound is optional. Use the narrow Photos permission appropriate to the implemented action, or the system share/document interface when broad library access is unnecessary. Denial and restriction must lead to actionable, truthful UI rather than a crash.
3. Audit `Info.plist` purpose strings, entitlements, `PrivacyInfo.xcprivacy`, required-reason APIs and dependency manifests. Declare only reasons that match code actually present. Do not copy a long list of reason codes as a “future-proof” workaround, and do not set App Store privacy answers merely by copying the manifest.
4. Extend the package validator from phase 17 with size and allocation bounds, canonical-path checks, manifest validation and resource caps. Treat imported projects and filenames as untrusted data. Keep secrets, raw image bytes, purchase details and room metadata out of logs and crash breadcrumbs.
5. Prepare a short privacy notice and support-diagnostics preview. Any proposed report must show the user what will be included and require explicit sharing. The owner must supply a real support contact and public policy URL before release; do not invent either.
6. Add pre-capture safety instructions: clear the route, stay aware of surroundings and stop if uncertain. Never direct backwards walking, stairs, roads or movement toward obstacles. AR tracking is not obstacle detection or a safety guarantee. Keep an accessible Stop control available during all live states.
7. Move customer-facing strings into String Catalogs under `Sources/SecondShotApp/Resources/`. Start with complete English, pseudo-localization and a right-to-left layout audit. Additional released languages need human-readable review and terminology consistency, not machine-filled completion claims. Use localized units, plurals, prices and date formatting; preserve technical project schema identifiers unchanged.

## Verification and acceptance

Simulator tests cover denied/restricted permissions, malformed imports, oversized fields, pseudo-localized expansion and right-to-left UI. Inspect logs from successful and failed journeys for sensitive content. Exercise the actual permission dialogs, share sheets, Photos behavior, network behavior and device backup/export policies on real hardware.

Acceptance requires a traceable data inventory, no unexplained app-originated network endpoint, no permission requested solely by launching Demo Studio, no unbounded package allocation, and no personally identifying diagnostic content in committed fixtures. Capture guidance is understandable without color, sound or haptics alone. Permission descriptions must match real behavior in every offered language.

If a dependency adds collection, remove or disable it pending an explicit decision; do not retroactively justify hidden collection. If a user declines diagnostics or permission, preserve their access to existing projects and truthful non-camera functionality. A translation or security finding blocks the affected feature rather than being hidden by a fallback success state.

## Evidence and handoff

Attach the inventory, dependency audit, tested permission-state matrix, network inspection method/results, redacted log examples and localization screenshots. Record exactly which languages are released. Update the privacy policy draft and App Store answers together when behavior changes, then request owner approval before publishing legal/business representations.

Primary sources checked 2026-10-26: [privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [App Store privacy details](https://developer.apple.com/app-store/app-privacy-details/), [camera purpose string](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription). Requirements must be rechecked on the release date.
