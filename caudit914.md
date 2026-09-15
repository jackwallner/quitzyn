# Quit Zyn 1.2.4 release-readiness audit (2026-09-14)

Scope: everything shipped between live 1.2.3 (commit `5153bb3`, build 25) and HEAD `be23529` (1.2.4 build 32). Read-only: no app code, metadata, ASC or RevenueCat state was changed. Repro tests and old/new builds ran from copies in the session scratchpad, not the repo.

## Verdict

**OK to release, with one fix that doesn't need a new build.** 1.2.4 has no crash, data-loss or upgrade regression that I could find. The upgrade from 1.2.3 was tested end to end on disk. The confirmed bugs are in rare slip-editing paths, and the 1.2.3 code handled those same paths worse (it wiped the tree and moved the counter forward). The one item to act on before or at release is privacy disclosure: 1.2.4 starts sending usage-funnel attributes to RevenueCat, and the privacy policy says it doesn't.

## Current release state (verified via ASC API)

| Item | Value |
| --- | --- |
| 1.2.4 version state | `PENDING_DEVELOPER_RELEASE` (approved, waiting for you to release it) |
| Attached build | 32, uploaded 2026-09-11, VALID. Matches HEAD (last commit is the 31 -> 32 bump) |
| Live | 1.2.3 `READY_FOR_SALE` |
| `scripts/.asc-state.json` | Stale (`draftVersion 1.2.3`, `liveVersion 1.0`). Tooling only, no user impact |

Because the version is approved and locked, any code fix means a new build and a new review. The privacy-policy fix (P1-A) is a website change and needs neither.

## Verification performed

| Check | Result |
| --- | --- |
| Full build (iOS app + watch app + widget extension, Debug, iOS 26.5 sim) | Succeeded |
| `SoberTests` unit suite | **121 tests in 28 suites passed** (first attempt failed with a simulator bootstrap timeout, not a test failure; retry with `test-without-building` passed) |
| **Upgrade 1.2.3 -> 1.2.4 on a real on-disk store** | Passed. Built 1.2.3 from `5153bb3`, seeded 40 days (41 check-ins, 1 journey), installed HEAD over it. Store opened in place with no `.unopenable-*` file, all 41 rows migrated to `wasLogged = 1`, `ZCRAVINGEPISODE` table created, `carryoverDays = 0`. Home showed 41 days, "Today is logged", 7/7 tended, craving button present |
| Slip sheet on the upgraded store (`-slip`) | Renders correctly ("Your tree keeps 20 days of growth" for a 41-day streak) |
| Targeted repro tests for slip edge cases (scratch copy only) | 2 of 3 scenarios reproduce bugs (below) |

Not verified (can't be done from here): a physical-device TestFlight install over the App Store 1.2.3, Apple Watch hardware sync, the ASC App Privacy "nutrition label", the RevenueCat dashboard, or a real sandbox trial purchase to see the trial-reminder permission prompt.

---

## P1: fix or decide before, or right after, release

### P1-A. Privacy disclosures contradict new off-device usage analytics (compliance and trust)

- **What changed:** `SubscriptionService.syncConversionAttributes()` (new in 1.2.4) sends RevenueCat subscriber attributes for **every user**, free users included, whenever a paywall impression is tracked and each time the app goes to the background (`Sober/App.swift` scenePhase `.background`). The data covers:
  - onboarding step counters (`funnel_onboardingReached`, `funnel_trialCTATapped`, `funnel_freeVersionChosen`, and so on)
  - app open count, paywall views per screen, and first-pitch date
  - `days_since_install` and conversion details

  Sources: `Shared/Services/ConversionDiagnostics.swift`, `Shared/Services/SubscriptionService.swift:244-268`.
- **What the disclosures say:**
  - `privacy-policy.html:114` (and `docs/privacy-policy.html`): "No account, **server-side usage analytics**, advertising, cross-app tracking..."
  - The same policy's RevenueCat paragraph lists only an anonymous ID, purchase/entitlement info and "limited technical context".
  - `fastlane/metadata/en-US/description.txt:27-28`: "All your data stays on your device." / "No tracking. **No servers.**"
  - `Sober/PrivacyInfo.xcprivacy`: `NSPrivacyCollectedDataTypes` is empty.
- **Risk:** The public policy is inaccurate from the day 1.2.4 ships. The ASC App Privacy answers may also be out of date (Usage Data > Product Interaction, linked to an anonymous RevenueCat user ID). None of this is health data or free text, so severity is moderate. It is still the kind of mismatch that draws a 5.1.1 / 2.3.1 complaint.
- **Fix without a build:** Update the privacy policy to name the RevenueCat funnel attributes. Review the ASC App Privacy answers. Soften "No servers" in the description and promo text on the next editable version (the description is locked while the version sits in Pending Developer Release).
- **Alternative:** Leave the disclosures alone and remove or gate the attribute sync in 1.2.5.

### P1-B. Back-filling an older slip after a newer one rewrites the garden (confirmed by repro)

- **Where:** `Shared/Services/SlipRecorder.swift:567-578`. The `alreadyRestarted` check correctly skips the journey reset for an out-of-order slip. But `garden.recordSlip(previousStreakDays:)` still runs **unconditionally**, and it:
  - recomputes `carryoverDays` from the older slip's streak plus the *current* carryover
  - overwrites `carryoverBeforeSlip`
  - takes 0.3 off vitality
  - resets `lastUnlockNotifiedAtDays` to 0, so stage celebrations replay
- **How a user hits it:** Timeline, select a day inside an earlier run (the calendar allows any day after the first journey's start), then "Log a slip" or "Change to slip".
- **Repro (scratch test `r1`):**
  1. 111-day run, slip 10 days ago: carryover 50, counter 10.
  2. Back-fill a slip 70 days ago: carryover **drops to 45**. The counter stays at 10 (correct), but the longest streak stays at 101 even though a slip now sits inside that run.
  3. Undo the most recent slip: counter 111, carryover restored to **50** (it should be 0, which was its value before the real slip). The tree renders at **161 days** against a 111-day streak.
- **Impact:** The tree silently shrinks or grows, celebrations replay, and undo inflates the tree. Rare flow, no data loss.
- **Regression vs 1.2.3?** No. In 1.2.3 the same action moved the counter forward and wiped the tree entirely.
- **Existing coverage gap:** `SlipCorrectionRegressionTests.anOutOfOrderSlipDoesNotRewindTheCounter` asserts only the counter, never the garden.

### P1-C. Slip today, then back-date a slip to yesterday: extra journey and a bigger tree (confirmed by repro)

- **Where:** Same function. A slip logged *today* opens a new journey at `.now` (start clamps to now), not tomorrow. So when a later slip is back-dated to yesterday, `alreadyRestarted` (`activeStart >= dayAfter`, where `dayAfter` is tomorrow) is false.
- **How a user hits it:** Home, "I slipped", log for today. Then Timeline, select yesterday, "Log a slip" (for example, realizing the slip was actually last night).
- **Repro (scratch test `r2`):** 41-day run, slip today: carryover 20, 2 journeys. Slip yesterday: carryover **30** (the tree *grows* from a second slip), **3 journeys**, one of them zero-length (start == end == now). `canUndo(yesterday)` is false. `canUndo(today)` is true, but the matching closed run is now the zero-length stub, so the undo would reopen the stub rather than the 41-day run.
- **Impact:** Confusing tree growth after a slip, a junk journey row, and an undo that can't restore the real run. Rare flow.
- **Regression vs 1.2.3?** Not directly. 1.2.3 would also have added an extra journey and wiped the tree.
- **Fix direction for 1.2.5:** Only call `garden.recordSlip` inside `if !alreadyRestarted`. Compare `alreadyRestarted` on the start *day* (`activeStart >= startOfDay(restartFrom)`) rather than on `dayAfter`. Add garden assertions to the out-of-order tests.

---

## P2: poor experiences worth scheduling for 1.2.5

1. **Undo is hard to find.** The only undo is in Timeline, on the slip day. The slip confirmation ("Logged. You're still on the journey.") and Home's "Today is logged as a slip" card offer none, yet the What's New says "a mistaken slip can be undone". A user who mis-taps "Log it and keep going" has no visible way back. Suggest an "Undo" on the confirmation screen and on the Home slip card while `SlipRecorder.canUndo` is true.
2. **Home slip card overstates what the tree kept.** `HomeView.swift` "Today is logged as a slip" says "Your tree kept its growth", but the tree keeps half, and 0 on a day-1 slip. Use the real carryover or neutral copy.
3. **An accidental tap on "I'm having a craving" logs a craving.** Closing with X in the first second still writes an `unresolved` `CravingEpisode` (`CravingModeView.finish`). Those rows feed the Patterns hour chart, peak window, heaviest weekday and weekly change, which count every session. Suggest not recording sessions under roughly 5 to 10 seconds, or excluding them from timing insights.
4. **Trial reminder ignores cancellation.** `TrialLifecycle.sync` keys only on `periodType == .trial`, so a user who already turned off auto-renew still gets "Your Bloom+ trial ends soon ... cancel any time before it renews" two days out. Check `entitlement.willRenew`.
5. **Notification prompt without context for upgrading users mid-trial.** On the first 1.2.4 launch, `apply(customerInfo:)` calls `TrialLifecycle.sync` for an unseen trial, which calls `ensureAuthorized()`. For anyone whose permission is still `.notDetermined`, the system prompt appears at launch with no explanation. Small population, since onboarding already asks.
6. **Timeline edits promote days silently.** Typing a note or tapping a mood on an assumed (faint) day sets `wasLogged = true`, which flips the day to "Logged nicotine-free" and changes the week-strip dot. Probably intended, but it is an implicit check-in.
7. **Pending purchase in onboarding still counts as done** (carried over from audit823, not a regression). `OnboardingView` `.pending` records `purchasePending` and then calls `finishOnboarding()` with no "awaiting approval" message. `MainTabView`'s trial sheet does the same.

## P3: minor, cosmetic, or hygiene

- `TrialLifecycle` recap banner (`shouldShowRecap`, `dismissRecap`, the `recapSummary` setter) is never called, so the reminder always uses the generic body. Dead code.
- Copy is pouch-specific for all nicotine users: "ended without a pouch" (`CravingInsights`) and "planning my day around a can" (`HabitVocabulary`). The listing also targets vaping, dip and cigarettes.
- Reset-counter alert says "restart at zero", but the counter is 1-based ("Day 1"). Pre-existing.
- "I slipped" (safe) sits directly above "Reset counter" (destructive: wipes carryover and placed garden items) in the Home menu. The confirm alert mitigates this.
- `PaywallView.task` records `trialOfferReached` on every Bloom tab appearance, which inflates that funnel counter relative to onboarding.
- `RevenueCatProbe.testStoreKey` (a `test_` key) is committed, DEBUG-only. Low risk, noted for hygiene.
- `store recovery`: an unopenable store is now moved aside instead of deleted (good), but the fallback is still a silent in-memory session with no user-visible state (carried over from audit823).

## Reviewed and found sound

- `wasLogged` migration: runs in `SoberApp.init` before any `fillJourney`, and the marker is written only after the save succeeds. Verified on a real upgraded store.
- `WidgetSnapshot` custom decoder: an old payload without `carryoverDays` still decodes (unit test), so the widget won't flash 0 days after the update.
- Widget, watch, Home, Timeline and species picker all draw the tree at `treeDays`, while the counter keeps the honest streak.
- Watch refreshes `now` and the snapshot on scenePhase `.active`, and iOS re-sends the snapshot on WCSession activation and watch-state change.
- Timeline calendar grid fix (a single ForEach over cells) removes the dropped first days of a month.
- Back-dated slip closes the old run on the slip day, so the longest streak is no longer inflated (tests).
- Re-submitting a slip for the same day no longer halves the tree again (tests).
- Paywall now scrolls at large Dynamic Type sizes, so the CTA, disclosure and Restore/Terms/Privacy stay reachable (3.1.2).
- Trial copy no longer hard-codes 7 days, and the reminder day matches `trialReminderLeadDays` (test).
- The daily-reminder authorization guard, plus re-arming when permission comes back in Settings.
- Craving mode has no paywall in the flow, and "I gave in" hands off to the cancellable slip sheet only after the cover dismisses.
- Post-onboarding paywall flag is spent only when the pitch can actually show.
- No medical treat/cure/diagnose claims in the new craving, patterns or coach copy.

## Recommended path

1. Now: update `privacy-policy.html` and `docs/privacy-policy.html` for the RevenueCat funnel attributes, and check the ASC App Privacy answers (P1-A).
2. Release 1.2.4 (build 32).
3. 1.2.5: the P1-B/C `SlipRecorder` fix with garden assertions in the out-of-order tests, undo on the slip confirmation, the Home slip-card copy, the short-session craving filter, and the cancelled-trial reminder check.
