//
//  BaseNumberRow.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

/// gives localized labels their full height and keeps the base editor usable
/// when the available width or Dynamic Type category changes.
struct BaseNumberRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let label: LocalizedStringKey
    let prompt: String
    @Binding var base: Int
    let fieldIdentifier: String
    let labelIdentifier: String

    var body: some View {
        layout {
            Text(label)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .accessibilityIdentifier(labelIdentifier)
            BaseNumberField(prompt: prompt, base: $base)
                .font(.body)
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier(fieldIdentifier)
                .frame(minWidth: 44, maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var layout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        } else {
            AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        }
    }
}
