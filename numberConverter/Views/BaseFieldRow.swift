//
//  BaseFieldRow.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import SwiftUI

// MARK: - BaseField + presentation

extension BaseField {
    /// the fixed label shown in front of the field (same across languages).
    var labelText: String {
        switch self {
        case .binary: "Bin (2)"
        case .octal: "Oct (8)"
        case .decimal: "Dec (10)"
        case .hexadecimal: "Hex (16)"
        }
    }

    /// an example number used as the field's placeholder (verbatim, not localized).
    var placeholder: String {
        switch self {
        case .binary: "101"
        case .octal: "471"
        case .decimal: "249"
        case .hexadecimal: "2F4"
        }
    }

    /// the keyboard best suited to this base's digit alphabet.
    var keyboardType: UIKeyboardType {
        switch self {
        case .binary, .hexadecimal: .asciiCapable
        case .octal, .decimal: .numbersAndPunctuation
        }
    }

    /// hex and binary may contain letters, so capitalize for the a-f range;
    /// the engine is case-insensitive, so lowercase input still converts.
    var autocapitalization: TextInputAutocapitalization {
        switch self {
        case .binary, .hexadecimal: .characters
        case .octal, .decimal: .never
        }
    }
}

// MARK: - BaseFieldRow

/// a single row of the main-systems section: a fixed label, an editable value,
/// and a trailing detail button that pushes the per-field breakdown.
struct BaseFieldRow: View {
    let field: BaseField
    @Binding var text: String
    let error: ConversionError?
    let onDetail: () -> Void

    private var isInvalid: Bool {
        error != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent {
                HStack {
                    TextField(text: $text, axis: .vertical) {
                        Text(verbatim: field.placeholder)
                    }
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(isInvalid ? Color("ValidationError") : Color.primary)
                    .keyboardType(field.keyboardType)
                    .textInputAutocapitalization(field.autocapitalization)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("converter.input.\(field.base)")

                    DetailButton(action: onDetail)
                        .accessibilityIdentifier("converter.detail.\(field.base)")
                        .disabled(isInvalid)
                }
            } label: {
                Text(verbatim: field.labelText)
            }
            if let error {
                validationMessage(error)
                    .font(.callout)
                    .foregroundStyle(Color("ValidationError"))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("converter.error.\(field.base)")
            }
        }
    }

    private func validationMessage(_ error: ConversionError) -> Text {
        if error == .invalidCharacter {
            let digits = String("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".prefix(field.base))
            return Text("input.invalidForBase \(field.base) \(digits)")
        }
        return Text(error.localizedTextKey)
    }
}

// MARK: - DecimalRangeRow

/// the all-bases shortcut row: a decimal input plus a detail button that pushes
/// the full 2...36 breakdown.
struct DecimalRangeRow: View {
    @Binding var text: String
    let onDetail: () -> Void

    var body: some View {
        LabeledContent {
            HStack {
                TextField(text: $text, axis: .vertical) {
                    Text(verbatim: "129")
                }
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .accessibilityIdentifier("converter.all.input")

                DetailButton(action: onDetail)
                    .accessibilityIdentifier("converter.all.detail")
                    .disabled(ConversionEngine.toDecimal(text, fromBase: 10) == nil)
            }
        } label: {
            Text("converter.field.decimalInput")
        }
    }
}

// MARK: - DetailButton

/// the trailing info button that opens a detail screen for a row.
private struct DetailButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.accentColor)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("converter.detail.accessibility"))
    }
}
