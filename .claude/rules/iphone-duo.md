---
paths:
  - "Sober/App.swift"
  - "Sober/Utilities/UnfoldedSplit.swift"
  - "Sober/Features/Calendar/TimelineView.swift"
  - "Sober/Features/Today/HomeView.swift"
  - "Sober/Features/Onboarding/OnboardingView.swift"
  - "Sober/Features/Health/HealthView.swift"
  - "Sober/Features/Journal/JournalView.swift"
  - "Sober/Features/Paywall/BloomPlusTabView.swift"
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
  on a phone. It is set on each tab's content, not the `TabView` (there it
  flipped the vertical bar to a bottom bar on the first tab switch).
- Unfolded, iOS 27.1 picks the pane's bar placement itself, from one launch
  to the next: a bottom floating bar (63 pt, 20 pt above the edge, no safe
  area) or a vertical bar beside the content (as side safe area). Each tab
  screen applies `.paneTabBarClearance()` *inside* its `NavigationStack`
  (driven by the `clearsPaneTabBar` environment value); outside the stack the
  same padding never reached Home, and the bar covered the craving card. It
  pads by `UnfoldedSplit.tabBarClearance` less any bottom inset, and not at
  all when side insets show a vertical bar. Don't force the placement with
  `toolbarVerticalBehavior(.disabled)`: it inset the root about 42 pt on both
  sides, leaving blank strips at the display edges. Home is a non-scrolling
  stack, so `HomeView.fittedGardenMinHeight` lowers the garden's floor as far
  as the measured space needs (`StackSpace`). DEBUG screenshot runs log
  `HOMELAYOUT` and `PANECLEAR`.
- gh-sim marks `--wait 30` runs `crashed` (exit 1) because the app is gone by
  its end check, though app.log has no crash and the last shot shows the app
  alive. Shorter passes ended clean; keep each pass under about 150 s.
- Onboarding unfolded: steps in the right pane, a grown-tree preview on the left.
- Screenshot runs: `-DuoScreen home|timeline|health|journal|bloom` (DEBUG)
  opens that tab at launch, so gh-sim relaunches once per surface with
  `--screen` and shoots it folded and unfolded. Unfolded, `timeline` lands on
  Home, since Timeline is the right pane. Never use `--url`: on iOS 27.1 any
  custom-scheme openurl raises an "Open in?" alert, and made-up schemes fail
  the run. `-QuitZynScreenshot` seeds journal entries, moods and cravings and
  suppresses launch trial pitches and the growth celebration overlay. Every
  tab root keeps the large title (Health, Journal, Bloom+/Support, Timeline),
  so the panes' headers match. Recipe: `gh-sim all --device 'iPhone Duo'
  --record-seconds 20 --env SOBER_SCREENSHOT_MODE=1 --args "-seedDemo -demoPro
  -seedDays 129 -QuitZynScreenshot" --screen "-DuoScreen home" --screen
  "-DuoScreen health" --screen "-DuoScreen journal" --screen "-DuoScreen
  bloom" --screen "-DuoScreen timeline"`. The older `-screenshotTour` still
  cycles tabs every 16 s for recordings.
