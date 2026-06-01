//
//  EngineCorrectnessTests.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import ConversionEngine
import Foundation
import Testing

// MARK: - Named anchors

@Suite struct AnchorTests {
    private func convert(_ number: String, _ from: Int, _ to: Int) -> String {
        ConversionEngine.convert(number, fromBase: from, toBase: to).fixtureValue
    }

    @Test func convertAnchors() {
        #expect(convert("0.1", 10, 16) == "0.19999999999A")
        #expect(convert("0.101", 10, 2) == "0.00011001111")
        #expect(convert("0.5", 10, 3) == "0.111111111112")
        #expect(convert("A.8", 16, 10) == "10.5")
        #expect(convert("0.A", 16, 10) == "0.625")
        #expect(convert("255", 10, 16) == "FF")
        #expect(convert("36", 10, 36) == "10")
        #expect(convert("35", 10, 36) == "Z")
        #expect(convert("1", 10, 2) == "1")
    }

    @Test func encodeAnchors() {
        #expect(ConversionEngine.twosComplementEncode(-128, enabled: true) == "10000000")
        #expect(ConversionEngine.twosComplementEncode(-129, enabled: true) == "1111111101111111")
        #expect(ConversionEngine.twosComplementEncode(-255, enabled: true) == "1111111100000001")
        #expect(ConversionEngine.twosComplementEncode(255, enabled: true) == "11111111")
        #expect(ConversionEngine.twosComplementEncode(1, enabled: true) == "1")
        #expect(ConversionEngine.twosComplementEncode(-1, enabled: true) == "11111111")
        #expect(ConversionEngine.twosComplementEncode(0, enabled: true) == "0")
        #expect(ConversionEngine.twosComplementEncode(-128, enabled: false) == "-10000000")
    }

    @Test func decodeAnchors() {
        func decode(_ bits: String, _ enabled: Bool) -> Int? {
            switch ConversionEngine.twosComplementDecode(bits, enabled: enabled) {
            case let .success(value): value
            case .failure: nil
            }
        }
        #expect(decode("01111111", true) == 127)
        #expect(decode("00000001", true) == 1)
        #expect(decode("11111111", true) == -1)
        #expect(decode("10000000", true) == -128)
        #expect(decode("11111111", false) == 255)
    }

    @Test func arithmeticAnchors() {
        func calc(_ op: ConversionEngine.Operation, _ a: String, _ sa: Int,
                  _ b: String, _ sb: Int, _ sr: Int) -> String {
            ConversionEngine.calculate(op, a, base: sa, b, base: sb, resultBase: sr).fixtureValue
        }
        #expect(calc(.divide, "10", 10, "3", 10, 10) == "3.333333333333")
        #expect(calc(.add, "0.5", 10, "0.5", 10, 10) == "1")
        #expect(calc(.add, "FF", 16, "1", 10, 16) == "100")
        #expect(calc(.divide, "1", 10, "3", 10, 2) == "0.010101010101")
        #expect(calc(.multiply, "0.5", 10, "0.5", 10, 10) == "0.25")
    }
}

// MARK: - Round-trip

@Suite struct RoundTripTests {
    /// integer round-trip across every base pair: render then parse back must be
    /// the original decimal value.
    @Test(arguments: 2...36)
    func integerRoundTripsAcrossBases(_ base: Int) {
        let samples = [0, 1, 7, 35, 36, 100, 255, 999, 1_234_567, 1_000_000_000]
        for value in samples {
            let toBase = ConversionEngine.convert("\(value)", fromBase: 10, toBase: base).fixtureValue
            let back = ConversionEngine.convert(toBase, fromBase: base, toBase: 10).fixtureValue
            #expect(back == "\(value)", "round trip \(value) via base \(base) -> \(toBase) -> \(back)")
        }
    }

    @Test(arguments: 2...36)
    func negativeIntegerRoundTrips(_ base: Int) {
        for value in [-1, -42, -255, -100_000] {
            let toBase = ConversionEngine.convert("\(value)", fromBase: 10, toBase: base).fixtureValue
            let back = ConversionEngine.convert(toBase, fromBase: base, toBase: 10).fixtureValue
            #expect(back == "\(value)", "round trip \(value) via base \(base)")
        }
    }

    /// integer round-trip for every ordered base pair (from, to) in 2...36:
    /// decimal -> from -> to -> back-to-decimal preserves the value, exercising
    /// every base as both a source and a target (not just the fixtures' bases).
    @Test(arguments: 2...36, 2...36)
    func integerRoundTripsAcrossEveryBasePair(_ fromBase: Int, _ toBase: Int) {
        for value in [0, 1, 35, 200, 4_095, 123_456, 987_654_321] {
            // seed the value in `fromBase`, then go fromBase -> toBase -> decimal.
            let inFrom = ConversionEngine.convert("\(value)", fromBase: 10, toBase: fromBase).fixtureValue
            let inTo = ConversionEngine.convert(inFrom, fromBase: fromBase, toBase: toBase).fixtureValue
            let back = ConversionEngine.convert(inTo, fromBase: toBase, toBase: 10).fixtureValue
            #expect(back == "\(value)",
                    "integer \(value): 10->\(fromBase)=\(inFrom) ->\(toBase)=\(inTo) ->10=\(back)")
        }
    }

    /// short binary fractions round-trip losslessly between base 2 and every
    /// other power-of-two base (4, 8, 16, 32). each source value has at most 6
    /// binary fraction bits, so even after regrouping into the wider base and
    /// back it stays well inside the 12-digit budget and the trip is an identity.
    /// this exercises fractional conversion across bases beyond the fixtures'.
    @Test(arguments: [4, 8, 16, 32])
    func shortBinaryFractionsRoundTripThroughPowerOfTwoBases(_ wideBase: Int) {
        for binary in ["0.1", "0.01", "0.11", "1.1", "0.101", "11.011"] {
            let wide = ConversionEngine.convert(binary, fromBase: 2, toBase: wideBase).fixtureValue
            let back = ConversionEngine.convert(wide, fromBase: wideBase, toBase: 2).fixtureValue
            #expect(back == binary, "binary \(binary): 2->\(wideBase)=\(wide) ->2=\(back)")
        }
    }

    /// half-power decimal fractions (denominators that are pure powers of two)
    /// round-trip through every base divisible by two. the decimal value
    /// terminates AND the base value terminates, so the trip is lossless within
    /// the 12-digit policy.
    @Test(arguments: [2, 4, 8, 10, 16, 20, 32])
    func dyadicDecimalFractionsRoundTrip(_ base: Int) {
        for value in ["0.5", "0.25", "0.75", "0.125", "12.5"] {
            let inBase = ConversionEngine.convert(value, fromBase: 10, toBase: base).fixtureValue
            let back = ConversionEngine.convert(inBase, fromBase: base, toBase: 10).fixtureValue
            #expect(back == value, "decimal \(value): ->\(base)=\(inBase) ->10=\(back)")
        }
    }

    /// "0.1" in base B is exactly 1/B; for bases whose only prime factors are 2
    /// and/or 5 the value 1/B also terminates in decimal, so base -> 10 -> base
    /// returns the original. covers every such base in 2...36.
    @Test(arguments: [2, 4, 5, 8, 10, 16, 20, 25, 32])
    func singleDigitBaseFractionRoundTrips(_ base: Int) {
        let asDecimal = ConversionEngine.convert("0.1", fromBase: base, toBase: 10).fixtureValue
        let back = ConversionEngine.convert(asDecimal, fromBase: 10, toBase: base).fixtureValue
        #expect(back == "0.1", "1/\(base): base->10=\(asDecimal) ->base=\(back)")
    }
}

// MARK: - Edge cases

@Suite struct EdgeCaseTests {
    @Test func emptyAndLoneTokensNormalizeToZero() {
        for token in ["", "-", ".", "-.", ",", "-,"] {
            let result = ConversionEngine.convert(token, fromBase: 10, toBase: 2).fixtureValue
            #expect(result == "0", "token \(token.isEmpty ? "<empty>" : token) -> \(result)")
        }
    }

    @Test func zeroNeverCarriesSign() {
        #expect(ConversionEngine.convert("-0", fromBase: 10, toBase: 2).fixtureValue == "0")
        #expect(ConversionEngine.convert("-0.0", fromBase: 10, toBase: 16).fixtureValue == "0")
    }

    @Test func mixedCaseHexParsesIdentically() {
        let lower = ConversionEngine.convert("ff.a", fromBase: 16, toBase: 10).fixtureValue
        let upper = ConversionEngine.convert("FF.A", fromBase: 16, toBase: 10).fixtureValue
        #expect(lower == upper)
    }

    @Test func commaConvertsToDot() {
        #expect(ConversionEngine.convert("1,5", fromBase: 10, toBase: 10).fixtureValue == "1.5")
    }

    @Test func negativeFractionRenders() {
        #expect(ConversionEngine.convert("-0.5", fromBase: 10, toBase: 2).fixtureValue == "-0.1")
    }

    @Test func divisionByZeroIsTyped() {
        let result = ConversionEngine.calculate(.divide, "100", base: 10, "0", base: 10, resultBase: 10)
        #expect(result == .failure(.divisionByZero))
    }

    @Test func invalidOperandIsTyped() {
        let result = ConversionEngine.calculate(.add, "G", base: 10, "1", base: 10, resultBase: 10)
        #expect(result == .failure(.invalidCharacter))
    }

    @Test func outOfRangeBaseIsTyped() {
        #expect(ConversionEngine.convert("1", fromBase: 37, toBase: 10) == .failure(.baseOutOfRange))
        #expect(ConversionEngine.convert("1", fromBase: 10, toBase: 1) == .failure(.baseOutOfRange))
    }

    @Test func invalidInputIsTyped() {
        #expect(ConversionEngine.convert("G", fromBase: 10, toBase: 2) == .failure(.invalidCharacter))
        #expect(ConversionEngine.convert("1.2.3", fromBase: 10, toBase: 2) == .failure(.invalidCharacter))
    }

    @Test func twosComplementFlagAffectsBinaryIntegerPath() {
        // base-2 integer rendering of a negative value with TC on uses the
        // two's-complement encoding; with TC off it is sign-magnitude.
        let on = ConversionEngine.convert("-128", fromBase: 10, toBase: 2, twosComplement: true).fixtureValue
        let off = ConversionEngine.convert("-128", fromBase: 10, toBase: 2, twosComplement: false).fixtureValue
        #expect(on == "10000000")
        #expect(off == "-10000000")
    }

    @Test func twosComplementFlagRoundTripsBinaryInteger() {
        // a binary TC pattern decoded then re-encoded stays the same.
        let result = ConversionEngine.convert("11111111", fromBase: 2, toBase: 2, twosComplement: true).fixtureValue
        #expect(result == "11111111")
        // decoding 11111111 under TC to decimal yields -1.
        let toDecimal = ConversionEngine.convert("11111111", fromBase: 2, toBase: 10, twosComplement: true).fixtureValue
        #expect(toDecimal == "-1")
    }

    @Test func twosComplementFlagIgnoredForFractions() {
        let on = ConversionEngine.convert("0.5", fromBase: 10, toBase: 2, twosComplement: true).fixtureValue
        let off = ConversionEngine.convert("0.5", fromBase: 10, toBase: 2, twosComplement: false).fixtureValue
        #expect(on == off)
        #expect(on == "0.1")
    }
}

// MARK: - SPEC-named decimal helpers

@Suite struct DecimalHelperTests {
    @Test func toDecimalParsesValidInput() {
        #expect(ConversionEngine.toDecimal("FF", fromBase: 16) == Decimal(255))
        #expect(ConversionEngine.toDecimal("0.A", fromBase: 16) == Decimal(string: "0.625"))
        #expect(ConversionEngine.toDecimal("G", fromBase: 16) == nil)
        #expect(ConversionEngine.toDecimal("1", fromBase: 99) == nil)
    }

    @Test func fromDecimalRenders() {
        #expect(ConversionEngine.fromDecimal(Decimal(255), toBase: 16) == "FF")
        #expect(ConversionEngine.fromDecimal(Decimal(36), toBase: 36) == "10")
        #expect(ConversionEngine.fromDecimal(Decimal(1), toBase: 99) == nil)
    }
}

// MARK: - Large-value coverage (within Decimal's exact range)

@Suite struct LargeValueTests {
    @Test func wideIntegersConvertExactly() {
        // 12 base-36 digits (~19 decimal digits) stays well inside Decimal's
        // 38 significant digits and round-trips exactly.
        let big = ConversionEngine.convert("ZZZZZZZZZZZZ", fromBase: 36, toBase: 10).fixtureValue
        #expect(big == "4738381338321616895")
        let back = ConversionEngine.convert(big, fromBase: 10, toBase: 36).fixtureValue
        #expect(back == "ZZZZZZZZZZZZ")
    }

    @Test func wideProductIsExact() {
        // 9999999999 * 9999999999 = 99999999980000000001 (20 digits, exact in Decimal).
        let result = ConversionEngine.calculate(.multiply, "9999999999", base: 10,
                                                "9999999999", base: 10, resultBase: 10).fixtureValue
        #expect(result == "99999999980000000001")
    }
}
