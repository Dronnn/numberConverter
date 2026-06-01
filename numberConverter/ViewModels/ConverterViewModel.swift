//
//  ConverterViewModel.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation

// MARK: - BaseField

/// the four numeral systems the main converter syncs between.
enum BaseField: CaseIterable {
    case binary, octal, decimal, hexadecimal

    /// the numeric base for this field.
    var base: Int {
        switch self {
        case .binary: 2
        case .octal: 8
        case .decimal: 10
        case .hexadecimal: 16
        }
    }
}

// MARK: - ConverterViewModel

/// view model for the main converter: four base fields that stay in sync.
///
/// only ``userEdited(_:_:)`` performs conversion and writes into the other
/// fields. the view binds each text field with a getter that returns the stored
/// value and a setter that calls ``userEdited(_:_:)``. programmatic writes go
/// straight to the stored properties, so they never trigger another conversion,
/// which prevents an infinite update loop.
@Observable
@MainActor
final class ConverterViewModel {
    // MARK: Fields

    private(set) var binary = ""
    private(set) var octal = ""
    private(set) var decimal = ""
    private(set) var hexadecimal = ""

    /// fields whose current text is invalid for their base.
    private(set) var invalidFields: Set<BaseField> = []

    /// whether the binary field renders negative integers in two's complement.
    /// the view sets this from `AppSettings`.
    var twosComplement: Bool {
        didSet {
            guard twosComplement != oldValue else { return }
            recomputeForTwosComplementChange()
        }
    }

    init(twosComplement: Bool = false) {
        self.twosComplement = twosComplement
    }

    // MARK: Editing

    /// handles a user edit of one field: stores the text, validates it, and on
    /// success writes the converted value into the other three fields.
    func userEdited(_ field: BaseField, _ text: String) {
        store(text, in: field)

        if text.isEmpty {
            // empty input clears every field consistently.
            clearAll()
            invalidFields.remove(field)
            return
        }

        guard ConversionEngine.isValid(text, base: field.base) else {
            invalidFields.insert(field)
            return
        }
        invalidFields.remove(field)

        for other in BaseField.allCases where other != field {
            let converted = ConversionEngine.convert(
                text,
                fromBase: field.base,
                toBase: other.base,
                twosComplement: twosComplement
            )
            switch converted {
            case let .success(value):
                store(value, in: other)
                invalidFields.remove(other)
            case .failure:
                invalidFields.insert(other)
            }
        }
    }

    // MARK: Navigation seeds

    /// the (base, current text) pair for a field, used to push the main-systems screen.
    func seed(for field: BaseField) -> (base: Int, number: String) {
        (field.base, value(of: field))
    }

    /// the current decimal-field text, used to push the decimal-to-all screen.
    var decimalSeed: String {
        decimal
    }

    // MARK: Private

    /// recomputes all fields from the current decimal value when the toggle flips,
    /// so the binary rendering reflects the new two's-complement setting.
    private func recomputeForTwosComplementChange() {
        guard !decimal.isEmpty, ConversionEngine.isValid(decimal, base: BaseField.decimal.base) else {
            return
        }
        userEdited(.decimal, decimal)
    }

    private func store(_ text: String, in field: BaseField) {
        switch field {
        case .binary: binary = text
        case .octal: octal = text
        case .decimal: decimal = text
        case .hexadecimal: hexadecimal = text
        }
    }

    private func value(of field: BaseField) -> String {
        switch field {
        case .binary: binary
        case .octal: octal
        case .decimal: decimal
        case .hexadecimal: hexadecimal
        }
    }

    private func clearAll() {
        binary = ""
        octal = ""
        decimal = ""
        hexadecimal = ""
    }
}
