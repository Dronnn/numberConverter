//
//  NativeIntegerClosureTests.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation
import Testing

@Suite struct NativeIntegerClosureTests {
    @Test(arguments: 2...36)
    func everyNativePowerOfTenCanBeReparsedInEveryBase(_ base: Int) {
        for exponent in 0...127 {
            let decimal = "1" + String(repeating: "0", count: exponent)
            let expected = Decimal(sign: .plus, exponent: exponent, significand: 1)
            let encoded = radixOracle(decimal, base: base)
            #expect(ConversionEngine.convert(decimal, fromBase: 10, toBase: base) == .success(encoded))
            #expect(ConversionEngine.convert(encoded, fromBase: base, toBase: 10) == .success(decimal))
            #expect(ConversionEngine.toDecimal(encoded, fromBase: base) == expected)
            #expect(ConversionEngine.calculate(.add, encoded, base: base, "0", base: 10, resultBase: base) == .success(encoded))
            #expect(ConversionEngine.calculate(.subtract, encoded, base: base, encoded, base: base, resultBase: 10) == .success("0"))
            #expect(ConversionEngine.calculate(.multiply, encoded, base: base, "1", base: 10, resultBase: 10) == .success(decimal))
            #expect(ConversionEngine.calculate(.divide, encoded, base: base, "1", base: 10, resultBase: base) == .success(encoded))
        }
    }

    @Test func largeNativeCoefficientsAndMaximumMagnitudeRemainExactAcrossBases() {
        let coefficient = "12345678901234567890123456789012345678"
        let largestCoefficient = "340282366920938463463374607431768211455" // 2^128 - 1
        for (significand, exponent) in [(coefficient, 0), (coefficient, 1), (coefficient, 38),
                                        (coefficient, 100), (coefficient, 127), (largestCoefficient, 127)] {
            let decimal = significand + String(repeating: "0", count: exponent)
            let expected = Decimal(sign: .plus, exponent: exponent, significand: Decimal(string: significand)!)
            for base in 2...36 {
                let encoded = radixOracle(decimal, base: base)
                for sign in ["", "-"] {
                    let expectedValue = sign.isEmpty ? expected : -expected
                    #expect(ConversionEngine.convert(sign + decimal, fromBase: 10, toBase: base) == .success(sign + encoded))
                    #expect(ConversionEngine.convert(sign + encoded, fromBase: base, toBase: 10) == .success(sign + decimal))
                    #expect(ConversionEngine.toDecimal(sign + encoded, fromBase: base) == expectedValue)
                    #expect(ConversionEngine.calculate(.add, sign + encoded, base: base, "0", base: 10, resultBase: 10) == .success(sign + decimal))
                }
            }
        }
        #expect(ConversionEngine.toDecimal(largestCoefficient + String(repeating: "0", count: 127), fromBase: 10) == .greatestFiniteMagnitude)
    }

    @Test func finalPrecisionAndRangeLossRemainRejectedInEveryBase() {
        let maximum = "340282366920938463463374607431768211455" + String(repeating: "0", count: 127)
        let overflow = "340282366920938463463374607431768211456" + String(repeating: "0", count: 127)
        let beyondMaximum = String(maximum.dropLast()) + "1"
        let precisionLoss = "1" + String(repeating: "0", count: 99) + "1"
        for decimal in [overflow, beyondMaximum, precisionLoss] {
            for base in 2...36 {
                let encoded = radixOracle(decimal, base: base)
                #expect(ConversionEngine.convert(encoded, fromBase: base, toBase: 10) == .failure(.numberOutOfRange))
                #expect(ConversionEngine.toDecimal(encoded, fromBase: base) == nil)
                #expect(ConversionEngine.calculate(.add, encoded, base: base, "0", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
            }
        }
    }

    /// independent test oracle accumulates decimal digits in the target base,
    /// unlike production's repeated division of source digits. every carry fits Int.
    private func radixOracle(_ decimal: String, base: Int) -> String {
        var littleEndian = [0]
        for byte in decimal.utf8 {
            var carry = Int(byte - 48)
            for index in littleEndian.indices {
                let next = littleEndian[index] * 10 + carry
                littleEndian[index] = next % base
                carry = next / base
            }
            while carry > 0 {
                littleEndian.append(carry % base)
                carry /= base
            }
        }
        return littleEndian.reversed().map { String($0, radix: 36, uppercase: true) }.joined()
    }
}
