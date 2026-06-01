//
//  ConverterView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - ConverterDestination

/// the detail screens pushed from the converter root.
enum ConverterDestination: Hashable {
    case mainSystems(base: Int, number: String)
    case decimalToAll(number: String)
}

// MARK: - ConverterView

/// root screen of the converter tab: four base fields that stay in sync, an
/// all-bases shortcut, and the two's-complement toggle.
struct ConverterView: View {
    @Environment(AppSettings.self) private var settings

    @State private var viewModel: ConverterViewModel
    @State private var decimalInput = ""
    @State private var destination: ConverterDestination?

    init(viewModel: ConverterViewModel = ConverterViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var settings = settings

        Form {
            MainSystemsSection(viewModel: viewModel, destination: $destination)
            AllRangeSection(decimalInput: $decimalInput, destination: $destination)
            SettingsSection(twosComplement: $settings.twosComplement)
        }
        .navigationTitle(Text("nav.converter"))
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case let .mainSystems(base, number):
                MainSystemsView(base: base, number: number)
            case let .decimalToAll(number):
                DecimalToAllView(number: number)
            }
        }
        .onChange(of: settings.twosComplement) { _, newValue in
            viewModel.twosComplement = newValue
            AppLogger.converter.info("twos-complement toggled \(newValue, privacy: .public)")
        }
        .onAppear {
            viewModel.twosComplement = settings.twosComplement
            AppLogger.converter.screen("converter")
        }
    }
}

// MARK: - MainSystemsSection

/// the four cross-synced base fields, each with a push-to-detail button.
private struct MainSystemsSection: View {
    let viewModel: ConverterViewModel
    @Binding var destination: ConverterDestination?

    var body: some View {
        Section {
            ForEach(BaseField.allCases, id: \.self) { field in
                BaseFieldRow(
                    field: field,
                    text: binding(for: field),
                    isInvalid: viewModel.invalidFields.contains(field)
                ) {
                    let seed = viewModel.seed(for: field)
                    destination = .mainSystems(base: seed.base, number: seed.number)
                }
            }
        } header: {
            Text("converter.section.mainSystems")
        }
    }

    /// a binding whose setter routes through `userEdited` so only user edits
    /// trigger a cross-field conversion (programmatic writes never loop).
    private func binding(for field: BaseField) -> Binding<String> {
        Binding(
            get: { value(for: field) },
            set: { viewModel.userEdited(field, $0) }
        )
    }

    /// the view model's current stored text for a field.
    private func value(for field: BaseField) -> String {
        switch field {
        case .binary: viewModel.binary
        case .octal: viewModel.octal
        case .decimal: viewModel.decimal
        case .hexadecimal: viewModel.hexadecimal
        }
    }
}

// MARK: - AllRangeSection

/// the all-bases shortcut: a decimal input plus a push-to-detail button.
private struct AllRangeSection: View {
    @Binding var decimalInput: String
    @Binding var destination: ConverterDestination?

    var body: some View {
        Section {
            DecimalRangeRow(text: $decimalInput) {
                destination = .decimalToAll(number: decimalInput)
            }
        } header: {
            Text("converter.section.allRange")
        }
    }
}

// MARK: - SettingsSection

/// the two's-complement toggle, bound to the shared settings.
private struct SettingsSection: View {
    @Binding var twosComplement: Bool

    var body: some View {
        Section {
            Toggle(isOn: $twosComplement) {
                Text("converter.toggle.twosComplement")
            }
        } header: {
            Text("converter.section.settings")
        }
    }
}

#Preview {
    NavigationStack {
        ConverterView()
            .environment(AppSettings())
    }
}
