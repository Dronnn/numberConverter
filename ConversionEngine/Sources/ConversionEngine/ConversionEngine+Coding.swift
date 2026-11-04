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
    /// finite input coefficients must fit `Decimal` exactly. non-terminating
    /// fractions use native decimal precision before the final 12-digit rounding.
    static func parse(_ number: String, fromBase: Int,
                      allowRecurringFraction: Bool = false) throws(ConversionError) -> Decimal {
        var normalized = number.replacing(",", with: ".")
        let negative = normalized.hasPrefix("-")
        if negative { normalized.removeFirst() }
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        let integerPart = parts[0]
        var fractionPart = parts.count > 1 ? parts[1] : Substring()
        while fractionPart.last == "0" { fractionPart.removeLast() }

        let base = Decimal(fromBase)
        var coefficient = Decimal.zero
        for character in integerPart + fractionPart {
            coefficient = try decimalOperation(.multiply, coefficient, base)
            coefficient = try decimalOperation(.add, coefficient, Decimal(digitValue(character)))
        }
        var divisor = Decimal(1)
        for _ in fractionPart {
            divisor = try decimalOperation(.multiply, divisor, base)
        }
        let value = try decimalOperation(.divide, coefficient, divisor)
        if !allowRecurringFraction {
            let result = decimalComponents(value)
            let product = multiplyIntegers(result.digits, decimalComponents(divisor).digits)
            let expected = normalizedDigits(decimalComponents(coefficient).digits + Array(repeating: 0, count: result.scale))
            guard product == expected else { throw .numberOutOfRange }
        }
        return negative ? -value : value
    }

    /// decimal operations report overflow/underflow and discarded significant digits.
    /// division may produce a recurring fraction, which the renderer rounds explicitly.
    static func decimalOperation(_ operation: Operation,
                                 _ lhs: Decimal,
                                 _ rhs: Decimal) throws(ConversionError) -> Decimal {
        var left = lhs
        var right = rhs
        var result = Decimal()
        let error: Decimal.CalculationError
        switch operation {
        case .add: error = NSDecimalAdd(&result, &left, &right, .plain)
        case .subtract:
            var negativeRight = -right
            error = NSDecimalAdd(&result, &left, &negativeRight, .plain)
        case .multiply: error = NSDecimalMultiply(&result, &left, &right, .plain)
        case .divide: error = NSDecimalDivide(&result, &left, &right, .plain)
        }
        if error == .divideByZero { throw .divisionByZero }
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
