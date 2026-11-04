//
//  EngineSafetyTests.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import ConversionEngine
import Foundation
import Testing

@Suite struct EngineSafetyTests {
    @Test(arguments: [Int.min, Int.min + 1, -1_000_000, -1, 0, 1, 255, 1_234_567_890, Int.max])
    func integerConversionsMatchNativeRadixOracle(_ value: Int) {
        for sourceBase in 2...36 {
            let input = String(value, radix: sourceBase, uppercase: true)
            for targetBase in 2...36 {
                let expected = String(value, radix: targetBase, uppercase: true)
                #expect(ConversionEngine.convert(input, fromBase: sourceBase, toBase: targetBase) == .success(expected))
            }
        }
    }

    @Test func unicodeLookalikesAreNotDigits() {
        for input in ["ſ", "ß", "ﬀ", "é", "１", "١", "🙂"] {
            #expect(!ConversionEngine.isValid(input, base: 36))
            #expect(ConversionEngine.convert(input, fromBase: 36, toBase: 10) == .failure(.invalidCharacter))
        }
    }

    @Test func signedBinaryConversionsRoundTripEveryBoundary() {
        for value in [Int.min, -129, -128, -1, 0, 1, 127, 128, 255, Int.max] {
            let encoded = ConversionEngine.convert(String(value), fromBase: 10, toBase: 2, twosComplement: true)
            if case let .success(bits) = encoded {
                #expect(ConversionEngine.convert(bits, fromBase: 2, toBase: 10, twosComplement: true) == .success(String(value)))
                #expect(ConversionEngine.convert(bits, fromBase: 2, toBase: 2, twosComplement: true) == encoded)
            } else {
                Issue.record("failed signed conversion for \(value)")
            }
        }
        #expect(ConversionEngine.convert("-101", fromBase: 2, toBase: 2, twosComplement: true) == .failure(.invalidCharacter))
        #expect(ConversionEngine.convert("-101", fromBase: 2, toBase: 10, twosComplement: true) == .failure(.invalidCharacter))
        #expect(ConversionEngine.convert("9223372036854775808", fromBase: 10, toBase: 2, twosComplement: true) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.convert("-9223372036854775809", fromBase: 10, toBase: 2, twosComplement: true) == .failure(.numberOutOfRange))
    }

    @Test func largeNativeDecimalIntegersKeepLowDigits() {
        // 2^127, independently known; the leading one is at bit position 127.
        let decimal = "170141183460469231731687303715884105728"
        let binary = "1" + String(repeating: "0", count: 127)
        #expect(ConversionEngine.convert(decimal, fromBase: 10, toBase: 2) == .success(binary))
        #expect(ConversionEngine.convert(binary, fromBase: 2, toBase: 10) == .success(decimal))
        let powerOfTen = "1" + String(repeating: "0", count: 100)
        #expect(ConversionEngine.convert(powerOfTen, fromBase: 10, toBase: 10) == .success(powerOfTen))
    }

    @Test func inputOverflowAndSignificantDigitLossAreTyped() {
        let tooLarge = String(repeating: "9", count: 200)
        let losesUnit = "10000000000000000000000000000000000000001"
        for input in [tooLarge, losesUnit] {
            #expect(ConversionEngine.convert(input, fromBase: 10, toBase: 16) == .failure(.numberOutOfRange))
            #expect(ConversionEngine.toDecimal(input, fromBase: 10) == nil)
            #expect(ConversionEngine.calculate(.add, input, base: 10, "1", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        }
    }

    @Test func arithmeticOverflowAndPrecisionLossAreTyped() {
        let large = "1" + String(repeating: "0", count: 100)
        #expect(ConversionEngine.calculate(.multiply, large, base: 10, large, base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.calculate(.add, large, base: 10, "1", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.calculate(.add, large, base: 10, "-1", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.calculate(.subtract, large, base: 10, "1", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.fromDecimal(.nan, toBase: 10) == nil)
        #expect(ConversionEngine.calculate(.add, "1", base: 1, "1", base: 10, resultBase: 10) == .failure(.invalidCharacter))
        #expect(ConversionEngine.calculate(.add, "1", base: 10, "1", base: 37, resultBase: 10) == .failure(.invalidCharacter))
    }

    @Test func roundingToZeroDoesNotKeepTheSign() {
        #expect(ConversionEngine.convert("-0.0000000000001", fromBase: 10, toBase: 10) == .success("0"))
        #expect(ConversionEngine.convert("0.0000000000001", fromBase: 10, toBase: 10) == .success("0"))
        #expect(ConversionEngine.convert("9.9999999999995", fromBase: 10, toBase: 10) == .success("10"))
        #expect(ConversionEngine.convert("1.9999999999999", fromBase: 10, toBase: 2) == .success("10"))
    }
}

@Suite struct ExactDivisionTests {
    @Test func nearHalfQuotientsRetainTheSideOfTheTieAtNativePrecision() {
        let twiceUnitDenominator: UInt64 = 9_476_762_676_643_233_792
        for exponent in 16...19 {
            // N / (2*36^12*N +/- 1) lies strictly below/above the half unit.
            // the largest denominators have 38 decimal digits; floating-point
            // approximations erase which side of the boundary they occupy.
            let numerator = "1" + String(repeating: "0", count: exponent)
            let below = String(twiceUnitDenominator) + String(repeating: "0", count: exponent - 1) + "1"
            let above = String(twiceUnitDenominator - 1) + String(repeating: "9", count: exponent)
            #expect(ConversionEngine.calculate(.divide, numerator, base: 10, below, base: 10, resultBase: 36) == .success("0"))
            #expect(ConversionEngine.calculate(.divide, numerator, base: 10, above, base: 10, resultBase: 36) == .success("0.000000000001"))
        }
    }

    @Test func base36HalfUnitAndItsNeighborsRoundExactly() {
        // 2*36^12 fits UInt64 but exceeds Int64. its reciprocal is exactly half
        // of the final base-36 output unit, independently of decimal approximation.
        var denominator: UInt64 = 2
        for _ in 0..<12 { denominator *= 36 }
        #expect(denominator == 9_476_762_676_643_233_792)
        #expect(ConversionEngine.calculate(.divide, "1", base: 10, String(denominator), base: 10, resultBase: 36) == .success("0.000000000001"))
        #expect(ConversionEngine.calculate(.divide, "1", base: 10, String(denominator + 1), base: 10, resultBase: 36) == .success("0"))
        #expect(ConversionEngine.calculate(.divide, "1", base: 10, String(denominator - 1), base: 10, resultBase: 36) == .success("0.000000000001"))
        #expect(ConversionEngine.calculate(.divide, "-1", base: 10, String(denominator), base: 10, resultBase: 36) == .success("-0.000000000001"))
    }

    @Test(arguments: 2...36)
    func smallRationalQuotientsMatchIndependentIntegerOracle(_ base: Int) {
        for numerator in [0, 1, -1, 2, 7, 127, -255] {
            for denominator in [1, -1, 2, 3, 7, 11, 32] {
                let expected = DivergenceOracle.calculate(.divide, String(numerator), base: 10,
                                                         String(denominator), base: 10, resultBase: base)
                #expect(ConversionEngine.calculate(.divide, String(numerator), base: 10,
                                                  String(denominator), base: 10, resultBase: base) == .success(expected))
            }
        }
    }

    @Test func largeQuotientsAndFractionalOperandsRespectNativePrecision() {
        let large = "1" + String(repeating: "0", count: 100)
        #expect(ConversionEngine.calculate(.divide, large, base: 10, "3", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.calculate(.divide, large, base: 10, "2", base: 10, resultBase: 10) == .success("5" + String(repeating: "0", count: 99)))
        #expect(ConversionEngine.calculate(.divide, "-0.5", base: 10, "-0.25", base: 10, resultBase: 10) == .success("2"))
        #expect(ConversionEngine.calculate(.divide, "0", base: 10, "0.25", base: 10, resultBase: 10) == .success("0"))
        // 1/3 cannot be represented exactly as a finite native Decimal.
        #expect(ConversionEngine.toDecimal("0.1", fromBase: 3) == nil)
        #expect(ConversionEngine.calculate(.add, "0.1", base: 3, "1", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.convert("0.1", fromBase: 3, toBase: 10) == .success("0.333333333333"))
        // native Decimal also cannot preserve every digit of this finite dyadic.
        #expect(ConversionEngine.toDecimal("0." + String(repeating: "0", count: 126) + "1", fromBase: 2) == nil)
    }

    @Test func inputLengthBoundsPerKeystrokeWork() {
        let tooLong = String(repeating: "0", count: ConversionEngine.maxInputLength + 1)
        #expect(ConversionEngine.convert(tooLong, fromBase: 10, toBase: 2) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.toDecimal(tooLong, fromBase: 10) == nil)
        #expect(ConversionEngine.calculate(.add, tooLong, base: 10, "0", base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.calculate(.add, "0", base: 10, tooLong, base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.twosComplementDecode(tooLong, enabled: true) == .failure(.numberOutOfRange))
    }
}
