# iOS 27 compatibility audit: Quit Zyn

- Audit date: 2026-08-05
- Runtime: iOS 27.0 (24A5390f)
- Xcode: 26.6 (17F113)
- Scheme: `Sober`
- Unit target: `SoberTests`
- Overall: Pass with asset and RevenueCat update candidates

## Checks

- Debug build: Pass.
- Unit tests: Pass.
- Normal rebuild after tests: Pass.
- Install and launch smoke test: Pass.
- Runtime UI snapshot: Pass. Get Started and Restore controls rendered.

## Findings

- `Sober/Assets.xcassets` reports an unassigned `icon_256.png` AppIcon child.
- `Shared/Services/SubscriptionService.swift:236` uses deprecated RevenueCat `init(paywallId:offeringId:)`.
- No iOS 27-specific compiler error or runtime blocker was observed.

## Recommended follow-up

- Assign or remove the unreferenced AppIcon child and migrate the deprecated RevenueCat initializer.
