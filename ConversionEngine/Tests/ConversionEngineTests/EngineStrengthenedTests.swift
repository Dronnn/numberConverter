//
//  EngineStrengthenedTests.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import ConversionEngine
import Foundation
import Testing

// MARK: - Two's-complement boundaries & inverse property

/// independently calculated signed-field boundaries plus the inverse property.
@Suite struct TwosComplementBoundaryTests {
    private func encode(_ value: Int) -> String {
        ConversionEngine.twosComplementEncode(value, enabled: true)
    }

    @Test func positiveBoundariesPreserveTheirSign() {
        #expect(encode(0) == "00000000")
        #expect(encode(1) == "00000001")
        #expect(encode(127) == "01111111")
        #expect(encode(128) == "0000000010000000")
        #expect(encode(255) == "0000000011111111")
        #expect(encode(256) == "0000000100000000")
        #expect(encode(Int.max) == "0" + String(repeating: "1", count: Int.bitWidth - 1))
    }

    @Test func negativeBoundariesUseTheSmallestSignedByteWidth() {
        #expect(encode(-1) == "11111111")
        #expect(encode(-128) == "10000000")
        #expect(encode(-129) == "1111111101111111")
        #expect(encode(-32_768) == "1000000000000000")
        #expect(encode(-32_769) == "111111110111111111111111")
        #expect(encode(Int.min) == "1" + String(repeating: "0", count: Int.bitWidth - 1))
    }

    @Test func everySmallIntegerAndNativeBoundariesRoundTrip() {
        for value in Array(-1_024...1_024) + [Int.min, Int.min + 1, Int.max - 1, Int.max] {
            let bits = encode(value)
            #expect(bits.count.isMultiple(of: 8))
            #expect(ConversionEngine.twosComplementDecode(bits, enabled: true) == .success(value))
        }
    }
}

// MARK: - Fraction rounding half-up threshold

/// the renderer emits up to 12 fraction digits, then rounds the 12th digit
/// HALF-UP when the dropped remainder is >= 1/2 of that digit's unit. each input
/// below is an exact dyadic / decimal value whose 12-digit boundary lands just
/// below, exactly at, or just above the half threshold; every expected string is
/// derived by exact rational reasoning, not by running the engine.
@Suite struct FractionRoundingThresholdTests {
    private func convert(_ number: String, _ from: Int, _ to: Int) -> String {
        ConversionEngine.convert(number, fromBase: from, toBase: to).fixtureValue
    }

    /// base 10 -> base 10: the 13th decimal digit decides the 12th. with twelve
    /// `1`s, the dropped remainder is 0.4 / 0.5 / 0.6 of a unit.
    @Test func base10MidRangeThreshold() {
        // 13th digit 4 -> remainder 0.4 < 1/2 -> round down.
        #expect(convert("0.1111111111114", 10, 10) == "0.111111111111")
        // 13th digit 5 -> remainder exactly 1/2 -> half-up rounds UP.
        #expect(convert("0.1111111111115", 10, 10) == "0.111111111112")
        // 13th digit 6 -> remainder 0.6 >= 1/2 -> round up.
        #expect(convert("0.1111111111116", 10, 10) == "0.111111111112")
    }

    /// base 10 -> base 10 with twelve `9`s: rounding up ripples through every
    /// digit and carries past the radix point into the integer part.
    @Test func base10AllNinesCarryToInteger() {
        // remainder 0.4 < 1/2 -> round down, stays a fraction.
        #expect(convert("0.9999999999994", 10, 10) == "0.999999999999")
        // remainder exactly 1/2 -> half-up -> carry through all nines -> 1.
        #expect(convert("0.9999999999995", 10, 10) == "1")
        // remainder 0.6 -> round up -> carry to integer -> 1.
        #expect(convert("0.9999999999996", 10, 10) == "1")
    }

    /// base 16 -> base 16: the 12th hex digit is `F`; a 13th hex digit of 7/8/9
    /// puts the dropped remainder just below / exactly at / just above 1/2, so the
    /// half-up carry turns `...000F` into `...0010` (a base-aware carry that stays
    /// inside the fraction). hex digit 8 = 8/16 = exactly half a unit.
    @Test func base16WithinFractionCarryThreshold() {
        // 13th hex digit 7 -> remainder 7/16 < 1/2 -> keep the F.
        #expect(convert("0.00000000000F7", 16, 16) == "0.00000000000F")
        // 13th hex digit 8 -> remainder exactly 1/2 -> half-up -> F carries to 10.
        #expect(convert("0.00000000000F8", 16, 16) == "0.00000000001")
        // 13th hex digit 9 -> remainder 9/16 > 1/2 -> round up -> F carries to 10.
        #expect(convert("0.00000000000F9", 16, 16) == "0.00000000001")
    }

    /// base 2 -> base 2: the 13th bit decides the 12th. `0.0000000000011` is
    /// 1/2^12 + 1/2^13; the dropped 1/2^13 is exactly half of the 12th-bit unit,
    /// so half-up rounds the trailing bit up (000000000001 -> 00000000001).
    @Test func base2ExactHalfRoundsUp() {
        #expect(convert("0.0000000000011", 2, 2) == "0.00000000001")
        // base 2 -> base 10: 3/2^13 = 0.0003662109375, whose 13th decimal digit
        // is 5 -> half-up -> 0.000366210938.
        #expect(convert("0.0000000000011", 2, 10) == "0.000366210938")
    }
}

// MARK: - Invalid-input / validation table

/// explicit validation cases the fixtures do not cover. each expected verdict is
/// derived from the contract in `ConversionEngine.isValid`: only a single leading
/// `-`, at most one `.`, digits below the base, comma->dot; whitespace, `+`, and
/// out-of-range digits are illegal; empty / lone `-` / lone `.` / `-.` normalize
/// to zero and are valid. `isValid` is a pure character check, so even an
/// astronomically large magnitude is valid as long as every character is legal.
@Suite struct ValidationTableTests {
    @Test(arguments: [
        // leading / trailing / internal whitespace is illegal.
        (" 1", 10, false),
        ("1 ", 10, false),
        ("1 0", 10, false),
        ("\t1", 10, false),
        ("- 1", 10, false),
        // a `+` sign is illegal anywhere (only leading `-` is allowed).
        ("+1", 10, false),
        ("1+1", 10, false),
        // multiple decimal separators are illegal.
        ("1.2.3", 10, false),
        ("1.2,3", 10, false),  // comma normalizes to '.', giving two dots.
        // a misplaced / doubled minus is illegal.
        ("--1", 10, false),
        ("1-", 10, false),
        ("1-1", 10, false),
        // a digit at or above the base is illegal.
        ("2", 2, false),
        ("8", 8, false),
        ("A", 10, false),
        ("G", 16, false),
        ("g", 16, false),
        // legal digits at the very top of the base are valid (case-insensitive).
        ("1", 2, true),
        ("7", 8, true),
        ("9", 10, true),
        ("F", 16, true),
        ("f", 16, true),
        ("Z", 36, true),
        ("z", 36, true),
        // empty / lone tokens normalize to zero -> valid.
        ("", 10, true),
        ("-", 10, true),
        (".", 10, true),
        ("-.", 10, true),
        (",", 10, true),    // comma -> '.', then lone '.' is valid.
        // ordinary signed / fractional forms are valid.
        ("-1", 10, true),
        ("1.", 10, true),
        (".1", 10, true),
        ("1,5", 10, true),  // comma -> '.', valid fraction.
        // huge magnitudes: pure character check, so still valid (no overflow here).
        ("99999999999999999999999999999999999999999", 10, true),
        ("-ZZZZZZZZZZZZZZZZZZZZZZZZZZZZ", 36, true)
    ])
    func isValidMatchesContract(_ number: String, _ base: Int, _ expected: Bool) {
        #expect(ConversionEngine.isValid(number, base: base) == expected,
                "isValid(\"\(number)\", base: \(base)) expected \(expected)")
    }

    /// a base outside `2...36` is always invalid, regardless of the characters.
    @Test(arguments: [-1, 0, 1, 37, 99]) func unsupportedBaseIsInvalid(_ base: Int) {
        #expect(ConversionEngine.isValid("1", base: base) == false)
        #expect(ConversionEngine.isValid("", base: base) == false)
    }
}

// MARK: - Two's-complement decode edge contracts

@Suite struct TwosComplementDecodeEdgeTests {
    @Test func redundantSignBitsPreserveTheValue() {
        #expect(ConversionEngine.twosComplementDecode(String(repeating: "1", count: 200), enabled: true) == .success(-1))
        #expect(ConversionEngine.twosComplementDecode(String(repeating: "0", count: 200) + "1", enabled: true) == .success(1))
        #expect(ConversionEngine.twosComplementDecode("1" + String(repeating: "0", count: 64), enabled: true) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.twosComplementDecode("0" + String(repeating: "1", count: 64), enabled: true) == .failure(.numberOutOfRange))
    }

    @Test func unsignedNativeOverflowIsAnError() {
        #expect(ConversionEngine.twosComplementDecode(String(repeating: "1", count: 64), enabled: false) == .failure(.numberOutOfRange))
        #expect(ConversionEngine.twosComplementDecode(String(repeating: "0", count: 200), enabled: false) == .success(0))
    }

    @Test func malformedDecodeIsTypedError() {
        for bits in ["10201", "1.0", "abc", " 1", "-1"] {
            #expect(ConversionEngine.twosComplementDecode(bits, enabled: true) == .failure(.invalidCharacter))
        }
        #expect(ConversionEngine.twosComplementDecode("", enabled: true) == .success(0))
    }
}

// MARK: - Negative fraction rounding thresholds

/// the renderer rounds the magnitude HALF-UP at the 12th fraction digit and then
/// re-applies the sign, so negative inputs round symmetrically to their positive
/// mirror (these mirror `FractionRoundingThresholdTests`). every expected string
/// is the negation of the independently reasoned positive result.
@Suite struct NegativeFractionRoundingThresholdTests {
    private func convert(_ number: String, _ from: Int, _ to: Int) -> String {
        ConversionEngine.convert(number, fromBase: from, toBase: to).fixtureValue
    }

    /// base 10: 13th digit 4 / 5 / 6 -> round down / half-up / up, sign preserved.
    @Test func base10MidRangeThreshold() {
        #expect(convert("-0.1111111111114", 10, 10) == "-0.111111111111")
        #expect(convert("-0.1111111111115", 10, 10) == "-0.111111111112")
        #expect(convert("-0.1111111111116", 10, 10) == "-0.111111111112")
    }

    /// base 10 all-nines: the half-up carry ripples through every nine and past the
    /// radix point, giving `-1` (no `-0`).
    @Test func base10AllNinesCarryToInteger() {
        #expect(convert("-0.9999999999994", 10, 10) == "-0.999999999999")
        #expect(convert("-0.9999999999995", 10, 10) == "-1")
        #expect(convert("-0.9999999999996", 10, 10) == "-1")
    }

    /// base 2 / base 16 carries inside the fraction, sign preserved.
    @Test func base2AndBase16Thresholds() {
        // -(1/2^12 + 1/2^13): dropped 1/2^13 is exactly half the 12th-bit unit.
        #expect(convert("-0.0000000000011", 2, 2) == "-0.00000000001")
        // hex 8 in the 13th place is exactly half a unit -> F carries to 10.
        #expect(convert("-0.00000000000F8", 16, 16) == "-0.00000000001")
    }
}

// MARK: - Arithmetic rounding thresholds

/// arithmetic results route through the same renderer, so a quotient whose exact
/// value needs half-up at the 12th digit must round there. each expected string is
/// derived from the exact rational quotient, not from running the engine.
@Suite struct ArithmeticRoundingThresholdTests {
    private func divide(_ a: String, _ b: String, base: Int) -> String {
        ConversionEngine.calculate(.divide, a, base: 10, b, base: 10, resultBase: base).fixtureValue
    }

    /// 2/3 = 0.6666...; the 13th digit is 6 (>= 5) so the 12th digit rounds 6 -> 7.
    @Test func twoThirdsRoundsUpAtTwelfthDigit() {
        #expect(divide("2", "3", base: 10) == "0.666666666667")
        // 1/6 = 0.16666...; same half-up at the 12th digit.
        #expect(divide("1", "6", base: 10) == "0.166666666667")
        // negative mirrors: -2/3 -> -0.666666666667.
        #expect(divide("-2", "3", base: 10) == "-0.666666666667")
    }

    /// 1/7 = 0.142857142857142857...; the 12-digit prefix is 142857142857 and the
    /// 13th digit is 1 (< 5), so it rounds DOWN (no change) — a control case.
    @Test func oneSeventhRoundsDown() {
        #expect(divide("1", "7", base: 10) == "0.142857142857")
    }
}

// MARK: - Calculate base-range contract

/// `calculate` rejects an out-of-range `resultBase` with the typed
/// `baseOutOfRange` error (the operand validation is unrelated).
@Suite struct CalculateBaseRangeTests {
    @Test(arguments: [-1, 0, 1, 37, 100])
    func resultBaseOutOfRangeIsTyped(_ base: Int) {
        let result = ConversionEngine.calculate(.add, "1", base: 10, "1", base: 10, resultBase: base)
        #expect(result == .failure(.baseOutOfRange))
    }

    /// in-range result bases at the boundaries (2 and 36) succeed.
    @Test func resultBaseBoundariesSucceed() {
        #expect(ConversionEngine.calculate(.add, "1", base: 10, "1", base: 10, resultBase: 2).fixtureValue == "10")
        #expect(ConversionEngine.calculate(.add, "35", base: 10, "1", base: 10, resultBase: 36).fixtureValue == "10")
    }

    /// convert surfaces the typed errors that correspond to these invalid inputs.
    @Test func convertMapsInvalidInputsToTypedErrors() {
        #expect(ConversionEngine.convert(" 1", fromBase: 10, toBase: 2) == .failure(.invalidCharacter))
        #expect(ConversionEngine.convert("+1", fromBase: 10, toBase: 2) == .failure(.invalidCharacter))
        #expect(ConversionEngine.convert("G", fromBase: 16, toBase: 10) == .failure(.invalidCharacter))
        #expect(ConversionEngine.convert("1.2.3", fromBase: 10, toBase: 2) == .failure(.invalidCharacter))
        #expect(ConversionEngine.convert("1", fromBase: 1, toBase: 10) == .failure(.baseOutOfRange))
        #expect(ConversionEngine.convert("1", fromBase: 10, toBase: 37) == .failure(.baseOutOfRange))
    }

    /// large-magnitude integers within `Decimal`'s exact range convert losslessly;
    /// this pins the engine's behavior at the high end of its real value range.
    @Test func largeMagnitudeIntegersConvertExactly() {
        // 10^30 in base 16 -> exact (independently: 10^30 = 0xC9F2C9CD04674EDEA40000000).
        #expect(ConversionEngine.convert("1000000000000000000000000000000",
                                         fromBase: 10, toBase: 16).fixtureValue
                == "C9F2C9CD04674EDEA40000000")
        // and back.
        #expect(ConversionEngine.convert("C9F2C9CD04674EDEA40000000",
                                         fromBase: 16, toBase: 10).fixtureValue
                == "1000000000000000000000000000000")
    }
}
