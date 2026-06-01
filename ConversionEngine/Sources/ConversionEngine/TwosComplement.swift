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
    ///
    /// `W` is capped at `Int.bitWidth` (64), the widest signed range a native
    /// `Int` can hold; `Int.min` resolves to that width without overflow.
    static func width(for value: Int) -> Int {
        var w = 8
        while w < Int.bitWidth {
            // signed range at width w is -2^(w-1) ... 2^(w-1)-1, computed without
            // negating 2^(w-1) (which would trap for the full-width bound).
            let upper = (1 << (w - 1)) - 1   // 2^(w-1) - 1
            let lower = -upper - 1           // -2^(w-1)
            if lower <= value, value <= upper { return w }
            w += 8
        }
        return Int.bitWidth
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
        if value > 0 { return plainBinary(UInt(value)) }
        // value < 0
        if !enabled {
            // -Int.min would overflow; take the magnitude via the unsigned domain.
            return "-" + plainBinary(value.magnitude)
        }
        let w = width(for: value)
        // low W bits of the value's two's-complement representation; using the
        // unsigned bit pattern keeps the full-width case (W = 64) trap-free.
        let mask: UInt = w == UInt.bitWidth ? .max : (1 << UInt(w)) - 1
        let pattern = UInt(bitPattern: value) & mask
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
        // accumulate the unsigned value in `UInt` so a full 64-bit pattern never
        // overflows during shifting.
        var n: UInt = 0
        for ch in bits {
            switch ch {
            case "0": n <<= 1
            case "1": n = (n << 1) | 1
            default: throw ConversionError.invalidCharacter
            }
        }
        if !enabled { return Int(n) }
        let width = bits.count
        if bits.first == "1" {
            // negative field: sign-extend by setting every bit above the field,
            // then reinterpret the pattern as signed. this is `n - 2^width`
            // without ever forming `2^width` (which traps for width 63 and is
            // unrepresentable for width >= 64); for width >= 64 the shift
            // overshifts to a zero mask, leaving the full-width pattern intact.
            let mask: UInt = width >= UInt.bitWidth ? 0 : (~UInt(0) << UInt(width))
            return Int(bitPattern: n | mask)
        }
        return Int(n)
    }

    // MARK: Private

    /// plain (unsigned) binary of a non-negative value; zero renders as `"0"`.
    private static func plainBinary(_ value: UInt) -> String {
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
