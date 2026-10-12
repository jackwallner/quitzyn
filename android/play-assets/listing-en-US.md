# Quit Zyn: Google Play listing (en-US)

Source of truth for the Play Console store listing. Adapted from
`fastlane/metadata/` for the Android build (no Watch app; home-screen widget;
Google Play billing and cancellation wording). No prices in copy: Play shows them.

## Listing text

Title, short and full description per locale live in
`metadata/android/<locale>/` (fastlane supply layout), uploaded with:

    fastlane supply --json_key <service account> --package_name com.jackwallner.quitzyn \
      --metadata_path android/play-assets/metadata/android --track internal \
      --skip_upload_apk true --skip_upload_aab true --skip_upload_changelogs true --sync_image_upload true

Text only, staged without sending for review (how the 50-locale listing went up):
add `--skip_upload_images true --skip_upload_screenshots true
--changes_not_sent_for_review true` and drop `--track`/`--sync_image_upload`.

Locales (50): en-US (default), en-GB/AU/CA/IN, de-DE, fr-FR/CA, es-ES/419/US,
pt-BR/PT, it-IT, nl-NL, sv-SE, no-NO, da-DK, fi-FI, pl-PL, cs-CZ, sk, sl, hr,
hu-HU, ro, el-GR, tr-TR, ru-RU, uk, ar, iw-IL, hi-IN, bn-BD, mr-IN, ta-IN,
te-IN, kn-IN, ml-IN, id, ms/ms-MY, th, vi, ja-JP, ko-KR, zh-CN/TW/HK, ca.
Nordic titles follow the iOS snus titles; other localized titles use generic
"snus" and "nicotine pouches" terms, never another brand.
Every localized description says the app is in English. Every description ends
with the not-medical-advice line and the ZYN non-affiliation line. No prices,
no em dashes, no medical claims. `scripts/validate-play-listing.py --app quitzyn`
checks limits and these rules before any upload. Graphics are en-US only.

## Graphics

- App icon: `icon-512.png` (512 x 512), from the iOS icon (`scripts/make_android_icon.py`)
- Feature graphic: `feature-graphic.png` (1024 x 500)
- Phone screenshots: `screenshots/` (1080 x 1920), raw captures in `raw/` from
  the debug build on the Pro AVD (status bar in demo mode), composited by
  `scripts/play_screenshot_compositor.py` with the App Store set's headlines,
  copied into `metadata/android/en-US/images/`. No health or paywall shot.

## Store settings

- Category: Health & Fitness. Tags: addiction recovery, habit tracking.
- Contact email: jackwallner+qz@gmail.com. Website: https://jackwallner.github.io/quitzyn/
- Privacy policy: https://jackwallner.github.io/quitzyn/android-privacy.html

## Products

| Play product | Type | Base plan / offer | RevenueCat package |
|---|---|---|---|
| `com.jackwallner.quitzyn.pro.monthly` | Subscription | base plan `monthly` (P1M), offer `trial-7d` (P1W free, new customers) | `$rc_monthly` |
| `com.jackwallner.quitzyn.pro.yearly` | Subscription | base plan `yearly` (P1Y), offer `trial-7d` (P1W free, new customers) | `$rc_annual` |
| `com.jackwallner.quitzyn.pro.lifetime` | One-time product | buy option `lifetime` | `$rc_lifetime` |

Android US ladder $6.99 / $27.99 / $63.99, about 20% under iOS ($8.99 / $34.99
/ $79.99), matching Sober's Android discount. Local prices are Play's
conversion of the US price, then the fleet PPP curve, all set by
`scripts/play-products.py`. The iOS RevenueCat project `proj8395c8fc` is untouched.

## Policy answers (from the code)

- Ads: no. App access: everything without an account. Reviewer access to
  Bloom+: long press Settings > About > Version, enter the private code
  (`QUITZYN_PLAY_REVIEW_CODE` in `~/.quitzyn_credentials`), tap Unlock.
- Target audience: 18+ only (nicotine cessation).
- Content rating: references to tobacco/nicotine in a quitting context; no
  violence, sexuality, gambling, user-generated sharing, or location.
- Health apps declaration: addiction and substance-use support (quit tracking,
  general wellness information with sources). Not a medical device; no Health
  Connect access.
- Data Safety: collected by the RevenueCat SDK only. Financial info > Purchase
  history; App activity > App interactions (purchase-screen counts, app-open
  counts, funnel step counts); Device or other IDs (RevenueCat's anonymous app
  user ID, not a hardware or advertising ID). Purposes: app functionality and
  analytics. Encrypted in transit. Not shared (RevenueCat is a service
  provider). Not optional. Deletion by email request. Quit records, journal,
  cravings and settings never leave the device.
- Notifications: optional daily reminder and trial heads-up; permission asked
  after onboarding's pledge, when the reminder is turned on, or when a trial starts.
