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

## Second pass (2026-11-08)

### Scope

- Reviewed `0543606..f52ace7` (origin/main, build 68), app sources only.
  This takes in the `ship/1.3.1` merge (`5a2e89d`, builds 53 to 62) plus the
  UI fixes on main after it: onboarding contrast and 44 pt targets, saved
  quit date restored after a mid-onboarding kill, check-in sheet opening on
  today's saved mood and note, Home trial offer waiting for a quiet Home,
  craving dock sizing, week strip hit region, `textTertiary` and
  `brandSecondary` darkened, DEBUG screenshot copy for eight more locales.
- `origin/main` was merged into this branch so the fix below sits on the
  code being submitted.

### Checks run

- Crash and data loss: no schema change, no new force unwraps or index
  reads outside DEBUG (`symbols[value - 1]` and `moodLabels[value - 1]`
  iterate `1...5` over 5-element arrays). `restoreSavedSetup` divides by
  `pouchesPerDay` only inside `pouchesPerDay > 0`.
- Purchases: no RevenueCat, offering, restore or entitlement logic changed.
  Paywall and onboarding legal footers keep Restore, Terms and Privacy, now
  with 44 pt targets. The Home trial offer now restarts its 20 s wait each
  time Home clears; `TrialNudgeGate`, `hasClaimedTrial`,
  `hasTrialOfferAvailable` and the pending-request guard still apply.
- App Review: the new screenshot copy and seed changes sit inside
  `#if DEBUG`. Two new catalog uses (`Low`, `Great` feeling labels).
  `python3 Tools/Localization/check.py`: 608 keys, 15 languages, 0 problems.

### Findings

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P1 | `Sober/Features/Today/HomeView.swift:757` | The check-in sheet now opens on today's saved mood and note, but Save called `checkIn(mood:note:)`, which treats nil as "keep". Deleting the note or deselecting the mood and tapping Save silently kept the old values, so a note the user removed came back. | Fixed (`022b397`): Save writes the sheet's values through new `CheckInService.setDetails`, which never touches `wasSober` or `wasLogged`. Tests in `CheckInDetailClearTests`. |
| P2 | `Sober/Features/Onboarding/OnboardingView.swift:878` | After a kill mid-onboarding, the restored price per can is back-computed from the saved cost per day with the default 15 pouches per can (the can size is not stored) and rounded to $0.50, clamped to $1 to $20. A user who picked 20 or 24 sees a different can size and price; the daily cost drifts by a few cents when they continue. | Not fixed (only after a kill mid-onboarding, small drift, needs a stored can size to fix properly) |

No P0 findings. The two P2s from the first pass are unchanged.

### Tests (second pass)

`gh-sim test --scheme Sober --only SoberTests` on this branch with the fix,
id `nicfree@20261108-075707-590c-claude-mbpro39fad-1108-075900-15387`, GitHub
run 42497525079: 196 passed, 0 failed, 0 skipped (Xcode 27.1, iPhone 17,
iOS 27.2). Includes the three new `CheckInDetailClearTests`.
