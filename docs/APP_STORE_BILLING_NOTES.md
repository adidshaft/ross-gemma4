# App Store Billing Notes

This repository includes entitlement infrastructure and billing stubs only. Final billing implementation must be validated against current platform rules at release time.

## iOS

- Digital feature unlocks may require in-app purchase depending on the final sales flow.
- Web-based entitlements may be more appropriate for firm procurement or multiplatform admin scenarios, but product and legal review must confirm compliance.
- Do not assume that all externally purchased digital subscriptions can be surfaced in-app without App Store review.

## Android

- Billing pathways vary by geography, policy state, and distribution model.
- User choice or alternative billing may be available only in certain contexts and should not be assumed universally.
- Production rollout should document the exact channel and user journey for entitlement activation.

## Shared guidance

- Keep billing state distinct from case data
- Do not mix payment requests with case uploads
- Treat entitlement checks as `account_token` payload class only
- Keep billing integrations swappable behind backend stubs

