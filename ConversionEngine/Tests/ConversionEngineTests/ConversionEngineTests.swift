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
    static let rows = FixtureLoader.rows("validation")

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let expected = row.expected == "YES"
        let got = ConversionEngine.isValid(row.string("num"), base: row.int("base"))
        #expect(got == expected, "isValid \(row)")
    }
}

@Suite struct GoldenIntegerFixtureTests {
    static let rows = FixtureLoader.rows("golden_integer")

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let result = ConversionEngine.convert(row.string("num"),
                                              fromBase: row.int("from"),
                                              toBase: row.int("to"))
        #expect(result.fixtureValue == row.expected, "convert \(row)")
    }
}

@Suite struct FractionFixtureTests {
    static let rows = FixtureLoader.rows("fraction")

    @Test(arguments: rows)
    func matchesExpected(_ row: FixtureRow) {
        let result = ConversionEngine.convert(row.string("num"),
                                              fromBase: row.int("from"),
                                              toBase: row.int("to"))
        #expect(result.fixtureValue == row.expected, "convert \(row)")
    }
}

@Suite struct ArithmeticFixtureTests {
    static let rows = FixtureLoader.rows("arithmetic")

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
    static let rows = FixtureLoader.rows("twos_complement")

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
    static let rows = FixtureLoader.rows("divergence")

    @Test(arguments: rows)
    func engineDoesNotProduceLegacyBuggyValue(_ row: FixtureRow) {
        let legacy = row.expected
        let got: String

        switch row.op {
        case "Convert10Number":
            got = ConversionEngine.convert(row.string("num"),
                                           fromBase: 10,
                                           toBase: row.int("to")).fixtureValue
        case "ConvertAllNumberToSystem10":
            got = ConversionEngine.convert(row.string("num"),
                                           fromBase: row.int("from"),
                                           toBase: 10).fixtureValue
        case "tc_encode":
            let value = Int(row.string("num")) ?? 0
            got = ConversionEngine.twosComplementEncode(value, enabled: true)
        case "tc_decode":
            switch ConversionEngine.twosComplementDecode(row.string("num"), enabled: true) {
            case let .success(value): got = String(value)
            case .failure: got = ""
            }
        case "Addition", "Subtraction", "Multiplication", "Division":
            let op: ConversionEngine.Operation = switch row.op {
            case "Addition": .add
            case "Subtraction": .subtract
            case "Multiplication": .multiply
            default: .divide
            }
            got = ConversionEngine.calculate(op,
                                             row.string("a"), base: row.int("sa"),
                                             row.string("b"), base: row.int("sb"),
                                             resultBase: row.int("sr")).fixtureValue
        default:
            Issue.record("unknown divergence method \(row.op)")
            return
        }

        #expect(got != legacy, "engine reproduced legacy bug for \(row): got \(got)")
    }
}
