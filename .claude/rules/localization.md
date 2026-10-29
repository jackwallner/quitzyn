---
paths:
  - "Sober/**"
  - "Shared/**"
  - "SoberWatch/**"
  - "SoberWidgets/**"
  - "Tools/Localization/**"
---

# Quit Zyn: localization

The app, widgets and Watch ship in English plus de, ru, cs, sv, fi, nl, es, da,
pl, sk, nb, ro, uk, it and zh-Hans. These languages reflect markets with at
least two new customers in the prior 90 days.

## Setup

- `Shared/Localizable.xcstrings` is the single source-English catalog shared by
  the app, widgets, Watch and tests. Every key is manual. XcodeGen 2.39 or newer
  reads its languages into `knownRegions`; the app, Watch and widget
  `Info.plist` files each declare `CFBundleLocalizations`.
- There is no `InfoPlist.xcstrings`. These targets have no permission-purpose
  strings and the display name is the Quit Zyn brand.
- Run `python3 Tools/Localization/check.py` before builds that change copy. It
  checks source keys, all target languages and format specifiers without Xcode.

## Copy

- SwiftUI text APIs localize literal keys. A string stored in a model, catalog,
  notification, service result or view parameter must use `String(localized:)`.
  Logs, analytics, RevenueCat identifiers, stored tags and storage keys remain
  plain English values.
- Keep complete sentences and labels as keys. Do not join translated sentence
  fragments. Use plural variations for counted nouns, including one, few and
  many in Russian, Czech, Polish, Slovak and Ukrainian. Romanian uses one, few
  and other. Keep the English plural variations in the catalog too.
- Translate stored trigger tags through `HabitVocabulary.triggerLabel(_:)`
  and journal feeling tags through `JournalEntry.feelingLabel(_:)`. Never
  migrate a saved tag to a translated value.
- Use Foundation formatters for dates, numbers, measurements, durations and
  currency. Subscription prices come from StoreKit. Trial length comes from
  `soberIntroOfferDays`, not by parsing display copy.
- Keep Quit Zyn, Bloom+, NIAAA, CDC, ACS, AHA, NCI and Truth Initiative names.
  Translate habit terms for the local market: German uses Nikotinbeutel, Swedish
  uses portionssnus or nikotinpåsar, Finnish uses nikotiinipussit, and other
  languages should use their familiar nicotine pouch or snus term. Use
  informal address in German, and follow common Health & Fitness usage in each
  other market.
- Preserve every qualification in health copy. Do not translate tracking or
  recovery milestones as claims to treat, cure, diagnose or prevent illness.
  Keep the full wellness disclaimer.
- Check German, Finnish and Russian first on compact rows such as tabs, badges,
  buttons, plan cards and widgets. Keep those translations at or below the
  English length where possible.

## Proof

`SoberTests/LocalizationTests.swift` verifies every compiled `.lproj`, Russian
plural selection and translated German copy. The `gh-sim` verification recipe
is in the root guide. Do not set the production RevenueCat key for simulator
runs.
