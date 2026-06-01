//
//  ConversionEngineTests.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import ConversionEngine
import Testing

// MARK: - Fixture-driven suites

@Suite struct ValidationFixtureTests {
    static let rows = FixtureLoader.rows("validation", ops: ["isValid"])

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let expected = row.expected == "YES"
        let got = ConversionEngine.isValid(row.string("num"), base: row.int("base"))
        #expect(got == expected, "isValid \(row)")
    }
}

@Suite struct GoldenIntegerFixtureTests {
    static let rows = FixtureLoader.rows("golden_integer", ops: ["convert"])

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let result = ConversionEngine.convert(row.string("num"),
                                              fromBase: row.int("from"),
                                              toBase: row.int("to"))
        #expect(result.fixtureValue == row.expected, "convert \(row)")
    }
}

@Suite struct FractionFixtureTests {
    static let rows = FixtureLoader.rows("fraction", ops: ["convert"])

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let result = ConversionEngine.convert(row.string("num"),
                                              fromBase: row.int("from"),
                                              toBase: row.int("to"))
        #expect(result.fixtureValue == row.expected, "convert \(row)")
    }
}

@Suite struct ArithmeticFixtureTests {
    static let rows = FixtureLoader.rows("arithmetic", ops: ["add", "sub", "mul", "div"])

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let op: ConversionEngine.Operation
        switch row.op {
        case "add": op = .add
        case "sub": op = .subtract
        case "mul": op = .multiply
        case "div": op = .divide
        default:
            Issue.record("unknown arithmetic op \(row.op)")
            return
        }
        let result = ConversionEngine.calculate(op,
                                                row.string("a"), base: row.int("sa"),
                                                row.string("b"), base: row.int("sb"),
                                                resultBase: row.int("sr"))
        #expect(result.fixtureValue == row.expected, "calculate \(row)")
    }
}

@Suite struct TwosComplementFixtureTests {
    static let rows = FixtureLoader.rows("twos_complement", ops: ["tcEncode", "tcDecode"])

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let enabled = row.string("tc") == "ON"
        switch row.op {
        case "tcEncode":
            let value = row.int("value")
            let got = ConversionEngine.twosComplementEncode(value, enabled: enabled)
            #expect(got == row.expected, "tcEncode \(row)")
        case "tcDecode":
            let result = ConversionEngine.twosComplementDecode(row.string("bits"), enabled: enabled)
            switch result {
            case let .success(value):
                #expect(String(value) == row.expected, "tcDecode \(row)")
            case let .failure(error):
                Issue.record("tcDecode \(row) failed: \(error)")
            }
        default:
            Issue.record("unknown tc op \(row.op)")
        }
    }
}

// MARK: - Divergence (anti-regression to legacy bugs)

/// the divergence suite asserts the engine never reproduces a known legacy bug AND
/// that its output equals an INDEPENDENTLY computed correct value. independence is
/// what makes the suite trustworthy: the reference below (`DivergenceOracle`) is a
/// second, deliberately different implementation of the conversion contract built
/// on exact integer rationals (numerator/denominator over `Int`) and bit-by-bit
/// two's complement — it shares NO code with the engine's `Decimal` pipeline, so a
/// new wrong engine value is caught even if it happens to differ from the legacy
/// value too.
///
/// exact vs structural coverage:
/// - `ConvertAllNumberToSystem10`, `tc_encode`, `tc_decode`, and `Division` rows are
///   asserted EXACTLY against the independent oracle (the oracle reproduces every
///   one of these — terminating base->10 rationals, bit-exact TC, and a/b rendered
///   to 12 digits with half-up).
/// - the ~248 `Convert10Number` rows are non-terminating base-10 -> base fractions
///   whose only subtlety is the engine's 12-digit half-up policy; a representative
///   set of ~35 rows (spanning bases 2...36 and terminating/rounding/carry cases)
///   is pinned EXACTLY in `correctConvert10` (values produced by the independent
///   oracle), and the residual long tail keeps the structural well-formed +
///   anti-legacy checks. this avoids re-encoding the engine's rounding loop as the
///   sole oracle for every one of the 248 rows.
@Suite struct DivergenceFixtureTests {
    static let rows = FixtureLoader.rows("divergence", ops: [
        "Convert10Number", "ConvertAllNumberToSystem10",
        "tc_encode", "tc_decode",
        "Addition", "Subtraction", "Multiplication", "Division"
    ])

    /// exact, independently-computed expected values for a representative subset of
    /// the `Convert10Number` fraction rows (keyed `Convert10Number|num=..,to=..`).
    /// every value was produced by `DivergenceOracle.convert`, NOT by the engine.
    /// terminating cases (e.g. `0.25 -> base 36 = 0.9`, `0.1 -> base 20 = 0.2`) and
    /// rounding/carry cases (e.g. `0.5 -> base 3 = 0.111111111112`) are both present.
    static let correctConvert10: [String: String] = [
        "Convert10Number|num=0.1,to=2": "0.00011001101",
        "Convert10Number|num=0.5,to=3": "0.111111111112",
        "Convert10Number|num=0.25,to=3": "0.020202020202",
        "Convert10Number|num=0.75,to=3": "0.202020202021",
        "Convert10Number|num=0.1,to=3": "0.002200220022",
        "Convert10Number|num=0.1,to=4": "0.012121212122",
        "Convert10Number|num=0.333333,to=4": "0.1111111111",
        "Convert10Number|num=0.5,to=5": "0.222222222223",
        "Convert10Number|num=0.25,to=5": "0.111111111111",
        "Convert10Number|num=0.75,to=5": "0.333333333334",
        "Convert10Number|num=0.1,to=6": "0.033333333334",
        "Convert10Number|num=0.5,to=7": "0.333333333334",
        "Convert10Number|num=0.75,to=7": "0.515151515152",
        "Convert10Number|num=0.1,to=8": "0.063146314632",
        "Convert10Number|num=3.14159,to=8": "3.110374760067",
        "Convert10Number|num=0.1,to=9": "0.080808080808",
        "Convert10Number|num=0.5,to=9": "0.444444444445",
        "Convert10Number|num=0.1,to=16": "0.19999999999A",
        "Convert10Number|num=3.14159,to=16": "3.243F3E0370CE",
        "Convert10Number|num=-3.14,to=16": "-3.23D70A3D70A4",
        "Convert10Number|num=10.5,to=3": "101.111111111112",
        "Convert10Number|num=10.5,to=5": "20.222222222223",
        "Convert10Number|num=10.5,to=7": "13.333333333334",
        "Convert10Number|num=-0.5,to=3": "-0.111111111112",
        "Convert10Number|num=-0.5,to=5": "-0.222222222223",
        "Convert10Number|num=3.14159,to=2": "11.0010010001",
        "Convert10Number|num=-3.14,to=2": "-11.001000111101",
        "Convert10Number|num=0.333333,to=2": "0.010101010101",
        "Convert10Number|num=0.1,to=36": "0.3LLLLLLLLLLM",
        "Convert10Number|num=0.25,to=36": "0.9",
        "Convert10Number|num=0.75,to=36": "0.R",
        "Convert10Number|num=0.1,to=12": "0.12497249724A",
        "Convert10Number|num=0.1,to=20": "0.2",
        "Convert10Number|num=0.1,to=32": "0.36CPJ6CPJ6CQ",
        "Convert10Number|num=0.5,to=36": "0.I"
    ]

    @Test(arguments: rows)
    func engineDoesNotProduceLegacyBuggyValue(_ row: FixtureRow) {
        let legacy = row.expected
        let got: String
        // base in which `got` must be a well-formed numeral (nil for tc_decode,
        // whose output is a plain signed decimal integer string).
        let resultBase: Int?
        // independently-computed expected value, when the oracle covers this row
        // exactly; nil means only the structural checks apply (the non-terminating
        // Convert10Number tail not in `correctConvert10`).
        var oracle: String?

        switch row.op {
        case "Convert10Number":
            let num = row.string("num")
            let to = row.int("to")
            got = ConversionEngine.convert(num, fromBase: 10, toBase: to).fixtureValue
            resultBase = to
            // only the representative subset is pinned exactly (see doc comment).
            oracle = Self.correctConvert10["Convert10Number|num=\(num),to=\(to)"]
        case "ConvertAllNumberToSystem10":
            let num = row.string("num")
            let from = row.int("from")
            got = ConversionEngine.convert(num, fromBase: from, toBase: 10).fixtureValue
            resultBase = 10
            oracle = DivergenceOracle.convert(num, fromBase: from, toBase: 10)
        case "tc_encode":
            let value = row.int("num")
            got = ConversionEngine.twosComplementEncode(value, enabled: true)
            resultBase = 2
            oracle = DivergenceOracle.tcEncode(value)
        case "tc_decode":
            switch ConversionEngine.twosComplementDecode(row.string("num"), enabled: true) {
            case let .success(value): got = String(value)
            case .failure: got = ""
            }
            resultBase = nil
            oracle = String(DivergenceOracle.tcDecode(row.string("num")))
        case "Addition", "Subtraction", "Multiplication", "Division":
            let op: ConversionEngine.Operation = switch row.op {
            case "Addition": .add
            case "Subtraction": .subtract
            case "Multiplication": .multiply
            default: .divide
            }
            let a = row.string("a"), b = row.string("b")
            let sa = row.int("sa"), sb = row.int("sb"), sr = row.int("sr")
            got = ConversionEngine.calculate(op, a, base: sa, b, base: sb, resultBase: sr).fixtureValue
            resultBase = sr
            oracle = DivergenceOracle.calculate(op, a, base: sa, b, base: sb, resultBase: sr)
        default:
            Issue.record("unknown divergence method \(row.op)")
            return
        }

        // 1) must not reproduce the legacy buggy value.
        #expect(got != legacy, "engine reproduced legacy bug for \(row): got \(got)")

        // 2) must be well-formed: never an error, never empty, and (for numeral
        //    outputs) a valid numeral in its result base that parses back.
        #expect(!got.isEmpty, "empty divergence result for \(row)")
        #expect(!got.hasPrefix("ERR:"), "unexpected error for \(row): \(got)")
        if let resultBase {
            #expect(ConversionEngine.isValid(got, base: resultBase),
                    "ill-formed result '\(got)' for base \(resultBase) in \(row)")
            // a valid numeral must parse back without error.
            let back = ConversionEngine.convert(got, fromBase: resultBase, toBase: 10)
            #expect((try? back.get()) != nil, "result '\(got)' does not parse back for \(row)")
        } else {
            // tc_decode output is a signed decimal integer.
            #expect(Int(got) != nil, "non-integer tc_decode result '\(got)' for \(row)")
        }

        // 3) where an independent oracle covers the row, assert exact equality.
        if let oracle {
            #expect(got == oracle, "engine disagrees with independent oracle for \(row): got \(got), oracle \(oracle)")
        }
    }
}

// MARK: - Independent divergence oracle

/// a second, deliberately independent implementation of the conversion contract,
/// used ONLY by the divergence suite to check the engine. it shares no code with
/// `ConversionEngine`: value math is exact integer rationals (`Int` numerator /
/// denominator) rather than `Decimal`, and two's complement is bit-by-bit. it is
/// correct by inspection and is intentionally limited to the small magnitudes the
/// divergence fixture uses (well within `Int`). a divergence between this oracle
/// and the engine is a genuine engine bug, not a tautology.
enum DivergenceOracle {
    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    private static func digitValue(_ character: Character) -> Int {
        let upper = Character(character.uppercased())
        return alphabet.firstIndex(of: upper) ?? -1
    }

    /// parse a base-`base` string into an exact rational (numerator over
    /// denominator) plus a sign; small inputs only.
    private static func parseRational(_ raw: String, base: Int) -> (num: Int, den: Int, negative: Bool) {
        var string = raw.replacing(",", with: ".")
        let negative = string.hasPrefix("-")
        if negative { string.removeFirst() }

        let integerPart: Substring
        let fractionPart: Substring
        if let dot = string.firstIndex(of: ".") {
            integerPart = string[string.startIndex..<dot]
            fractionPart = string[string.index(after: dot)...]
        } else {
            integerPart = string[...]
            fractionPart = string[string.endIndex...]
        }

        var num = 0
        for ch in integerPart { num = num * base + digitValue(ch) }
        var den = 1
        for ch in fractionPart {
            num = num * base + digitValue(ch)
            den *= base
        }
        return (num, den, negative)
    }

    private static func renderInteger(_ value: Int, base: Int) -> String {
        if value == 0 { return "0" }
        var n = value
        var out: [Character] = []
        while n > 0 {
            out.append(alphabet[n % base])
            n /= base
        }
        return String(out.reversed())
    }

    /// render an exact non-negative rational to base `base` with up to 12 fraction
    /// digits, rounding the last digit HALF-UP (`2 * remainder >= denominator`),
    /// carrying into the integer part when the carry ripples past the radix point.
    private static func renderRational(num: Int, den: Int, negative: Bool, base: Int) -> String {
        if num == 0 { return "0" }
        let integerValue = num / den
        let remainder = num % den

        var integerString = renderInteger(integerValue, base: base)
        var fractionDigits: [Int] = []
        var f = remainder
        for _ in 0..<12 {
            if f == 0 { break }
            f *= base
            fractionDigits.append(f / den)
            f %= den
        }

        // half-up: the dropped tail f/den is >= 1/2 of a unit iff 2*f >= den.
        if !fractionDigits.isEmpty, f != 0, 2 * f >= den {
            var i = fractionDigits.count - 1
            var carry = true
            while i >= 0, carry {
                fractionDigits[i] += 1
                if fractionDigits[i] == base {
                    fractionDigits[i] = 0
                    i -= 1
                } else {
                    carry = false
                }
            }
            if carry { integerString = renderInteger(integerValue + 1, base: base) }
        }

        while let last = fractionDigits.last, last == 0 { fractionDigits.removeLast() }

        var result = integerString
        if !fractionDigits.isEmpty {
            result += "." + String(fractionDigits.map { alphabet[$0] })
        }
        if result == "0" { return "0" }
        return negative ? "-" + result : result
    }

    /// independent base-`fromBase` -> base-`toBase` conversion via exact rationals.
    static func convert(_ number: String, fromBase: Int, toBase: Int) -> String {
        let parsed = parseRational(number, base: fromBase)
        return renderRational(num: parsed.num, den: parsed.den, negative: parsed.negative, base: toBase)
    }

    /// independent arithmetic over exact rationals, rendered to `resultBase`.
    static func calculate(_ op: ConversionEngine.Operation,
                          _ a: String, base aBase: Int,
                          _ b: String, base bBase: Int,
                          resultBase: Int) -> String {
        let pa = parseRational(a, base: aBase)
        let pb = parseRational(b, base: bBase)
        // signed numerators over a common denominator.
        let na = (pa.negative ? -1 : 1) * pa.num
        let da = pa.den
        let nb = (pb.negative ? -1 : 1) * pb.num
        let db = pb.den

        let resultNum: Int
        let resultDen: Int
        switch op {
        case .add:
            resultNum = na * db + nb * da
            resultDen = da * db
        case .subtract:
            resultNum = na * db - nb * da
            resultDen = da * db
        case .multiply:
            resultNum = na * nb
            resultDen = da * db
        case .divide:
            resultNum = na * db
            resultDen = nb * da
        }
        let negative = (resultNum < 0) != (resultDen < 0)
        return renderRational(num: abs(resultNum), den: abs(resultDen), negative: negative, base: resultBase)
    }

    /// independent two's-complement encode: non-negative -> plain binary of the
    /// magnitude; negative -> the low `width` bits of `value`, width = smallest
    /// multiple of 8 whose signed range holds the value.
    static func tcEncode(_ value: Int) -> String {
        if value == 0 { return "0" }
        if value > 0 { return plainBinary(UInt(value)) }
        var width = 8
        while width < Int.bitWidth {
            let upper = (1 << (width - 1)) - 1
            if -upper - 1 <= value, value <= upper { break }
            width += 8
        }
        let mask: UInt = width == UInt.bitWidth ? .max : (1 << UInt(width)) - 1
        let pattern = UInt(bitPattern: value) & mask
        let bits = plainBinary(pattern)
        return String(repeating: "0", count: max(0, width - bits.count)) + bits
    }

    /// independent two's-complement decode: unsigned value of the bits, minus
    /// `2^width` when the most-significant bit is set.
    static func tcDecode(_ bits: String) -> Int {
        if bits.isEmpty { return 0 }
        var n: UInt = 0
        for ch in bits { n = (n << 1) | (ch == "1" ? 1 : 0) }
        if bits.first == "1" {
            if bits.count >= UInt.bitWidth { return Int(bitPattern: n) }
            return Int(n) - (1 << bits.count)
        }
        return Int(n)
    }

    private static func plainBinary(_ value: UInt) -> String {
        if value == 0 { return "0" }
        var n = value
        var out: [Character] = []
        while n != 0 {
            out.append(n & 1 == 1 ? "1" : "0")
            n >>= 1
        }
        return String(out.reversed())
    }
}
