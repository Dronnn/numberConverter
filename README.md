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

## Xcode Cloud tests

Open `numberConverter.xcworkspace` and select the shared `numberConverter` scheme. Its default **AllTests** plan includes the engine, app unit/integration, snapshot and UI targets without filters. The separate engine action is unnecessary when a workflow uses the workspace and this plan: its 76 definitions are already included.

The 15 plans in `TestPlans/` partition that inventory into Core, Snapshots, SharedUI, six normal-language plans and six largest-text plans. `Scripts/validate-cloud-test-plans.py` checks the partition against Xcode's native test enumeration, including missing, duplicate, disabled or unknown tests. Snapshot recording stays disabled. Building or enumerating a plan does not establish a test pass.

Run `CloudSnapshots` on its pinned 3× Pro host. Its device presets test different point sizes using that host's renderer; they do not establish 2× iPad snapshot-host compatibility. Use the language and largest-text UI plans for actual iPad and Duo execution. The unfiltered `AllTests` plan includes the same host-specific snapshot suite.

The earlier remote Default build failed: the unsharded four-device run exceeded its whole-build time limit and reported missing snapshot references and UI failures. The reference resolver now supports bundled test resources; local validation of these fixes and a replacement Cloud workflow are separate gates. Workflow changes are not yet confirmed saved. Use separate builds for the plans, starting with `CloudCore` on one iPhone and manual Snapshot/AX pilots. Measure runtime and compute before enabling a larger schedule; the full four-device language matrix exceeds the account's last observed remaining allowance. Do not stack all 15 actions into a single build.

The separate `ci_scripts/ci_pre_xcodebuild.sh` setup hook installs missing SwiftFormat and SwiftLint through Homebrew and verifies both executables before the app build. Installation failures fail the Cloud action. Engine tests do not run in this hook. Its syntax and mocked setup/failure cases passed locally; actual Cloud execution is still pending.

## Developer tips

`numberConverterTests/Resources/TipJar.storekit` contains local test products at USD 2.99, 8.99, 19.99, 49.99, and 99.99. The shared Debug scheme selects this file for local StoreKit testing; integration tests load it from the test bundle with `SKTestSession(contentsOf:)`. The catalog is not a production app resource. These are consumable tips, without subscriptions or feature unlocks. Production displays `Product.displayPrice` from the customer's App Store storefront; it never substitutes a hardcoded price when products cannot be loaded.

The five consumable products from `TipProduct.allowedIDs` are configured in App Store Connect with USD base prices 2.99, 8.99, 19.99, 49.99, and 99.99, six localized names/descriptions, availability, and review screenshots/notes. All five review screenshots show the current USD prices, and all five products have 1024-pixel tip artwork. These saved prices and image attachments were verified after reloading each product. The first two tips have lower custom prices in 142 storefronts, verified after reloading all country prices; the other 33 storefronts and the three larger tips retain Apple's automatic equivalents. For example, the first two tips are EUR 2.99/9.99 in Germany, EUR 0.99/3.99 in Lithuania, USD 0.49/1.99 in Armenia, and INR 29/99 in India. These are optional-tip pricing choices, not predictions of individual affordability. Review manual prices quarterly because Apple does not automatically update them for exchange rates or taxes. The complete [regional price snapshot and maintenance policy](AppStoreAssets/pricing/POLICY.md) is included with the store assets. The app download price is configured as free in all 175 storefronts, and the calculated 4+ age rating and content-rights declaration are saved. The products and app remain unsubmitted. Production App Store sandbox transactions and final release validation are still required; local StoreKit tests do not establish that approval or storefront availability is complete.

Unit tests inject a `TipService`; StoreKit integration tests use `SKTestSession` and real local StoreKit products/transactions. UI tests explicitly select a DEBUG-only tip fixture so they cannot charge money. Release builds ignore that fixture argument.

## Test scope

Conversion-engine coverage, app code coverage, and UI matrix completion are separate measurements. A line-coverage percentage does not establish that every possible input, screen size, device pose, or translation is correct. Keep the actual `.xcresult` bundles and coverage reports when reporting a run.

Each language has a navigation smoke test, a full end-to-end test, and a largest-text layout test. Completed flows attach a `workflow-completed` marker; an interrupted flow is a failure. Native accessibility audits retain issue attachments. Exact Dynamic Type diagnostics for measured SwiftUI elements are classified using separate screenshot/glyph-growth regressions; unexpected issues still fail.

An earlier Device Hub checkpoint on iPhone Duo/iOS 27.1 verified Closed, Open, and Partially Open transitions and rotation for English normal-text Converter, Quiz, and Help scenes. Input, quiz answers and Help selection survived those transitions without a crash or sustained overlap. This is not final six-language/largest-text/all-angle acceptance; generic iPad snapshots do not establish Duo hinge behavior. The current marketing captures preserve a genuine native Duo display whose pose was not exposed by the capture API.

## Release preparation

Latest completed validation checkpoint, November 5, 2026 (additional audit fixes are still being validated):

| Scope | Result | Limits |
| --- | --- | --- |
| Conversion engine | 76 tests passed; 474/474 lines and 52/52 functions covered. An independent rational-number oracle passed 10,458 checks. | This is engine coverage, not whole-app coverage. Coverage alone did not reveal the long-fraction and silent-rounding defects found and fixed during the audit. |
| App unit/integration tests | The current Core plan passed all 266 checks: 76 engine and 190 app tests, with no failures or skips. Earlier 257-test checkpoints passed three consecutive runs. Native editor/navigation stress passed 50/50. | Current app-target unit coverage is 2,662/3,752 lines (70.95%) and 342/473 functions (72.30%). These are native Debug unit/integration metrics; earlier UI profiles or changed binaries are not merged into them. |
| Combined app coverage | Passed Core266 and full Snapshot19 profiles cover 3,555/3,752 lines (94.75%) and 425/473 functions (89.85%). Each input reproduces its native per-run counts. | Only the byte-identical instrumented app object and matching production Swift sources are merged, with unchanged denominators, no exclusions and no failed diagnostic profiles. Completed UI profiles are not yet included. |
| Snapshots | All 1,112 bundled comparisons passed separately on iOS 27.0 and 27.2 after the adaptive-row fix, with unchanged thresholds. The 27.2 map has 780 shared images and 332 independently reviewed runtime overrides. Six shared references were subsequently updated for independently reviewed Russian Help copy corrections. | After that correction, all 480 affected Help/Privacy comparisons passed again on each runtime. Offscreen prose traversal is a separate UI check. The fixture freezes only a fresh discarded test host after a real mounted render; it does not test animation behavior. Four compact ES/PT cuts were fixed and verified with complete-label OCR and row containment. |
| UI validation | Twelve functional cells have passed, including normal flows in all six languages and completed English/Russian/French largest-text cases. All four published Home shortcuts passed warm/cold paths. Native iPad base replacement, invalid-input recovery and direct Done-button checks passed. All six largest-text Help table right edges and native Finish large-content viewers were verified. | The complete 48-cell matrix and strict native-audit acceptance remain open. A French Duo largest-text run failed at a calculator-field focus step and is under driver investigation. The long runs retain their pre-correction catalog identity; focused checks cover changed prose separately. Unexpected native findings still fail. |
| Live product metadata | A separate native StoreKit read loaded all five actual App Store products at the current US prices without an active local StoreKit session or UI fixture. | This verifies metadata loading only. No purchase or transaction verification was performed in that read-only check. |

App-wide 100% coverage and completion of the entire UI/device matrix have not been achieved. Transaction tests use Apple's local StoreKit environment; those tests and the separate live metadata read do not establish a completed real sandbox purchase or App Review approval.

The public policy URL is saved in all six App Store localizations. Ninety native screenshots are uploaded and their previews verified across six languages and iPhone, iPad and the current Duo display; the [asset manifest](AppStoreAssets/MANIFEST.md) records capture limits. Header/Search artwork and refreshed IAP artwork/review images are saved. Final-source QA, a monitored private support contact, App Review contact information, privacy-label publication, and a signed final Release upload validated through TestFlight remain release gates. Inspect the UserDefaults required-reason manifest and absence of test resources in that archive. A local build, saved listing, or StoreKit test does not establish App Review approval.

Two [custom product page drafts](AppStoreAssets/promotion-pages.json) focus on learning and mixed-base calculations. Each has six saved localized texts, three screenshots per display group and 54 loaded previews, plus Header/Search artwork. Neither page is submitted or approved.

A signed Release 1.6 (80) archive has been refreshed after the final text correction and inspected: all 1,398 compiled translations match source; the short Home names, opaque icons and privacy manifest are present; test catalogs, fixtures and libraries are absent. Local distribution export is blocked by Xcode reporting `No Accounts`, so this final candidate has not been uploaded. Genuine iOS 18 fallback testing also remains unverified: Apple's official download commands reported both 18.0 and 18.6 runtime variants unavailable. No physical device was used as a substitute.

## Support and privacy

Read the [six-language support guide](SUPPORT.md). For non-confidential questions or bug reports, use the [project's issue tracker](https://github.com/Dronnn/numberConverter/issues). The private Help contact awaits owner confirmation before release. Keep private numbers, personal information, and payment details out of public issues.

The [privacy policy](PRIVACY.md) describes local storage, optional tips, diagnostics, and contact handling. It is also available from Help inside the app in all six supported languages.

## License

Copyright © Andreas Maier. All rights reserved.
