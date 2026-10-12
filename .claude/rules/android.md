---
paths:
  - "android/**"
  - "scripts/sync-android-*"
  - "scripts/android-*"
  - "scripts/play-*"
  - "scripts/play_screenshot_compositor.py"
  - "scripts/make_android_icon.py"
---

# Quit Zyn Android rules

## Product

- Native port in `android/`: Kotlin, Compose, Gradle Kotlin DSL, JDK 17,
  minSdk 26, target/compile 36. Package and namespace `com.jackwallner.quitzyn`
  (permanent once uploaded), launcher label "Quit Zyn", Play title
  "Quit Zyn: Pouch & Snus Tracker". Version name follows iOS `MARKETING_VERSION`.
- Built from Sober's Android port (`~/sober/android`, shipped 2026-10-10), the
  same way this iOS app forks Sober. Kotlin type names stay `Sober*` to match
  the iOS low-churn fork. When Quit Zyn's iOS code changes, port the change; when
  Sober's Android port fixes something shared, check whether it applies here.
- Screen-for-screen port of Quit Zyn iOS, not of Sober: six-step onboarding
  (can card, reminder hour, pledge), the older paywall plus the small
  `TrialOfferSheet` for pitches, pouch/nicotine savings, no milestone-eve or
  lapse nudges, no history line or trial-recap banner on Home, review prompt
  gates 5 launches / 7 days / 3 moments, nudge cooldown 20h/28h/44h/4d/7d.
- Content is exported from Swift, never retyped: `scripts/sync-android-content.sh`
  (`scripts/android-export/main.swift` -> `quitzyn-content.json`). The exporter
  replaces each nicotine milestone's copy with non-medical Play wording keyed by
  id; a new milestone id fails the export until it gets reviewed copy. The bonsai
  renderer is identical to Sober's; `scripts/sync-android-bonsai.py` refreshes
  its fixtures. `PortParityTest`, `SoberEngineTest` and `BonsaiParityTest` pin parity.
- Intentional Android differences: Play In-App Review with no enjoyment question
  (Settings has separate Rate and Send Feedback rows); Settings shows cost per
  day with cents; Play cancellation wording; no Watch app; Glance widget.
- Reminders: `AlarmManager.setWindow` (15 min) re-armed on delivery. Onboarding
  schedules the daily reminder from `graph.scope`, because the screen leaves
  composition the moment onboarding completes.

## Billing

- RevenueCat project `proj42f37ce2` "Quit Zyn Android" (separate from iOS
  `proj8395c8fc`). Play app `appe15e6cbf94`, Test Store app `app4f5a8ab85b`.
  Entitlement `pro` (`entl427e85db88`), offering `android` (`ofrng671e306bb3`)
  with `$rc_monthly`, `$rc_annual`, `$rc_lifetime`. Test Store products carry
  no trial (the API rejects trial durations), so a Test Store run resolves
  onboarding as unavailable; use `--ez previewStore true` to see the trial flow.
- Debug uses the Test Store key; release uses `goog_`. Keys, upload keystore
  (`~/.android/keystores/quitzyn-upload.p12`, alias `upload`) and
  `PLAY_REVIEW_CODE_SHA256` live in ignored `android/local.properties`; the
  review code and keystore password are in `~/.quitzyn_credentials`.
- Android US ladder $6.99 / $27.99 / $63.99 (about 20% under iOS $8.99 /
  $34.99 / $79.99), 7-day trial offer `trial-7d` on both subscriptions, local
  prices = Play conversion then the fleet PPP curve, via `scripts/play-products.py`.
- Play reviewers unlock Bloom+ by long-pressing Settings > About > Version and
  entering the review code (hash-checked in release).

## Release

- Listing text and graphics: `android/play-assets/metadata/android/<locale>/`
  (fastlane supply layout, 50 locales, checked by `scripts/validate-play-listing.py --app quitzyn`); see `android/play-assets/listing-en-US.md`
  for policy answers and Data safety.
- Bundles: `PLAY_SERVICE_ACCOUNT_JSON=~/.config/google-play/mahj-service-account.json
  ./scripts/play-upload.sh internal-draft`. Bump `versionCode` before every upload.
- Play Console: E3 Apps account `8314164911785412040`, app `4973378888882968817`.
  Managed publishing is OFF. The shared `revenuecat-service-account` has
  app-level access to Quit Zyn (same nine permissions as Sober) and is the
  RevenueCat Play credential (validated 2026-10-11).
- State 2026-10-11: versionCode 1 (1.2.7) live on internal testing (tester list
  "IM Iron Splits internal testers"), store listing in 13 locales, every App
  content declaration, IARC rating (ESRB Teen for the tobacco references, 3+ in most other regions),
  products active. 2026-10-11: listing text expanded to 50 locales and staged
  over the API (changes not sent for review). 20+ changes sit unsubmitted in Publishing overview: nothing
  has been sent for review. Before production review, Jack pastes the reviewer
  code into App content > Sign in details (Password field; the instructions
  entry is already saved) and sends the changes from Publishing overview.
- Verified 2026-10-11 on the Play AVD (`small_phone`, Jack's license-tester
  account): Play-installed 1.2.7 showed the real 7-day trial at $27.99 / year,
  the Play sheet offered the test card ("You will not be charged"), the yearly
  trial started and unlocked Bloom+, RevenueCat shows a `play_store` sandbox
  `trialing` subscription with `pro` active, and after clearing app data the
  entitlement came back and Restore Purchases kept it. That account now owns a
  test yearly subscription; do not buy it again. Pre-launch reports are not
  generated for the internal track. Google developer notifications (RTDN) are
  not connected in RevenueCat.

## Emulator (remote Pro only)

- Never boot an emulator on this Mac. Pro is `jackwallner@192.168.4.25`
  (BatchMode, strict host key), SDK `/Users/jackwallner/Library/Android/sdk`.
- `small_phone` (port 5554) is the Play AVD with an account: preserve it.
  Debug work uses a temporary config-only AVD `quitzyn_agent_test` on port 5560
  (`emulator-5560`), created by copying `small_phone.avd/config.ini` as in
  `~/ironman/.claude/rules/android.md`, then set to 1080 x 2400 at 420 dpi so
  captures match the Play compositor. Stop it with `adb -s emulator-5560 emu kill`
  on Pro, then delete only `~/.android/avd/quitzyn_agent_test.avd` and `.ini`.
- Connected tests: `scripts/android-connected-tests.sh` builds here, installs on
  Pro, and runs each UI Automator test with `pm clear` between (the orchestrator
  cannot reach its service on the API 36.1 image, and Compose's test rule fails
  there). It fails on any failure or a zero executed count.
- Debug launch extras (debug build only): `resetAll`, `seedDemo`, `seedDays`,
  `demoPro`, `previewStore`, `previewTrialDays`, `previewTrialUsed`,
  `seedCravings`, `tab`, `onboardingStep`, `craving`, `slip`, `showProgress`,
  `gallery`, `testReminderIn`, `uiTest` (see `DebugLaunchOptions.kt`).
