//
//  CalculatorViewModelTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
@testable import numberConverter
import Testing

// MARK: - CalculatorViewModelTests

@MainActor
struct CalculatorViewModelTests {
    @Test
    func addsBinaryOperands() {
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "101",
            baseA: 2,
            operandB: "11",
            baseB: 2,
            resultBase: 2
        )

        #expect(sut.result == "1000")
        #expect(sut.error == nil)
    }

    @Test
    func addsMixedBaseOperands() {
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "FF",
            baseA: 16,
            operandB: "1",
            baseB: 10,
            resultBase: 16
        )

        #expect(sut.result == "100")
        #expect(sut.error == nil)
    }

    @Test
    func subtractsRecomputesLive() {
        let sut = CalculatorViewModel(
            operation: .subtract,
            operandA: "10",
            baseA: 10,
            operandB: "4",
            baseB: 10,
            resultBase: 10
        )
        #expect(sut.result == "6")

        // mutate operandB after construction: 10 - 7 = 3.
        sut.operandB = "7"
        #expect(sut.result == "3")
        #expect(sut.error == nil)

        // mutate operandA after construction: 25 - 7 = 18.
        sut.operandA = "25"
        #expect(sut.result == "18")
        #expect(sut.error == nil)
    }

    @Test
    func multipliesRecomputesLive() {
        let sut = CalculatorViewModel(
            operation: .multiply,
            operandA: "6",
            baseA: 10,
            operandB: "7",
            baseB: 10,
            resultBase: 10
        )
        #expect(sut.result == "42")

        // mutate operandB after construction: 6 * 9 = 54.
        sut.operandB = "9"
        #expect(sut.result == "54")
        #expect(sut.error == nil)

        // mutate operandA after construction: 8 * 9 = 72.
        sut.operandA = "8"
        #expect(sut.result == "72")
        #expect(sut.error == nil)
    }

    @Test
    func switchingOperationRecomputes() {
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "6",
            baseA: 10,
            operandB: "2",
            baseB: 10,
            resultBase: 10
        )
        #expect(sut.result == "8")

        sut.operation = .multiply
        #expect(sut.result == "12")

        sut.operation = .subtract
        #expect(sut.result == "4")
    }

    @Test
    func changingOperandRecomputes() {
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "6",
            baseA: 10,
            operandB: "2",
            baseB: 10,
            resultBase: 10
        )

        sut.operandB = "10"
        #expect(sut.result == "16")
    }

    @Test
    func divisionByZeroFlagsError() {
        let sut = CalculatorViewModel(
            operation: .divide,
            operandA: "100",
            baseA: 10,
            operandB: "0",
            baseB: 10,
            resultBase: 10
        )

        #expect(sut.error == .divisionByZero)
        #expect(sut.result.isEmpty)
    }

    @Test
    func invalidOperandFlagsError() {
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "G",
            baseA: 10,
            operandB: "1",
            baseB: 10,
            resultBase: 10
        )

        #expect(sut.error == .invalidCharacter)
        #expect(sut.result.isEmpty)
    }

    // MARK: - Division (independent expected values)

    @Test
    func dividesBinaryOperandsExactly() {
        // binary 1010 = 10, binary 10 = 2; 10 / 2 = 5 = binary 101.
        let sut = CalculatorViewModel(
            operation: .divide,
            operandA: "1010",
            baseA: 2,
            operandB: "10",
            baseB: 2,
            resultBase: 2
        )

        #expect(sut.result == "101")
        #expect(sut.error == nil)
    }

    @Test
    func dividesFractionalRoundsHalfUpToTwelveDigits() {
        // 2 / 3 = 0.6666...; 12 fraction digits = 666666666666, the 13th digit
        // is 6 (>= 5) so half-up rounds the last digit to 7 -> 0.666666666667.
        let sut = CalculatorViewModel(
            operation: .divide,
            operandA: "2",
            baseA: 10,
            operandB: "3",
            baseB: 10,
            resultBase: 10
        )

        #expect(sut.result == "0.666666666667")
        #expect(sut.error == nil)
    }

    @Test
    func dividesFractionalTruncatesWhenNextDigitBelowHalf() {
        // 100 / 3 = 33.3333...; 12 fraction digits = 333333333333, the 13th digit
        // is 3 (< 5) so no rounding occurs -> 33.333333333333.
        let sut = CalculatorViewModel(
            operation: .divide,
            operandA: "100",
            baseA: 10,
            operandB: "3",
            baseB: 10,
            resultBase: 10
        )

        #expect(sut.result == "33.333333333333")
        #expect(sut.error == nil)
    }

    // MARK: - Fractional mixed-base operands

    @Test
    func addsFractionalMixedBaseOperands() {
        // hex FF.4 = 255 + 4/16 = 255.25; binary 1.1 = 1 + 1/2 = 1.5.
        // 255.25 + 1.5 = 256.75; rendered to hex: 256 = 100, 0.75 = 0.C -> 100.C.
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "FF.4",
            baseA: 16,
            operandB: "1.1",
            baseB: 2,
            resultBase: 16
        )

        #expect(sut.result == "100.C")
        #expect(sut.error == nil)
    }

    @Test
    func dividesFractionalMixedBaseOperands() {
        // hex A.8 = 10 + 8/16 = 10.5; binary 10 = 2; 10.5 / 2 = 5.25 (base 10).
        let sut = CalculatorViewModel(
            operation: .divide,
            operandA: "A.8",
            baseA: 16,
            operandB: "10",
            baseB: 2,
            resultBase: 10
        )

        #expect(sut.result == "5.25")
        #expect(sut.error == nil)
    }

    // MARK: - Live mutation of operands / bases / result base

    @Test
    func changingOperandALive() {
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "6",
            baseA: 10,
            operandB: "2",
            baseB: 10,
            resultBase: 10
        )
        #expect(sut.result == "8")

        // mutate operandA after construction: 15 + 2 = 17.
        sut.operandA = "15"
        #expect(sut.result == "17")
        #expect(sut.error == nil)
    }

    @Test
    func changingBaseALive() {
        // start: hex 11 = 17, + 1 = 18 (base 10).
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "11",
            baseA: 16,
            operandB: "1",
            baseB: 10,
            resultBase: 10
        )
        #expect(sut.result == "18")

        // reinterpret operandA "11" as binary = 3; 3 + 1 = 4.
        sut.baseA = 2
        #expect(sut.result == "4")
        #expect(sut.error == nil)
    }

    @Test
    func changingBaseBLive() {
        // start: 16 (base 10) - binary 10 (= 2) = 14.
        let sut = CalculatorViewModel(
            operation: .subtract,
            operandA: "16",
            baseA: 10,
            operandB: "10",
            baseB: 2,
            resultBase: 10
        )
        #expect(sut.result == "14")

        // reinterpret operandB "10" as hex = 16; 16 - 16 = 0.
        sut.baseB = 16
        #expect(sut.result == "0")
        #expect(sut.error == nil)
    }

    @Test
    func changingResultBaseLive() {
        // 12 + 0 = 12 (base 10).
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "12",
            baseA: 10,
            operandB: "0",
            baseB: 10,
            resultBase: 10
        )
        #expect(sut.result == "12")

        // render 12 to hex: 12 = C.
        sut.resultBase = 16
        #expect(sut.result == "C")
        #expect(sut.error == nil)

        // render 12 to binary: 12 = 1100.
        sut.resultBase = 2
        #expect(sut.result == "1100")
        #expect(sut.error == nil)
    }

    // MARK: - Error flags

    @Test
    func invalidOperandBFlagsError() {
        // "2" is not a legal digit in base 2, so operandB is invalid.
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "1",
            baseA: 2,
            operandB: "2",
            baseB: 2,
            resultBase: 2
        )

        #expect(sut.error == .invalidCharacter)
        #expect(sut.result.isEmpty)
    }

    @Test
    func operandBaseOutOfRangeFlagsInvalidCharacter() {
        // an operand base outside 2...36 short-circuits to invalidCharacter
        // (the engine reserves baseOutOfRange for the result base only).
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "1",
            baseA: 37,
            operandB: "1",
            baseB: 10,
            resultBase: 10
        )

        #expect(sut.error == .invalidCharacter)
        #expect(sut.result.isEmpty)
    }

    @Test
    func resultBaseOutOfRangeFlagsBaseOutOfRange() {
        // a result base outside 2...36 flags the typed baseOutOfRange error.
        let sut = CalculatorViewModel(
            operation: .add,
            operandA: "1",
            baseA: 10,
            operandB: "1",
            baseB: 10,
            resultBase: 37
        )

        #expect(sut.error == .baseOutOfRange)
        #expect(sut.result.isEmpty)
    }
}
