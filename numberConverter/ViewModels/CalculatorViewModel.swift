//
//  CalculatorViewModel.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation

// MARK: - CalculatorViewModel

/// view model for the arithmetic calculator: two operands in (possibly) different
/// bases, an operation, and a result base. it recomputes live whenever the
/// operation or any field changes.
@Observable
@MainActor
final class CalculatorViewModel {
    var operation: ConversionEngine.Operation {
        didSet { recompute() }
    }

    var operandA: String {
        didSet { recompute() }
    }

    var baseA: Int {
        didSet { recompute() }
    }

    var operandB: String {
        didSet { recompute() }
    }

    var baseB: Int {
        didSet { recompute() }
    }

    var resultBase: Int {
        didSet { recompute() }
    }

    private(set) var result = ""
    private(set) var error: ConversionError?

    init(
        operation: ConversionEngine.Operation = .add,
        operandA: String = "",
        baseA: Int = 10,
        operandB: String = "",
        baseB: Int = 10,
        resultBase: Int = 10
    ) {
        self.operation = operation
        self.operandA = operandA
        self.baseA = baseA
        self.operandB = operandB
        self.baseB = baseB
        self.resultBase = resultBase
        recompute()
    }

    // MARK: Recompute

    /// runs the calculation for the current state, setting `result` or `error`.
    func recompute() {
        let outcome = ConversionEngine.calculate(
            operation,
            operandA,
            base: baseA,
            operandB,
            base: baseB,
            resultBase: resultBase
        )
        switch outcome {
        case let .success(value):
            result = value
            error = nil
        case let .failure(conversionError):
            result = ""
            error = conversionError
        }
    }
}
