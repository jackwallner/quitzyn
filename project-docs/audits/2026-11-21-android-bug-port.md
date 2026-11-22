# Android port of the 2026-11-20 bug fixes

Checked 2026-11-22 on `main`. Each row of
[2026-11-20-bug-fixes.md](2026-11-20-bug-fixes.md) was checked against the
`android/` port by reading the code. Bugs that exist there were fixed with the
smallest change that matches the iOS behavior. Tests are in
`android/app/src/test/java/com/jackwallner/quitzyn/BugCatalogRegressionTest.kt`,
named after their iOS counterparts.

Unit runs (`fm-gradle testDebugUnitTest`, GitHub Linux):

- Before the fixes, with the B4, B5 and B6 tests: `nicfree-mbairfcc1-1122-095625-20067`,
  62 tests, 4 failed (the three bug tests plus the bonsai manifest, below).
- At HEAD: `nicfree-mbairfcc1-1122-100437-15895`, **70 passed, 0 failed.**

No emulator run. The Compose wiring of B2, B3 and B7 was checked by reading
the code; their unit tests cover the logic each screen calls.

| iOS bug | Android verdict | Commit | Test | Notes |
|---|---|---|---|---|
| B1 One failed database open hides the history for good | not applicable | | `PortParityTest` (unreadable record) | No SwiftData store to quarantine. Android keeps one atomic JSON file; `SoberStore.load` blocks every write after a failed read and tries again on the next launch, so nothing is swapped in over the history |
| B2 Can price and cost per day capped at dollar sizes | ported | a08b0df | `b2_*` (4 tests; `SpendScale` is new, so they do not compile without the fix) | Onboarding's can price and Settings' cost per day were hardcoded to 1 to 20 and 0 to 200. `model/SpendScale.kt` is the iOS table |
| B3 Trial pitch after the third check-in comes up over the note sheet | ported | 39a790e | `b3_checkInPitchIsHeldUntilTheNoteSheetCloses` (new class) | On Android the pitch stacked over the note sheet 2.5 s after the check-in. It is held until the sheet closes; the welcome-back check-in sends it at once |
| B4 Start date edited far back and corrected leaves a phantom tree | ported | 8f82ade | `b4_correctingAFarEarlierStartDateDropsThePhantomTreeAndKeepsCelebrations`: failed before, passes | `SoberEngine.changeStart` trims the grove and lowers the watermark |
| B5 Delete log inside an earlier run leaves a hole | ported | f938a2c | `b5_deletingALogInsideAClosedRunKeepsTheDay`: failed before (18 to 17), passes; control `b5_deletingTodaysLogStillClearsIt` | `SoberEngine.deleteLog` |
| B6 Slip on a gap day halves the garden | ported | 368761a | `b6_aSlipOnAGapDayLeavesTheTreeAndCounterAlone`: failed before (carryover 8 to 0), passes | `SoberEngine.recordSlip` returns after writing the row |
| B7 Craving clock freezes while the app is away | ported | 0e907c4 | `b7_cravingClockCountsTimeTheTimerMissed` (new function) | The clock added one second per tick. It now reads elapsed from the start time on each tick |
| B8 Trial reminder tap from a closed app lands on Home | not applicable | | | Disproven on iOS, no change there |
| B9 Craving hours re-bucketed into the current zone | ported | 2b1d5dc | `b9_peakHoursDoNotMoveWithTheDeviceZone`, `b9_aStoreFromBeforeTheZoneOpensWithItsCravingsIntact` (new field) | `CravingEpisode.timeZoneId`, saved as `timeZoneID` in the JSON. Older rows have none and read in the device zone |

Counts: 7 ported, 0 already fine, 2 not applicable.

## Also fixed

`BonsaiParityTest.swiftBonsaiFilesMatchManifest` was already failing on `main`:
iOS commit `bd55ad4` moved the bonsai style names into the string catalog,
which changed two Swift file hashes. Nothing drawn changed. I re-ran
`scripts/sync-android-bonsai.py`; the scene and wind fixtures came out
byte-identical and only `manifest.json` moved. The script also needed
`-plugin-path` for `@State` on the current Xcode.

## Needs Jack

Nothing blocking. Not uploaded to Play.
