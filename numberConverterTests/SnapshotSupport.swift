//
//  SnapshotSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import numberConverter
import SnapshotTesting
import SwiftUI

// MARK: - SnapshotDevice

/// the two device presets the matrix renders on: a modern iPhone and an iPad.
/// names feed the snapshot file suffix (`-iphone` / `-ipad`).
enum SnapshotDevice: String, CaseIterable {
    case iphone
    case ipad

    /// the `swift-snapshot-testing` layout preset for this device.
    var config: ViewImageConfig {
        switch self {
        case .iphone: .iPhone13
        case .ipad: .iPadMini
        }
    }
}

// MARK: - SnapshotAppearance

/// light / dark appearance, contributing the `-light` / `-dark` file suffix.
enum SnapshotAppearance: String, CaseIterable {
    case light
    case dark

    var style: UIUserInterfaceStyle {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - SnapshotLocale

/// the two locales the matrix renders in. `en` intentionally renders the
/// localization keys for now (the English catalog is empty by design).
enum SnapshotLocale: String, CaseIterable {
    case ru
    case en
}

// MARK: - Matrix helpers

/// the percentage a pixel must match the reference to count as equal. kept
/// below 1.0 so anti-aliasing and sub-pixel text differences are absorbed.
let snapshotPerceptualPrecision: Float = 0.96

// MARK: - MatrixCell

/// one cell of the snapshot matrix: a locale, an appearance and a device.
/// bundled so callers forward a single value instead of three arguments.
struct MatrixCell {
    let locale: SnapshotLocale
    let appearance: SnapshotAppearance
    let device: SnapshotDevice

    /// the file-name suffix this cell contributes: `-<locale>-<light|dark>-<iphone|ipad>`.
    var suffix: String {
        "\(locale.rawValue)-\(appearance.rawValue)-\(device.rawValue)"
    }
}

/// hosts `view` in a `NavigationStack`, applies the environment objects, locale
/// and appearance, and asserts an image snapshot named `<name>-<cell.suffix>`.
@MainActor
func assertScreen(
    _ view: some View,
    named name: String,
    cell: MatrixCell,
    dynamicTypeSize: DynamicTypeSize = .large,
    twosComplement: Bool = false,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    let settings = AppSettings(defaults: isolatedDefaults())
    settings.twosComplement = twosComplement

    let root = NavigationStack { view }
        .environment(settings)
        .environment(AppNavigationState())
        .environment(QuickActionRouter.shared)
        .environment(\.locale, Locale(identifier: cell.locale.rawValue))
        .environment(\.dynamicTypeSize, dynamicTypeSize)

    let host = UIHostingController(rootView: root)

    assertSnapshot(
        of: host,
        as: .image(
            on: cell.device.config,
            perceptualPrecision: snapshotPerceptualPrecision,
            traits: UITraitCollection(userInterfaceStyle: cell.appearance.style)
        ),
        named: "\(name)-\(cell.suffix)",
        file: file,
        testName: testName,
        line: line
    )
}

/// runs `body` for every (locale, appearance, device) cell of the full matrix.
@MainActor
func forEachMatrixCell(_ body: (MatrixCell) -> Void) {
    for locale in SnapshotLocale.allCases {
        for appearance in SnapshotAppearance.allCases {
            for device in SnapshotDevice.allCases {
                body(MatrixCell(locale: locale, appearance: appearance, device: device))
            }
        }
    }
}

/// a fresh, isolated UserDefaults suite so snapshots never read or write the
/// real defaults. each call gets a unique, empty domain.
func isolatedDefaults() -> UserDefaults {
    let suiteName = "snapshot.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
