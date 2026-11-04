//
//  NativeConversionIntegrationTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation
@testable import numberConverter
import Testing

@MainActor
struct NativeConversionIntegrationTests {
    @Test
    func largeExactDecimalValuesSurviveGeneratedNavigationSeeds() {
        for exponent in [38, 100, 127] {
            let decimal = "1" + String(repeating: "0", count: exponent)
            let expected = Decimal(sign: .plus, exponent: exponent, significand: 1)
            let converter = ConverterViewModel()
            converter.userEdited(.decimal, decimal)

            #expect(converter.invalidFields.isEmpty)
            #expect(converter.decimalSeed == decimal)
            for field in BaseField.allCases {
                let seed = converter.seed(for: field)
                let detail = MainSystemsViewModel(base: seed.base, number: seed.number, twosComplement: false)

                #expect(detail.decimal == decimal)
                #expect(detail.binary == converter.binary)
                #expect(detail.octal == converter.octal)
                #expect(detail.hexadecimal == converter.hexadecimal)
            }

            let allSystems = DecimalToAllViewModel(number: converter.decimalSeed)
            #expect(allSystems.rows.map(\.base) == Array(2 ... 36))
            for row in allSystems.rows {
                #expect(ConversionEngine.toDecimal(row.value, fromBase: row.base) == expected)
                let detail = MainSystemsViewModel(base: row.base, number: row.value, twosComplement: false)
                #expect(detail.decimal == decimal)
            }
        }
    }

    @Test
    func calculatorRejectsLostIntegerDigitsAndOverflowThenRecovers() {
        let large = "1" + String(repeating: "0", count: 100)
        let calculator = CalculatorViewModel(operation: .divide, operandA: large, operandB: "3")

        #expect(calculator.error == .numberOutOfRange)
        #expect(calculator.result.isEmpty)

        calculator.operandB = "2"
        #expect(calculator.error == nil)
        #expect(calculator.result == "5" + String(repeating: "0", count: 99))

        calculator.operation = .multiply
        calculator.operandB = large
        #expect(calculator.error == .numberOutOfRange)
        #expect(calculator.result.isEmpty)

        calculator.operandA = "2"
        calculator.operandB = "3"
        #expect(calculator.error == nil)
        #expect(calculator.result == "6")
    }

    @Test
    func recurringNumeralConversionAndExactArithmeticHaveDeliberatePrecisionLimits() {
        let conversion = AllSystemsViewModel(number: "0.1", sourceBase: 3, targetBase: 10)
        #expect(conversion.error == nil)
        #expect(conversion.result == "0.333333333333")

        let calculator = CalculatorViewModel(operandA: "0.1", baseA: 3, operandB: "1")
        #expect(calculator.error == .numberOutOfRange)
        #expect(calculator.result.isEmpty)

        calculator.baseA = 5
        #expect(calculator.error == nil)
        #expect(calculator.result == "1.2")
    }
}
