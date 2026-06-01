//
//  BaseFieldRow.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

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
    let isInvalid: Bool
    let onDetail: () -> Void

    var body: some View {
        LabeledContent {
            HStack {
                TextField(text: $text) {
                    Text(verbatim: field.placeholder)
                }
                .multilineTextAlignment(.trailing)
                .foregroundStyle(isInvalid ? Color.red : Color.primary)
                .keyboardType(field.keyboardType)
                .textInputAutocapitalization(field.autocapitalization)
                .autocorrectionDisabled()

                DetailButton(action: onDetail)
            }
        } label: {
            Text(verbatim: field.labelText)
        }
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
                TextField(text: $text) {
                    Text(verbatim: "129")
                }
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()

                DetailButton(action: onDetail)
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
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("converter.detail.accessibility"))
    }
}
