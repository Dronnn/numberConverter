//
//  ConversionEngine+Division.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

extension ConversionEngine {
    /// division rounds the exact ratio of two finite native decimals. this avoids
    /// moving an exact half-unit tie to either side through intermediate rounding.
    static func divide(_ lhs: Decimal, _ rhs: Decimal, toBase: Int) throws(ConversionError) -> String {
        guard rhs != .zero else { throw .divisionByZero }
        let left = decimalComponents(lhs)
        let right = decimalComponents(rhs)
        let numerator = left.digits + Array(repeating: 0, count: right.scale)
        let denominator = right.digits + Array(repeating: 0, count: left.scale)
        let whole = divideIntegers(numerator, by: denominator)
        let wholeText = whole.quotient.isEmpty ? "0" : String(whole.quotient.map(digitCharacter))
        // reject integer quotients that exceed native Decimal precision instead of
        // returning a fabricated rounded integer such as 10^100 / 3.
        _ = try parse(wholeText, fromBase: 10)
        var digits = renderPositional(wholeText, fromBase: 10, toBase: toBase).map(digitValue)
        var remainder = whole.remainder
        var fractionCount = 0
        for _ in 0..<maxFractionDigits {
            if remainder.isEmpty { break }
            let step = divideIntegers(multiplyIntegers(remainder, String(toBase).map(digitValue)), by: denominator)
            digits.append(step.quotient.reduce(0) { $0 * 10 + $1 })
            remainder = step.remainder
            fractionCount += 1
        }
        let roundUp = isAtLeast(multiplyIntegers(remainder, [2]), denominator)
        let result = finishDigits(digits, fractionCount: fractionCount, roundUp: roundUp,
                                  negative: (lhs < .zero) != (rhs < .zero), base: toBase)
        // the rounded coefficient must also fit the supported native precision.
        _ = try parse(result, fromBase: toBase, allowRecurringFraction: true)
        return result
    }

    /// absolute decimal coefficient and the number of decimal places.
    static func decimalComponents(_ value: Decimal) -> (digits: [Int], scale: Int) {
        var magnitude = value < .zero ? -value : value
        let text = NSDecimalString(&magnitude, Locale(identifier: "en_US_POSIX"))
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let fraction = parts.count > 1 ? String(parts[1]) : ""
        return (normalizedDigits((String(parts[0]) + fraction).map(digitValue)), fraction.count)
    }

    static func normalizedDigits(_ digits: [Int]) -> [Int] {
        Array(digits.drop(while: { $0 == 0 }))
    }

    /// decimal digit-array helpers operate on coefficients bounded by native
    /// Decimal range and maxInputLength, not on unbounded public number types.
    static func isAtLeast(_ lhs: [Int], _ rhs: [Int]) -> Bool {
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        return !lhs.lexicographicallyPrecedes(rhs)
    }

    static func multiplyIntegers(_ lhs: [Int], _ rhs: [Int]) -> [Int] {
        var result = Array(repeating: 0, count: lhs.count + rhs.count)
        for leftIndex in lhs.indices.reversed() {
            var carry = 0
            for rightIndex in rhs.indices.reversed() {
                let index = leftIndex + rightIndex + 1
                let product = lhs[leftIndex] * rhs[rightIndex] + result[index] + carry
                result[index] = product % 10
                carry = product / 10
            }
            result[leftIndex] += carry
        }
        return normalizedDigits(result)
    }

    static func subtractIntegers(_ lhs: [Int], _ rhs: [Int]) -> [Int] {
        var result = lhs
        var borrow = 0
        for index in lhs.indices.reversed() {
            let rightIndex = index - (lhs.count - rhs.count)
            let rightDigit = rightIndex >= 0 ? rhs[rightIndex] : 0
            let difference = lhs[index] - rightDigit - borrow
            result[index] = difference < 0 ? difference + 10 : difference
            borrow = difference < 0 ? 1 : 0
        }
        return normalizedDigits(result)
    }

    static func divideIntegers(_ numerator: [Int], by denominator: [Int]) -> (quotient: [Int], remainder: [Int]) {
        var quotient: [Int] = []
        var remainder: [Int] = []
        for digit in numerator {
            remainder = normalizedDigits(remainder + [digit])
            var next = 0
            while isAtLeast(remainder, denominator) {
                remainder = subtractIntegers(remainder, denominator)
                next += 1
            }
            quotient.append(next)
        }
        return (normalizedDigits(quotient), remainder)
    }
}
