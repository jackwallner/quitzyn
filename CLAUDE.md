# Nicotine Free — Claude Project Guide

App Store name: **Sober Tracker - Nicotine Free**. A fork of the alcohol "Sober Tracker" app, re-targeted at quitting nicotine (Zyn / nicotine pouches, snus, vaping, dip, cigarettes). iOS + watchOS. Day counter, calendar, virtual garden that grows with nicotine-free days, nicotine-recovery timeline, journal, achievements, money/pouches/nicotine avoided. Freemium with RevenueCat (Pro entitlement).

Note: internal target/type names are still `Sober*` (low-churn fork). The outward identity (bundle IDs, App Group, display name, content) is nicotine.

XcodeGen project/scheme: `Sober`, simulator device `agent-sober`.

## Tech stack
- Swift 6 strict concurrency, SwiftUI, SwiftData (App Group store).
- iOS 17, watchOS 10. XcodeGen (`project.yml`). RevenueCat 5.14+ via SPM. WidgetKit.

## Targets (project.yml)
- `Sober` (iOS app) — bundle `com.jackwallner.quitzyn`
- `SoberWatch` (watchOS app) — `com.jackwallner.quitzyn.watch`
- `SoberWidgets` (iOS widget extension) — `com.jackwallner.quitzyn.widgets`
- `SoberTests` (unit tests)

All share App Group `group.com.jackwallner.quitzyn` for SwiftData container + widget snapshots.

## Architecture
- `Shared/Models/` — SwiftData `@Model` types: SobrietyJourney, DailyCheckIn, JournalEntry, GardenState, UserSettings, UnlockedAchievement, UnlockedHealthBenefit.
- `Shared/Services/` — DataService (container), SobrietyService, CheckInService, SettingsService, GardenService, NotificationService, SubscriptionService (RevenueCat wrapper), WidgetSnapshotPump.
- `Shared/Catalogs/` — static content: HealthBenefitCatalog (13 nicotine-recovery milestones, ACS/NCI/AHA/Truth Initiative sources), AchievementCatalog, JournalPromptCatalog, GardenSpeciesCatalog.
- `Shared/Utilities/` — Theme, DateHelpers, AppGroup, WidgetSnapshot.
- `Sober/Features/` — feature folders (Onboarding, Today, Calendar, Health, Journal, Achievements, Stats, Settings, Paywall, Components).

Root flow: `SoberApp → RootView → (OnboardingView | MainTabView)`.

## Pro entitlement (`"pro"`)
- Free: day counter, single check-in/day, calendar, basic garden, first 2 health benefits.
- Pro: full health timeline + sources, journal compose, achievement unlocks, money/calories saved, additional garden species.

## App-specific notes
- Enjoyment funnel triggers after **daily check-in** or **garden unlock celebration** (3.5s delay). (Shared funnel mechanics + playbook in the `ios-dev` skill.)
- `Sober.storekit` tests the paywall in the simulator without RevenueCat dashboard config.
- SwiftData migrations: any change to a `@Model`'s stored properties needs a schema migration (lightweight is fine for now; wipe-and-retry on corruption).
- Widget snapshots are decoupled from SwiftData via `WidgetSnapshotStore` so the widget doesn't need a SwiftData schema.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, RevenueCat dev tips, review funnel, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill.
