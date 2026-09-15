# Quit Zyn 1.2.4 release-readiness audit

Date: 2026-09-14

Target: 1.2.4, build 32, commit `be23529`

Scope: source review of the 1.2.4 change surface, unit-test evidence, Debug and Release builds, headless simulator smoke testing, App Store Connect state, metadata, and user-facing privacy and health claims.

## Decision

**NOT RELEASE READY.** Hold build 32. It is buildable, the uploaded artifact is valid, and the main free flows are usable, but three P1 findings can strand a paid user, corrupt garden history, or make the current privacy promises inaccurate.

The first two findings require code and a new build. The privacy finding requires an explicit decision to remove the new data flow or update the privacy policy, site, App Store metadata, App Privacy answers, and any applicable privacy manifest entries.

## Release blockers

### P1-1: Deferred or not-yet-visible purchases exit onboarding

Evidence:

- `Shared/Services/SubscriptionService.swift:286-308` returns `.purchased` only when the returned CustomerInfo already contains the `pro` entitlement. Every non-cancelled result without that entitlement becomes `.pending`, which conflates a real deferred StoreKit purchase with a delayed entitlement refresh or mapping failure.
- `Sober/Features/Onboarding/OnboardingView.swift:604-610` calls `finishOnboarding()` for `.pending`.
- The direct trial sheet also closes on `.pending` at `Sober/Features/Onboarding/OnboardingView.swift:608-610`.
- The regular paywall handles the same state correctly by keeping the sheet open and showing an awaiting-approval message at `Sober/Features/Paywall/PaywallView.swift:526-533`.

Impact: Ask to Buy, parental approval, SCA, or a server-delayed entitlement can leave a new user in the free app after tapping the trial or purchase CTA, with no persistent pending state or clear next action. If the app is terminated before the delegate refresh arrives, the user can reasonably believe the purchase failed or that the trial started when it did not.

Required before release: distinguish true deferred state from missing entitlement state, keep onboarding and the trial offer in an explicit pending state, and provide a persistent retry or restore path. Exercise the deferred-purchase path in StoreKit testing or TestFlight before sign-off.

### P1-2: An older slip can corrupt the garden and undo state

Evidence:

- `Shared/Services/SlipRecorder.swift:62-92` correctly avoids restarting the counter a second time when a backdated slip is entered after a newer slip, but it still calls `GardenService.recordSlip` for the older event.
- `GardenService.recordSlip` overwrites `carryoverBeforeSlip` and applies the 50% rule to the current carryover at `Shared/Services/GardenService.swift:159-179`. The model stores no chronological slip event or per-slip garden state.
- The current undo implementation restores that single overwritten `carryoverBeforeSlip` value at `Shared/Services/GardenService.swift:182-202`.

Temporary isolated repro:

1. Start with a 111-day journey.
2. Record a slip 10 days ago. The carryover becomes 50, the current run is 10 days, and the longest run is 101 days.
3. Record an older slip 70 days ago. The counter and longest run stay unchanged, but carryover changes from 50 to 45.
4. Undo the newer slip. The current run reopens to 111 days, carryover restores to 50, and the tree renders at 161 days even though the older slip remains logged.

Impact: The calendar can retain both slips while the tree shows growth from a history that the counter no longer represents. Undoing the latest slip can also reopen a run across a remaining older slip. This directly contradicts the promise that slips preserve an honest, coherent record.

Required before release: make garden state chronological, rebuild it from slip history, or reject out-of-order garden mutations. Add regression coverage for older-after-newer slips and undo with remaining slips. The existing tests cover same-day idempotency and counter reset, but not this garden consistency path.

### P1-3: New RevenueCat funnel attributes contradict privacy disclosures

Evidence:

- `Shared/Services/ConversionDiagnostics.swift:182-227` builds behavioral attributes including pitch counts by surface, first-pitch date, days since install, opens before the first pitch, conversion surface, conversion date, plan, trial state, and offering.
- `Shared/Services/SubscriptionService.swift:244-268` sends those values to RevenueCat with `Purchases.shared.attribution.setAttributes`. The sync runs after paywall impressions and when the app backgrounds, including for free users who have seen a pitch.
- `docs/privacy-policy.html:93-116` says journey content is not uploaded and that there is no server-side usage analytics. The policy describes RevenueCat purchase and entitlement processing, but not these behavioral attributes.
- `fastlane/metadata/en-US/description.txt:26-29` says “No tracking. No servers.”
- `docs/index.html:579-580`, `613`, and `624` say no analytics, no network requests, and no third-party SDKs beyond StoreKit. The app embeds RevenueCat, and now sends funnel data off-device.
- `Sober/PrivacyInfo.xcprivacy:5-10` declares zero collected data types. App Store Connect App Privacy could not be verified because the read-only API request returned 404.

Impact: This is a material disclosure mismatch. It is not evidence that journal, check-in, or health content is being uploaded, and it is not by itself proof of prohibited tracking, but the current public promises do not describe the new off-device usage data flow.

Required before release: either remove the funnel attributes or update the privacy policy, web copy, App Store metadata, App Store Privacy answers, and any applicable privacy manifest declarations. Confirm the final RevenueCat data handling and retention language before submitting or releasing.

## High-priority follow-ups

### P2: Trial reminder state can say scheduled when no notification exists

`Shared/Services/TrialLifecycle.swift:89-120` sets `reminderScheduledKey` after `scheduleTrialEndingReminder` returns. `Shared/Services/NotificationService.swift:106-145` returns no success value, silently ignores `UNUserNotificationCenter.add` errors, and can return without scheduling for a very short trial. A later sync sees the flag and does not retry. `SubscriptionService.swift:339-342` also checks only trial period type, not whether the entitlement will renew, so a cancelled trial can still receive copy about a future renewal.

The normal product trial is seven days and the normal reminder date is valid, so this is not the default-path failure. It remains a real permission, notification-service, and cancellation edge case. Mark the flag only after confirmed scheduling, clear or retry when the request is absent, and align reminder eligibility with renewal state.

### P2: SwiftData recovery can look successful while history disappears

`Shared/Services/DataService.swift:20-48` moves an unopenable store aside, retries with a new persistent store, and finally falls back to an in-memory container. There is no user-visible warning, recovery action, or indication that the current session is not using the user's history. The old files are preserved, which is good, but a user can interact normally and lose the new session on relaunch or fail to understand that their history needs recovery.

Surface a clear recovery state, preserve an actionable path to the aside store, and avoid silently presenting an empty or non-persistent account as normal.

### P2: Slip undo is hard to find and the Home copy overpromises

The runtime slip flow and Home card do not expose Undo. The only visible correction path is selecting the slip day in Timeline, where `SlipRecorder.canUndo` exposes “Change to nicotine-free” at `Sober/Features/Calendar/TimelineView.swift:368-395`. The release notes promise that a mistaken slip can be undone. Home says “Your tree kept its growth” at `Sober/Features/Today/HomeView.swift:313-327`, while the product actually keeps half of the prior growth, as confirmed by the runtime smoke test.

Add a directly reachable undo action to the confirmation or Home state, and use precise copy such as “Your tree kept some growth” unless the exact carryover is shown.

### P2: Onboarding Restore can fail silently

`Sober/Features/Onboarding/OnboardingView.swift:625-636` awaits restore and finishes only if Pro becomes active, but never displays `subscriptions.lastError` or a “no purchase found” result. A returning customer can tap Restore, see no feedback, and remain on the same step without knowing whether the operation completed.

Show the same explicit error and no-purchase states already used by the regular paywall.

### P2: Craving timing insights count accidental one-second sessions

`Sober/Features/Craving/CravingModeView.swift:349-365` records every closed session, including an immediate unresolved close. `Shared/Services/CravingInsights.swift:47-52`, `74-93`, `105-127` excludes unresolved sessions from outcome rate but includes them in timing, weekday, trigger, and weekly counts.

An accidental open-and-close can therefore influence “hardest between” and related personal patterns. Either discard sessions below a minimum duration, exclude unresolved sessions from each relevant statistic, or explain the sample definition in the UI. This is lower risk because the feature has sample floors and does not claim a medical prediction.

### P2: Editing a faint assumed day implicitly marks it as checked in

Timeline initially says “Counted toward your journey. Not checked in yet.” at `Sober/Features/Calendar/TimelineView.swift:358-361`. Editing mood or note then sets `wasLogged = true` at `Sober/Features/Calendar/TimelineView.swift:426-468`, changing the day in the week strip, calendar shading, and `daysSinceLastCheckIn` without an explicit log action.

This may be intentional, but it is an ambiguous state transition. Make the save action explicit or update the copy so users understand that adding context also counts as a check-in.

### P2: Large Dynamic Type still needs an accessibility pass

The paywall disclosure at `Sober/Features/Paywall/PaywallView.swift:396-404` is capped at three lines and scaled to 80%. The trial billing note at `Sober/Features/Paywall/TrialOfferSheet.swift:210-216` is not inside an outer scroll view. The recent ScrollView change improves reachability, but the legal price and renewal text still needs verification at the largest accessibility sizes.

### P3: AppIcon asset warning

Debug and Release builds emit the known `actool` warning that `icon_256.png` is an unassigned child of the `AppIcon` set. `Contents.json` assigns `icon_1024.png`, so this did not block the build or invalidate the uploaded artifact. Remove or assign the stray asset in a future build.

### P3: Craving copy is pouch-specific across a broader nicotine product

`Shared/Utilities/HabitVocabulary.swift` uses “pouches” and “a pouch” for the craving and pattern surfaces, while the product positioning also mentions vaping, dip, cigarettes, and snus. Review whether that language is intentionally Zyn-first or should be generalized for users quitting other nicotine products.

## What passed

- Debug build succeeded for the iOS app, watch app, and widget extension on the leased headless iOS 26.5 simulator.
- Release configuration build succeeded for the same targets.
- The completed XCTest/Swift Testing result bundle reports 121 passed, 0 failed, 0 skipped. The `xcodebuild` wrapper did not exit cleanly because simulator diagnostics timed out after test execution, so the green result bundle is the test evidence, not the wrapper exit code. A follow-up `test-without-building` attempt was not used as evidence because the Debug-only derived data did not contain the test bundle.
- Headless runtime smoke test passed onboarding launch, setup, Home, craving mode, craving close-out, slip confirmation, and the post-slip Home state without a crash. The slip path correctly kept the tree and reset the honest counter.
- App Store Connect reports version 1.2.4 as `PENDING_DEVELOPER_RELEASE`; build 32 is attached, `VALID`, App Store eligible, and configured for iOS 17.0+.
- App Store Connect reports the monthly and yearly subscriptions and lifetime purchase as `APPROVED`. Both subscriptions are available in new territories and each has a one-week free trial configured across 175 territories.
- All 50 localizations have local metadata for name, subtitle, keywords, promotional text, description, and release notes. The checked field lengths are within App Store limits, including the 100-character Urdu keyword field.
- Current metadata scans found no stale alcohol or “sober” product wording. The Health screen includes a general-wellness disclaimer, and no current store metadata claims to treat, cure, or diagnose.
- Existing tests and static review cover the `wasLogged` migration, widget snapshot compatibility, same-day slip idempotency, backdated counter reset, and shared tree carryover paths. The out-of-order garden case remains untested and failing as described above.

## Not verified by this audit

- Real App Store purchase, Ask to Buy or deferred approval, restore, cancellation, renewal, and RevenueCat entitlement timing on TestFlight or a physical device.
- Notification permission changes and actual trial-ending delivery.
- Physical Apple Watch synchronization and widget refresh after an upgrade or slip.
- Largest Dynamic Type sizes and VoiceOver across onboarding, paywall, trial sheet, slip confirmation, and Timeline.
- App Store Connect App Privacy answers, because the read-only endpoint returned 404. The current privacy manifest and public disclosures need an explicit owner review.

No app source, project configuration, App Store Connect state, RevenueCat state, metadata, or TestFlight state was changed during this audit. Only this audit document is task-owned. Pre-existing changes in `scripts/.astro-app.json` and the separate `caudit914.md` file were preserved.
