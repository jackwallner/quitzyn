# State machine audit, 2026-11-06

Scope: iOS app, `Shared/`, widget and watch targets. Android out of scope. There is no backend function in this repo: Pro entitlement is read client-side from RevenueCat (`SubscriptionService.apply`), so no server code was read. Audited the committed tree on branch `fleet/20261106-114248-fdaf-claude` (working tree was clean; `git stash -u` had nothing to stash). Nothing was fixed and no app code changed.

**Summary: 6 bugs. 4 proved by test (SM-1, SM-2, SM-3, SM-4), 2 code path only (SM-5, SM-7). 10 product calls and 3 latent hazards are listed and not counted.**

Test run: `gh-sim test --scheme Sober --only SoberTests/StateMachineAuditRepro`, Xcode 27.1, iPhone 17, iOS 27.2 simulator. Run A (default region, an earlier revision of the suite): 8 tests, 5 passed, 3 failed. Run B (`-testRegion DE`): 9 tests, 4 passed (three controls and the region precondition), 5 failed, locale en_DE. The suite is `state-machines-2026-11-06-repro.swift` next to this file (copy it into `SoberTests/` to rerun). Every failing test has controls that pass (`control_*`) and asserts its own preconditions first.

## Bugs, ranked by users reached times cost

| Id | Bug | What the user sees | Promise | Route | Impact | Evidence | Where |
|---|---|---|---|---|---|---|---|
| SM-4 | Cost is entered and shown in the device currency, but the Pro money screens format it with a stored `currencyCode` that is always "USD" | A German Pro user who typed 6 EUR per can reads their savings with a dollar sign | Settings footer "Used to estimate the money, pouches, and nicotine you avoid" (SettingsView.swift:124); Settings shows the same cost in the device currency (SettingsView.swift:107) | Onboarding step 2 cost stepper > ... > Pro > Home > Progress (chart icon) > Saved > Money; or Bloom+ tab hub | Every Pro user whose device currency is not USD, on every view of both screens. The app ships 15 non-English localizations, so most of its markets | Test, failed in run B (locale en_DE): `settings.currencyCode → "USD"`, `local → "EUR"`; passes in run A (en_US), which is the control | UserSettings.swift:24, OnboardingView.swift:306,872, HomeView.swift:886,918, BloomPlusTabView.swift:44,166 |
| SM-5 | Granting notification permission later does not re-arm the reminder | Reminder toggle on, banner gone, no reminder next morning | Code comment at SettingsView.swift:199-201: "granting it in the Settings app has to re-arm the reminder" | Deny at onboarding alert > Home > More > Settings > Daily Reminder > "Allow notifications in Settings" > enable in iOS Settings > return, no relaunch | Users who decline, then allow through the in-app banner in the same process and day. Costs one missed morning reminder, then self-heals on the next new-day open | Code path | NotificationService.swift:165-167 vs SettingsView.swift:195-203 |
| SM-1 | A slip dated inside a run the Reset button (or the retired "Start fresh") ended does not split that run | Timeline "Longest" keeps counting through the slip day | Log-a-slip alert: "Your longest streak reflects the corrected dates" (TimelineView.swift:113) | Home > More > Reset counter > Reset. Later Timeline > tap a day inside the old run > Check-in > Log a slip > Log slip > read Longest | Users who ever reset the counter and later back-log a slip into that period. Rare. Cost: best streak overstated for good; the same call also re-runs the 50% garden rule on the current tree (code read, not asserted) | Test, failed: `longestStreakDays() → 31`, expected 16 | SlipRecorder.swift:63-103 |
| SM-7 | Unfolded Duo: Timeline pane keeps a stale draft after Home changes the same day | Pane says "Logged" but mood and note fields are blank; typing a note overwrites the one saved on Home | Comment "A logged day reloads (Home may have changed it)" (TimelineView.swift:97) | Unfolded iPhone Duo > Home > Check in for today > mood + note > Save > look at the Timeline pane (today selected) > type in Note | Unfolded foldable only, no known users | Code path | TimelineView.swift:96-104, 193-199, 576-592 |
| SM-2 | Undo stays offered after the counter was reset and then reopens the wrong run | Home keeps "Today is logged as a slip" with Undo; Undo leaves the counter at the reset value, not the pre-slip run | "Puts your counter and your tree back the way they were before this slip" (TimelineView.swift:507); `reversibleSplit`: only the slip "the live counter is sitting on" (SobrietyService.swift:141) | Home > More > I slipped > Today > Log it > Done > More > Reset counter > Reset > Undo on the slip card | Someone who resets right after slipping. Rare. Cost: Undo promises more than it does | Test, failed: `canUndo → true`; `undoAfterTheResetPutsTheCounterBackLikeThePromise` failed: counter after Undo `→ 1`, expected 41 | SobrietyService.swift:150-167, HomeView.swift:363-367 |
| SM-3 | Slip then Undo past 365 days adds a second grove tree | Grove shows 2 trees for one year of growth, permanently | "a permanent record of milestones actually reached" (GardenState.swift:15) | Counter at 401 > More > I slipped > Today > Log it > Undo, then any Home refresh | Streaks over a year (tiny) who mis-tap. Cost: false permanent trophy | Test, failed: `completedTreeStyles.count → 2`, expected 1 | GardenService.swift:196,212-224,245 |

### Details

**SM-4.** `UserSettings.currencyCode` defaults to "USD" (UserSettings.swift:24) and nothing assigns it: `grep currencyCode` over `Sober/` and `Shared/` finds only reads. Onboarding formats the per-can price with `Locale.current` (OnboardingView.swift:306-316) and stores `costPerDayCents` (872-874). Settings formats cost per day with `Locale.current.currency` (SettingsView.swift:107). The Progress sheet and Bloom+ hub format the same cents with `settings?.currencyCode ?? Locale.current...`; the fallback never runs because the settings row always exists (HomeView.swift:886, 918-923; BloomPlusTabView.swift:44, 166). So the number the user typed in their currency is shown with a dollar sign next to a Settings row that shows their own currency. The test runs the creation call onboarding makes (`SettingsService.current()`, OnboardingView.swift:872) and compares the stored code with the device currency; the string formatting itself lives in private view code and was read, not executed.

**SM-5.** `refreshDailyReminder` stores `lastReminderPlan` before the scheduling Task runs and the plan string has no permission term (NotificationService.swift:165-167). `scheduleDailyReminder` returns at `guard await isAuthorized()` (line 75) when permission is missing, having queued nothing. When permission arrives, `refreshNotificationStatus` calls `rescheduleReminder()` (SettingsView.swift:202) and Home's `scenePhase` refresh calls it again (HomeView.swift:127-129); both reach the same function with an identical plan and return at line 166. The queue is re-armed only when the plan changes (a check-in, a slip, a new day with Home on screen, any setting edit) or the process restarts. Scheduler call sites, complete list: OnboardingView.swift:914, NotificationService.swift:169 (via `refreshDailyReminder`), reached from HomeView.swift:512, SettingsView.swift:276 and 292, TimelineView.swift:538, 613, 626, 633. What would settle it: a UI test that denies at the alert, allows through a springboard stub, foregrounds, and reads `getPendingNotificationRequests`; or a protocol seam over `UNUserNotificationCenter` in `NotificationService` (none exists, so a fake cannot be added from the test target without touching app code). Not run here for that reason.

**SM-1.** Test `slipInsideAResetEndedRunSplitsTheLongestStreak`. Preconditions asserted first: no slip on record, the day is inside the closed run, the active run does not cover it, `dayCount(asOf:) == 16`, `longestStreakDays() == 31`. After `SlipRecorder.record(on: 25 days ago)` the slip row exists and `longestStreakDays()` is still 31 (expected 16). Control `control_slipInsideRunEndedByALaterSlipSplitsTheLongestStreak` passes: the same date with a later slip on record goes 31 to 16. Cause: the split branch needs `laterSlipOnRecord` (SlipRecorder.swift:63,74), which is false when the run was ended by `SobrietyService.reset()` (no slip row), and `alreadyRestarted` then skips the journey change (92-95) while `garden.recordSlip` still runs (103).

**SM-7.** `TimelineView.onAppear` calls `loadDraft` (line 96-104) and `.onChange(of: selectedDate)` does too (104); nothing reloads when the selected day's row changes. Tabs remount on selection so folded phones are fine; the unfolded pane (`TimelineView(selection:)` at App.swift:444) is mounted once. The note field writes `ci.note = new` from a draft that started empty (TimelineView.swift:583-587). What would settle it: a UI test on the Duo device that saves a note in Home's sheet and reads the pane's Note field.

**SM-2.** Test `undoIsNotOfferedAfterTheCounterWasReset`. Preconditions: today's row is a logged slip, `canUndo` is true before the reset, after `reset()` plus `resetForNewJourney()` (what HomeView.swift:105-106 runs) the active run is a different run and carryover is 0. Then `canUndo → true`. `reversibleSplit` only checks that the active run starts within a day of the slip and that some other run ended that day (SobrietyService.swift:154-165); the slip's own run, closed by the reset the same instant, matches and wins `max(by: startDate)`. The follow-up test taps the Undo that is still shown: precondition the counter is 1 and today is a logged slip, `undo` returns true, then `currentDayCount() → 1` while the slip row is flipped to nicotine-free and the 41-day run stays closed. An earlier assertion that Undo would also bring back the wiped tree was wrong and is removed: `carryoverBeforeSlip` is 0 for a first slip.

**SM-3.** `recordSlip` sets `groveCountAtJourneyStart = completedTreeStyles.count` (GardenService.swift:196); `undoSlip` restores carryover, watermark and vitality but not that baseline (212-224). After undo the reopened run is 401 days old, `processCycleCompletions` expects `baseline (1) + completed cycles (1) = 2` and appends (245-253). Test `undoingASlipAfterATreeCompletedDoesNotAddAnotherTree`: precondition grove count is 1 and the counter is back to 401; then count is 2. Control below one year adds nothing.

## Product calls (no citation that the code contradicts; not counted)

- P1 Reminder toggle on while iOS permission is `notDetermined` (app killed during the onboarding alert): nothing queued, no prompt, no banner (Settings only warns for `.denied`). SettingsView.swift:88.
- P2 "Reset counter" alert says the counter restarts "at zero" but Home then reads Day 1, and the alert does not say the tree's carried growth is wiped and cannot be undone (HomeView.swift:111; GardenService.swift:292).
- P3 Editing the start date can overlap a closed run and a logged slip day; no undo (SettingsView.swift:261).
- P4 A lapsed Pro keeps drawing the premium species they had selected; only switching is gated (GardenService.swift:308).
- P5 A start date edited far back appends grove trees that stay after the date is corrected (GardenService.swift:243).
- P6 After travelling west, a logged row from the east can sit in the future and read as logged when its date arrives (CheckInService.swift:225-266).
- P7 The free first journal entry can be deleted and rewritten indefinitely (JournalView.swift:13).
- P8 After Reset, the welcome-back card still asks "Still going strong?" and its backfill promotes the old run's assumed days (HomeView.swift:305; CheckInService.swift:138).
- P9 Dead code: `startComplimentaryTrial`, `TrialLifecycle.shouldShowRecap/dismissRecap/daysRemaining`, `recapSummary` setter, `purchaseInFlight` reads. The type comment describes an in-app recap that does not exist.
- P10 "Still nicotine-free" after a gap marks the whole span tended, which can unlock streak achievements in one tap (CheckInService.swift:138-169).

## Latent hazards (no tap route found; not counted)

- H1 `TrialLifecycle.clear()` while the scheduling Task awaits the permission alert: the Task then adds the reminder and writes `reminderScheduled = true` for an untracked trial (TrialLifecycle.swift:109-126, 131-137). Testable with the existing fake scheduler once a route exists.
- H2 A cold launch from the trial-ending notification posts `soberOpenBloomPlus` from `didReceive` (App.swift:153) with no stored destination; if `MainTabView` has not subscribed yet the tap lands on Home.
- H3 Two reminder passes with different plans run as separate unawaited Tasks whose `add` calls interleave by identifier (NotificationService.swift:168-172, 79-96).

## Related fixes, in order

1. Currency (SM-4): write `currencyCode` from the device currency when onboarding stores the cost, and repair existing rows still at the default.
2. Reminder (SM-5, P1, H3): include authorization status in the plan key, or clear the memo when `refreshNotificationStatus` sees a change; ask once when status is `notDetermined`; serialize scheduling passes.
3. Slip history (SM-1, SM-2, SM-3): treat any day strictly inside a closed run as a history correction (split, leave the garden alone); make `reversibleSplit` require the run that the slip closed to end on a `resetReason == "slip"` boundary and the active run to be the one the slip opened; store the grove baseline before a slip and restore it in `undoSlip`.
4. Timeline pane (SM-7): reload the draft when the selected day's row changes.

## State machines

Invariants are numbered per machine. A transition row names the invariant it breaks only where the code can reach the break (bug ids refer to the table above). Everything else is a documented or benign transition.

### M1 Onboarding (`OnboardingView`, `UserSettings.hasCompletedOnboarding`)

States: `step` 0 welcome, 1 start date, 2 usage and cost, 3 offer (trial or paid), 4 reminder hour, 5 pledge; persisted facts: journey row exists, `UserSettings` row exists, `hasCompletedOnboarding`, `postOnboardingPaywallPending` default.

Invariants
- O1 At most one active journey; a re-entered setup moves its start, never opens a second one (`persistSetup`, OnboardingView.swift:872).
- O2 `hasCompletedOnboarding` flips once; the reminder is armed and permission asked only after it flips (OnboardingView.swift:901-925).
- O3 The day-0 paywall flag is set only when the offer step never ran (OnboardingView.swift:921).
- O4 The cost stored with `currencyCode` is the cost the user typed, in the currency they typed it in.

| From | Event | To | Notes |
|---|---|---|---|
| 0-2 | Continue | next | Nothing persisted until step 2 continues. |
| 2 | Continue (`resolveTrialAndContinue`) | 3, or 4 when already Pro or no plan | `persistSetup` runs here: journey + settings + garden rows now exist while `hasCompletedOnboarding` is still false. |
| 2/3 | force quit | relaunch at step 0 | Journey exists; `persistSetup` takes the `updateStartDate` branch with the default `.now` in `@State`, so the date chosen before the quit is overwritten by whatever the user re-enters (benign, O1 holds). |
| 3 | purchase `.purchased` / `.cancelled` / `.pending` / throw | 4 / 3 / 3 + message / 3 + message | Pending keeps the user on the step; the `isProSubscriber` observer is what moves on. |
| 3 | skip | 4 | |
| 5 | commit or "Not now" | main app | `requestAuthorization` then `scheduleDailyReminder` in a detached `Task` (OnboardingView.swift:911). If the app dies while the system alert is up, permission stays `notDetermined` and nothing re-asks (product call P1). |
| any | cost typed in locale currency | stored with `currencyCode = "USD"` | Breaks O4 (SM-4). |

### M2 Entitlement gate (`SubscriptionService.isProSubscriber`)

State: `entitlementActive` (RevenueCat), `localOverride` (DEBUG only), `isTrialActive` (complimentary trial keys, no caller ever sets them: `startComplimentaryTrial` is dead), `isConfigured`, `packages`, `introEligibility(+Resolved)`, `lastError`, `purchaseInFlight` (written, never read).

Invariants
- E1 `isProSubscriber` is true exactly when RevenueCat reports an active entitlement (named or any), or DEBUG override.
- E2 No claim of a free trial is shown before eligibility is resolved (Apple 3.1.2).
- E3 `entitlementActive` follows every `CustomerInfo` that arrives (purchase result, refresh, delegate).
- E4 Every `apply` also drives `TrialLifecycle.sync`.

| From | Event | To | Notes |
|---|---|---|---|
| inactive | purchase `.purchased` | active | `apply(result)` then optionally `apply(fresh)`; both call `TrialLifecycle.sync`. |
| inactive | `paymentPendingError` | inactive | Delegate flips it later. |
| active | foreground refresh `.fetchCurrent` fails | active (stale) | Left as is by design; lapses show on the next successful refresh. |
| active | entitlement expires while app open | active (stale) | Same. |
| any | restore | per result | `lastError` is shared with product fetch: a "No active purchase" message stays in `lastError`, which makes `resolveOnboardingTrial` refetch products. A failed refetch sets `packages = []` and drops a good offering (SubscriptionService.swift:249-254). Benign in practice (no route found where plans were already shown). |
| Pro | lapses | free | Active premium bonsai species stays selected and drawn; only switching is locked (P4). |

### M3 Trial lifecycle (`TrialLifecycle`, App Group defaults)

Keys: `endsAt`, `reminderScheduled`, `recapDismissedForEnd`, `recapSummary` (never written by anything, so the reminder body is always the generic one). `shouldShowRecap`, `dismissRecap`, `daysRemaining` have no caller: the "in-app recap" the type comment describes does not exist in the UI.

Invariants
- T1 A pending trial-ending reminder exists only while `endsAt` is set and in the future.
- T2 `reminderScheduled` is true only when the reminder is actually pending.
- T3 `willRenew == false` clears tracking and the reminder.
- T4 A retry for the same trial never re-prompts for permission.

| From | Event (`sync`) | To | Notes |
|---|---|---|---|
| untracked | trialing, `willRenew`, end in future | tracked, Task: ensureAuthorized, schedule | Permission asked here (TrialLifecycle.swift:117). |
| tracked, scheduled | same trial again | unchanged | Early return. |
| tracked, not scheduled | same trial again | retry if already authorized | Handles permission granted later (this path works; compare SM-5, which does not). |
| tracked | end date moved > 60 s | re-tracked, rescheduled | Old reminder replaced (same identifier). |
| tracked | not trialing / will not renew / expired | untracked, reminder cancelled | |
| tracked, Task in flight | `clear()` | untracked, then Task adds the reminder and writes `reminderScheduled = true` | Would break T1/T2. Window is the permission alert; no tap route found that clears a trial while it is up. Latent (H1). |

### M4 Trial pitch presentation (`TrialOfferCoordinator`, `MainTabView` flags, gates)

State: `pendingRequest`, `isPresentingSheet`, `showTrialOffer`, `showTrialPaywall`, `pendingPaywallAfterTrialDismiss`, `trialPurchaseInFlight`, persisted `TrialNudgeGate` (count, last shown), per-intent action counts, in-memory per-session pitch counts, `postOnboardingPaywallPending`.

Invariants
- P1 A pitch is never shown to a Pro user (checked in `handleTrialPitch`, `presentTrialOffer`, on `isProSubscriber` change).
- P2 The review prompt never appears over a pitch, and vice versa (`isPresentingSheet`, `pendingRequest`).
- P3 The day-0 paywall flag is consumed only when the request is actually made (HomeView.swift:585).
- P4 A purchase in flight cannot be dismissed (`interactiveDismissDisabled`).

| From | Event | To | Notes |
|---|---|---|---|
| idle | request | `pendingRequest` set, immediately cleared by `MainTabView`, sheet flag set | |
| offer sheet | "See all plans" | offer closed, paywall opened in `onDismiss` | If approval of a pending purchase lands between the tap and the dismiss, a Pro user sees the plan picker once (cosmetic, P1 broken for one frame; not counted). |
| offer sheet + paywall flag both set | second request while a sheet is up | second sheet queued by SwiftUI | Both flags remain true; shown after the first closes. |

### M5 Daily reminder queue (`NotificationService`)

State: `UserSettings.dailyReminderEnabled/Hour/madeCommitment`, iOS authorization status, up to 30 pending requests `sober.daily-reminder.0...29` (plus legacy bare id), in-memory `lastReminderPlan`.

Scheduler call sites (complete list): `OnboardingView.swift:914` (direct), `NotificationService.refreshDailyReminder` (the only other path to `scheduleDailyReminder`, NotificationService.swift:169) called from `HomeView.refreshCheckInState` (HomeView.swift:512), `SettingsView.startDateBinding` (276), `SettingsView.rescheduleReminder` (292, via hour, enabled, pledge toggles and `refreshNotificationStatus`), `TimelineView.confirmSlip` (538), `logCheckIn` (613), `undoSlip` (626), `deleteCheckIn` (633). Cancel: `cancelDailyReminder` from the same function when disabled. No other call site (SlipSheet, craving and Reset all go through Home's `refreshCheckInState`).

Invariants
- R1 When the toggle is on and iOS permission is granted, the next 30 days have one pending request each, numbered for their own date.
- R2 Today's request is absent once today is logged (check-in or slip).
- R3 Toggle off means nothing pending.
- R4 A change in permission re-arms the queue (SettingsView.swift:199-202 states this as the intent).
- R5 Two arming passes never interleave into a mixed queue.

| From | Event | To | Notes |
|---|---|---|---|
| any | state change (check-in, slip, undo, reset, start edit, hour, pledge, new day) | plan string changes, Task re-queues | R1, R2. |
| any | same plan again | skipped | `lastReminderPlan` guard (NotificationService.swift:166). |
| armed/denied | permission `denied` -> granted while app stays alive | plan unchanged, skipped | Breaks R4 (SM-5). |
| any | two different plans within milliseconds | two unawaited Tasks, adds interleave by identifier | Could break R2/R5 (H3); needs two state changes inside one scheduling pass, no tap route found. |
| enabled, `notDetermined` | any refresh | `isAuthorized()` false, nothing queued, no prompt, no banner | P1 below. |
| disabled | refresh | `lastReminderPlan = nil`, queue removed | R3 holds. |

### M6 Journeys, check-ins, slips (`SobrietyService`, `CheckInService`, `SlipRecorder`)

State: `SobrietyJourney` rows (start, end?, reason?), `DailyCheckIn` rows (day, wasSober, wasLogged, mood, note), Home `@State` (`checkedInToday`, `todayWasSlip`, `daysMissed`, `week`).

Invariants
- J1 At most one open journey; closed journeys never overlap.
- J2 Best streak never counts a logged slip day as sober.
- J3 A logged slip is the end of the run it sits in (or the start day of the next).
- J4 `SlipRecorder.undo` reverses row, counter, journey and garden together, and only for the slip the live counter sits on.
- J5 `wasLogged` means a tap; assumed rows (`fillJourney`) never count as tended.
- J6 All rows are keyed to the current zone's midnights before they are compared (`normalizeDayKeys`).

| From | Event | To | Invariant |
|---|---|---|---|
| active run | slip today | run closed today, new run today, garden halved | ok |
| active run | slip back-dated, later slip logged | closed run split at the day | ok |
| active run | slip back-dated, no later slip | closed at the day, new run next day | ok |
| closed run ended by Reset or pre-slip-era "Start fresh" | slip dated inside it | row logged, **no split**, garden rule still applied | Breaks J2/J3 (SM-1). |
| slip today | Home Reset | stub run closed, new run, tree wiped | Home's slip card and Undo stay (row still a logged slip). |
| slip today after Reset | Undo | stub reopened, tree carryover restored, pre-slip run stays closed | Breaks J4 (SM-2). |
| slip, tree completed (>365 days) | Undo | run reopened, `groveCountAtJourneyStart` not restored | Breaks J4 (SM-3). |
| active run | Settings start date edit | start moved, assumed rows outside runs dropped, gaps refilled | Can overlap a closed run and slip day (P3). |
| zone change | `significantTimeChange` or foreground | rows re-keyed, duplicates merged | J6 holds (tested elsewhere). |
| unlogged day | Timeline mood or note edit | row logged | Intentional (J5 "user has spoken"). |
| past logged sober day | Timeline "Delete log" | row removed; refilled as assumed on next Home refresh | Mood and note lost; the day reads blank until Home refreshes. Benign. |

### M7 Garden (`GardenService`, `GardenState`)

State: `carryoverDays`, `carryoverBeforeSlip`, `lastUnlockNotifiedAtDays` (also the celebration watermark), `groveCountAtJourneyStart`, `completedTreeStyles`, `vitality`, `lastWateredAt`, `vitalityDecayDays`, `activeBonsaiStyleID`.

Invariants
- G1 `completedTreeStyles.count == groveCountAtJourneyStart + completed cycles of the current run` (never exceeds the real count).
- G2 A slip halves tree growth once; re-submitting a slip is an edit.
- G3 Undo restores what the slip took.
- G4 Celebrations fire once per stage crossed.
- G5 Tree days never wrap the 365 boundary because of carryover.

| From | Event | To | Invariant |
|---|---|---|---|
| tree | slip | carryover halved, watermark 0, grove baseline = count, vitality -0.3, `lastWateredAt` nil | ok |
| after slip | undo | carryover, watermark, vitality (+0.3, can exceed the pre-slip value after the 0.3 floor) restored; baseline and `lastWateredAt` not | Baseline breaks G1/G3 (SM-3); vitality over-restore is cosmetic. |
| any | Reset | carryover 0, baseline = count, placed items cleared (not user reachable) | Not undoable (P2). |
| any | start date edit | watermark and carryover untouched | A far-back edit appends grove trees permanently (P5). |

### M8 Craving session (`CravingModeView`, `CravingService`)

States: `breathing` -> `reflect` -> `done`, plus `hasFinished`. Row is written once at the end.

Invariants: C1 exactly one row per finished session; C2 an unresolved session under 8 s is not logged; C3 the cover cannot be dismissed while breathing; C4 "I gave in" never changes the counter without the slip sheet's confirmation.

Transitions: breathing -> reflect on timer, "I'm through it", or close (close logs `.unresolved` directly and leaves); reflect -> done only for `.rodeItOut` and a successful save; other outcomes dismiss. The timer is a main run loop `Timer`, so time in the background is not counted (`secondsElapsed` can be lower than `endedAt - startedAt`; cosmetic). No bug found.

### M9 Review prompt (`ReviewPromptTracker`)

Keys: launch count, positive moment count and pending flag, last shown, outcome. Invariants: a prompt needs a pending moment, 2+ launches, a 30-day gap and no `openedWriteReview`; it is never raised over a sheet. Transitions are in `HomeView.scheduleReviewRequestAfterPositiveMoment`. No bug found.

### M10 Widget and watch snapshot (`WidgetSnapshotPump`, `WatchConnectivityService`)

Invariant W1: the snapshot is re-pushed after every change to start date, slip, undo, reset, check-in, species and mood edits. The consumers recompute the day count from `sobrietyStartDate` at render time, so midnight needs no push. All mutation sites push (HomeView, SlipRecorder, SettingsView, TimelineView). No bug found. Watch only sees data via `updateApplicationContext`; an unpaired or uninstalled watch is a no-op by design.

### M11 Timeline selection (`TimelineSelection`, `TimelineView`)

State: month, selected day, draft mood, draft note, `draftDay`, `pendingSlipDay`. Owned above the view so folding the Duo does not lose it.

Invariants: S1 a logged day's draft equals the stored row; S2 an unlogged day keeps its typed draft across remounts.

| From | Event | To | Invariant |
|---|---|---|---|
| tab | tab selected | `onAppear` reloads a logged day's draft | S1 holds. |
| unfolded pane, today selected | Home check-in with mood or note | row changes, pane never remounts, `loadDraft` is not called | Breaks S1 (SM-7). |

### M12 Day key and time zone (`CheckInService.normalizeDayKeys`)

Invariant Z1: every `DailyCheckIn.day` is a midnight of the zone recorded in `checkInDayKeyZone`. Transitions: zone differs -> re-key, merge duplicates (logged beats assumed, slip beats sober, notes kept), save, then record the zone; a failed save rolls back and leaves the zone unrecorded so the next launch retries. Unit-tested in the repo (`OvernightBugHuntTests`). A logged row from a zone east of the user can become a future-dated row after travelling west and then reads as logged when that date arrives (P6, a calendar-identity choice).
