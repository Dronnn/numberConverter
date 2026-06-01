//
//  ResultRow.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import SwiftUI

// MARK: - ResultRow

/// a read-only result field. it shows the rendered value, or the localized
/// error in red when the last conversion failed.
struct ResultRow: View {
    let label: LocalizedStringResource
    let prompt: String
    let result: String
    let error: ConversionError?

    var body: some View {
        LabeledContent {
            content
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            Text(label)
        }
    }

    @ViewBuilder private var content: some View {
        if let error {
            Text(error.localizedTextKey)
                .foregroundStyle(.red)
        } else if result.isEmpty {
            Text(verbatim: prompt)
                .foregroundStyle(.secondary)
        } else {
            Text(verbatim: result)
        }
    }
}
