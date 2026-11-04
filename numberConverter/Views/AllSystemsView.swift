//
//  AllSystemsView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - AllSystemsView

/// root screen of the all-systems tab: convert one number between any two bases.
struct AllSystemsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var viewModel = AllSystemsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section {
                LabeledContent {
                    TextField(text: $viewModel.number, axis: .vertical) {
                        Text(verbatim: "1023")
                    }
                    .lineLimit(nil)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("allSystems.number")
                } label: {
                    Text("allSystems.field.number")
                }

                LabeledContent {
                    BaseNumberField(prompt: "6", base: $viewModel.sourceBase)
                        .accessibilityIdentifier("allSystems.sourceBase")
                } label: {
                    Text("allSystems.field.fromBase")
                }

                LabeledContent {
                    BaseNumberField(prompt: "9", base: $viewModel.targetBase)
                        .accessibilityIdentifier("allSystems.targetBase")
                } label: {
                    Text("allSystems.field.toBase")
                }

                Button {
                    viewModel.convert()
                } label: {
                    Text("allSystems.button.convert")
                }
                .accessibilityIdentifier("allSystems.convert")

                ResultRow(
                    label: "allSystems.field.result",
                    prompt: "276",
                    result: viewModel.result,
                    error: viewModel.error,
                    accessibilityPrefix: "allSystems"
                )
            } header: {
                Text("allSystems.section.title")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle(Text("nav.allSystems"))
        .appHelpToolbar()
        .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDismissal()
        .onAppear { AppLogger.allSystems.screen("allSystems") }
    }
}

#Preview {
    NavigationStack {
        AllSystemsView()
    }
}
