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

/// keeps partially typed digits separate from the last valid base so entering
/// a two-digit base does not clamp its first digit before the second is typed.
struct BaseNumberField: View {
    let prompt: String
    @Binding var base: Int

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(prompt: String, base: Binding<Int>) {
        self.prompt = prompt
        _base = base
        _text = State(initialValue: String(base.wrappedValue))
    }

    var body: some View {
        TextField(text: bridge) {
            Text(verbatim: prompt)
        }
        .multilineTextAlignment(.trailing)
        .keyboardType(.numberPad)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if !focused {
                commit()
            }
        }
        .onChange(of: base) { _, newBase in
            if !isFocused {
                text = String(newBase)
            }
        }
    }

    /// empty text and an initial 1 remain editable without changing the base.
    private var bridge: Binding<String> {
        Binding(
            get: { text },
            set: { newText in
                text = newText.filter { $0.isASCII && $0.isNumber }
                if let parsed = Int(text), ConversionEngine.supportedBaseRange.contains(parsed) {
                    base = parsed
                }
            }
        )
    }

    private func commit() {
        if let parsed = Int(text) {
            let range = ConversionEngine.supportedBaseRange
            base = min(max(parsed, range.lowerBound), range.upperBound)
        }
        text = String(base)
    }
}
