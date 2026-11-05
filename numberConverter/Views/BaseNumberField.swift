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
        TextField(text: $text) {
            Text(verbatim: prompt)
        }
        .multilineTextAlignment(.trailing)
        .keyboardType(.numberPad)
        .focused($isFocused)
        .onChange(of: text) { _, newText in
            // normalize after accepting the native edit so a repeated invalid
            // paste still changes state and redraws the corrected text.
            let digits = newText.filter { $0.isASCII && $0.isNumber }
            if text != digits {
                text = digits
            }
            if let parsed = Int(digits), ConversionEngine.supportedBaseRange.contains(parsed) {
                base = parsed
            }
        }
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

    private func commit() {
        if let parsed = Int(text) {
            let range = ConversionEngine.supportedBaseRange
            base = min(max(parsed, range.lowerBound), range.upperBound)
        }
        text = String(base)
    }
}
