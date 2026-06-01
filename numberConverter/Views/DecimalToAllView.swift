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
            }
        }
        .navigationTitle(Text("nav.allSystems"))
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
                .foregroundStyle(.secondary)
        } label: {
            Text(verbatim: value)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    NavigationStack {
        DecimalToAllView(number: "129")
    }
}
