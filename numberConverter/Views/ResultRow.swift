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
    let accessibilityPrefix: String

    var body: some View {
        LabeledContent {
            content
                .font(.body)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            Text(label)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(accessibilityPrefix).resultLabel")
        }
    }

    @ViewBuilder private var content: some View {
        if let error {
            Text(error.localizedTextKey)
                .foregroundStyle(Color("ValidationError"))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(accessibilityPrefix).error")
        } else if result.isEmpty {
            Text(verbatim: prompt)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(accessibilityPrefix).result")
        } else {
            Text(verbatim: result)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(accessibilityPrefix).result")
        }
    }
}
