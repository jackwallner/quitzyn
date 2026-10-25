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

# Quit Zyn: iPhone Duo (2026-10-21, strip 2026-10-25)

- Unfolded (regular width, at least 720 pt), `MainTabView` puts the tab view
  (Home, Health, Journal, Bloom+) left of the fold and Timeline in its own
  pane on the right; the Timeline tab drops out while split. Pane edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division)`), else an even split. Portrait unfolded (669 pt)
  and every compact width keep the single column. Split math: `UnfoldedSplit`,
  tested in `SoberTests/UnfoldedSplitTests.swift`.
- iOS 27.1 reserves about 64 pt down the unfolded display's trailing edge
  (the clock and battery ring around the camera). A List keeps clear of it
  even under `ignoresSafeArea`, and neither the stack's geometry proxy nor the
  key window reported it (runs R1 to R3, 2026-10-23); measuring a row to pad
  the fold side to match still failed review. So in its pane Timeline draws
  the same sections as cards in a `ScrollView` under
  `ignoresSafeArea(.container, edges: .trailing)`, which runs into the column
  and leaves equal margins on both sides (2026-10-24).
- In its pane (`\.isTimelinePane`), Timeline draws the selected day's tree
  as a 96 pt thumbnail beside its caption: the 200 pt scene started near the
  display's bottom edge and showed only empty sky.
- Folding only moves frames: the `TabView` is never rebuilt. Timeline moves
  between the tab and the pane, so its month, day and unsaved draft live in
  `TimelineSelection`, owned by `MainTabView`. Keep new Timeline state there.
- Each pane's screens get `horizontalSizeClass = .compact`, so they lay out as
  on a phone. It is set on each tab's content, not the `TabView` (there it
  flipped the vertical bar to a bottom bar on the first tab switch).
- Unfolded, the system tab bar is hidden and `PaneTabStrip` heads the
  leading pane (`UnfoldedSplit.paneTabStripHeight`), so both panes run to the
  display's bottom edge. iOS 27.1 picked a floating bottom bar or a vertical
  bar per launch, and review rejected every bottom bar layout: the pane's last
  row was always cut above the glass, faded or not (2026-10-23 to 10-24). The
  strip names every tab when they fit, else only the open one
  (`ViewThatFits`). Don't force the bar with
  `toolbarVerticalBehavior(.disabled)`: it inset the root about 42 pt on both
  sides.
- The status column's 84 pt trailing inset reaches the leading pane's
  `NavigationStack`s too, though the column sits past the fold, so content
  stopped short of the fold. Each tab root applies `.leadingPaneEdge()`
  *inside* its stack (on the `TabView` or outside the stack it did nothing).
  An inset-grouped List under it loses its trailing margin, so list roots
  pass `isList: true` for 20 pt content margins on both sides.
- Home's bar items stand in a vertical column down the leading pane's
  trailing edge, squeezing the garden. In the leading pane Home hides its
  navigation bar and draws Progress and More as 44 pt circles flanking the
  counter. `HomeView.fittedGardenMinHeight` lowers the garden's floor as far
  as the measured space needs (`StackSpace`); DEBUG screenshot runs log
  `HOMELAYOUT`.
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
