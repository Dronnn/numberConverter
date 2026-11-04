//
//  ConversionEngine.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - ConversionEngine

/// pure, dependency-free numeral-system conversion core (bases 2...36).
///
/// value-carrying math uses `Decimal` (exact within its 38 significant digits,
/// never `Double`/`Float`) and `Int`. inputs and outputs are strings to preserve
/// leading zeros and mixed-case hex semantics.
public enum ConversionEngine {
    /// the inclusive range of numeral-system bases the engine supports.
    public static let supportedBaseRange = 2...36

    /// maximum number of fraction digits emitted before half-up rounding.
    public static let maxFractionDigits = 12

    /// bounds per-keystroke work and pasted input before native numeric validation.
    public static let maxInputLength = 1_024

    /// digit alphabet; index equals digit value (0...35).
    static let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    // MARK: Operation

    /// the four arithmetic operations the calculator supports.
    public enum Operation: Sendable {
        case add, subtract, multiply, divide
    }

    // MARK: Validation

    /// validates `number` against `base` (SPEC 3.1).
    ///
    /// rules: base must be `2...36`; comma auto-converts to `.`; the legal
    /// alphabet is an optional single leading `-`, at most one `.`, digits up to
    /// `min(base-1, 9)`, and for bases > 10 letters up to the one for `base-1`
    /// (case-insensitive); empty / lone `-` / lone `.` normalize to `0` and are
    /// valid; two or more `.` is invalid; a `-` anywhere but leading is invalid.
    public static func isValid(_ number: String, base: Int) -> Bool {
        guard supportedBaseRange.contains(base) else { return false }

        let s = number.replacing(",", with: ".")

        if s.isEmpty || s == "-" || s == "." { return true }

        if s.filter({ $0 == "." }).count > 1 { return false }

        let minusCount = s.filter { $0 == "-" }.count
        if minusCount > 1 { return false }
        if minusCount == 1, !s.hasPrefix("-") { return false }

        let body = s.hasPrefix("-") ? String(s.dropFirst()) : s
        if body.isEmpty || body == "." { return true }

        let maxDigit = base - 1
        for ch in body where ch != "." {
            let value = digitValue(ch)
            if value < 0 || value > maxDigit { return false }
        }
        return true
    }

    // MARK: Convert

    /// converts `number` from `fromBase` to `toBase` (SPEC 3.2 + 3.3).
    ///
    /// when `twosComplement` is `true` it affects only the base-2 *integer* path:
    /// base-2 integer parsing and base-2 integer rendering go through the
    /// two's-complement helpers. fractional values and non-base-2 conversions
    /// ignore the flag.
    public static func convert(_ number: String,
                               fromBase: Int,
                               toBase: Int,
                               twosComplement: Bool = false) -> Result<String, ConversionError> {
        guard supportedBaseRange.contains(fromBase) else { return .failure(.baseOutOfRange) }
        guard supportedBaseRange.contains(toBase) else { return .failure(.baseOutOfRange) }
        guard number.utf8.count <= maxInputLength else { return .failure(.numberOutOfRange) }
        guard isValid(number, base: fromBase) else { return .failure(.invalidCharacter) }

        do throws(ConversionError) {
            let normalized = number.replacing(",", with: ".")
            let signedBinary = twosComplement && !normalized.contains(".")
            let value: Decimal
            if signedBinary, fromBase == 2 {
                value = Decimal(try TwosComplement.decode(normalized, enabled: true))
            } else {
                value = try parse(normalized, fromBase: fromBase, allowRecurringFraction: true)
            }
            if signedBinary, toBase == 2 {
                guard value >= Decimal(Int.min), value <= Decimal(Int.max) else {
                    return .failure(.numberOutOfRange)
                }
                return .success(TwosComplement.encode(NSDecimalNumber(decimal: value).intValue, enabled: true))
            }
            if signedBinary, fromBase == 2 {
                return .success(render(value, toBase: toBase))
            }
            return .success(renderPositional(normalized, fromBase: fromBase, toBase: toBase))
        } catch {
            return .failure(error)
        }
    }

    // MARK: Calculate

    /// performs an exact arithmetic operation across mixed operand bases and
    /// renders the result to `resultBase` (SPEC 3.5).
    ///
    /// invalid operands map to ``ConversionError/invalidCharacter``; division by
    /// zero maps to ``ConversionError/divisionByZero``.
    public static func calculate(_ op: Operation,
                                 _ a: String, base aBase: Int,
                                 _ b: String, base bBase: Int,
                                 resultBase: Int) -> Result<String, ConversionError> {
        guard supportedBaseRange.contains(aBase),
              supportedBaseRange.contains(bBase) else { return .failure(.invalidCharacter) }
        guard a.utf8.count <= maxInputLength, b.utf8.count <= maxInputLength else {
            return .failure(.numberOutOfRange)
        }
        guard isValid(a, base: aBase), isValid(b, base: bBase) else {
            return .failure(.invalidCharacter)
        }
        guard supportedBaseRange.contains(resultBase) else { return .failure(.baseOutOfRange) }

        do throws(ConversionError) {
            let va = try parse(a, fromBase: aBase)
            let vb = try parse(b, fromBase: bBase)
            if op == .divide {
                return .success(try divide(va, vb, toBase: resultBase))
            }
            let result = try decimalOperation(op, va, vb)
            return .success(render(result, toBase: resultBase))
        } catch {
            return .failure(error)
        }
    }

    // MARK: Two's complement helpers

    /// two's-complement encode of an integer value (see ``TwosComplement``).
    public static func twosComplementEncode(_ value: Int, enabled: Bool) -> String {
        TwosComplement.encode(value, enabled: enabled)
    }

    /// two's-complement decode of a binary string (see ``TwosComplement``).
    public static func twosComplementDecode(_ bits: String, enabled: Bool) -> Result<Int, ConversionError> {
        do {
            return .success(try TwosComplement.decode(bits, enabled: enabled))
        } catch {
            return .failure(error)
        }
    }

    // MARK: SPEC-named decimal helpers

    /// parses a base-`fromBase` string into a `Decimal`, or `nil` when invalid /
    /// out of range. `Decimal` is the engine's native value type (SPEC 3.2 naming).
    public static func toDecimal(_ number: String, fromBase: Int) -> Decimal? {
        guard number.utf8.count <= maxInputLength,
              supportedBaseRange.contains(fromBase), isValid(number, base: fromBase) else {
            return nil
        }
        return try? parse(number, fromBase: fromBase)
    }

    /// renders a `Decimal` into a base-`toBase` string, or `nil` when the base is
    /// out of range (SPEC 3.3 naming).
    public static func fromDecimal(_ value: Decimal, toBase: Int) -> String? {
        guard supportedBaseRange.contains(toBase), !value.isNaN else { return nil }
        return render(value, toBase: toBase)
    }

    // MARK: Digit helpers

    /// value of a single digit character (0...35), or `-1` if not a base-36 digit.
    static func digitValue(_ character: Character) -> Int {
        guard let ascii = character.asciiValue else { return -1 }
        switch ascii {
        case 48...57: return Int(ascii - 48)
        case 65...90: return Int(ascii - 55)
        case 97...122: return Int(ascii - 87)
        default: return -1
        }
    }

    /// character for a digit value 0...35.
    static func digitCharacter(_ value: Int) -> Character {
        digits[value]
    }
}
