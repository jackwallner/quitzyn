---
paths:
  - "Sober/Features/Today/HomeView.swift"
  - "Sober/Features/Paywall/BloomPlusTabView.swift"
  - "SoberUITests/StoreScreenshotLocalizationUITests.swift"
  - "fastlane/screenshots/**/*.png"
  - "artifacts/asc-screenshots/**"
---

# Localized store sets

- Use the latest `artifacts/asc-screenshots/l10n-*/app.json` and
  `en-live.json`. Only root-level frames in the live English inventory are
  eligible; Watch and Duo sets stay English.
- Recapture with `artifacts/asc-screenshots/l10n-20261105/tools/capture.sh`
  (all locales by default, or pass locale codes). It writes the locale list
  into the UI-test bundle, navigates through all seven scenes during one app
  launch per locale, sorts the attachments, then reskins, gates, and writes
  contact sheets for every selected locale.
- `gh-sim launch` has a 10-minute screenshot-step limit. A two-locale, seven
  scene launch run timed out after the English set and four Finnish scenes.
  The `StoreScreenshotLocalizationUITests` XCUITest loop captures all locales
  in one test job instead.
- The live English screens use an older app layout, so cropped-screen NCC did
  not match. For this set, `locate.py --bezel --radius` gives the phone screen
  rectangle from the visible continuous bezel.
- `-screenshotGarden`, `-screenshotCheckIn`, and `-screenshotPatterns` are
  DEBUG-only routes for the garden picker, daily check-in sheet, and craving
  patterns. `-craving` opens the breathing session. Seed with
  `-seedDemo -demoPro -seedDays 130 -QuitZynScreenshot` and set
  `SOBER_SCREENSHOT_MODE=1`; never configure a production RevenueCat key.
- Keep raw captures out of git. Run `locate.py`, `reskin.py`, `sheet.py`, and
  `gate.py` from the kit before replacing root-level target-locale PNGs.

## 2026-11-08 run (es-MX, it, no, pl, ro, sv, uk, zh-Hans)

- One `capture.sh` (no arguments) took one gh-sim XCUITest job for en-US plus
  the eight locales (about 19 min of test time; the GitHub macOS queue added
  over two hours of waiting). Rerun a subset with `capture.sh <locales>`.
- `capture.sh` and `process.sh` run under macOS bash 3.2: empty-array expansion
  needs `${arr[@]+"${arr[@]}"}`.
- Headers sit in a 1240 px box at up to 156 px; keep lines under about 17
  characters in Latin and Cyrillic scripts so they stay clear of the canvas edge.
- Norwegian is store locale `no` with `-AppleLanguages (nb)`.
