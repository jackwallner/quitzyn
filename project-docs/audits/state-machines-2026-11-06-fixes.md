# State machine fixes, 2026-11-06

Fixes for the claims `state-machines-2026-11-06-review.md` confirmed in `state-machines-2026-11-06.md`, in the review's ranked order. No `-verify.md` existed, so this is the first pass.

**Summary: 6 in scope (1 CONFIRMED, 5 CONFIRMED-MINOR, 0 UNVERIFIED). 6 fixed, 0 held, 0 skipped.**

Branch `fleet/20261106-195522-78fb-claude` (continuing the interrupted run `fleet/20261106-165206-7e3b-claude`), base `70be040`. Regression tests live in `SoberTests/StateMachineFixRegressionTests.swift`. The audit's repro suite was never added to the test target, so there was nothing to remove.

## Claims

| Id | Result | Commit | Regression test | What changed |
|---|---|---|---|---|
| SM-4 | Fixed | `020ba5e` | `sm4_moneyUsesTheDeviceCurrencyNotTheStoredDefault` | Every money figure (Progress sheet money and "per day" rows, the free trial row "You've saved X so far", the Bloom+ hub) now goes through `UserSettings.formattedMoney(cents:)`. It formats in the device currency, the one onboarding and Settings use when the cost is typed in. The never-written `currencyCode` column stays stored so existing stores open unchanged, but nothing reads it. The test runs on an existing row that still holds the "USD" default (the upgrade case). |
| SM-5 | Fixed | `441c502` | `sm5_aPassWithoutPermissionLeavesThePlanUnarmed` | `refreshDailyReminder` still memoises its plan, but a pass that finds no permission clears the memo (when it is still that pass's plan). So the next refresh after permission is granted (the Settings `refreshNotificationStatus` call, or Home's foreground refresh) arms the reminder. The function now returns its Task (`@discardableResult`) so the test can await it. |
| SM-1 | Fixed | `932d0fa` | `sm1_slipInsideAResetEndedRunSplitsItAndLeavesTheTreeAlone`, control `sm1_backDatedSlipInsideTheLiveRunStillRestartsTheCounter` | `SlipRecorder.record` handles a day that sits before the live run and inside a closed run as a history correction even when no later slip exists. The closed run is split, the counter is unchanged, and the garden is left alone. Before, a run that Reset had ended stayed whole (Longest overstated), and the 50% rule grew the live tree. The test asserts the whole promise: Longest 16, counter, carryover and vitality all unchanged. It uses Timeline's `startOfDay` date, as the review asked. |
| SM-2 | Fixed | `0cc248f` | `sm2_todaySlipThenResetThenUndoKeepsTheResetAndDropsTheSlip`, `sm2_yesterdaySlipThenResetThenUndoLeavesNoOverlappingRuns`, controls `sm2_undoWithoutAResetStillRestoresTheRunAndTheTree`, `sm2_aSlipBehindALaterSlipStaysIrreversibleAfterAReset` | Undo is still offered after a Reset, as AGENTS.md and the Timeline copy state. `reversibleSplit` now finds the run the slip itself closed (`resetReason == "slip"`), takes the next run as the one the slip opened, and refuses when a later slip boundary exists. If that next run is still active, Undo reopens the pre-slip run as before. If a Reset closed it, the pre-slip run takes over its end and reason. The Reset stands (no discarded Reset, no overlapping runs), the slip's boundary leaves the history, and the garden the Reset wiped is not regrown. Timeline's "Puts your counter and your tree back..." caption now shows only when Undo actually does that. The tests use the UI's arguments (`startOfDay()` from the slip sheet, `.now` from Home's card) and vary the date by one day. The audit's two opinion tests (`undoIsNotOfferedAfterTheCounterWasReset`, the 41-day expectation) were not kept. |
| SM-3 | Fixed | `31a4f96` | `sm3_undoingASlipAfterATreeCompletedDoesNotAddAnotherTree` (the audit's repro, which the review called sound), upgrade `sm3_undoOfASlipFromAnOlderBuildAddsNoTree` and `sm3_aStoreFromTheOlderSchemaOpensWithItsGardenIntact`, control `sm3_aRunAfterASlipStillAddsItsOwnTrees` | `recordSlip` saves the previous grove baseline in a new optional `GardenState.groveCountBeforeSlip`, and `undoSlip` restores it. A slip that an older build recorded has no saved value, so its baseline is derived instead (grove count minus the reopened run's finished cycles). The new column is optional with no default value, so SwiftData migrates it lightweight. The on-disk test opens a store written with the pre-change `GardenState` schema and checks that every garden value survives. |
| SM-7 | Fixed | `8a61a56`, `38608a3` | `sm7_aCheckInSavedOnHomeReachesThePaneDraft`, `sm7_anAssumedRowLeavesAHalfTypedNoteAlone` | `TimelineView` watches the selected day's stored row (logged, sober, mood, note) and passes changes to `TimelineSelection.storedRowDidChange`. A logged row reloads the draft, so the unfolded pane follows a check-in saved on Home and typing no longer overwrites the saved note. An assumed row leaves a half-typed note alone. |

## Held for Jack

None.

## Skipped

None.

## Limits of the proof

- SM-5: the unit test host cannot grant notification permission, so the test pins the half it can observe: a pass without permission leaves the plan unarmed, and a second pass with the same plan runs. The grant itself (and the pending requests that follow) still needs a UI test with a springboard grant, as the review noted.
- SM-7: the test covers `TimelineSelection`'s reload rule. The view's `onChange` wiring that calls it was not exercised: gh-sim unfolds the Duo only in launch mode, not for `test`.
- SM-4, SM-5 and SM-7 tests (and the two SM-3 upgrade tests) call APIs the fixes introduce, so they cannot run on the base commit. The review's run `nicfree@20261106-131202-c506-claude-imac9474-1106-131924-2242` reproduced SM-4 with a copy of the old formatter ("48 US$"). SM-5 and SM-7 failures without the fix are established by the code read in the review.

## Test results

- Full suite, final tree: `gh-sim test --scheme Sober`, run `nicfree@20261106-195522-78fb-claude-mbpro3bd59-1106-210138-23540` (GitHub Actions run 42340972951), Xcode 27.1, iPhone 17, iOS 27.2. **192 passed, 0 failed, 0 skipped**, all 14 tests in `StateMachineFixRegressionTests.swift` among them. No test failed, so nothing needed a rerun on `70be040`.
- The first full run on this branch, `nicfree@20261106-195522-78fb-claude-mbpro3bd59-1106-200533-20905` (run 42336902353), did not compile: the test target builds `Shared/` itself, so the SM-7 tests handed the test module's `DailyCheckIn` to the app module's `TimelineSelection`. `38608a3` points those two tests at the app module's models. No app code changed.
- Base check: the SM-1, SM-2 and SM-3 regression tests that compile on `70be040` (the eight that use no API the fixes add) were copied onto a detached `70be040` worktree and run with `gh-sim test --scheme Sober --only SoberTests/StateMachineFixBaseCheck`, run `nicfree-base-sm-mbpro3bd59-1106-215324-2602` (GitHub Actions run 42344614464). 4 passed, 4 failed. All four bug tests fail without the fixes: `sm1_slipInsideAResetEndedRunSplitsItAndLeavesTheTreeAlone` (Longest 31, expected 16), `sm2_todaySlipThenResetThenUndoKeepsTheResetAndDropsTheSlip` (the slip's boundary still on record), `sm2_yesterdaySlipThenResetThenUndoLeavesNoOverlappingRuns` (counter 41, the Reset discarded) and `sm3_undoingASlipAfterATreeCompletedDoesNotAddAnotherTree` (grove 2). All four controls pass on the base. The copy was a temporary worktree and is not in the test target.
- Tests that already failed on `70be040`: none observed. The final suite had no failures.
