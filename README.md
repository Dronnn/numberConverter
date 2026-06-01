# NumberConverter

An iOS app for working with numeral systems. Convert numbers between any bases from 2 to 36, perform arithmetic across mixed bases, view a number in binary/octal/decimal/hexadecimal at once, and test yourself with a built-in quiz.

A from-scratch SwiftUI rewrite of the original "Number Systems" app.

## Features

- **Converter** — live conversion between binary, octal, decimal, and hexadecimal, with optional two's-complement representation.
- **All systems** — convert a number from any base (2–36) to any other base.
- **Calculator** — add, subtract, multiply, and divide numbers given in different bases, with the result in a base of your choice.
- **Quiz** — practice conversions per base (integers and fractions) with score tracking.
- **Info** — built-in help on how numeral systems work.
- Watch app, home-screen widget, and app-icon quick actions.
- English and Russian, with more languages to come.

## Stack

- Swift 6, SwiftUI, MVVM
- iOS 18+
- Conversion logic in a local Swift package
- Apple-native diagnostics (os.Logger, MetricKit)

## Development

- SwiftLint and SwiftFormat run automatically in the "Lint & Format" build phase. Configs live at the repo root.
- Build through Xcode. Run the unit and snapshot tests before pushing.

## License

Copyright © Andreas Maier. All rights reserved.
