//
//  ConversionEngine+Coding.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - Parse / render

extension ConversionEngine {
    /// parses an already-validated base-`fromBase` string into an exact `Decimal`.
    ///
    /// the integer part is accumulated with horner's method; the fraction part
    /// sums each digit weighted by `base^-position`. empty / lone `-` / lone `.`
    /// / `-.` map to zero. letters A...Z map to 10...35; the sign is preserved.
    /// callers must validate first.
    static func parse(_ number: String, fromBase: Int) -> Decimal {
        var s = number.replacing(",", with: ".")

        if s.isEmpty || s == "-" || s == "." || s == "-." {
            return .zero
        }

        let negative = s.hasPrefix("-")
        if negative { s.removeFirst() }

        let integerPart: Substring
        let fractionPart: Substring
        if let dotIndex = s.firstIndex(of: ".") {
            integerPart = s[s.startIndex..<dotIndex]
            fractionPart = s[s.index(after: dotIndex)...]
        } else {
            integerPart = s[...]
            fractionPart = s[s.endIndex...]
        }

        let base = Decimal(fromBase)
        var value = Decimal.zero

        // integer part: horner over digits.
        for ch in integerPart {
            value = value * base + Decimal(digitValue(ch))
        }

        // fraction part: digit * base^-pos.
        if !fractionPart.isEmpty {
            var weight = Decimal(1) / base // 1 / base
            for ch in fractionPart {
                value += Decimal(digitValue(ch)) * weight
                weight /= base
            }
        }

        return negative ? -value : value
    }

    /// renders an exact `Decimal` into a base-`toBase` string: the integer part
    /// via repeated euclidean division, the fraction part via repeated
    /// multiply-by-base, with base-aware half-up rounding of the final fraction
    /// digit and carry that can ripple into the integer part.
    static func render(_ value: Decimal, toBase: Int) -> String {
        if value == .zero { return "0" }

        let negative = value < .zero
        let magnitude = negative ? -value : value
        let base = Decimal(toBase)

        var integerValue = floor(magnitude)       // value >= 0 so floor == truncation
        let fraction = magnitude - integerValue   // 0 <= fraction < 1

        var integerString = renderInteger(integerValue, base: toBase)

        // fractional digits as values so rounding can carry.
        var fractionDigits: [Int] = []
        var f = fraction
        for _ in 0..<maxFractionDigits {
            if f == .zero { break }
            f *= base
            let digit = floor(f)
            fractionDigits.append(intValue(digit))
            f -= digit
        }

        // round the final digit half-up when a non-zero remainder is >= 1/2.
        if !fractionDigits.isEmpty, f != .zero, f + f >= Decimal(1) {
            var i = fractionDigits.count - 1
            var carry = true
            while i >= 0, carry {
                fractionDigits[i] += 1
                if fractionDigits[i] == toBase {
                    // base-aware carry: carry only when the digit reaches the base.
                    fractionDigits[i] = 0
                    carry = true
                    i -= 1
                } else {
                    carry = false
                }
            }
            if carry {
                // carry rippled past the radix point into the integer part.
                integerValue += 1
                integerString = renderInteger(integerValue, base: toBase)
            }
        }

        // trim trailing zero fraction digits.
        while let last = fractionDigits.last, last == 0 {
            fractionDigits.removeLast()
        }

        let result: String
        if fractionDigits.isEmpty {
            result = integerString
        } else {
            let fractionString = String(fractionDigits.map { digitCharacter($0) })
            result = integerString + "." + fractionString
        }

        if result == "0" { return "0" }
        return negative ? "-" + result : result
    }

    // MARK: Decimal helpers

    /// renders a non-negative integer-valued `Decimal` to a base string via
    /// repeated euclidean division.
    private static func renderInteger(_ value: Decimal, base: Int) -> String {
        if value == .zero { return "0" }
        var digitsOut: [Character] = []
        var n = value
        let baseDecimal = Decimal(base)
        while n > .zero {
            let quotient = floor(n / baseDecimal)
            let remainder = n - quotient * baseDecimal
            digitsOut.append(digitCharacter(intValue(remainder)))
            n = quotient
        }
        return String(digitsOut.reversed())
    }

    /// largest integer-valued `Decimal` not greater than a non-negative `value`;
    /// exact for the engine's value ranges.
    private static func floor(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .down)
        return result
    }

    /// converts an integer-valued `Decimal` (a single base digit, 0...35) to `Int`.
    private static func intValue(_ value: Decimal) -> Int {
        NSDecimalNumber(decimal: value).intValue
    }
}
