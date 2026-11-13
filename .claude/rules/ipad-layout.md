---
paths:
  - "project.yml"
  - "Sober/Info.plist"
  - "Sober/Utilities/ReadableWidth.swift"
  - "Sober/Utilities/UnfoldedSplit.swift"
  - "Sober/App.swift"
  - "Sober/Features/Paywall/PaywallView.swift"
  - "Sober/Features/Paywall/TrialOfferSheet.swift"
  - "Sober/Features/Craving/CravingModeView.swift"
  - "SoberUITests/IPadLayoutShotsUITests.swift"
---

# Quit Zyn: iPad (2026-11-12)

`TARGETED_DEVICE_FAMILY "1,2"` on the app, all four iPad orientations
(`UISupportedInterfaceOrientations~ipad`). The watch stays 4. iPad support can
never be removed once shipped.

- **The Duo split is the iPad layout.** At regular width of 720 pt or more
  (every full-screen iPad, both orientations) `MainTabView` shows the tabs in
  the leading pane under `PaneTabStrip` and Timeline in the trailing pane, an
  even split because an iPad has no fold. Narrow widths (Split View,
  Slide Over) are compact and keep the phone's single column with the tab bar.
  Rules for the split are in `iphone-duo.md`. The Timeline pane draws on
  `Theme.background` with white cards, like the leading pane.
- **Cap full-width columns.** `readableWidth(_:)` (`ReadableWidth.swift`)
  frames a column at 560 pt (520 for docked buttons) and centres it. Used on
  the paywall stack, the trial sheet and the craving screens, which sit
  outside the split and would otherwise stretch plan rows and buttons across
  a 1376 pt screen.
- **`pageSheetOnPad()`** gives Settings, Garden customization and the slip
  sheet `presentationSizing(.page)` on iOS 18+. The default iPad form sheet
  cut their lists off. Short sheets (check-in) keep the form size.
- **Proof.** `IPadLayoutShotsUITests` shoots every screen, paywalls and
  onboarding steps, portrait and landscape: `gh-sim test --scheme SoberUITests
  --device 'iPad Pro 13-inch (M5)' --only SoberUITests/IPadLayoutShotsUITests`.
  The framebuffer is always portrait, so a landscape attachment comes back
  rotated: `sips -r 270 in.png --out out.png` for `landscapeLeft`. Use
  `XCUIScreen.main.screenshot()`; `app.screenshot()` clips the landscape frame.
  `gh-sim get` can fail silently when the run finished just before the
  artifact; fall back to `gh run download <run> -R jackwallner/gh-sim -n result`.
