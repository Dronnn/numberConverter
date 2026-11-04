//
//  DecimalToAllView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - DecimalToAllView

/// read-only breakdown of one decimal value across every supported base (2...36).
struct DecimalToAllView: View {
    @State private var viewModel: DecimalToAllViewModel

    init(number: String) {
        _viewModel = State(wrappedValue: DecimalToAllViewModel(number: number))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.rows) { row in
                    BaseValueRow(base: row.base, value: row.value)
                }
            } header: {
                Text("decimalToAll.header")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle(Text("nav.allSystems"))
        .appHelpToolbar()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppLogger.converter.screen("decimalToAll") }
    }
}

// MARK: - BaseValueRow

/// a single row pairing the rendered value with its base.
private struct BaseValueRow: View {
    let base: Int
    let value: String

    var body: some View {
        LabeledContent {
            Text(verbatim: "\(base)")
                .font(.body)
                .foregroundStyle(Color.primary)
                .accessibilityIdentifier("base.label.\(base)")
        } label: {
            Text(verbatim: value)
                .font(.body)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier("base.value.\(base)")
        }
    }
}

#Preview {
    NavigationStack {
        DecimalToAllView(number: "129")
    }
}
