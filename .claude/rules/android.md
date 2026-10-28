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
  from the 2nd launch with a 30-day cooldown (feedback never stops it), nudge
  cooldown 20h/28h/44h/4d/7d.
- Content is exported from Swift, never retyped: `scripts/sync-android-content.sh`
  (`scripts/android-export/main.swift` -> `quitzyn-content.json`). The exporter
  replaces each nicotine milestone's copy with non-medical Play wording keyed by
  id; a new milestone id fails the export until it gets reviewed copy. The bonsai
  renderer is identical to Sober's (see Bonsai parity); `scripts/sync-android-bonsai.py`
  refreshes its fixtures. `PortParityTest`, `SoberEngineTest` and `BonsaiParityTest` pin parity.
- Intentional Android differences: Play In-App Review with no enjoyment question
  (Settings has separate Rate and Send Feedback rows); Settings shows cost per
  day with cents; Play cancellation wording; no Watch app; Glance widget.
- Reminders: `AlarmManager.setWindow` (15 min) re-armed on delivery. Onboarding
  schedules the daily reminder from `graph.scope`, because the screen leaves
  composition the moment onboarding completes.

## Bonsai parity

- The garden's bonsai is a Kotlin port of `Shared/Bonsai/{BonsaiRenderer,BonsaiPaint,BonsaiScene,BonsaiWind}.swift`
  in `android/app/src/main/java/com/jackwallner/quitzyn/ui/bonsai/`
  (`BonsaiRenderer.kt`, `BonsaiPaint.kt`, `BonsaiScene.kt`, `BonsaiWind.kt`, `BonsaiMath.kt`,
  `BonsaiGraphics.kt` geometry, `BonsaiView.kt` Compose). Keep the Swift operation order. Math goes
  through the StrictMath wrappers in `BonsaiMath.kt` and Swift's `.rounded()` is `swiftRounded()`.
  Path booleans (`union`, `intersection`, `subtracting`) stay lazy in `BonsaiPath` and are combined
  once per scene with Compose `PathOperation`. The scene is recorded once per (style, day, detail,
  vitality) and replayed each frame; only the wind (bend, drift, limb stretch, petals) is per frame.
  The scene is built off the main thread in `BonsaiView`; the wind clock is `rememberWindClock()`.
- Parity guard. `scripts/sync-android-bonsai.py` (macOS, Xcode) compiles the real Swift with
  `scripts/android-bonsai/export-main.swift` and records, per scene, each layer's ink, clip chain,
  wind motion and coverage of a 2 unit sampling grid (count and centroid), plus the wind math, into
  `android/app/src/test/resources/bonsai/` with a manifest of the SHA-256 of every
  `Shared/Bonsai/*.swift` file. `BonsaiParityTest` fails when any of those Swift files changes
  (`swiftBonsaiFilesMatchManifest`), compares the Kotlin scenes to the recording within a small tolerance
  (`scenesMatchSwift`), and compares the wind math tightly (`windMathMatchesSwift`).
- When Swift bonsai changes: 1. port it to Kotlin, 2. run `scripts/sync-android-bonsai.py`,
  3. `fm-gradle -p android testDebugUnitTest`, 4. look at the compare images below. Re-recording
  without porting fails `scenesMatchSwift`; do not loosen the tolerance or re-pin the manifest to
  get green.
- Not in the fixtures: airborne petals and leaves (their paths move every frame, only the wind math
  is pinned) and anti-aliasing. Check them by eye. Debug launch extras
  `--ez gallery true --es galleryStyle sakura --ei galleryDay 365 [--ei galleryWindMs 1400]` draw one
  320 dp tree on white, framed like `Tools/BonsaiAudit --mode=render --config=home320 --days=365
  [--wind=1400]`. Screenshot it on the emulator, scale the iOS render to the same size and put them
  side by side in `android/build/bonsai-compare/` (gitignored). The 2026-10-27 port matched iOS at
  ink overlap 0.977 or better on every style at days 7, 30, 90 and 365.
- GitHub-built debug APKs use a new debug keystore each run, so `adb uninstall` before
  reinstalling. The software-GL emulator needs 20 to 45 s after launch to draw the first frame; take
  the screenshot late, and retake a blank one.

## Billing

- Moving into the iOS project (2026-10-27): Play app `appadb46ee842` in `proj8395c8fc` has the Play products on entitlement `Quit Zyn Pro` and a non-current `android` offering. The next release swaps `REVENUECAT_PLAY_KEY` to that app's `goog_` key, and the code syncs existing Play purchases once (`SYNCED_TO_SHARED_PROJECT`) so old-project trials keep access. Upload the service-account JSON to that app first. Until then the release ships the old key below.
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
- Live in Play production since 2026-10-20 (public page 200). The next bullet is the
  2026-10-11 internal-testing history, kept for the checks it records.
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
- Connected tests: `scripts/android-connected-tests.sh` builds with
  `fm-gradle`, installs on Pro, and runs each UI Automator test with
  `pm clear` between (the orchestrator cannot reach its service on the API 36.1
  image, and Compose's test rule fails there). It fails on any failure or a
  zero executed count.
- Debug launch extras (debug build only): `resetAll`, `seedDemo`, `seedDays`,
  `demoPro`, `previewStore`, `previewTrialDays`, `previewTrialUsed`,
  `seedCravings`, `tab`, `onboardingStep`, `craving`, `slip`, `showProgress`,
  `gallery`, `galleryStyle`, `galleryDay`, `galleryWindMs`, `testReminderIn`, `uiTest` (see `DebugLaunchOptions.kt`).
- When Pro is overloaded (load above 10, the emulator's watchdog kills it) the iMac (`ssh imac`,
  Ubuntu, KVM) has the idle `agent-emu-1` AVD: start it on port 5560 with
  `$HOME/Android/sdk/emulator/emulator -avd agent-emu-1 -port 5560 -no-window -no-audio
  -no-boot-anim -no-snapshot-save -gpu swiftshader_indirect` under `setsid nohup`, drive it with
  `$HOME/Android/sdk/platform-tools/adb` over ssh, and stop it with `adb -s emulator-5560 emu kill`.
  Leave `mahj-live` (port 5556) alone.
