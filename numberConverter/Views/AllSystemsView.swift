//
//  AllSystemsView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - AllSystemsView

/// root screen of the all-systems tab: convert one number between any two bases.
struct AllSystemsView: View {
    @State private var viewModel = AllSystemsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section {
                LabeledContent {
                    TextField(text: $viewModel.number) {
                        Text(verbatim: "1023")
                    }
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                } label: {
                    Text("allSystems.field.number")
                }

                LabeledContent {
                    BaseNumberField(prompt: "6", base: $viewModel.sourceBase)
                } label: {
                    Text("allSystems.field.fromBase")
                }

                LabeledContent {
                    BaseNumberField(prompt: "9", base: $viewModel.targetBase)
                } label: {
                    Text("allSystems.field.toBase")
                }

                Button {
                    viewModel.convert()
                } label: {
                    Text("allSystems.button.convert")
                }

                ResultRow(
                    label: "allSystems.field.result",
                    prompt: "276",
                    result: viewModel.result,
                    error: viewModel.error
                )
            } header: {
                Text("allSystems.section.title")
            }
        }
        .navigationTitle(Text("nav.allSystems"))
    }
}

#Preview {
    NavigationStack {
        AllSystemsView()
    }
}
