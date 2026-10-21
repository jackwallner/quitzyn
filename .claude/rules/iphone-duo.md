---
paths:
  - "Sober/App.swift"
  - "Sober/Utilities/UnfoldedSplit.swift"
  - "Sober/Features/Calendar/TimelineView.swift"
  - "Sober/Features/Onboarding/OnboardingView.swift"
---

# Quit Zyn: iPhone Duo (2026-10-21)

- Unfolded (regular width, at least 720 pt), `MainTabView` puts the tab view
  (Home, Health, Journal, Bloom+ and its tab bar) left of the fold and Timeline
  in its own pane on the right; the Timeline tab drops out of the bar while
  split. Pane edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division)`), else an even split. Portrait unfolded (669 pt)
  and every compact width keep the single column. Split math: `UnfoldedSplit`,
  tested in `SoberTests/UnfoldedSplitTests.swift`.
- Folding only moves frames: the `TabView` is never rebuilt. Timeline moves
  between the tab and the pane, so its month, day and unsaved draft live in
  `TimelineSelection`, owned by `MainTabView`. Keep new Timeline state there.
- Each pane's screens get `horizontalSizeClass = .compact`, so they lay out as
  on a phone. Set it on each tab's content, never on the `TabView`: there it
  flipped the Duo's vertical bar to a bottom bar on the first tab switch, with
  no safe-area inset, covering Home's craving card.
- Onboarding unfolded: steps in the right pane, a grown-tree preview on the left.
- Screenshot runs: `-screenshotTour` (DEBUG) walks Home, Health, Journal,
  Bloom+ and Timeline on a timer (unfolded, the last step stays on Home). On
  iOS 27, `simctl openurl` to the app's own scheme stops on an "Open in?"
  alert, so gh-sim's `--url` is only a shot trigger: pass four URLs with an
  unregistered scheme and `--wait 20`. `-QuitZynScreenshot` seeds journal
  entries, moods and cravings and suppresses launch trial pitches and the
  growth celebration overlay. Recipe: `gh-sim all --device 'iPhone Duo'
  --wait 20 --env SOBER_SCREENSHOT_MODE=1 --args "-seedDemo -demoPro
  -seedDays 129 -QuitZynScreenshot -screenshotTour" --url noop://1
  ... --url noop://4`.
