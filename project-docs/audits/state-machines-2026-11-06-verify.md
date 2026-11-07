VERDICT: PASS

# Verification of the state machine fixes, 2026-11-06

Independent check of `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md` and the whole change `git diff 70be04042a483d462089a069d4a5cf8b3d86a6b2..HEAD` (HEAD `94cf89b`, branch `fleet/20261106-230307-b9a9-claude`). Every claim was re-read in the code; no app code or test was changed. No earlier verify doc existed.

**Summary:** all 6 fixes work on the review's user route. No regression found. Full suite 192 passed, 0 failed. With the fixes reverted and their tests kept, all 7 bug tests (SM-4, SM-5, SM-1, both SM-2, both SM-3) fail and all 5 controls pass. SM-7's test only exercises the fix's own hook; the pane wiring is left as a device check. Nothing in scope (check 4) fails.

## Fixes

| Id | Works | Regression check | Evidence |
|---|---|---|---|
| SM-4 | Yes | None. Every money figure the review named now formats in the device currency, the one onboarding and Settings price the cost in. `currencyCode` stays stored and unread, so no schema change. | `UserSettings.swift:56-71`; Progress sheet money row and per-day line `HomeView.swift:762, 886, 918`; free trial row `HomeView.swift:809` (same `lifetimeMoneySaved`); Bloom+ hub `BloomPlusTabView.swift:116, 162, 175`. No other reader of `currencyCode` (grep). Screenshot in de_DE: hub shows "416 €" and "1.168 € pro Jahr". Test fails with the fix reverted ("USD"). |
| SM-5 | Yes | None. The memo is in-memory only (no stored setting cleared); a pass without permission now clears it, so the grant route re-arms. Concurrent passes with a newer plan are not disturbed (`lastReminderPlan == plan` guard). Reminder-off path unchanged. | `NotificationService.swift:166-179`. Grant routes reach it: Settings returns to `.active`, `refreshNotificationStatus` sees denied to allowed and calls `rescheduleReminder` (`SettingsView.swift:219-234, 323`); Home's foreground refresh calls `refreshDailyState` then `refreshCheckInState` then `refreshDailyReminder` (`HomeView.swift:127-128, 492-512`). Test fails with the fix reverted ("retry nil"), so its permission guard did not return early. |
| SM-1 | Yes | None. Only days outside the live run and inside a closed run take the new branch; Home's slip sheet cannot pick such a day (`SlipSheet.swift:24-26`). Days in the live run and days before the first run keep the old path (control passes). Widget snapshot pushed on the branch, so Longest on the widget follows. | `SlipRecorder.swift:77-82`, `SobrietyService.swift:84-92`. Route: Home > More > Reset, then Timeline > a pre-reset day > Change to slip / Log a slip > `confirmSlip` (`TimelineView.swift:541-551`). Test asserts Longest 16, counter, carryover and vitality unchanged; fails with the fix reverted (Longest 31). |
| SM-2 | Yes | None. With no Reset in between, undo still reopens the live run and returns the tree (control passes). A slip behind a later slip stays irreversible (control passes). Garden is returned only when the live run reopened (`SlipRecorder.swift:146`); the Reset's wipe stands. No overlap after either date variant. Slips from older builds carry `resetReason == "slip"` since the slip port (`8a5ca54`) and the initial fork, so upgrades stay undoable. | `SobrietyService.swift:143-151, 178-196`. Routes: Home slip card Undo (`HomeView.swift:363-367`, `.now`), Timeline "Change to nicotine-free" (`TimelineView.swift:508-521`). Timeline caption "Puts your counter and your tree back..." now shows only when that is true (`TimelineView.swift:517`). Yesterday test fails with the fix reverted (counter 41, Reset discarded). |
| SM-3 | Yes | None. New optional `GardenState.groveCountBeforeSlip` (no default) migrates lightweight in the unversioned schema (`DataService.swift:8-17`); the on-disk upgrade test opens a pre-change store with every garden value intact. Older-build slips derive the baseline. A stale value left by a Reset-then-undo is overwritten by the next `recordSlip` before any live undo can read it. | `GardenService.swift:196, 218-222`, `GardenState.swift:32-37`. Route: streak past 365 > I slipped > Undo. Both bug tests fail with the fix reverted (grove 2, and 4 for the older-build case). |
| SM-7 | Yes, by code read | None found. Self-edits in the pane write the row first, so the reload reads back the same values; an assumed row (`fillJourney`) does not touch the draft; a day change reloads once, then the row hook reloads the same values again. | `TimelineView.swift:105-112` wires `selectedRowState` (the selected day's logged, sober, mood, note) to `TimelineSelection.storedRowDidChange` (`TimelineView.swift:685-688`), which reloads only for a logged row on the drafted day. The pane is never remounted (`.claude/rules/iphone-duo.md`), and the view's `@Query` re-renders on Home's insert, so `onChange` fires. Device check left open, see below. |

### Disputed

The fixes doc lists no "Disputed" items, so there is nothing to rule on.

### Left open as device checks

- **SM-7:** both tests call `TimelineSelection.loadDraft`/`storedRowDidChange` directly. They prove the reload rule, not that the view calls it. Open: on an unfolded iPhone Duo, select an unlogged today in the Timeline pane, check in on Home with a mood and a note, and confirm the pane shows them and that typing extends the saved note rather than replacing it.
- **SM-5:** the test proves the memo no longer swallows the retry. Open: deny at onboarding, allow in iOS Settings, return, and confirm 30 pending `dailyReminder` requests exist.
- **SM-4:** the Progress sheet (Home > chart icon) has no launch argument; the shared helper was seen working on the Bloom+ hub only.

## Must change

Nothing in the app or tests. One doc correction for the fixes doc: it cites commit `38608a3` for the SM-7 test fix, which is not in this history; the commit is `dec5fa7`.

## Tests

| Run | GitHub run | Result |
|---|---|---|
| Full suite, HEAD: `gh-sim test --scheme Sober`, id `nicfree@20261106-230307-b9a9-claude-imace3c4-1106-230449-28922` | 42349741691 | **192 passed, 0 failed, 0 skipped.** All 14 tests in `StateMachineFixRegressionTests.swift` passed. Matches the fixes doc (192/192). |
| Fail-without-fix: scratch branch with the SM-1, SM-2, SM-3, SM-4, SM-5 behaviour reverted, tests kept, `gh-sim test --scheme Sober --only SoberTests/StateMachineFixRegressionTests`, id `nicfree@20261106-230307-b9a9-claude-imace3c4-1106-234809-23690` | 42352787402 | 5 passed, 7 failed, as expected. Failed: `sm4_moneyUsesTheDeviceCurrencyNotTheStoredDefault` ("USD"), `sm5_aPassWithoutPermissionLeavesThePlanUnarmed` (retry nil), `sm1_slipInsideAResetEndedRunSplitsItAndLeavesTheTreeAlone` (Longest 31), `sm2_yesterdaySlipThenResetThenUndoLeavesNoOverlappingRuns` (counter 41), `sm2_todaySlipThenResetThenUndoKeepsTheResetAndDropsTheSlip`, `sm3_undoingASlipAfterATreeCompletedDoesNotAddAnotherTree` (grove 2), `sm3_undoOfASlipFromAnOlderBuildAddsNoTree` (grove 4). Passed: the 4 controls and the schema upgrade test. |
| Screens, HEAD: `gh-sim launch --device 'iPhone Duo'`, de_DE, `-seedDemo -demoPro -seedDays 129 -QuitZynScreenshot`, `-DuoScreen bloom` and `timeline`, id `nicfree@20261106-230307-b9a9-claude-imace3c4-1107-002550-14256` | 42355459653 | Success. Bloom+ hub in euros; unfolded Home \| Timeline split renders as before. |

How the scratch revert was made: `SlipRecorder.swift`, `SobrietyService.swift` and `GardenService.swift` restored from `70be040`, plus a one-line `undoReopensLiveRun` stub returning `canReopenJourney` so `TimelineView` and the tests compile; `displayCurrencyCode` returned "USD" (the stored default every row held, which the old screens used); the permission guard removed from `refreshDailyReminder`'s Task. The SM-4 and SM-5 tests call APIs the fixes add, so a plain base checkout cannot compile them; this keeps the API and reverts only the behaviour. The scratch branch was deleted; this branch holds only this doc commit on top of `94cf89b`.

No test failed on HEAD, so no `--only` rerun or base comparison was needed.

## Scope (check 4)

- Changes stay within the six reviewed claims. Side changes: `refreshDailyReminder` returns its Task (`@discardableResult`, all callers ignore it) and `lastReminderPlan` is `private(set)` (read by no test). Both harmless.
- No trial, onboarding, paywall, price, offer or entitlement logic changed. The trial row on Home changed only its currency symbol.
- No backend, App Store Connect or RevenueCat change needed.
- No stored setting or record is cleared on an inferred state; SM-5 clears an in-memory memo only.
- One new optional column; existing data opens unchanged (proved by `sm3_aStoreFromTheOlderSchemaOpensWithItsGardenIntact`). `currencyCode` kept.
- All 6 review claims are in the fixes table; none held, skipped or UNVERIFIED.

## Notes

- New neighbouring behaviour, consistent with the documented rule: a slip back-logged into a run the Reset ended (SM-1) is now the most recent slip on record, so Timeline offers "Change to nicotine-free" for it, without the counter-and-tree caption. Undo merges the split back (`SobrietyService.swift:146-148`), leaves counter and garden untouched, and the row returns to nicotine-free. Before, such a slip was never undoable. AGENTS.md says a slip is reversible "while it is still the most recent slip on record", so this is the rule applied, not scope creep.
- SM-2 after a Reset: Timeline shows "Change to nicotine-free" with no caption. Accurate, and simpler than adding copy.
- SM-4: money follows the device region, as Settings already did. A user who changes region later sees the same number in the new currency; that is unchanged from Settings and outside this audit.
- SM-7: a half-typed note in the pane on a day with no row is replaced when Home logs that day. That draft was never saved and the logged row is now the truth, so this is the intended trade.
- `sm5_aPassWithoutPermissionLeavesThePlanUnarmed` took 121 s on HEAD (the notification-settings calls in the test host). It passed, and failed when reverted, so it is not vacuous; it does stretch the suite.
- On the scratch run, `sm2_todaySlipThenResetThenUndoKeepsTheResetAndDropsTheSlip` first failed on the stubbed `undoReopensLiveRun` line. Its base failure on the real assertion ("slip's boundary still on record") is from the fixes doc's base run 42344614464; the yesterday variant fails on behaviour in this run.
