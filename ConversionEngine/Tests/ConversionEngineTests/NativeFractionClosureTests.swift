//
//  NativeFractionClosureTests.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation
import Testing

@Suite struct NativeFractionClosureTests {
    @Test(arguments: [10, 20, 30])
    func nativePowersOfTenSurviveFractionalRadixCoefficients(_ base: Int) {
        for scale in [1, 12, 38, 80, 81, 100, 127, 128] {
            let input = fractionalOracle(coefficient: "1", scale: scale, base: base)
            let expected = Decimal(sign: .plus, exponent: -scale, significand: 1)
            let multiplier = "1" + String(repeating: "0", count: scale)
            let rounded = scale > 12 ? "0" : "0." + String(repeating: "0", count: scale - 1) + "1"
            for sign in ["", "-"] {
                #expect(ConversionEngine.toDecimal(sign + input, fromBase: base) == (sign.isEmpty ? expected : -expected))
                #expect(ConversionEngine.convert(sign + input, fromBase: base, toBase: 10) == .success(rounded == "0" ? rounded : sign + rounded))
                #expect(ConversionEngine.calculate(.multiply, sign + input, base: base, multiplier, base: 10, resultBase: 10) == .success(sign + "1"))
                #expect(ConversionEngine.calculate(.divide, sign + input, base: base, sign + input, base: base, resultBase: 10) == .success("1"))
            }
        }
    }

    @Test func adjacentNativeCoefficientsAtTheMinimumExponentRemainDistinct() {
        let coefficients = [
            "9999999999999999999999999999",
            "10000000000000000000000000001",
            "340282366920938463463374607431768211455" // native 2^128 - 1
        ]
        let multiplier = "1" + String(repeating: "0", count: 128)
        for coefficient in coefficients {
            let expected = Decimal(sign: .plus, exponent: -128, significand: Decimal(string: coefficient)!)
            for base in [10, 20, 30] {
                let input = fractionalOracle(coefficient: coefficient, scale: 128, base: base)
                #expect(ConversionEngine.toDecimal(input, fromBase: base) == expected)
                #expect(ConversionEngine.toDecimal("-" + input, fromBase: base) == -expected)
                #expect(ConversionEngine.calculate(.multiply, input, base: base, multiplier, base: 10, resultBase: 10) == .success(coefficient))
            }
        }
    }

    @Test func nativeFractionsDoNotRequireNativeRepresentableDenominators() {
        // 5^-127 = 2^127 * 10^-127 and 25^-63 = 2^126 * 10^-126.
        for (base, places, scale, coefficient) in [
            (5, 127, 127, "170141183460469231731687303715884105728"),
            (25, 63, 126, "85070591730234615865843651857942052864")
        ] {
            let input = "0." + String(repeating: "0", count: places - 1) + "1"
            let expected = Decimal(sign: .plus, exponent: -scale, significand: Decimal(string: coefficient)!)
            #expect(ConversionEngine.toDecimal(input, fromBase: base) == expected)
            #expect(ConversionEngine.convert(input, fromBase: base, toBase: 10) == .success("0"))
            let multiplier = "1" + String(repeating: "0", count: scale)
            #expect(ConversionEngine.calculate(.multiply, input, base: base, multiplier, base: 10, resultBase: 10) == .success(coefficient))
        }
        #expect(ConversionEngine.toDecimal("7.F", fromBase: 30) == Decimal(string: "7.5"))
        #expect(ConversionEngine.toDecimal("0.3", fromBase: 6) == Decimal(string: "0.5"))
    }

    @Test func finalNativePrecisionAndUnderflowStillFailAfterReduction() {
        let overflowCoefficient = "340282366920938463463374607431768211456"
        // (10^1400+1)/10^128 is outside native magnitude. Its base-30
        // numerator contains 3^128, but that cancellation must not delay rejection.
        let hugeForeignCancellation = fractionalOracle(
            coefficient: "1" + String(repeating: "0", count: 1399) + "1", scale: 128, base: 30
        )
        #expect(hugeForeignCancellation.utf8.count <= ConversionEngine.maxInputLength)
        let inputs = [
            (30, hugeForeignCancellation),
            (30, fractionalOracle(coefficient: overflowCoefficient, scale: 128, base: 30)),
            (10, fractionalOracle(coefficient: "1", scale: 129, base: 10)),
            (20, fractionalOracle(coefficient: "1", scale: 129, base: 20)),
            (30, fractionalOracle(coefficient: "1", scale: 129, base: 30))
        ]
        for (base, input) in inputs {
            #expect(ConversionEngine.toDecimal(input, fromBase: base) == nil)
            #expect(ConversionEngine.convert(input, fromBase: base, toBase: 10) == .failure(.numberOutOfRange))
            #expect(ConversionEngine.calculate(.add, input, base: base, "0", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        }
        // 2^-56 exceeds exact native precision but remains an ordinary
        // conversion input; twelve decimal output places round it to zero.
        for (base, places) in [(2, 56), (5, 128)] {
            let inexact = "0." + String(repeating: "0", count: places - 1) + "1"
            #expect(ConversionEngine.toDecimal(inexact, fromBase: base) == nil)
            #expect(ConversionEngine.convert(inexact, fromBase: base, toBase: 10) == .success("0"))
            #expect(ConversionEngine.calculate(.add, inexact, base: base, "0", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        }
    }

    @Test func recurringFractionsKeepConversionAndArithmeticContracts() {
        for (base, rounded) in [(3, "0.333333333333"), (6, "0.166666666667"),
                                (7, "0.142857142857"), (11, "0.090909090909"), (30, "0.033333333333")] {
            #expect(ConversionEngine.convert("0.1", fromBase: base, toBase: 10) == .success(rounded))
            #expect(ConversionEngine.toDecimal("0.1", fromBase: base) == nil)
            #expect(ConversionEngine.calculate(.multiply, "0.1", base: base, String(base), base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        }
    }

    /// Independent construction: m/10^n = (m*(b/10)^n)/b^n for b=10,20,30.
    /// Accumulate directly in the target radix; production instead reduces a
    /// parsed decimal coefficient by denominator primes. Every carry fits Int.
    private func fractionalOracle(coefficient: String, scale: Int, base: Int) -> String {
        var digits = [0]
        for byte in coefficient.utf8 {
            multiply(&digits, by: 10, adding: Int(byte - 48), base: base)
        }
        for _ in 0..<scale {
            multiply(&digits, by: base / 10, adding: 0, base: base)
        }
        let text = digits.reversed().map { String($0, radix: 36, uppercase: true) }.joined()
        let padded = String(repeating: "0", count: max(0, scale - text.count + 1)) + text
        let point = padded.index(padded.endIndex, offsetBy: -scale)
        return String(padded[..<point]) + "." + String(padded[point...])
    }

    private func multiply(_ digits: inout [Int], by factor: Int, adding: Int, base: Int) {
        var carry = adding
        for index in digits.indices {
            let value = digits[index] * factor + carry
            digits[index] = value % base
            carry = value / base
        }
        while carry > 0 {
            digits.append(carry % base)
            carry /= base
        }
    }
}
