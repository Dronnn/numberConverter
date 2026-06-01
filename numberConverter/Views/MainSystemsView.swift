//
//  MainSystemsView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - MainSystemsView

/// read-only breakdown of one seeded value across the four main numeral systems.
struct MainSystemsView: View {
    @State private var viewModel: MainSystemsViewModel

    init(base: Int, number: String) {
        let twosComplement = UserDefaults.standard.bool(forKey: AppSettings.twosComplementKey)
        _viewModel = State(
            wrappedValue: MainSystemsViewModel(
                base: base,
                number: number,
                twosComplement: twosComplement
            )
        )
    }

    var body: some View {
        Form {
            ValueRow(header: "mainSystems.header.binary", value: viewModel.binary)
            ValueRow(header: "mainSystems.header.octal", value: viewModel.octal)
            ValueRow(header: "mainSystems.header.decimal", value: viewModel.decimal)
            ValueRow(header: "mainSystems.header.hexadecimal", value: viewModel.hexadecimal)
        }
        .navigationTitle(Text("nav.mainSystems"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ValueRow

/// a single read-only section: a header and the value, trailing-aligned.
private struct ValueRow: View {
    let header: LocalizedStringResource
    let value: String

    var body: some View {
        Section {
            Text(verbatim: value)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textSelection(.enabled)
        } header: {
            Text(header)
        }
    }
}

#Preview {
    NavigationStack {
        MainSystemsView(base: 10, number: "255")
            .environment(AppSettings())
    }
}
