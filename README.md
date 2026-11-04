# NumberConverter

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
- Adaptive Help and Quiz navigation for compact screens, iPad, and iPhone Duo.
- Native Liquid Glass navigation and tip buttons on iOS 26+, with standard controls on older supported versions.

## Stack

- Swift 6, SwiftUI, MVVM
- iOS 18+
- Conversion logic in a local Swift package
- Apple-native diagnostics (os.Logger, MetricKit)

## Development

- The "Lint & Format" build phase checks formatting and lint without rewriting source. Configs live at the repo root. The phase adds the standard Apple Silicon and Intel Homebrew binary directories to `PATH`, so GUI-launched Xcode can find installed tools.
- Run `Scripts/update-lint-inputs.sh` after adding or removing Swift files. The generated input list lets the build checks run with Xcode's script sandbox enabled.
- Build through Xcode. Run the unit and snapshot tests before pushing.
- The conversion package has standalone correctness and safety tests (`swift test --package-path ConversionEngine --enable-code-coverage`). Arithmetic uses native `Decimal` precision; unsupported precision/range is reported as an error. Two's complement uses signed, byte-aligned native integers.
- UI tests cover the supported languages, full feature flows, large text, rotation, persistence, and accessibility. Snapshot tests cover compact/standard/landscape/tablet layouts in light and dark mode.

## Developer tips

`numberConverter/Support/TipJar.storekit` contains local test products at USD 3, 9, 19, 49, and 99. The shared Debug scheme selects it for local StoreKit testing. These are consumable tips, without subscriptions or feature unlocks. Production displays `Product.displayPrice` from the customer's App Store storefront; it never substitutes a hardcoded price when products cannot be loaded.

Before release, create the five consumable products from `TipProduct.allowedIDs` in App Store Connect, add their six localized names/descriptions, set prices and availability, and complete the account's commerce setup. The local StoreKit configuration does not create App Store Connect products. Test the submitted products with an App Store sandbox account before release.

Unit tests inject a `TipService`; StoreKit integration tests use `SKTestSession` and real local StoreKit products/transactions. UI tests explicitly select a DEBUG-only tip fixture so they cannot charge money. Release builds ignore that fixture argument.

## Test scope

Conversion-engine coverage, app code coverage, and UI matrix completion are separate measurements. A line-coverage percentage does not establish that every possible input, screen size, device pose, or translation is correct. Keep the actual `.xcresult` bundles and coverage reports when reporting a run.

Each language has a navigation smoke test, a full end-to-end test, and a largest-text layout test. Completed flows attach a `workflow-completed` marker; an interrupted flow is a failure. Native accessibility audits retain issue attachments. Exact Dynamic Type diagnostics for measured SwiftUI elements are classified using separate screenshot/glyph-growth regressions; unexpected issues still fail.

The Duo outer display can be tested on the available simulator. Open and Book poses require working Simulator fold controls or RocketSim; generic iPad snapshots are not evidence that a Duo hinge transition passed.

## Release preparation

The engine has 68 passing tests and 100% line/function coverage, including large-number round trips through every supported base. App-wide 100% coverage and completion of the entire UI/device matrix have not been achieved; full UI validation is ongoing.

Release also requires a public privacy policy linked inside the app and in App Store Connect, the UserDefaults required-reason privacy manifest, production tip products and commerce setup, localized store metadata/screenshots, privacy/age-rating declarations, and a signed Release archive validated through TestFlight. A local build or StoreKit test does not establish App Review approval.

## License

Copyright © Andreas Maier. All rights reserved.
