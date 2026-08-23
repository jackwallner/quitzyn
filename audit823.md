# Quit Zyn audit 823

## Audit metadata

- Scope: Quit Zyn only, repository /Users/jackwallner/nicfree.
- Review date: 2026-08-23.
- Review mode: fresh max-reasoning rerun.
- Deliverable: this file only.
- Change boundary: read-only inspection. No app code, configuration, ASC, RevenueCat, website, metadata, or automation files were changed. No build, upload, notification deployment, commit, or push was performed.
- Evidence notation:
  - Verified means directly observed in the local repository or in the available signed-in ASC and RevenueCat context.
  - Inference means a risk or opportunity derived from verified implementation, and it still needs runtime or dashboard validation.
  - Recommendation means proposed work for a later implementation agent.
- Health and wellness boundary: recommendations below must not introduce claims that Quit Zyn treats, cures, prevents, or diagnoses nicotine dependence or another condition. Prefer educational and general-wellness wording, source dates, individual-variation language, and a clear not-medical-advice notice.
- Deliberately excluded: inconsistencies about RevenueCat and data-collection disclosure wording. That area was explicitly out of scope for this audit.

## Executive disposition

Quit Zyn has a solid core activation loop: a one-tap daily check-in, a visible garden, a health timeline, local persistence, watch and widget surfaces, a trial-first purchase path, restore support, and a guarded review prompt. The largest near-term risk is not a missing feature. It is that several release, price, free-tier, and marketing sources disagree. An implementation agent could make a correct change in one source and ship a contradictory experience from another.

The three urgent issues are:

1. Release and catalog truth is split. The live ASC context shows app ID 6784788496, status Ready for Distribution, version 1.2.3. The local XcodeGen project says marketing version 1.2.4 and build 28. Local ASC state says a different live version, and several ASC writer scripts still encode old prices.
2. An App Store purchase that returns pending is treated as onboarding completion in the onboarding flow. The service correctly distinguishes pending from purchased, but the onboarding caller records pending and finishes immediately. This can leave a user in an unclear state after asking for a trial or subscription.
3. Store recovery can delete the persistent SwiftData store and fall back to in-memory storage without a user-visible recovery state. This can avoid a launch crash while silently losing local history. It also makes a production regression harder to detect.

Recommended order:

| Priority | Focus | Why it matters |
| --- | --- | --- |
| P0 | Reconcile ASC, RevenueCat, StoreKit, project version, metadata, website, review notes, and price writers | Prevents wrong price disclosures, failed purchases, review confusion, and release automation drift |
| P0 | Make pending purchase handling durable and explicit | Prevents a trial or purchase attempt from being mistaken for a completed entitlement |
| P0 | Instrument and surface store recovery and persistence failures | Protects the primary user history and gives a watchdog a signal before support volume rises |
| P1 | Correct the free-health-benefit count across code, site, support, and structured data | Removes a direct expectation mismatch in the acquisition and paywall funnel |
| P1 | Split conversion events and paywall impressions by semantic meaning, entry point, package, and variant | Makes trial-start, paywall, and purchase experiments trustworthy |
| P1 | Correct translated ASO copy that describes alcohol sobriety instead of nicotine-pouch cessation | Protects relevance, trust, and conversion in affected storefronts |
| P1 | Consolidate duplicate metadata, website, release-state, and agent documentation sources | Reduces the chance that a future agent acts on stale instructions |
| P1 | Review health timeline claims and all trial disclosures for App Review and consumer clarity | Reduces compliance and refund risk while keeping the wellness positioning |
| P2 | Test onboarding friction, paywall defaults, review timing, reminder opt-in, and accessibility | Improves conversion after the truth and reliability issues are fixed |

## 1. Observed identity and release status

### Verified identity

| Item | Evidence | Assessment |
| --- | --- | --- |
| ASC app | Available ASC context: Quit Zyn: Pouch & Snus Tracker, app ID 6784788496 | Matches local app links and review URL |
| Live ASC status | Available ASC context: Ready for Distribution | Treat as current for this audit snapshot |
| Live ASC version | Available ASC context: 1.2.3 | Conflicts with local project version |
| Local XcodeGen marketing version | project.yml:10-16, MARKETING_VERSION: 1.2.4 | Likely intended next release, but not proven to be uploaded |
| Local build | project.yml:10-16, build 28 | Must be paired with an ASC build lookup before release |
| Internal project name | project.yml:1, name: Sober | Internal naming is intentional, but it leaks into some docs and log namespaces |
| iOS bundle ID | project.yml:46-55, com.jackwallner.quitzyn | Matches CLAUDE.md and website identity |
| watch bundle ID | project.yml watch target and CLAUDE.md, com.jackwallner.quitzyn.watch | Verify that the submitted watch build belongs to the same version train |
| widget bundle ID | project.yml widget target and CLAUDE.md, com.jackwallner.quitzyn.widgets | Verify extension versioning with the iOS build |
| App Group | group.com.jackwallner.quitzyn in CLAUDE.md and project settings | Core to widget, watch, and conversion state sharing |
| RevenueCat project | Available RevenueCat context: project Quit Zyn, project ID 8395c8fc | App-specific live metrics were not captured |
| App Store review URL | Shared/Utilities/AppStoreReviewLinks.swift:4-17 | Uses app ID 6784788496 and storefront-aware links |
| Marketing URLs | fastlane/metadata/*/support_url.txt, marketing_url.txt, privacy_url.txt | Store metadata points to GitHub Pages while HTML canonical points to jackwallner.com |

### Release-state conflicts

scripts/.asc-state.json reports:

- app ID 6784788496
- draft version 1.2.3
- live version 1.0
- updated at 2026-08-11

That local state is inconsistent with the available live ASC context showing version 1.2.3 Ready for Distribution, and with project.yml targeting 1.2.4 build 28. It should be treated as stale machine state, not as proof of the current ASC state.

scripts/.astro-app.json contains the correct Quit Zyn app ID and bundle ID but is machine-generated state and was already modified before this audit. It was not changed. Do not use it as the only release source of truth.

### P0 release truth reconciliation

Before another release, establish one read-only comparison report containing:

1. ASC app version, editable version, live version, build numbers, review status, and territories.
2. ASC subscription product IDs, prices, introductory-offer eligibility, availability, and review metadata.
3. RevenueCat offering identifier, package identifiers, entitlement identifier, product IDs, price display, and trial eligibility as returned by the production project.
4. Sober.storekit product IDs, local prices, and trial configuration.
5. SubscriptionService product and entitlement identifiers.
6. project.yml version and build.
7. Store metadata description, promotional text, screenshots, review notes, website JSON-LD, visible website pricing, support copy, terms, and privacy links.

Acceptance criteria for a later implementation:

- Every product ID appears in all expected sources exactly once or is deliberately documented as environment-specific.
- The production price and introductory offer shown by RevenueCat, ASC, the in-app disclosure, and the review notes are either the same or explicitly region-dependent.
- A single release manifest records the version and build. Stale state files are regenerated or clearly marked as derived and disposable.
- A dry-run preflight fails with a path-specific message when the sources disagree.

## 2. Download and App Store acquisition audit

### Current listing evidence

The US metadata files contain:

- Name: fastlane/metadata/en-US/name.txt:1, Quit Zyn: Pouch & Snus Tracker
- Subtitle: fastlane/metadata/en-US/subtitle.txt:1, Stop Nicotine Pouches & Dip
- Keywords: fastlane/metadata/en-US/keywords.txt:1, a 94-character nicotine-pouch, dip, streak, craving, and vaping term set
- Promotional text: fastlane/metadata/en-US/promotional_text.txt:1, focused on quitting pouches, snus, and dip, then tracking days and savings
- Marketing URL: fastlane/metadata/en-US/marketing_url.txt:1
- Support URL: fastlane/metadata/en-US/support_url.txt:1
- Privacy URL: fastlane/metadata/en-US/privacy_url.txt:1
- Description: fastlane/metadata/en-US/description.txt:1, includes free and Pro sections and says prices are shown before purchase

The local ASO structural report at scripts/aso-locale-verification-report.json reports no structural issues. That verifies file presence and format constraints, not translation quality, search demand, impression share, or conversion.

The live ASC app name observed in context matches the US metadata name. The app ID in the website, review links, and local ASC scripts also matches 6784788496.

### Acquisition gaps

No reliable Quit Zyn-specific download, product-page-view, conversion, trial-start, trial-to-paid, rating-count, or proceeds metrics were captured in the available context. The RevenueCat numbers visible in context were fleet-level aggregate values, not Quit Zyn values, so they must not be used as app performance.

A later agent should capture the following before choosing ASO or paywall winners:

| Question | Read-only source | Required breakdown |
| --- | --- | --- |
| Are impressions becoming product-page views? | ASC App Analytics, Acquisition | App version, storefront, source, date, device |
| Are product-page views becoming downloads? | ASC Acquisition | Product page conversion, first-time versus redownload |
| Which terms or sources produce quality users? | ASC Acquisition and any campaign links | Source, locale, version, trial start, retained activation |
| Does the trial start after install? | ASC subscription and RevenueCat customer data | Trial starts by product, offer, entry point, version |
| Does a trial become paid? | ASC subscription events and RevenueCat | Intro offer, product, cohort, cancel, renewal, expiration |
| Do downloads become first check-ins? | App event instrumentation, not currently complete | Install, onboarding completion, first check-in, day-7 return |
| Which paywall entry converts? | RevenueCat and local event stream | Onboarding, Bloom tab, locked feature, post-check-in, passive nudge |

Recommended acquisition scorecard:

1. Product-page conversion.
2. Download to onboarding start.
3. Onboarding completion.
4. First check-in within 24 hours.
5. Trial offer reached, only when an eligible trial offer was actually displayed.
6. Trial CTA tapped.
7. Purchase started.
8. Purchase completed or entitlement activated.
9. Day-2 and day-7 return.
10. Refund, cancellation, and review prompt outcomes.

Do not use a single aggregate paywall conversion number until the event-definition issues in section 5 are fixed.

### Screenshot inventory

fastlane/screenshots contains 50 locale directories. The observed inventory has six screenshots in most locales, five iPhone 6.7-inch assets and one Apple Watch 46mm asset, while en-US has 12 assets. This may be intentional, but it creates a selection and ordering risk.

Validate:

- Which six US assets ASC actually selects.
- Whether the extra six US assets are old, alternate, or duplicate frames.
- Whether the Apple Watch screenshot is useful in the first search result impression or should be moved after the strongest iPhone sequence.
- Whether every screenshot uses the current price and free-tier messaging.
- Whether localized screenshots contain text that is translated separately from the metadata.
- Whether the watch screenshot is presented only where a watch feature is available and understandable.

The website root references screenshot-1-counter.png through screenshot-6-species.png in index.html:601-616. Verify that these images match the current app build and not a prior UI.

### Metadata opportunities

These are hypotheses, not proven winners:

- Keep the title and subtitle specific to nicotine pouches, snus, dip, and a trackable nicotine-free streak. Avoid replacing high-intent nicotine terms with generic habit language.
- Test a subtitle focused on the first job users want, such as tracking nicotine-free days, against the current “Stop Nicotine Pouches & Dip” wording.
- Test promotional text that leads with the first successful check-in and garden feedback instead of the entire feature list.
- Test whether “pouch and snus tracker” is clearer than a title that requires the user to know “Zyn” as the category term.
- Validate the word “withdrawal” and all health outcome language with App Review and wellness compliance review before preserving it in keyword or description text.
- Use campaign links and cohort tracking before judging a metadata variant. Search impressions alone will not show whether the resulting users start trials or complete the first check-in.

## 3. Locale and metadata quality

### High-confidence translation and audience errors

Several localized descriptions use alcohol sobriety language or “without drinking” wording, even though the product is for nicotine pouches, snus, dip, and related nicotine use.

| Locale | Evidence | Risk |
| --- | --- | --- |
| Croatian | fastlane/metadata/hr/description.txt:1, uses sobriety wording and a sobriety calendar phrase | Wrong category signal and loss of trust |
| Slovak | fastlane/metadata/sk/description.txt:1, uses sober or sobriety wording | Wrong category signal |
| Greek | fastlane/metadata/el/description.txt:1, uses a sobriety term | Wrong category signal |
| Ukrainian | fastlane/metadata/uk/description.txt:1, uses a sobriety term and sobriety calendar wording | Wrong category signal |
| Malay | fastlane/metadata/ms/description.txt:1, ends with wording meaning every day without drinking | Alcohol product implication |
| Vietnamese | fastlane/metadata/vi/description.txt:1, ends with wording meaning every day without drinking | Alcohol product implication |
| Indonesian | fastlane/metadata/id/description.txt:1, ends with wording meaning every day without drinking | Alcohol product implication |
| Turkish | fastlane/metadata/tr/description.txt:1, uses a sober-day phrase | Wrong category signal |
| Russian | fastlane/metadata/ru/description.txt:1, contains malformed nicotine-free wording and a malformed calendar phrase | Grammar and trust risk |

This is a P1 acquisition issue. Have a native reviewer rewrite each affected description and all associated subtitle, keyword, promotional, screenshot, and release-note text. Do not perform a literal machine substitution of “alcohol” with “nicotine”. Preserve the intended nicotine-pouch context and check claims sentence by sentence.

Validation:

- Search every locale for alcohol terms, sobriety terms, drinking terms, and references to an alcohol calendar.
- Search for “nicotine”, “pouch”, “snus”, “dip”, or the locally appropriate category terms in every description.
- Have a native reviewer classify the app category from only the title, subtitle, and first two description paragraphs.
- Confirm the localized title and subtitle stay within ASC length limits.
- Compare screenshot text to the rewritten metadata.

### Metadata source-of-truth drift

The following files are competing authoring sources:

- scripts/aso_native_metadata.py
- scripts/generate_quitzyn_native_metadata.py
- scripts/quitzyn_locale_extras.json
- scripts/locale_aso_spec.py
- fastlane/metadata/*

scripts/locale_aso_spec.py:29-38 defines an EN subtitle that differs from the deployed fastlane/metadata/en-US/subtitle.txt:1. The generator and locale extras also contain old prices around the product copy. This means a future metadata regeneration can silently revert a current listing decision.

Recommendation:

- Select one canonical metadata manifest.
- Generate Fastlane files from it.
- Make generated files visibly marked or make the generator a dry-run validator.
- Add a check that rejects old price literals and alcohol-category terms in a Quit Zyn output.
- Require a versioned metadata snapshot and a source hash in the release report.

## 4. Trial and purchase funnel

### Current funnel map

The observed flow is:

1. App launch enters SoberApp -> RootView -> OnboardingView or MainTabView, as documented in CLAUDE.md:21-32.
2. OnboardingView initializes product loading and records onboarding reach in OnboardingView.swift:31-59.
3. The user moves through welcome, start date, spending inputs, reminder time, commitment, and trial steps.
4. SubscriptionService loads the RevenueCat offering and products, then refreshes intro eligibility.
5. A direct trial package is selected by SubscriptionService.preferredTrialPackage in SubscriptionService.swift:317-342, monthly first, yearly fallback.
6. OnboardingView.startOnboardingTrial attempts the direct trial, falls back to the full paywall when no eligible direct package exists, and persists setup before resolving the trial.
7. After onboarding, Home can present a post-onboarding paywall after a short delay, and later usage-based prompts can appear after check-ins or growth celebrations.
8. The Bloom+ tab, locked Health features, Journal, Garden, Progress, and Settings can open the paywall.
9. PaywallView shows the current offering with Yearly, Monthly, and Lifetime package cards and a purchase CTA.
10. TrialOfferSheet presents a trial-first path with a See all plans branch.
11. Settings exposes Upgrade, Restore, support, privacy, and EULA links.

### Onboarding evidence

Sober/Features/Onboarding/OnboardingView.swift has a six-stage flow:

- Welcome copy at lines 62-75.
- Start-date picker at lines 78-90.
- Spending inputs and annual savings projection at lines 94-216.
- Reminder time at lines 237-251.
- Commitment step at lines 255-311.
- Trial offer at lines 315-384 and 410-499.

Strengths:

- The user can use a meaningful date, spending context, and reminder preference.
- The trial state distinguishes eligible, ineligible, unavailable, and failed states in SubscriptionService.swift:344-378.
- The app does not promise a trial until eligibility is confirmed in SubscriptionService.swift:198-226.
- A Continue free path exists.
- Notification permission is requested after the onboarding flow rather than at the first screen.

Conversion risks:

- Six steps occur before the first check-in or garden reward.
- Default values are eight pouches per day, six dollars per can, and 15 pouches per can in OnboardingView.swift:4-29. These defaults can make projected savings feel inaccurate for many users.
- The primary commitment and trial CTAs are emotionally strong. This may motivate some users, but it can also feel like pressure before they have experienced the product.
- “Get Started” is the free path in OnboardingView.swift:410-499. Test a more explicit “Continue free” label so the no-purchase route is clear.
- If RevenueCat loading or eligibility resolution remains unresolved, the user can encounter “Checking trial availability…” and a Retry or Continue free branch. Test cold launch, offline launch, slow network, and an offering with no intro offer.
- persistSetup runs before trial resolution. This is useful for preserving user intent, but the state transition must be tested when the purchase is pending, failed, or the offering disappears.

### P0 pending purchase behavior

The service distinguishes .pending from .purchased in SubscriptionService.purchase at approximately lines 262-277. That is correct.

The onboarding caller does not preserve that distinction:

- OnboardingView.swift:582-615 records purchase pending and calls finishOnboarding immediately.
- Sober/App.swift:276-304 handles the direct trial sheet and also hides the sheet on pending.
- PaywallView.swift:497-527 keeps the general paywall open on pending and displays an approval message, which is a better pattern.

This creates different pending behavior depending on entry point. The onboarding user can leave the purchase surface and reach the free app without a durable pending status, while the general paywall user remains on the paywall. The RevenueCat delegate may later unlock the account, but the app may be backgrounded or terminated before that callback is observed.

Recommendation for a later implementation:

- Keep onboarding completion separate from entitlement activation.
- Persist a pending purchase state with product ID, offering ID, entry point, and timestamp.
- Show a non-blocking pending state after returning from StoreKit, with Restore purchases and Retry status actions.
- Recheck customer information on foreground and when the app returns from a purchase sheet.
- Only record purchase success and trial activation after entitlement state is confirmed.
- Make the pending message name the selected product and renewal timing without implying that payment or trial activation has completed.
- Test interrupted approval, Ask to Buy, network loss, app termination, restore after pending, and a delayed entitlement update.

Acceptance criteria:

- A pending purchase never increments the purchased or trial-started event.
- Relaunching the app shows a recoverable pending state or a clearly resolved state.
- A successful entitlement update dismisses or updates every purchase surface consistently.
- A failed or cancelled purchase does not mark onboarding as paid.

### Product and price evidence

Sober.storekit currently defines:

| Product | Product ID | Local price | Intro offer |
| --- | --- | --- | --- |
| Monthly | com.jackwallner.quitzyn.pro.monthly | $8.99 | 7-day free trial |
| Yearly | com.jackwallner.quitzyn.pro.yearly | $34.99 | 7-day free trial |
| Lifetime | com.jackwallner.quitzyn.pro.lifetime | $79.99 | None |

The in-app source uses these product IDs and the StoreKit local values. However, these ASC-related scripts still encode a different catalog:

- scripts/asc-create-iaps.py:11-22, $4.99 monthly, $29.99 yearly, $59.99 lifetime, and no monthly trial.
- scripts/asc-complete-bloom-iaps.py:12-26, the same old prices and yearly-only trial.
- scripts/asc-iap-availability-pricing.py:5-7, old monthly and yearly values.
- scripts/asc-fix-iap-pricing.py, old expected values.
- fastlane/metadata/review_information/notes.txt:10, old prices.

This is the strongest evidence of a catalog truth problem. It is not safe to infer which values are currently live in every storefront without a read-only ASC subscription and RevenueCat product lookup.

### Trial disclosure review

The onboarding trial footer derives the trial days and price from the selected package in OnboardingView.swift:410-499. That is the right direction.

TrialOfferSheet.swift:13-60 and TrialOfferSheet.swift:158-208 use a shorter billing note, approximately “After N days, $X unless you cancel.” Compare it against the full onboarding disclosure and the exact StoreKit and ASC renewal terms. Make all entry points show:

- trial length
- price after the trial
- renewal cadence
- renewal timing
- how to cancel
- where the user can restore
- region-specific pricing behavior where applicable

The disclosure must be derived from the selected StoreKit or RevenueCat package, not from a hardcoded price literal.

### Restore and entitlement behavior

SubscriptionService.restorePurchases is implemented at approximately lines 279-292, and Settings exposes Restore. This is good baseline coverage.

Validate:

- restore from onboarding after an interrupted trial purchase
- restore from Settings after reinstall
- restore with a lifetime purchase
- restore when the user is not entitled
- restore while RevenueCat is unavailable
- restore after a stale local complimentary-trial flag
- whether a local override or complimentary trial can accidentally mask an expired entitlement

The entitlement code accepts the named Sober Tracker - Nicotine Free Pro entitlement and also has an active-entitlement fallback around SubscriptionService.swift:449-470. Confirm the fallback is intentional and does not unlock an unrelated entitlement in the same RevenueCat project.

## 5. RevenueCat and usage instrumentation

### Current implementation

Verified in Shared/Services/SubscriptionService.swift:

- Production RevenueCat configuration is guarded on simulator at lines 99-120, reducing the risk of fake simulator customers in production charts.
- The entitlement string is Sober Tracker - Nicotine Free Pro at lines 31-35.
- The offering is loaded into the soberPaywallOffering state at approximately lines 164-195.
- Intro eligibility is refreshed only for packages that contain an intro offer at lines 198-226.
- Conversion counts are mirrored as funnel_* RevenueCat subscriber attributes at lines 229-246.
- Native custom paywall impression parameters are sent at lines 248-260.
- Customer information is refreshed after configuration and on the app lifecycle.
- Conversion attributes are synchronized when the app enters background in Sober/App.swift:90-98.

Current local conversion events in Shared/Services/ConversionDiagnostics.swift are:

- onboarding reached
- onboarding completed
- trial offer reached
- trial CTA tapped
- free version chosen
- purchase cancelled
- purchase failed
- purchase pending
- purchase succeeded

### Instrumentation correctness issues

1. PaywallView.swift:112-115 records trialOfferReached for every paywall appearance. A general upgrade paywall or lifetime-focused paywall is not necessarily a trial offer. This inflates the trial denominator.
2. PaywallView.swift:112-115 tracks the default paywall impression on every appearance unless the caller opts into a once-per-session behavior. Multiple surfaces can therefore create repeated impressions for the same session.
3. PaywallView.startPurchase at approximately lines 497-527 records trialCTATapped for every selected package, including Lifetime and purchases without an intro offer. This is not a trial CTA event.
4. Attributes sync only on background. A user can purchase, close, or crash before the cumulative attributes are synchronized.
5. The current attributes are cumulative totals, with no app version, build, storefront, entry point, package, offering, or experiment variant. They cannot reliably answer which flow produced the event.
6. The current event set has no explicit paywall loaded, empty, failed, retry, restore, or eligibility failure events. Product fetch failures can be seen in logs but are not a funnel state.
7. The counters are stored in App Group defaults. Confirm that watch and widget processes cannot increment or corrupt the same counters, and that a reinstall or app-group reset has a documented effect.

### Recommended event contract

Use events for state transitions and attributes for the latest low-cardinality state. Do not use RevenueCat customer attributes as an unbounded event log.

| Event | Record at | Required dimensions |
| --- | --- | --- |
| install or first session | First app session | app version, build, locale, storefront, device family |
| onboarding step started | Each step appearance | step name, step index |
| onboarding step completed | Successful next action | step name, step index |
| onboarding trial eligibility resolved | After resolveOnboardingTrial | eligible, ineligible, unavailable, failed, product ID, trial days |
| trial offer shown | Only when an eligible trial offer is visible | entry point, offer ID, package ID, paywall ID, variant |
| paywall impression | Once per surface appearance | entry point, paywall ID, offering ID, variant |
| package selected | When selection changes | package ID, package type, entry point, variant |
| purchase started | Before calling StoreKit or RevenueCat | package ID, offer ID, entry point, variant |
| purchase pending | On pending result | product ID, entry point, version |
| purchase failed | On error | product ID, normalized error class, entry point |
| purchase cancelled | On user cancellation | product ID, entry point |
| entitlement activated | Only after active entitlement is confirmed | product ID, entitlement, entry point |
| restore started, succeeded, empty, failed | Each restore state | entry point, normalized result |
| first check-in | First successful check-in | days since install bucket |
| first growth celebration | First garden growth | days since install bucket |
| journal first used | First journal open or save | entry point, no journal text |
| health timeline first used | First health surface interaction | free or Pro state |
| reminder permission result | After authorization request | authorized, denied, restricted, not-determined |
| review prompt shown and branch | Each in-app review sheet branch | positive, feedback, later |
| write-review URL opened | When URL is opened | storefront |

Do not send journal contents, mood text, free-form notes, or precise health inferences as RevenueCat attributes. If usage segmentation is approved, use coarse buckets only.

### Recommended custom attributes and placement

These are proposed attributes, not an instruction to add them without product and privacy review.

| Attribute | Set or update at | Example value | Why |
| --- | --- | --- | --- |
| app_version | App initialization | 1.2.4 | Segment regressions and paywall results by release |
| app_build | App initialization | 28 | Identify build-specific failures |
| storefront | App initialization or StoreKit product load | US | Explain price and offer differences |
| locale | App initialization | en-US | Compare localized funnel behavior |
| last_paywall_entry_point | Paywall presentation | onboarding, health_locked, bloom_tab, post_checkin, settings | Identify the latest conversion context |
| last_paywall_id | Paywall presentation | Stable surface ID | Join the paywall with an offering |
| last_offering_id | Product load | RevenueCat offering ID | Detect offering swaps |
| last_selected_package | Package selection | monthly, yearly, lifetime | Understand choice behavior |
| last_paywall_variant | Experiment assignment | Stable variant name | Compare native paywall experiments |
| trial_eligibility_state | Eligibility resolution | eligible, ineligible, unavailable, failed | Separate lack of offer from lack of intent |
| trial_product_id | Eligibility resolution | Product ID | Understand which product supplies the trial |
| trial_days | Eligibility resolution | 7 | Verify disclosure and product configuration |
| onboarding_completed | Onboarding completion | true | Segment activation |
| first_checkin_completed | First check-in | true | Separate acquisition from product activation |
| first_growth_completed | First growth | true | Measure the garden reward |
| notification_auth_status | Permission result | authorized, denied, restricted | Explain reminder retention effects |
| watch_available | Watch capability check | true or false | Compare cross-device retention |
| widget_available | Widget snapshot check | true or false | Compare widget adoption |
| daily_use_bucket | After setup, if approved | Coarse bucket such as 1-3, 4-10, 11+ | Personalize or segment without exact usage |
| cost_bucket | After setup, if approved | Coarse currency bucket | Segment savings messaging |

Avoid repeatedly setting attributes on every check-in. Keep only the latest state or cumulative low-cardinality counters. If an attribute changes frequently, use a separate analytics event system rather than turning RevenueCat into a time-series store.

### Synchronization and experiment requirements

- Sync a minimal release and experiment state at session start, after product load, after purchase resolution, after restore, and on background.
- Use stable names for entry points and variants. Do not use view filenames as experiment IDs.
- Include a schema version with each event payload.
- Treat RevenueCat custom paywall impressions as a denominator only when the paywall is fully rendered and the selected offering is known.
- Record trial shown only after the eligible trial package and exact disclosure are on screen.
- Keep purchase success downstream of entitlement confirmation.
- Add a local debug export or log view so a QA tester can see the event sequence without production credentials.

## 6. Native paywall and A/B test opportunities

The following tests should be run only after event definitions and catalog truth are fixed. Each test needs a stable assignment, a holdout, and a guardrail for cancellation, refund, pending, and support contacts.

| Surface | Control | Variant | Primary metric | Guardrails |
| --- | --- | --- | --- | --- |
| Default package | Yearly selected by current code | Monthly selected, or remember the last selection | Trial start and paid conversion | Annual versus monthly mix, refund, cancellation |
| Default package copy | Comment says monthly-first in PaywallView.swift:471-472, code selects yearly at 471-494 | Make comment and behavior agree, then test each | Package selection rate | Revenue per install, trial completion |
| Annual anchor | Savings percentage and annual spend anchor | Neutral annual price without savings emphasis | Purchase completion | Price comprehension, refund rate |
| Lifetime card | Third card with BEST DEAL | Neutral Lifetime card or lower visual priority | Lifetime purchase rate | Cannibalization of recurring plans |
| Trial surface | Trial-first TrialOfferSheet | Full plan picker first | Eligible trial start | Paywall dismissal and free activation |
| Trial CTA | Start N-Day Free Trial | Try free for N days with renewal line immediately below | Trial CTA tap to entitlement | Misunderstanding, refund, cancellation |
| Trial disclosure | Short TrialOfferSheet billing note | Same full disclosure used by onboarding | Purchase completion | Support contacts and charge complaints |
| Entry headline | Savings and garden hero | Focus-specific headline based on entry point | Entry-point conversion | Cross-surface consistency |
| Benefits | Four benefit cards and full timeline | Two strongest benefits, then concrete preview | Paywall completion | Feature comprehension, health-claim review |
| Health lock | Generic future milestone | Show a dated educational preview with locked action | Health-to-trial conversion | Compliance, accidental implication of guaranteed outcomes |
| Paywall layout | One-page no-scroll layout | Scrollable layout with CTA fixed to bottom | CTA completion | Small screens, Dynamic Type, VoiceOver |
| Trust row | Apple reminder only at PaywallView.swift:404-426 | Explicit renewal and cancellation explanation | Trial start | Text density, abandonment |
| Post-onboarding timing | Paywall after approximately 0.7 seconds | After first check-in or first growth celebration | Day-1 trial start | First check-in, onboarding abandonment |
| Passive nudge | Current schedule in BloomFeature.swift | Fewer prompts or a user-controlled reminder | Trial conversion | Session length, uninstall, prompt dismissal |
| Review collision | Existing positive-moment review flow | Suppress trial prompt for a cooldown around review prompt | Review completion and trial conversion | Prompt fatigue |

Test design requirements:

- Assign at the user or installation level, not per appearance.
- Preserve the assignment across app launches and purchase surfaces.
- Never show a variant that references a product or offer unavailable in the user’s storefront.
- Report by entry point, trial eligibility, product, app version, locale, and storefront.
- Use activation and retention as secondary metrics. A short-term trial tap increase is not a win if first check-ins or paid renewal decline.
- Keep health timeline copy legally reviewed in every variant.

## 7. Ratings, reviews, feedback, and trust

### Current review funnel

Shared/Services/ReviewPromptTracker.swift gates production review prompts on:

- at least five launches
- at least seven days since first launch
- at least three positive moments
- a 120-day cooldown

Sober/Features/Today/HomeView.swift:402-431 schedules the positive-moment path after a growth or check-in experience. Sober/Views/ReviewPromptSheet.swift offers:

- a positive branch that opens AppStoreReviewLinks.writeReviewURL
- a feedback branch that opens email
- a later branch that can lead to the native SKStoreReviewController request

Shared/Utilities/AppStoreReviewLinks.swift:4-17 correctly uses app ID 6784788496 and attempts to preserve the storefront.

Strengths:

- The prompt is delayed until there is repeated product use.
- The app offers a direct feedback path rather than forcing dissatisfied users to review.
- The app has a 120-day cooldown and records whether the review URL was opened.

Gaps:

- No reliable Quit Zyn star rating, rating count, review velocity, or review sentiment snapshot was captured in the available ASC context.
- ConversionDiagnostics has no review prompt shown, feedback branch, native prompt requested, or write-review opened event.
- Apple controls whether the native review sheet appears, so a request call is not the same as a visible prompt or submitted rating.
- The review flow can compete with a trial nudge or post-onboarding paywall if both are scheduled in the same session.
- The current positive-moment definition and cooldown should be validated against actual prompt frequency and user sentiment.

Recommended measurement:

- record the in-app sheet shown
- record positive, feedback, and later branches
- record write-review URL opened
- record native review request attempted, with the limitation that Apple does not disclose acceptance
- record prompt suppression reason, such as recent paywall, purchase pending, or another modal

Validation:

- Test five launches, seven-day boundary, three-positive-moment boundary, 120-day cooldown, and reinstall behavior.
- Test a user who has a pending purchase or an active trial.
- Test when the app enters background while the review sheet is visible.
- Verify the write-review link opens the correct storefront and does not expose an invalid country URL.
- Compare prompt cohorts with retention, support email volume, and refund rate, not only review count.

## 8. User experience and activation

### First value

HomeView.swift:43-179 provides the central daily state. On appearance, approximately lines 108-123:

- backfills days through yesterday
- refreshes garden state
- updates the widget
- updates notification copy
- may present the post-onboarding paywall
- may schedule a passive trial nudge after six seconds

The first check-in is the clearest activation event. HomeView.swift:241-341 supports:

- a one-tap Still nicotine-free check-in
- an I slipped reset path
- a missed-day backfill state
- a check-in detail and note flow

The positive loop is strong, but the post-onboarding paywall can appear after about 0.7 seconds in HomeView.swift:368-387, before the user has completed the first check-in. Test delaying monetization until the first successful check-in or first growth celebration. Keep an explicit upgrade path available for users who seek it.

### Onboarding tradeoffs

The spending calculator can make savings concrete, but it asks several numeric questions before product value is visible. Test:

- current six-step sequence
- a shorter setup with optional spending details
- a two-stage flow that asks only start date first, then asks savings details after first check-in
- default values versus blank inputs with examples
- the reminder step after the first successful check-in

Guardrails:

- onboarding completion
- first check-in within 24 hours
- trial offer reach for eligible users
- free-version continuation
- day-2 and day-7 retention
- support contacts about incorrect savings

### Health timeline

Shared/Catalogs/HealthBenefitCatalog.swift:22-145 contains 13 milestones. HealthView.swift:14-17 exposes five free reveals, then shows locked content. HealthView.swift:52 has a general-wellness disclaimer.

The implementation is concrete and likely useful, but the locked state can make a user interpret the timeline as a guaranteed medical progression. Keep each milestone framed as general educational information, cite and date sources, state that timelines vary, and avoid treatment, diagnosis, cure, or guaranteed-outcome wording.

### Journal, Garden, and progress

CLAUDE.md:21-32 and the main tab structure indicate Home, Timeline, Health, Journal, and Bloom+/Upgrade. These are good separate jobs:

- Home provides daily activation.
- Timeline provides long-horizon progress.
- Health provides educational content.
- Journal supports reflection.
- Bloom+ provides a premium feature destination.

Validate:

- whether free users understand what they can do in Journal before seeing a paywall
- whether locked feature taps produce a specific feature explanation rather than a generic upgrade
- whether a garden growth celebration is immediately understandable without reading copy
- whether a missed day path is supportive and does not imply failure or a medical outcome
- whether the data model preserves notes and dates after a version upgrade or store recovery

### Notifications

Shared/Services/NotificationService.swift schedules one repeating daily reminder and deep-links to check-in. The scheduling call uses try?, so failures are swallowed.

Recommendations:

- log a structured scheduling failure with the authorization state and error class
- expose a local diagnostic only when scheduling fails, without alarming normal users
- test denied, restricted, provisional, authorized, time-zone change, daylight-saving change, and deleted notification states
- verify the deep link lands on the check-in action after cold launch
- measure authorization outcome and first notification delivery where the platform permits

### Watch and widget

The App Group snapshot pump updates widgets and sends watch context when the paired or installed state permits. The widget and watch surfaces are useful retention mechanisms.

Validate:

- stale snapshot behavior after a missed day
- App Group unavailable or corrupted state
- watch connectivity unavailable or delayed
- widget reload throttling
- first install and upgrade from a prior schema
- free and Pro display consistency
- accessibility labels for all families

One minor copy issue to validate is the accessory-inline widget wording in SoberWidgets.swift:108, which always uses “days” and may be grammatically wrong for one day.

### Accessibility and device coverage

The paywall is a fixed one-page layout with minimum heights and limited disclosure lines. Test:

- Dynamic Type at the largest accessibility sizes
- VoiceOver order and labels
- Reduce Motion and Reduce Transparency
- 4-inch-class and current small iPhone widths
- landscape where supported
- RTL locales
- localized long prices and long trial text
- reduced contrast and dark-mode behavior, noting that Sober/App.swift:64-89 forces light color scheme

An accessibility failure on the purchase CTA or disclosure is a conversion and review risk, not only a visual defect.

## 9. Website, terms, privacy, and consistency

### URL and deployment evidence

The following URLs returned HTTP 200 in the read-only check:

- https://jackwallner.com/ios/quitzyn/
- https://jackwallner.github.io/quitzyn/
- https://jackwallner.github.io/quitzyn/privacy-policy.html
- https://jackwallner.github.io/quitzyn/terms.html

index.html identifies app ID 6784788496, includes a canonical jackwallner.com URL, JSON-LD, App Store links, and six screenshot references.

The store metadata points to GitHub Pages, while the root HTML canonical and visible site identity point to jackwallner.com. This split may be intentional, but it creates duplicate-content, link-checking, and analytics attribution risk. Choose one public canonical and make the other a redirect or a clearly documented deployment mirror.

### Root and docs site drift

docs/index.html is materially older than root index.html. The diff shows the root has pricing styles and a pricing section that the docs copy lacks, while the two copies otherwise present similar product content. This is a P1 conversion and maintenance risk because the URL served by a deployment workflow may not be the URL being reviewed locally.

There are duplicate root and docs copies of:

- index.html
- support.html
- privacy-policy.html
- terms.html

The privacy and terms pages use different relative navigation depending on whether they are in root or docs. Both copies should either be generated from a single source or one should be removed from the deployment path.

### Pricing and free-tier consistency matrix

| Source | Free health content | Monthly | Yearly | Lifetime | Version |
| --- | --- | --- | --- | --- | --- |
| HealthView.swift:14-17 | First 5 reveals | Not applicable | Not applicable | Not applicable | Runtime source |
| Root index.html:35-53 JSON-LD | First 5 | $8.99 | $34.99 | $79.99 | 1.2.3 |
| Root index.html:683-736 visible pricing | First 2 | Price not visibly shown in the inspected text | Price not visibly shown in the inspected text | Price not visibly shown in the inspected text | Current root copy |
| support.html:46 | First 2 | Not stated | Not stated | Not stated | Support copy dated 2026-06-26 |
| Sober.storekit | Runtime product behavior | $8.99 | $34.99 | $79.99 | Local StoreKit |
| fastlane/metadata/review_information/notes.txt:10 | Not stated | $4.99 | $29.99 | $59.99 | Stale review notes |
| ASC writer scripts | Not stated | $4.99 | $29.99 | $59.99 | Stale or unverified automation |

The five-versus-two free-benefit mismatch is a direct product promise mismatch. Fix the code, site, support, JSON-LD, screenshots, and App Store description from one approved constant.

### Version and feature consistency

- Root JSON-LD reports software version 1.2.3 at index.html:60.
- Local project targets 1.2.4 build 28.
- Review notes describe four tabs at fastlane/metadata/review_information/notes.txt:3-7; the current app has five visible tabs including Bloom+/Upgrade.
- The website says six garden species and 13 health benefits, which should be checked against the current runtime catalogs.
- The support page is dated June 26, 2026, while terms and privacy are dated August 17, 2026. This is not necessarily wrong, but it signals that support content may not have been reviewed with the current catalog.

### Terms and privacy

The terms at docs/terms.html:86-119 contain useful protections:

- general information and habit awareness framing
- explicit no diagnosis, prevention, treatment, or cure language
- renewal, cancellation, restore, Apple billing, and price-before-purchase language

The privacy policy at docs/privacy-policy.html:86-129 describes local SwiftData, UserDefaults, App Group storage, purchase processing, retention, and deletion. The user-requested RevenueCat disclosure consistency audit is intentionally omitted here.

Findability issue:

- In-app Settings and the paywall expose privacy and Apple EULA links.
- The root landing page footer does not visibly link to terms even though terms.html exists.
- Add terms to the public footer and link set during the next website pass.

### Compliance content review

Review these exact content areas with a health and wellness compliance reviewer:

- OnboardingView.swift:62-75, “watch your health return”
- HealthBenefitCatalog.swift:22-145, direct physiological milestone statements
- index.html:640-647, body recovery timeline
- index.html:761-789, “real nicotine-recovery timeline” and lung-function language
- App Store description and promotional text

Recommended framing:

- “educational timeline” or “general wellness timeline”
- “information commonly associated with quitting nicotine, with timing that varies”
- source attribution and source review date
- “not medical advice” near the content, not only buried in terms

Do not add or retain wording that promises treatment, a cure, diagnosis, prevention, or a guaranteed physical outcome.

## 10. Crash, regression, and watchdog signals

No production crash spike or Quit Zyn-specific live diagnostic trend was captured in the available ASC context. The following signals are present in code and should be observable by a later watchdog.

### Highest-risk signals

| Signal | Local evidence | What to watch |
| --- | --- | --- |
| Store recovery | DataService.swift:19-40 deletes store files after failure and falls back to memory | Count recovery attempts, affected app versions, and users with recovered or empty history |
| Persistence save failures | Multiple services use try? context.save() | Count failed saves by operation and model |
| Product fetch empty | SubscriptionService.swift:164-195 sets an error when offering packages are empty | Product fetch success, empty offering, timeout, and retry rate |
| Entitlement mismatch | SubscriptionService.swift:31-35 and 449-470 use a named entitlement plus fallback | Active purchase with locked Pro UI, or unrelated active entitlement |
| Purchase pending | SubscriptionService.swift:262-277, onboarding caller behavior described above | Pending volume, resolution time, pending after relaunch |
| Purchase failed | SubscriptionService.swift purchase error path | Normalized StoreKit or RevenueCat error class by version |
| Restore failure | SubscriptionService.swift:279-292 | Restore success, empty, error, and time to unlock |
| Notification schedule failure | NotificationService.swift uses try? | Authorization state, scheduling error, and missed reminder reports |
| Widget or watch transport failure | WidgetSnapshotPump and watch context paths | Snapshot age, send failure, unavailable pairing |
| Review or paywall collision | Home and BloomFeature timers | Simultaneous modal attempts, dropped presentations, repeated prompts |
| Asset issue | Sober/Assets.xcassets/AppIcon.appiconset/Contents.json references 1024 icon while icon_256.png is present but unassigned | Archive validation and App Store icon result |
| Stale release scripts | ASC scripts and .asc-state.json | Preflight disagreement before any metadata or IAP write |

### Watchdog design for a later implementation

The requested MacBook watchdog should be scaffolded later, not deployed as part of this audit. It should be configurable and read-only by default. Its input should be structured logs, ASC export files, App Store Connect diagnostics exports, RevenueCat exports, and local release manifests.

Recommended alert classes:

1. Crash regression:
   - alert when the same Quit Zyn crash signature appears for at least three distinct users in 15 minutes
   - alert when the current release crash-free session rate is at least 0.5 percentage points below its seven-day baseline
   - alert when a new release has a two-times increase in the same normalized crash signature
2. Purchase regression:
   - alert when product fetch empty or timeout exceeds a configurable percentage of sessions
   - alert when purchase errors exceed two times the trailing seven-day baseline
   - alert when pending purchases remain unresolved beyond a configurable window
   - alert when entitlement active but Pro UI locked appears in logs or test probes
3. Data safety:
   - alert on any store deletion, in-memory fallback, migration failure, or repeated save failure
   - alert when the store schema changes without a matching migration marker
4. Release consistency:
   - fail a preflight when project version, ASC version, website version, metadata version, and release manifest differ
   - fail on old product price literals or product IDs
   - fail when review notes describe the wrong tab count or product price
5. ASO and legal:
   - fail on alcohol sobriety terms in a nicotine listing
   - fail when free-benefit count differs across runtime, website, support, and JSON-LD
   - fail when required terms, privacy, support, or App Store URLs do not return 200
6. UX smoke:
   - run a StoreKit sandbox or local StoreKit matrix for eligible, ineligible, pending, cancelled, failed, purchased, and restored states
   - capture a screenshot and accessibility tree for onboarding trial, general paywall, restore, locked health benefit, and first check-in

### Suggested watchdog configuration

Keep thresholds in a versioned configuration file in the later implementation, with:

- app name and bundle IDs
- current release and baseline window
- crash signature thresholds
- purchase error thresholds
- pending resolution timeout
- required URL list
- canonical product IDs and prices
- expected free-benefit count
- expected tab count
- required metadata locales
- alert destinations disabled by default until explicitly configured

The watchdog must distinguish:

- app crash from a StoreKit cancellation
- a user voluntarily cancelling from an error
- RevenueCat network unavailability from an invalid product configuration
- a local simulator result from a production customer
- a store recovery event from a normal migration

The existing simulator guard in SubscriptionService.swift:99-120 should remain part of the release safety checks. Never use the production RevenueCat public key in an ordinary simulator purchase run.

## 11. Agent documentation and repository hygiene

### Current documentation state

CLAUDE.md is the main local agent guide. It correctly documents:

- internal Sober naming versus outward Quit Zyn identity
- iOS and watchOS targets
- bundle IDs and App Group
- SwiftUI, SwiftData, RevenueCat, WidgetKit, and XcodeGen
- the onboarding and MainTabView root flow
- review prompt, StoreKit, migration, and widget notes

However:

- CLAUDE.md:3 calls the outward app “Sober Tracker - Nicotine Free”, which conflicts with the live ASC name and current Store metadata.
- CLAUDE.md:9-19 says RevenueCat 5.14+ while project.yml:19-22 pins 5.67.0.
- The project name Sober is technically valid for targets and schemes, but agents need an explicit warning that all public copy must use Quit Zyn and nicotine-pouch language.
- No local AGENTS.md was observed in the repository.
- No local .cursor/rules, .claude, .codex, or .agents instruction directory was observed.
- Global agent guidance exists outside the repo, but a future agent operating only in this repository may not know the local naming, release, and documentation rules.

Recommendation:

- Keep one canonical local agent guide with a first section titled Public identity and prohibited stale naming.
- Make Cursor, Claude, and Codex entry points point to the same canonical instructions, without duplicating them.
- Document which files are generated, which are authoritative, and which are historical.
- Add a release source-of-truth section with the product IDs, approved prices, free-benefit count, tab count, app ID, and canonical URLs.
- Add a read-only audit mode section for agents performing audits.

### Stale or misleading local documents

| File | Evidence | Risk | Later disposition |
| --- | --- | --- | --- |
| aso-plan.md:1-3 | Says Sober Tracker ASO Plan, Alcohol Free, app ID 6768869215, repo ~/sober | An agent can update the wrong app or wrong listing | Move to an archive outside the active instruction path or replace with a Quit Zyn plan |
| ios27QuitZyn.md:1-26 | August 5 audit says a deprecated RevenueCat initializer exists at SubscriptionService.swift:236; current source uses CustomPaywallImpressionParams and the deprecated text appears only in the old audit | Agents may fix a resolved issue or spend time on a false regression | Mark superseded or archive after preserving history |
| scripts/.asc-state.json | Reports live version 1.0 and stale timestamps | Release automation can target the wrong version | Regenerate from a read-only ASC state command or mark derived |
| scripts/aso_native_metadata.py | Metadata source differs from Fastlane subtitle | Future regeneration can undo a listing decision | Choose one canonical source |
| scripts/generate_quitzyn_native_metadata.py | Contains old price literals | Can write wrong prices into metadata | Remove old literals or make the script fail |
| scripts/quitzyn_locale_extras.json | Contains localized price and copy data | Duplicate truth and locale drift | Fold into a versioned manifest |
| docs/index.html | Missing root pricing section and older layout | Deployment path can show incomplete landing page | Generate or redirect |
| fastlane/metadata/review_information/notes.txt | Old prices, four tabs, old support email | App Review instructions can be wrong | Regenerate from current review checklist |

Do not delete historical documents blindly. Move them to an explicitly named archive only after a later agent has verified that no automation or instruction references them.

### Agent-facing validation rules

A future implementation agent should be able to answer these from one local manifest:

- What is the public app name?
- What is the ASC app ID?
- What are the three production product IDs?
- What are the approved current prices and trial terms?
- How many health milestones are free?
- How many tabs are in the current app?
- Which URL is canonical?
- Which files are generated?
- Which files are historical?
- Which claims require health and wellness review?
- Which commands are read-only, and which can mutate ASC or Git?

## 12. Prioritized implementation backlog

### P0

1. Reconcile release and monetization truth.
   - Files: project.yml, scripts/.asc-state.json, Sober.storekit, SubscriptionService.swift, ASC writer scripts, fastlane/metadata/review_information/notes.txt, website JSON-LD.
   - Acceptance: a read-only report shows one approved version, product ID set, price set, trial set, and canonical URL set.
2. Fix pending purchase state transitions.
   - Symbols: SubscriptionService.purchase, OnboardingView.startOnboardingTrial, SoberApp trial sheet handler, PaywallView.startPurchase.
   - Acceptance: pending is never recorded as purchased, survives relaunch, and resolves through foreground refresh or restore.
3. Protect local user history during store recovery.
   - File: Shared/Services/DataService.swift:19-40.
   - Acceptance: corruption, migration failure, and in-memory fallback produce structured diagnostics, preserve a recoverable copy where possible, and have explicit tests. Any deletion must be deliberate and documented.
4. Add a release preflight that is dry-run by default.
   - Inputs: project, StoreKit, ASC read-only export, RevenueCat read-only export, metadata, website, review notes.
   - Acceptance: stale prices, IDs, version, tab count, free count, required URLs, and prohibited locale terms fail before a writer or ship script can run.

### P1

5. Make the free-health-benefit count one constant across HealthView.swift, root site, docs site, support, JSON-LD, screenshots, and App Store description.
6. Split trialOfferReached from paywallImpression, and split trialCTATapped from purchaseStarted.
7. Add entry point, package, offering, variant, storefront, version, and eligibility dimensions.
8. Sync essential purchase and release attributes after purchase resolution, restore, product load, and foreground, not only background.
9. Rewrite affected locale metadata with native review, removing alcohol sobriety wording and malformed nicotine wording.
10. Choose one canonical metadata authoring source and make all other writers validate or generate from it.
11. Reconcile root and docs website copies, canonical URL, navigation, terms link, pricing, free count, and version.
12. Update ASC review notes to five tabs, current product behavior, current price source, current trial behavior, and the current support email.
13. Review health timeline, website, promotional, and metadata claims for general-wellness compliance.
14. Make TrialOfferSheet disclosure match onboarding disclosure and derive all values from the selected package.
15. Add explicit product fetch empty, timeout, retry, entitlement mismatch, restore, notification, widget, watch, and persistence diagnostics.
16. Resolve the unassigned icon_256.png decision in Sober/Assets.xcassets/AppIcon.appiconset.
17. Update CLAUDE.md, add shared local agent entry-point guidance, and archive or mark stale documents.
18. Add test coverage for the purchase and data-loss matrices listed below.

### P2

19. Test shorter onboarding and optional spending inputs.
20. Test post-onboarding paywall timing after first check-in or growth.
21. Test Yearly, Monthly, and remembered-package defaults.
22. Test lifetime visual treatment and savings anchor.
23. Test trial-first versus full-plan-first presentation.
24. Test paywall long text, Dynamic Type, VoiceOver, reduced motion, RTL, and small devices.
25. Measure notification authorization and reminder scheduling success.
26. Measure review prompt branches and suppress prompt collisions.
27. Fix singular day copy in the accessory-inline widget.
28. Align OSLog subsystem names with the public Quit Zyn bundle identity or document the internal Sober namespace.

## 13. Validation plan for the later implementation agent

### Read-only repository checks

Run from /Users/jackwallner/nicfree:

    git status --short
    rg -n "4\.99|29\.99|59\.99|8\.99|34\.99|79\.99" .
    rg -n "first 2|first two|first 5|first five|freeRevealCount" .
    rg -n "sober|alcohol|sobri|drinking|without drinking" fastlane/metadata scripts *.md docs *.html
    rg -n "trialOfferReached|trialCTATapped|paywall|purchasePending|purchaseSucceeded" Sober Shared SoberTests
    rg -n "try\?|delete.*store|inMemory|modelContainer|context\.save" Shared Sober
    find fastlane/metadata -maxdepth 2 -type f | sort
    find fastlane/screenshots -maxdepth 2 -type f | sort

The first command is only a working-tree check. Do not run any script that writes ASC, Fastlane, Git, Xcode project, or website state during an audit.

### Product and purchase matrix

Run with local StoreKit or a controlled sandbox environment, never with production RevenueCat data from a simulator:

| Case | Expected |
| --- | --- |
| Eligible monthly trial | Exact trial days and renewal price are shown, purchase reaches entitlement |
| Eligible yearly trial | Fallback works when monthly is unavailable |
| Ineligible user | No trial promise, clear paid option and Continue free path |
| Offering unavailable | No dead end, retry and Continue free are available |
| Product fetch timeout | Error is observable, retry does not duplicate events |
| User cancellation | Cancelled event only, no success, no onboarding lock |
| StoreKit pending | Pending event only, persistent recovery state, no false trial completion |
| Pending resolves while foregrounded | Entitlement unlocks all surfaces consistently |
| Pending resolves after relaunch | Restore or refresh resolves it without a second misleading purchase |
| Purchase failure | Normalized error, no success, no duplicate CTA count |
| Lifetime purchase | No trial events, correct product and disclosure |
| Restore success | Entitlement unlocks and restore event is recorded |
| Restore empty | Clear result, no false entitlement |
| Restore unavailable | Retry path and diagnostic |
| Expired or revoked entitlement | Pro surfaces lock consistently and local fallback does not mask it |

### Onboarding and activation matrix

- fresh install online
- fresh install offline
- returning free user
- returning Pro user
- existing user with pending purchase
- setup with zero, low, and high pouch values
- setup with a missed date
- notification authorization allowed
- notification authorization denied
- notification scheduling failure
- first check-in
- missed-day backfill
- slip/reset path
- first growth celebration
- post-onboarding paywall dismissal
- passive nudge after the configured schedule
- review prompt eligible at the same time as a paywall

### Reliability and migration matrix

- upgrade from the prior Sober.store path to Sober.v2.store
- malformed or unreadable store
- save failure
- App Group unavailable
- widget process reading stale data
- watch unavailable
- app termination during save
- app termination during purchase
- app termination during onboarding completion
- schema migration with existing journal and check-in data

### ASO and website checks

- every metadata locale has required fields
- every metadata locale uses nicotine category language
- no locale contains alcohol sobriety wording
- no stale product price literals remain in active writers
- free count is the same in code, site, support, structured data, and screenshots
- tab count in review notes matches runtime
- canonical URL and Store metadata URLs are intentional
- root and docs pages are either identical by generation or one redirects
- terms, privacy, support, and App Store links return 200
- version displayed publicly matches the release manifest
- all health content has compliant framing and current sources

## 14. Evidence versus inference register

### Verified evidence

- Quit Zyn ASC app ID 6784788496, live app name, Ready for Distribution status, and version 1.2.3 were observed in the available signed-in ASC context.
- Local project targets 1.2.4 build 28.
- RevenueCat project Quit Zyn with project ID 8395c8fc was observed in available context, but no reliable app-specific metric snapshot was captured.
- Sober.storekit contains current-looking product IDs and $8.99, $34.99, and $79.99 local values, each monthly and yearly with a seven-day trial.
- Several ASC writer and review-note files contain the older $4.99, $29.99, and $59.99 values.
- Runtime HealthView exposes five free health benefit reveals.
- Root visible pricing and support copy say two free health benefits, while root JSON-LD says five.
- Onboarding pending handling finishes onboarding after recording pending.
- General PaywallView keeps the paywall open on pending.
- DataService deletes store files and falls back to memory after a store failure.
- The current source uses CustomPaywallImpressionParams; the old deprecated initializer finding appears in ios27QuitZyn.md, not current source.
- Locale descriptions contain alcohol sobriety or drinking wording in the listed locales.
- Root and docs website copies differ materially in pricing content.
- The review tracker uses five launches, seven days, three positive moments, and a 120-day cooldown.
- The repository has CLAUDE.md, but no local AGENTS, Cursor rules, Claude directory, Codex directory, or agents directory was observed.

### Inferences requiring validation

- The local 1.2.4 project may be a not-yet-uploaded next release, or ASC may be behind. It is not safe to infer which is intended.
- The old ASC scripts may be historical, or they may still be used by a release operator. Their active status must be established before editing or archiving.
- A pending onboarding purchase may resolve through the RevenueCat delegate later, but the current caller does not guarantee a durable user-facing recovery state.
- Store recovery can cause real local-history loss because the fallback is in memory. Measure whether the path is reachable in production and whether deletion occurs before a safe export.
- The duplicate website copies may be deployed through different channels. Confirm the actual deployment workflow.
- The current paywall default and savings framing may improve or reduce conversion. Run controlled experiments after instrumentation is corrected.
- Locale errors may reduce acquisition in only some storefronts, but the category mismatch is severe enough to prioritize without waiting for a full experiment.

## 15. Handoff summary for the implementation agent

Start with the P0 release truth report and pending purchase state. Do not begin by changing copy or selecting a paywall winner, because the current event denominators and product price sources are not reliable enough to judge those changes.

The first implementation pass should produce:

1. A read-only catalog and release preflight.
2. A durable pending-purchase state and foreground refresh behavior.
3. Store recovery diagnostics and tests.
4. One conversion event schema with semantic trial and paywall events.
5. One approved free-health-benefit constant and one metadata source.
6. A locale correction checklist with native review owners.
7. A single website source or redirect strategy.
8. A refreshed agent guide and an explicit archive policy.

After that, use the experiment matrix to test the paywall default, trial-first flow, first-value timing, health preview, and review timing. Judge results by first check-in, trial-to-paid conversion, renewal, retention, refunds, and support contacts, not by trial CTA taps alone.
