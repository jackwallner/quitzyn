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
- Unfolded, iOS 27.1 sometimes moved the pane's toolbars and tab bar into a
  vertical bar beside the fold and sometimes drew a bottom floating bar
  (63 pt, 20 pt above the edge, no safe area), from one launch to the next.
  While split, `horizontalBarsInPane` (`toolbarVerticalBehavior(.disabled)`)
  keeps every bar horizontal so the layout is the same each time; folded
  stays `.automatic`. Each tab screen applies `.paneTabBarClearance()`
  *inside* its `NavigationStack` (driven by the `clearsPaneTabBar`
  environment value): the same padding outside the stack never reached Home's
  content, and the bar covered the craving card. It pads by
  `UnfoldedSplit.tabBarClearance` less any inset the system gives. Home is a
  non-scrolling stack, so `HomeView.fittedGardenMinHeight` lowers the
  garden's floor as far as the measured space needs (`StackSpace`). DEBUG
  screenshot runs log `HOMELAYOUT` and `PANECLEAR`.
- gh-sim marks `--wait 30` runs `crashed` (exit 1) because the app is gone by
  its end check, though app.log has no crash and the last shot shows the app
  alive. Both `--wait 20` runs before it ended clean, so captures use 20.
- Onboarding unfolded: steps in the right pane, a grown-tree preview on the left.
- Screenshot runs: `-screenshotTour` (DEBUG) walks Health, Journal, Bloom+
  and Timeline on a per-pose schedule timed for `--wait 20` (unfolded, the
  last step stays on Home). Measured: folded shots start 15 to 18s after the
  tour starts, unfolded 24 to 28s, then 22.5 to 24s apart. On iOS 27, `simctl openurl` to
  the app's own scheme stops on an "Open in?" alert, so gh-sim's `--url` is
  only a shot trigger: pass four URLs with an unregistered scheme.
  `-QuitZynScreenshot` seeds journal entries, moods and cravings and
  suppresses launch trial pitches and the growth celebration overlay. Recipe:
  `gh-sim all --device 'iPhone Duo' --wait 20 --record-seconds 60 --env
  SOBER_SCREENSHOT_MODE=1 --args "-seedDemo -demoPro -seedDays 129
  -QuitZynScreenshot -screenshotTour" --url noop://1 ... --url noop://4`.
