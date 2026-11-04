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
    /// arithmetic values must fit `Decimal` exactly after rational reduction.
    /// ordinary conversion retains its existing approximate fractional range check.
    static func parse(_ number: String, fromBase: Int,
                      allowRecurringFraction: Bool = false) throws(ConversionError) -> Decimal {
        var normalized = number.replacing(",", with: ".")
        let negative = normalized.hasPrefix("-")
        if negative { normalized.removeFirst() }
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        let integerPart = parts[0]
        var fractionPart = parts.count > 1 ? parts[1] : Substring()
        while fractionPart.last == "0" { fractionPart.removeLast() }

        // a prefix can exceed native precision even when the complete integer
        // fits exactly: a binary representation of 10^100 passes through 5^100
        // before its trailing zero bits. validate the complete coefficient only.
        let coefficientText = renderPositional(String(integerPart + fractionPart), fromBase: fromBase, toBase: 10)
        if fractionPart.isEmpty {
            let value = try exactDecimal(coefficientText)
            return negative ? -value : value
        }
        if let decimalText = finiteDecimalText(coefficientText, fromBase: fromBase, places: fractionPart.count),
           let value = try? exactDecimal(decimalText) {
            return negative ? -value : value
        }
        guard allowRecurringFraction else { throw .numberOutOfRange }
        // only ordinary conversion uses this approximate range check. final
        // rendering uses the exact source digits, never this approximation.
        let coefficient = try exactDecimal(coefficientText)
        let base = Decimal(fromBase)
        var divisor = Decimal(1)
        for _ in fractionPart {
            divisor = try fractionOperation(divisor, base, multiplying: true)
        }
        let value = try fractionOperation(coefficient, divisor, multiplying: false)
        return negative ? -value : value
    }

    private static func exactDecimal(_ text: String) throws(ConversionError) -> Decimal {
        let locale = Locale(identifier: "en_US_POSIX")
        guard var value = Decimal(string: text, locale: locale), !value.isNaN,
              NSDecimalString(&value, locale) == text else {
            throw .numberOutOfRange
        }
        return value
    }

    /// cancel the positional denominator before judging native precision. e.g.
    /// 3^100 / 30^100 is the exact native decimal 10^-100 even though neither
    /// unreduced coefficient fits. a reduced finite denominator contains only 2/5.
    private static func finiteDecimalText(_ text: String, fromBase: Int, places: Int) -> String? {
        // after trailing source zeroes are removed, an exact native decimal
        // cannot require more fractional source places than its minimum exponent.
        guard places <= 128 else { return nil }
        var digits = text.map(digitValue)
        var remainingBase = fromBase
        var twos = 0
        var fives = 0
        for factor in 2...fromBase {
            var count = 0
            while remainingBase.isMultiple(of: factor) {
                remainingBase /= factor
                count += places
            }
            guard count > 0 else { continue }
            let divisor = String(factor).map(digitValue)
            while count > 0 {
                let step = divideIntegers(digits, by: divisor)
                if !step.remainder.isEmpty { break }
                digits = step.quotient
                count -= 1
            }
            if factor == 2 {
                twos = count
            } else if factor == 5 {
                fives = count
            } else if count > 0 {
                return nil
            }
        }
        let scale = max(twos, fives)
        let multiplier = twos > fives ? [5] : [2]
        for _ in 0..<abs(twos - fives) {
            digits = multiplyIntegers(digits, multiplier)
        }
        let padded = Array(repeating: 0, count: max(0, scale - digits.count + 1)) + digits
        return finishDigits(padded, fractionCount: scale, roundUp: false, negative: false, base: 10)
    }

    /// constructs the exact non-division result before native range judgment.
    /// NSDecimalAdd/Multiply can silently round even when they return .noError.
    static func arithmetic(_ operation: Operation, _ lhs: Decimal, _ rhs: Decimal) throws(ConversionError) -> Decimal {
        let left = decimalComponents(lhs)
        let right = decimalComponents(rhs)
        let digits: [Int]
        let negative: Bool
        let scale: Int
        if operation == .multiply {
            digits = multiplyIntegers(left.digits, right.digits)
            negative = (lhs < .zero) != (rhs < .zero)
            scale = left.scale + right.scale
        } else {
            scale = max(left.scale, right.scale)
            let a = normalizedDigits(left.digits + Array(repeating: 0, count: scale - left.scale))
            let b = normalizedDigits(right.digits + Array(repeating: 0, count: scale - right.scale))
            let leftNegative = lhs < .zero
            let rightNegative = (rhs < .zero) != (operation == .subtract)
            if leftNegative == rightNegative {
                digits = addIntegers(a, b)
                negative = leftNegative
            } else if isAtLeast(a, b) {
                digits = subtractIntegers(a, b)
                negative = leftNegative
            } else {
                digits = subtractIntegers(b, a)
                negative = rightNegative
            }
        }
        let padded = Array(repeating: 0, count: max(0, scale - digits.count + 1)) + digits
        let text = finishDigits(padded, fractionCount: scale, roundUp: false, negative: negative, base: 10)
        return try exactDecimal(text)
    }

    /// approximate native fractions are used only to preserve the conversion
    /// range policy; exact arithmetic and final output never depend on them.
    private static func fractionOperation(_ lhs: Decimal, _ rhs: Decimal,
                                          multiplying: Bool) throws(ConversionError) -> Decimal {
        var left = lhs
        var right = rhs
        var result = Decimal()
        let error: Decimal.CalculationError
        if multiplying {
            error = NSDecimalMultiply(&result, &left, &right, .plain)
        } else {
            error = NSDecimalDivide(&result, &left, &right, .plain)
        }
        guard error == .noError, !result.isNaN else { throw .numberOutOfRange }
        return result
    }

    /// renders a finite native decimal without rounding its integer quotient.
    static func render(_ value: Decimal, toBase: Int) -> String {
        var decimal = value
        let text = NSDecimalString(&decimal, Locale(identifier: "en_US_POSIX"))
        return renderPositional(text, fromBase: 10, toBase: toBase)
    }

    /// exact positional conversion uses only small digit/carry arithmetic. in
    /// particular, binary/hexadecimal half-up ties never depend on an approximate
    /// intermediate decimal fraction.
    static func renderPositional(_ number: String, fromBase: Int, toBase: Int) -> String {
        var normalized = number
        let negative = normalized.hasPrefix("-")
        if negative { normalized.removeFirst() }
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        var whole = parts[0].map(digitValue)
        var fraction = parts.count > 1 ? parts[1].map(digitValue) : []
        var result: [Int] = []
        repeat {
            var quotient: [Int] = []
            var remainder = 0
            for digit in whole {
                let current = remainder * fromBase + digit
                let next = current / toBase
                remainder = current % toBase
                if next != 0 || !quotient.isEmpty { quotient.append(next) }
            }
            result.append(remainder)
            whole = quotient
        } while !whole.isEmpty
        result.reverse()

        var fractionCount = 0
        for _ in 0..<maxFractionDigits {
            if fraction.allSatisfy({ $0 == 0 }) { break }
            result.append(multiplyFraction(&fraction, by: toBase, base: fromBase))
            fractionCount += 1
        }
        return finishDigits(result, fractionCount: fractionCount,
                            roundUp: multiplyFraction(&fraction, by: 2, base: fromBase) != 0,
                            negative: negative, base: toBase)
    }

    static func finishDigits(_ digits: [Int], fractionCount: Int, roundUp: Bool,
                             negative: Bool, base: Int) -> String {
        var result = digits
        var fractionCount = fractionCount
        if roundUp {
            var index = result.count - 1
            while index >= 0, result[index] == base - 1 {
                result[index] = 0
                index -= 1
            }
            if index >= 0 {
                result[index] += 1
            } else {
                result.insert(1, at: 0)
            }
        }
        while fractionCount > 0, result.last == 0 {
            result.removeLast()
            fractionCount -= 1
        }
        var text = String(result.map(digitCharacter))
        if fractionCount > 0 {
            text.insert(".", at: text.index(text.endIndex, offsetBy: -fractionCount))
        }
        if text == "0" { return "0" }
        return negative ? "-" + text : text
    }

    /// multiplies a base-fraction in place and returns its whole part. each
    /// temporary value is bounded by 35*36+35, so native integer arithmetic is exact.
    private static func multiplyFraction(_ digits: inout [Int], by multiplier: Int, base: Int) -> Int {
        var carry = 0
        for index in digits.indices.reversed() {
            let product = digits[index] * multiplier + carry
            digits[index] = product % base
            carry = product / base
        }
        return carry
    }
}
