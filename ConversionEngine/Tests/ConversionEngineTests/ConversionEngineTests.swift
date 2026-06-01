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
            let value = Int(row.string("value")) ?? 0
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

@Suite struct DivergenceFixtureTests {
    static let rows = FixtureLoader.rows("divergence", ops: [
        "Convert10Number", "ConvertAllNumberToSystem10",
        "tc_encode", "tc_decode",
        "Addition", "Subtraction", "Multiplication", "Division"
    ])

    /// independently-correct exact value for the divergence rows whose answer is
    /// cheap to compute by hand (terminating fractions, exact two's complement,
    /// exact division). keyed by `op|args`. these turn the divergence suite from
    /// "differs from legacy" into "equals the mathematically-correct value", so a
    /// NEW wrong value that merely differs from legacy is still caught.
    /// keys are `op|<args sorted by key>=value`, matching how the lookup key is
    /// rebuilt below from `row.args`.
    static let correct: [String: String] = [
        // terminating base->10 fractions: bits exactly represent a dyadic rational.
        "ConvertAllNumberToSystem10|from=2,num=0.1": "0.5",
        "ConvertAllNumberToSystem10|from=2,num=0.11": "0.75",
        "ConvertAllNumberToSystem10|from=2,num=0.101": "0.625",
        "ConvertAllNumberToSystem10|from=2,num=10.1": "2.5",
        "ConvertAllNumberToSystem10|from=8,num=0.4": "0.5",
        "ConvertAllNumberToSystem10|from=16,num=0.8": "0.5",
        "ConvertAllNumberToSystem10|from=16,num=A.8": "10.5",
        "ConvertAllNumberToSystem10|from=2,num=-10.1": "-2.5",
        // exact two's complement (legacy mis-sized the field / mis-signed the value).
        "tc_encode|num=-128,tc=ON": "10000000",
        "tc_decode|num=00000001,tc=ON": "1",
        "tc_decode|num=01111111,tc=ON": "127",
        // exact division to 12 fraction digits (legacy truncated to 6).
        "Division|a=10,b=3,sa=10,sb=10,sr=10": "3.333333333333",
        "Division|a=1,b=3,sa=10,sb=10,sr=2": "0.010101010101",
        "Division|a=-10,b=3,sa=10,sb=10,sr=10": "-3.333333333333"
    ]

    @Test(arguments: rows)
    func engineDoesNotProduceLegacyBuggyValue(_ row: FixtureRow) {
        let legacy = row.expected
        let got: String
        // base in which `got` must be a well-formed numeral (nil for tc_decode,
        // whose output is a plain signed decimal integer string).
        let resultBase: Int?

        switch row.op {
        case "Convert10Number":
            let to = row.int("to")
            got = ConversionEngine.convert(row.string("num"), fromBase: 10, toBase: to).fixtureValue
            resultBase = to
        case "ConvertAllNumberToSystem10":
            got = ConversionEngine.convert(row.string("num"),
                                           fromBase: row.int("from"),
                                           toBase: 10).fixtureValue
            resultBase = 10
        case "tc_encode":
            let value = Int(row.string("num")) ?? 0
            got = ConversionEngine.twosComplementEncode(value, enabled: true)
            resultBase = 2
        case "tc_decode":
            switch ConversionEngine.twosComplementDecode(row.string("num"), enabled: true) {
            case let .success(value): got = String(value)
            case .failure: got = ""
            }
            resultBase = nil
        case "Addition", "Subtraction", "Multiplication", "Division":
            let op: ConversionEngine.Operation = switch row.op {
            case "Addition": .add
            case "Subtraction": .subtract
            case "Multiplication": .multiply
            default: .divide
            }
            let sr = row.int("sr")
            got = ConversionEngine.calculate(op,
                                             row.string("a"), base: row.int("sa"),
                                             row.string("b"), base: row.int("sb"),
                                             resultBase: sr).fixtureValue
            resultBase = sr
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

        // 3) where the correct value is cheap to compute by hand, pin it exactly.
        let key = "\(row.op)|\(row.args.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ","))"
        if let expected = Self.correct[key] {
            #expect(got == expected, "wrong divergence value for \(row): got \(got), expected \(expected)")
        }
    }
}
