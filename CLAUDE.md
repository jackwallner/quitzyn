# Nicotine Free — Claude Project Guide

App Store name: **Sober Tracker - Nicotine Free**. A fork of the alcohol "Sober Tracker" app, re-targeted at quitting nicotine (Zyn / nicotine pouches, snus, vaping, dip, cigarettes). iOS + watchOS. Day counter, calendar, virtual garden that grows with nicotine-free days, nicotine-recovery timeline, journal, achievements, money/pouches/nicotine avoided. Freemium with RevenueCat (Pro entitlement).

Note: internal target/type names are still `Sober*` (low-churn fork). The outward identity (bundle IDs, App Group, display name, content) is nicotine.

XcodeGen project/scheme: `Sober`, sim lease owner `nicfree`.

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

## Craving mode + slips (ported from Sober 2026-09-08)
The two features aimed at the moments the app used to have nothing to say to.
Both cores are in `Shared/`, both are **free and ungated**, and every
habit-specific word in them lives in `Shared/Utilities/HabitVocabulary.swift`.
**That file is the fork point**: it is the only file that differs from Sober's
copy of these features, so keep edits there rather than in feature code. Never
write "nicotine" or "pouch" in craving/slip/patterns code, add a term instead.
- **Craving mode** (`Sober/Features/Craving/CravingModeView.swift`): full-screen
  box-breathing ride-it-out session, logged as `CravingEpisode`. No paywall
  anywhere in the flow. Intensity and trigger are captured on the way *out*, and
  both are optional (a skipped rating stores 0 rather than inventing a 3). The
  default session is 120s here against Sober's 180: nicotine urges run shorter.
  Copy arc lives in `Shared/Catalogs/CravingCoachCatalog.swift`.
- **Slips don't erase the garden.** The old "Start fresh" alert, which reset the
  journey and the tree, is gone. `GardenService.recordSlip` banks half the
  tree's growth into `GardenState.carryoverDays`; the tree renders at
  `GardenService.treeDays(streakDays:carryover:)` while the counter keeps showing
  the honest streak. Everything that logs a slip goes through `SlipRecorder`, and
  `SlipRecorder.undo` reverses a mis-tapped one in full (row, counter, journey,
  garden) while it is still the most recent slip on record.
- **`DailyCheckIn.wasLogged`** separates a day the user tapped from one
  `fillJourney` filled in. Home's week strip (`TendedWeek` + `WeekStripView`) and
  Timeline's calendar shading both key off it, and so does
  `daysSinceLastCheckIn`. It defaults to false for a lightweight migration, so
  `CheckInService.migrateLegacyCheckInsIfNeeded` (called from `SoberApp.init`,
  before any `fillJourney`) promotes pre-port rows.
- **`BloomFeature.patterns` leads the paywall.** `CravingInsights` reads the
  user's own logged urges back to them; every reading has a sample floor and
  returns nil below it rather than inventing a claim. Riding out an urge routes
  to the `.patterns` pitch via the `.cravingRelief` intent.
- **Headless verification:** `-craving` and `-slip` launch arguments (DEBUG only)
  open those screens directly. `axe describe-ui` / `axe tap` DO work on the pool
  (verified 2026-09-08 on agent-sim-1), so the full flows can also be walked.

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

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
