//
//  TwosComplement.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

// MARK: - TwosComplement

/// signed binary fields use the smallest whole-byte width that contains the value.
enum TwosComplement {
    static func width(for value: Int) -> Int {
        var width = 8
        while width < Int.bitWidth {
            let upper = (1 << (width - 1)) - 1
            if -upper - 1 <= value, value <= upper { return width }
            width += 8
        }
        return Int.bitWidth
    }

    /// enabled encodings include a sign bit for positive values as well as negative ones.
    static func encode(_ value: Int, enabled: Bool) -> String {
        guard enabled else {
            let magnitude = String(value.magnitude, radix: 2)
            return value < 0 ? "-" + magnitude : magnitude
        }
        let width = width(for: value)
        let mask: UInt = width == UInt.bitWidth ? .max : (1 << UInt(width)) - 1
        let pattern = UInt(bitPattern: value) & mask
        let bits = String(pattern, radix: 2)
        return String(repeating: "0", count: width - bits.count) + bits
    }

    /// signed input uses its entered width; unsigned results must fit a native `Int`.
    /// excess leading sign bits/zeroes are accepted only when they preserve the value.
    static func decode(_ bits: String, enabled: Bool) throws(ConversionError) -> Int {
        guard bits.utf8.count <= ConversionEngine.maxInputLength else { throw .numberOutOfRange }
        guard !bits.isEmpty else { return 0 }
        guard bits.allSatisfy({ $0 == "0" || $0 == "1" }) else {
            throw .invalidCharacter
        }

        var significant = Substring(bits)
        if enabled {
            while significant.count > 1,
                  significant.first == significant.dropFirst().first {
                significant.removeFirst()
            }
            guard significant.count <= Int.bitWidth else { throw .numberOutOfRange }
        } else {
            significant = significant.drop(while: { $0 == "0" })
            guard significant.count < Int.bitWidth else { throw .numberOutOfRange }
        }

        var pattern: UInt = 0
        for bit in significant {
            pattern = (pattern << 1) | (bit == "1" ? 1 : 0)
        }
        if enabled, significant.first == "1" {
            let width = significant.count
            let signMask: UInt = width == UInt.bitWidth ? 0 : (~UInt(0) << UInt(width))
            return Int(bitPattern: pattern | signMask)
        }
        return Int(pattern)
    }
}
