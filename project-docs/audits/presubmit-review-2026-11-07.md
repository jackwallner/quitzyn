# Quit Zyn 1.3.2 pre-submit review (2026-11-07)

## Scope

- Live version: 1.3.1, "ready for distribution" in App Store Connect
  (`release.py status`, read only). 1.3.2 is "prepare for submission" with
  build 67 the newest valid upload.
- Live commit: `f31b338`, the last commit at `MARKETING_VERSION: "1.3.1"`
  (`20ad207` starts 1.3.2).
- Reviewed: `f31b338..origin/main` (`0543606`, build 67), 42 commits, app
  sources only (`Sober/`, `Shared/`, `SoberWatch/`, `SoberWidgets/`,
  `project.yml`, `Info.plist`). Docs, fastlane, qa and tests excluded.
- The fleet copy had no `origin` remote and stopped at build 64. The review
  branch was cut from GitHub `jackwallner/quitzyn` main instead, so it matches
  what build 67 was archived from.

## What changed since 1.3.1

- State machine fixes SM-1 to SM-5 and SM-7 (slip inside a Reset-ended run,
  slip undo after a Reset, grove baseline on undo, device currency for money,
  reminder memo without permission, Duo Timeline pane draft sync). Already
  audited, reviewed and verified on 2026-11-06 (see the `state-machines-*`
  audits).
- New optional `GardenState.groveCountBeforeSlip` (lightweight migration).
- Settings Language row plus `UIPrefersShowingLanguageSettings`.
- Localization fixes (English trial disclosure plural, Czech, Slovak, Danish,
  Finnish, German strings), layout tweaks for long languages.
- DEBUG-only screenshot hooks (`-screenshotGarden`, `-screenshotCheckIn`,
  `-screenshotPatterns`, `storeScreenshot.*` identifiers, localized seeded
  journal copy).

## Checks run

- Crash and data loss: no new force unwraps or unchecked indexes in Release
  code (the `texts[0...3]` reads are DEBUG only on fixed 4-element arrays). The
  one schema change is an optional property, which migrates lightweight. No
  new `Codable` decoding of saved data. New `Task`s in `NotificationService`
  are created from `@MainActor` code and inherit its isolation.
- Purchases: no RevenueCat, offering, package, restore or entitlement code
  changed. `PaywallView` changes are layout and `LocalizedStringKey` eyebrows
  (literal call sites only). Terms, Privacy and Restore remain in the footer.
  `PaywallPreviewStore` (hard-coded `$` prices) is wrapped in `#if DEBUG`.
- State: slip undo (`reversibleSplit`) walked for live-run, Reset-after-slip,
  same-day Reset and back-logged split cases; Timeline blocks taps on days
  before the first run, so the old pre-start path is unreachable from UI.
  Duo pane `storedRowDidChange` checked against self-edits: mood and note
  edits write the row first, so the reload reads back the same values.
- App Review: every new launch argument and identifier is inside `#if DEBUG`.
  Only two new catalog keys ("Language", "Opens iOS Settings"). No new health
  claims, no other-platform links in app code, no hard-coded prices in copy.
  `python3 Tools/Localization/check.py`: 606 keys, 15 languages, 0 problems.

## Findings

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P2 | `Shared/Services/NotificationService.swift:168` | Two reminder refreshes with different plans (for example Home's foreground refresh, then a check-in a moment later) each run cancel then add 30 fixed IDs with awaits between steps, so they can interleave and leave a mix of the two plans; the new `await isAuthorized()` before scheduling widens that window slightly. Worst case a reminder for a day already checked in. Pre-existing pattern, not reproduced. | Not fixed (not definitely broken; a fix means serializing the scheduler, which is a design change) |
| P2 | `Shared/Services/SlipRecorder.swift:107` | A slip on a day outside every run (a gap, or before the first run) skips the counter reset (`alreadyRestarted`) but still runs `garden.recordSlip`, halving the live tree. Timeline disables days before the first run (`TimelineView.swift:357`) and Home's slip sheet only offers live-run days, so no UI route found. | Not fixed (unreachable from UI; behaviour unchanged since 1.3.1) |

No P0 or P1 findings. No code changes were made.

## Tests

Not run. `gh-sim test --scheme Sober` on `origin/main` (`0543606`), id
`nicfree@20261107-230102-8f3a-claude-mbpro33ce3-1107-231913-25042`, GitHub run
42458302612, sat queued for over 2 hours (22 fleet runs queued account-wide,
the Air lane had no room) and was cancelled past the 90-minute limit. No code
changed in this review, so the last proof of this code is the 2026-11-06
verification run 42349741691 (192 passed, 0 failed) on the state machine fixes.
One app commit landed after it (`f48c0b9`: layout, contrast, a 44 pt week strip
and a DEBUG seed guard, no logic the unit suite covers), and build 67 compiled
from it. Rerun the suite before submitting for a fresh pass.
