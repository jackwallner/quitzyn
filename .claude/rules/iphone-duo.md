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
- Each pane gets `horizontalSizeClass = .compact`, so it lays out as on a phone
  and the tab bar stays a bottom bar inside the left pane.
- Onboarding unfolded: steps in the right pane, a grown-tree preview on the left.
- Screenshot runs: `quitzyn://home|timeline|health|journal|bloom` selects a tab
  (unfolded, `timeline` lands on Home since Timeline is always showing).
  `-QuitZynScreenshot` seeds journal entries, moods and cravings and suppresses
  launch trial pitches and the growth celebration overlay. gh-sim recipe:
  `gh-sim all --device 'iPhone Duo' --env SOBER_SCREENSHOT_MODE=1 --args
  "-seedDemo -demoPro -seedDays 129 -QuitZynScreenshot" --url quitzyn://health ...`
