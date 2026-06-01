//
//  TwosComplement.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

// MARK: - TwosComplement

/// correct two's-complement encode/decode for binary integer values (SPEC 3.4).
///
/// pure helpers that operate on native `Int`.
enum TwosComplement {
    /// smallest multiple-of-8 width `W` with `-2^(W-1) <= value <= 2^(W-1)-1`.
    static func width(for value: Int) -> Int {
        var w = 8
        while true {
            // bound = 2^(w-1)
            let bound = 1 << (w - 1)
            if -bound <= value, value <= bound - 1 { return w }
            w += 8
        }
    }

    /// encode a decimal integer value to a binary string.
    ///
    /// - non-negative values render as plain binary (no sign padding); zero is `"0"`.
    /// - negative values with two's complement on render as a `W`-bit pattern,
    ///   `W` = smallest multiple of 8 that fits the value with a sign bit.
    /// - negative values with two's complement off render as `"-"` plus the plain
    ///   binary of the magnitude.
    static func encode(_ value: Int, enabled: Bool) -> String {
        if value == 0 { return "0" }
        if value > 0 { return plainBinary(value) }
        // value < 0
        if !enabled { return "-" + plainBinary(-value) }
        let w = width(for: value)
        // pattern = value + 2^W (a non-negative W-bit number).
        let pattern = value + (1 << w)
        return padded(plainBinary(pattern), toWidth: w)
    }

    /// decode a binary string to a decimal integer value.
    ///
    /// - two's complement off: plain unsigned value of the bits.
    /// - two's complement on: width is the bit count; if the MSB is set the value
    ///   is `n - 2^width`, else `n`.
    ///
    /// throws ``ConversionError/invalidCharacter`` when `bits` is not binary.
    static func decode(_ bits: String, enabled: Bool) throws -> Int {
        if bits.isEmpty { return 0 }
        var n = 0
        for ch in bits {
            switch ch {
            case "0": n <<= 1
            case "1": n = (n << 1) | 1
            default: throw ConversionError.invalidCharacter
            }
        }
        if !enabled { return n }
        let width = bits.count
        if bits.first == "1" {
            return n - (1 << width)
        }
        return n
    }

    // MARK: Private

    /// plain (unsigned) binary of a non-negative value; zero renders as `"0"`.
    private static func plainBinary(_ value: Int) -> String {
        if value == 0 { return "0" }
        var digits: [Character] = []
        var n = value
        while n != 0 {
            digits.append(n & 1 == 0 ? "0" : "1")
            n >>= 1
        }
        return String(digits.reversed())
    }

    private static func padded(_ bits: String, toWidth width: Int) -> String {
        if bits.count >= width { return bits }
        return String(repeating: "0", count: width - bits.count) + bits
    }
}
