//
//  BaseNumberField.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import SwiftUI

// MARK: - BaseNumberField

/// a numeric text field that edits an `Int` base via a string bridge. it accepts
/// digits only and clamps the parsed value to the engine's supported range, so
/// the bound base is always valid.
struct BaseNumberField: View {
    let prompt: String
    @Binding var base: Int

    var body: some View {
        TextField(text: bridge) {
            Text(verbatim: prompt)
        }
        .multilineTextAlignment(.trailing)
        .keyboardType(.numberPad)
    }

    /// bridges the `Int` base to editable text, parsing and clamping on write.
    private var bridge: Binding<String> {
        Binding(
            get: { String(base) },
            set: { newText in
                let digits = newText.filter(\.isNumber)
                guard let parsed = Int(digits) else { return }
                let range = ConversionEngine.supportedBaseRange
                base = min(max(parsed, range.lowerBound), range.upperBound)
            }
        )
    }
}
