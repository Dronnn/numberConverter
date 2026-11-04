//
//  CalculatorView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import OSLog
import SwiftUI

// MARK: - CalculatorView

/// root screen of the calculator tab: two operands in any bases, an operation,
/// and a result rendered in a chosen base. it recomputes live.
struct CalculatorView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var viewModel = CalculatorViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            CalculatorDataSection(viewModel: viewModel)
            CalculatorOperationSection(operation: $viewModel.operation)
        }
        .navigationTitle(Text("nav.calculator"))
        .appHelpToolbar()
        .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDismissal()
        .onAppear { AppLogger.calculator.screen("calculator") }
    }
}

// MARK: - CalculatorDataSection

/// the operands, their bases, the live result and the result base.
private struct CalculatorDataSection: View {
    @Bindable var viewModel: CalculatorViewModel

    var body: some View {
        Section {
            LabeledContent {
                OperandField(prompt: "1000", text: $viewModel.operandA)
                    .accessibilityIdentifier("calculator.operandA")
            } label: {
                Text("calculator.field.operandA")
            }

            LabeledContent {
                BaseNumberField(prompt: "2", base: $viewModel.baseA)
                    .accessibilityIdentifier("calculator.baseA")
            } label: {
                Text("calculator.field.base")
            }

            LabeledContent {
                OperandField(prompt: "100", text: $viewModel.operandB)
                    .accessibilityIdentifier("calculator.operandB")
            } label: {
                Text("calculator.field.operandB")
            }

            LabeledContent {
                BaseNumberField(prompt: "2", base: $viewModel.baseB)
                    .accessibilityIdentifier("calculator.baseB")
            } label: {
                Text("calculator.field.base")
            }

            ResultRow(
                label: "calculator.field.result",
                prompt: "",
                result: viewModel.result,
                error: viewModel.error,
                accessibilityPrefix: "calculator"
            )

            LabeledContent {
                BaseNumberField(prompt: "8", base: $viewModel.resultBase)
                    .accessibilityIdentifier("calculator.resultBase")
            } label: {
                Text("calculator.field.base")
                    .accessibilityIdentifier("calculator.resultBaseLabel")
            }
        } header: {
            Text("calculator.section.data")
                .foregroundStyle(Color.primary)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - CalculatorOperationSection

/// the segmented operation picker.
private struct CalculatorOperationSection: View {
    @Binding var operation: ConversionEngine.Operation

    var body: some View {
        Section {
            Picker(selection: $operation) {
                ForEach(CalculatorOperation.allCases) { item in
                    Text(verbatim: item.glyph).tag(item.operation)
                }
            } label: {
                Text("calculator.section.operation")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("calculator.operation")
        } header: {
            Text("calculator.section.operation")
                .foregroundStyle(Color.primary)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - OperandField

/// an operand text field. operands may contain letters (bases up to 36), so it
/// allows uppercase input; the engine is case-insensitive.
private struct OperandField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        TextField(text: $text, axis: .vertical) {
            Text(verbatim: prompt)
        }
        .lineLimit(nil)
        .multilineTextAlignment(.trailing)
        .keyboardType(.asciiCapable)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
    }
}

// MARK: - CalculatorOperation

/// the ordered, identifiable operations shown in the segmented picker.
private enum CalculatorOperation: CaseIterable, Identifiable {
    case add, subtract, multiply, divide

    var id: Self {
        self
    }

    /// the engine operation this case maps to.
    var operation: ConversionEngine.Operation {
        switch self {
        case .add: .add
        case .subtract: .subtract
        case .multiply: .multiply
        case .divide: .divide
        }
    }

    /// the math glyph shown in the picker segment.
    var glyph: String {
        switch self {
        case .add: "+"
        case .subtract: "−"
        case .multiply: "×"
        case .divide: "÷"
        }
    }
}

#Preview {
    NavigationStack {
        CalculatorView()
    }
}
