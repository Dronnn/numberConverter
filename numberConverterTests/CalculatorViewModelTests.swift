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
}
