# Number Systems Lab

An iOS app for working with numeral systems. Convert numbers between any bases from 2 to 36, perform arithmetic across mixed bases, view a number in binary/octal/decimal/hexadecimal at once, and test yourself with a built-in quiz.

A from-scratch SwiftUI rewrite of the original "Number Systems" app.

## Features

- **Converter** — live conversion between binary, octal, decimal, and hexadecimal, with optional two's-complement representation.
- **All systems** — convert a number from any base (2–36) to any other base.
- **Calculator** — add, subtract, multiply, and divide numbers given in different bases, with the result in a base of your choice.
- **Quiz** — practice conversions per base (integers and fractions) with score tracking.
- **Help** — built-in explanations and examples, available from each screen's navigation bar.
- **Support** — optional, one-time developer tips through StoreKit. Every feature is available without a tip.
- App-icon quick actions.
- English, Russian, Spanish, German, French, and Brazilian Portuguese, including built-in help.
- Short Home Screen names: Base Lab, Числа, Bases, Basen, Bases, and Bases respectively. The App Store title remains Number Systems Lab.
- Adaptive Help and Quiz navigation for compact screens, iPad, and iPhone Duo.
- Native Liquid Glass navigation and tip buttons on iOS 26+, with standard controls on older supported versions.

## Stack

- Swift 6, SwiftUI, MVVM
- iOS 18+
- Conversion logic in a local Swift package
- Apple-native diagnostics (os.Logger, MetricKit)

The app ships the local `ConversionEngine` package for conversion and arithmetic. `swift-snapshot-testing` is linked only to the unit-test target for image comparisons. `swift-custom-dump`, `swift-syntax`, and `xctest-dynamic-overlay` are transitive test-tool dependencies that may remain in the resolved package graph; they are not runtime libraries in the shipping app. The UI-test target uses Apple's XCTest, UIKit, and Vision frameworks.

## Development

- The "Lint & Format" build phase checks formatting and lint without rewriting source. Configs live at the repo root. The phase adds the standard Apple Silicon and Intel Homebrew binary directories to `PATH`, so GUI-launched Xcode can find installed tools.
- Run `Scripts/update-lint-inputs.sh` after adding or removing Swift files. The generated input list lets the build checks run with Xcode's script sandbox enabled.
- Build through Xcode. Run the unit and snapshot tests before pushing.
- The conversion package has standalone correctness and safety tests (`swift test --package-path ConversionEngine --enable-code-coverage`). Arithmetic uses native `Decimal` precision; unsupported precision/range is reported as an error. Two's complement uses signed, byte-aligned native integers.
- UI tests cover the supported languages, full feature flows, large text, rotation, persistence, and accessibility. Snapshot tests cover compact/standard/landscape/tablet layouts in light and dark mode.

## Local and Xcode Cloud tests

Open `numberConverter.xcworkspace` and select the shared `numberConverter` scheme. Its default **AllTests** plan includes the engine, app unit/integration, snapshot and UI targets without filters. The separate engine action is unnecessary when a workflow uses the workspace and this plan: its 76 definitions are already included.

The 15 plans in `TestPlans/` partition that inventory into Core, Snapshots, SharedUI, six normal-language plans and six largest-text plans. Current Xcode discovery lists 354 enabled definitions and zero disabled in AllTests: 76 engine, 209 app unit/integration/snapshot and 69 UI tests. Language-independent functional flows run in English at normal and largest text sizes. Six-language localization and screenshot coverage remains enabled. `Scripts/validate-cloud-test-plans.py` checks the partition against Xcode's native test enumeration, including missing, duplicate, disabled or unknown tests. The checked-in filters were validated against fresh AllTests discovery: all 354 definitions belong to exactly one shard. Separate native discovery of each shard was not refreshed in this checkpoint. Snapshot recording stays disabled. Building or enumerating a plan does not establish a test pass.

Run `CloudSnapshots` on its pinned 3× Pro host. Its device presets test different point sizes using that host's renderer; they do not establish 2× iPad snapshot-host compatibility. Use the language and largest-text UI plans for actual iPad and Duo execution. The unfiltered `AllTests` plan includes the same host-specific snapshot suite.

Pressing **⌘U** runs the active plan on the destination selected in Xcode's toolbar. It does not cycle through devices. In the Report navigator (**⌘9 → Local**), inspect each run's destination and results; one passing run establishes a pass only for that destination.

The checked-in [local device matrix](TestPlans/local-device-matrix.json) includes iPhone 17e, iPhone 16, iPhone 17, iPhone 18 Pro, iPhone 18 Pro Max, iPhone Duo, and iPad mini (A20 Pro). The [matrix runner](Scripts/run-local-test-matrix.py) runs Core and Snapshots once on the validated 3× Pro host, then all 13 UI plans on **every one of the seven devices**. With the current inventory, the intended scope is 354 definitions and all 69 UI definitions per device: 93 actions and 768 definition/device executions. It builds once, verifies the partition against fresh native discovery, retains separate result bundles, and rejects missing devices, failed/skipped tests, or incomplete results.

After any test run already active in Xcode finishes, run the complete local matrix with:

```sh
python3 Scripts/run-local-test-matrix.py --execute --output /private/tmp/numberconverter-full-matrix
```

Use a new output directory for each run. Inspect `report.json`: acceptance requires both `complete` and `passed` to be true. Each action records its actual destination, selected definitions, native result bundle and validation. To continue untouched actions after an interruption, use `--resume /private/tmp/numberconverter-full-matrix`; it verifies sources, products and previous results first. Failed or interrupted actions remain failures and are not silently retried. Merely configuring or starting this runner does not establish that the matrix passed. The normal phones use iOS 27.2; Duo uses its locally validated iOS 27.1 runtime.

Testing now runs **locally only**. The owner deactivated the Cloud workflow and canceled the Cloud test run. The existing plans are retained for the local runner. Historical Cloud build 7 started from the `aa27a94` push and exposed failures; its reports are diagnostic evidence, not release acceptance. Do not reactivate Cloud or start new Cloud builds as part of local verification. Engine tests remain included in Core.

The retained `ci_scripts/ci_pre_xcodebuild.sh` setup hook installs missing SwiftFormat and SwiftLint through Homebrew and verifies both executables before a Cloud app build. Engine tests do not run in this hook. It is inactive while Cloud is disabled; local development uses the installed tools.

## Developer tips

`numberConverterTests/Resources/TipJar.storekit` contains local test products at USD 2.99, 8.99, 19.99, 49.99, and 99.99. The shared Debug scheme selects this file for local StoreKit testing; integration tests load it from the test bundle with `SKTestSession(contentsOf:)`. The catalog is not a production app resource. These are consumable tips, without subscriptions or feature unlocks. Production displays `Product.displayPrice` from the customer's App Store storefront; it never substitutes a hardcoded price when products cannot be loaded.

The five consumable products from `TipProduct.allowedIDs` are configured in App Store Connect with USD base prices 2.99, 8.99, 19.99, 49.99, and 99.99, six localized names/descriptions, availability, and review screenshots/notes. All five review screenshots show the current USD prices, and all five products have 1024-pixel tip artwork. These saved prices and image attachments were verified after reloading each product. The first two tips have lower custom prices in 142 storefronts, verified after reloading all country prices; the other 33 storefronts and the three larger tips retain Apple's automatic equivalents. For example, the first two tips are EUR 2.99/9.99 in Germany, EUR 0.99/3.99 in Lithuania, USD 0.49/1.99 in Armenia, and INR 29/99 in India. These are optional-tip pricing choices, not predictions of individual affordability. Review manual prices quarterly because Apple does not automatically update them for exchange rates or taxes. The complete [regional price snapshot and maintenance policy](AppStoreAssets/pricing/POLICY.md) is included with the store assets. The app download price is configured as free in all 175 storefronts, and the calculated 4+ age rating and content-rights declaration are saved. The owner reports submitting the app for review; the individual in-app purchase submission states were not rechecked in this checkpoint. Production App Store sandbox transactions and final release validation are still required; local StoreKit tests do not establish that approval or storefront availability is complete.

Unit tests inject a `TipService`; StoreKit integration tests use `SKTestSession` and real local StoreKit products/transactions. Tip-purchase UI scenarios select a DEBUG-only service fixture. The separate live metadata probe uses production StoreKit and never selects a purchase button. Release builds ignore the fixture argument.

## Test scope

Conversion-engine coverage, app code coverage, and UI matrix completion are separate measurements. A line-coverage percentage does not establish that every possible input, screen size, device pose, or translation is correct. Keep the actual `.xcresult` bundles and coverage reports when reporting a run.

Two complete English workflows cover functional behavior at normal and largest text sizes, including native audits. Six-language localization tests check expected labels on all five tabs, Help/Privacy titles, Support copy and all five locale-formatted prices at both text sizes, without repeating arithmetic, statistics persistence or StoreKit retry flows. Rotation/state preservation runs in English. Dedicated translated-label, VoiceOver, Help-table and native accessibility regressions, six-language Store screenshots and all multilingual snapshots remain. Unit tests still check every compiled translation and all Help prose in all six languages. Completed flows attach a `workflow-completed` marker; an interrupted flow is a failure. The focused post-deduplication check reported 14 passed, zero failed and zero skipped; the new Russian localization UI scenario passed in 146.1 seconds. This is focused verification, not a complete six-language/largest-text/device-matrix pass. Native accessibility audits retain issue attachments. Exact Dynamic Type diagnostics for measured SwiftUI elements are classified using separate screenshot/glyph-growth regressions; unexpected issues still fail.

An earlier Device Hub checkpoint on iPhone Duo/iOS 27.1 verified Closed, Open, and Partially Open transitions and rotation for English normal-text Converter, Quiz, and Help scenes. Input, quiz answers and Help selection survived those transitions without a crash or sustained overlap. This is not final six-language/largest-text/all-angle acceptance; generic iPad snapshots do not establish Duo hinge behavior. The current marketing captures preserve a genuine native Duo display whose pose was not exposed by the capture API.

## Release preparation

Validation evidence from November 5, 2026. The owner reports that the app has been submitted for App Review; the live submission state and submitted build identity were not rechecked in this checkpoint. The earlier stopped full local run finished with 287 passed and 14 failed test definitions and did not execute the entire plan. Its 148 issue entries included repeated snapshot failures. The complete matrix remains to be rerun.

The latest complete `SnapshotTests` run on iOS 27.2 passed all 19 methods with zero failures in 209.8 seconds. The fixture now uses its own window, hides and restores the original app window, restores animation state, and lets UIKit process pending updates between captures. The previously reproduced Observation feedback-loop messages disappeared in the observed run. Image references and comparison thresholds were unchanged by this fixture repair. The separate QuartzCore message `cannot add handler to 0 from 0 - dropping` remains; its cause is not established. AllTests is active with all 354 remaining definitions enabled. Sixteen redundant UI methods were removed during language deduplication; engine, app unit/integration and snapshot definitions were unchanged. This does not establish that the full UI/device matrix or the outstanding StoreKit integration case passed.

| Scope | Result | Limits |
| --- | --- | --- |
| Conversion engine | 76 tests passed; 474/474 lines and 52/52 functions covered. An independent rational-number oracle passed 10,458 checks. | This is engine coverage, not whole-app coverage. Coverage alone did not reveal the long-fraction and silent-rounding defects found and fixed during the audit. |
| App unit/integration tests | An earlier Core checkpoint passed 266 definitions: 76 engine and 190 app tests. The latest complete Core execution passed 265 and failed the repeated-tip integration case at the existing timeout. That failure is under investigation. Native editor/navigation stress previously passed 50/50. | App-target unit coverage from the earlier checkpoint is 2,662/3,752 lines (70.95%) and 342/473 functions (72.30%). These are native Debug unit/integration metrics; earlier UI profiles or changed binaries are not merged into them. |
| Combined app coverage | Earlier passing Core/snapshot/focused-UI profiles, three fully passing four-case UI groups and the native product-metadata probe covered 3,683/3,752 lines (98.16%) and 454/473 functions (95.98%). Every input reproduces native per-file counts. | This is a historical coverage checkpoint, not a fresh measurement of subsequent fixes. Only byte-identical instrumented objects and matching production Swift sources were merged, with no production exclusions. Failed profiles, including the entire Duo group containing a failed case, were excluded. |
| Snapshots | All 1,112 bundled comparisons passed separately on iOS 27.0 and 27.2 after the adaptive-row fix, with unchanged thresholds. The 27.2 map has 780 shared images and 332 independently reviewed runtime overrides. Six shared references were subsequently updated for independently reviewed Russian Help copy corrections. | After that correction, all 480 affected Help/Privacy comparisons passed again on each runtime. Offscreen prose traversal is a separate UI check. The fixture freezes only a fresh discarded test host after a real mounted render; it does not test animation behavior. Four compact ES/PT cuts were fixed and verified with complete-label OCR and row containment. |
| UI validation | Completed functional cells include normal flows in all six languages and English/Russian/French largest-text cases. All four published Home shortcuts passed warm/cold paths. Native iPad base replacement, invalid-input recovery and direct Done-button checks passed. All six largest-text Help table right edges and native Finish large-content viewers were verified. | The complete seven-device matrix and strict native-audit acceptance remain open. Failed Duo input-focus and iPad runtime-synchronization cases are retained for corrected-driver/fresh-host reruns. Long runs retain their actual catalog identity; focused checks cover changed prose separately. Unexpected native findings still fail. |
| Live product metadata | A separate native StoreKit read loaded all five actual App Store products at the current US prices without an active local StoreKit session or UI fixture. | This verifies metadata loading only. No purchase or transaction verification was performed in that read-only check. |
| VoiceOver alerts | Native speech traversal passed wrong-answer and statistics alerts in all six languages, including distinct title/body/OK speech and separate OK focus. Original VoiceOver state was restored. | This is bounded semantic/modal-focus evidence using the iOS27+ public test API, not exhaustive node identity or a waiver of visual audit findings. Older OS versions cannot run this new speech-automation API. |

The accepted app coverage checkpoint is 98.16%; it predates the latest row/spinner layout changes. Completion of the entire UI/device matrix has not been achieved. Transaction tests use Apple's local StoreKit environment; those tests and the separate live metadata read do not establish a completed real sandbox purchase or App Review approval.

The public policy URL is saved in all six App Store localizations, and the Data Not Collected privacy label is published. Ninety native screenshots are uploaded and their previews verified across six languages and iPhone, iPad and the current Duo display; the [asset manifest](AppStoreAssets/MANIFEST.md) records capture limits. Header/Search artwork and refreshed IAP artwork/review images are saved. At the earlier console checkpoint, all five tips were in a saved Ready for Review draft. The owner subsequently reported submitting the app; current in-app purchase review states were not rechecked. Private App Review contact information is saved and verified. The source identity and TestFlight validation of the submitted build remain unverified here; final-source QA and a monitored in-app support contact still need confirmation. Inspect the UserDefaults required-reason manifest and absence of test resources in that archive. A local build, saved listing, or StoreKit test does not establish App Review approval.

Two [custom product page drafts](AppStoreAssets/promotion-pages.json) focus on learning and mixed-base calculations. Each has six saved localized texts, three screenshots per display group and 54 loaded previews, plus Header/Search artwork. Neither page is submitted or approved.

A signed Release 1.6 (80) archive was refreshed after the text correction and inspected: all 1,398 compiled translations match source; the short Home names, opaque icons and privacy manifest are present; test catalogs, fixtures and libraries are absent. The later multiline-input row fix was not validated in that archive; the owner's subsequently submitted build was not inspected in this checkpoint. The earlier distribution-export attempt reported `No Accounts`; final export/upload remains unverified. Genuine iOS 18 fallback testing also remains unverified: Apple's official download commands reported both 18.0 and 18.6 runtime variants unavailable. No physical device was used as a substitute.

## Support and privacy

Read the [six-language support guide](SUPPORT.md). For non-confidential questions or bug reports, use the [project's issue tracker](https://github.com/Dronnn/numberConverter/issues). The private Help contact awaits owner confirmation before release. Keep private numbers, personal information, and payment details out of public issues.

The [privacy policy](PRIVACY.md) describes local storage, optional tips, diagnostics, and contact handling. It is also available from Help inside the app in all six supported languages.

## License

Copyright © Andreas Maier. All rights reserved.
