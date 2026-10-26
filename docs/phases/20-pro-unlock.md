# Phase 20 — honest, restorable one-time Pro unlock

**Status:** PLANNED. No App Store product, production payment or commercial promise is created by this document.

## Outcome and dependencies

Offer an optional non-consumable purchase only after the core capture/retake workflow is useful and the phase-15 hardware/product gate passes. Depend on phases 14, 16, 17 and 19. The proposed US price is $24.99 once, not a subscription; the owner must validate value, choose the final price and approve the product identifier before production configuration. Revenue is not guaranteed, and one-time sales are not monthly recurring revenue.

The free experience must let someone evaluate the product truthfully: accessible demo, existing-project access and a clearly described usable preview. Candidate paid benefits are unlimited project creation and premium export options that actually exist on the device. Final limits require a written decision. Never lock a user's existing originals behind a new paywall or invent unsupported 4K/HDR capability to sell Pro.

## Implementation work

1. Define an `EntitlementProvider` seam and explicit states such as loading, free, verified Pro, purchase pending, unavailable and error. Keep the policy in `Sources/SecondShotCore/` independent of StoreKit; implement the StoreKit 2 adapter in `Sources/SecondShotApp/Commerce/`.
2. Load product metadata from StoreKit. Render its localized display price and purchase type; do not hardcode $24.99 into the purchase button for every storefront. A missing product must produce a useful unavailable state, never a fake success or charge through an alternative unapproved channel.
3. Start a single owned transaction-update listener early in the app lifecycle. Resolve current verified entitlements, handle verified purchase results, finish processed transactions, and apply revocations consistently. A forged local preference is not a purchase receipt. Keep StoreKit-specific verification failures separate from network unavailability.
4. Distinguish purchase cancellation, pending approval and verification failure. Only a verified transaction for the exact approved product unlocks production features. Do not show “Purchased” while the system sheet is still pending. Avoid duplicate concurrent purchase tasks.
5. Provide a visible Restore Purchases action. Refresh current entitlements normally; reserve user-interactive synchronization for an explicit restore action. Retain legitimate previously verified entitlement information across ordinary temporary outages using StoreKit's supported entitlement behavior; never convert “could not refresh” into an invented revocation or permanent grant.
6. Make restored/revoked purchase state nondestructive: old media and project-reading access stay available. Cancel new restricted operations at a defined boundary without corrupting an in-flight export. Respect the eventual owner decision on Family Sharing; do not promise it before configuration and tests.
7. Add a checked-in local `.storekit` configuration and injectable fake provider for tests. Keep the simulated purchase mode unmistakable and exclude debug overrides from release behavior. GitHub Actions must not buy real products or need an Apple account to execute local StoreKit tests.

## Verification

Use StoreKit Testing in Xcode and `StoreKitTest` for purchase success, cancellation, pending approval, interrupted flow, restore on reinstall, refund/revocation and transaction replay. Test verified versus unverified results, unknown product IDs, product-loading failure and listener cancellation. Add simulator journeys for reachable purchase dismissal, clear one-time wording and no purchase prompt at launch.

Before release, use Apple's sandbox/TestFlight flow with authorized testers to validate actual catalog configuration, localized pricing and restore behavior on real devices. Local StoreKit success proves app logic, not the existence or approval of a production product.

## Acceptance, recovery and evidence

The core app remains usable during store outages; existing footage is never deleted or held hostage. Payment state is derived from verified store information, duplicate updates are idempotent, and every offered benefit maps to a tested capability. No countdown, fake discount, recurring-charge ambiguity or forced rating request is permitted.

Attach local and sandbox test results separately, the approved free/paid capability matrix, storefront screenshots and redacted transaction-state traces. Record the chosen SKU and price decision only after owner approval. Do not commit receipts containing personal information, keys or account credentials. Hand off product-configuration gaps explicitly to phase 21/22.

Primary sources checked 2026-10-26: [local StoreKit testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode), [current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [transaction updates](https://developer.apple.com/documentation/storekit/transaction/updates), [explicit synchronization](https://developer.apple.com/documentation/storekit/appstore/sync()), [App Review payments guidance](https://developer.apple.com/app-store/review/guidelines/#payments). Consult the pinned SDK's API documentation during implementation.
