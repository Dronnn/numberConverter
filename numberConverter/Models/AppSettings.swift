//
//  AppSettings.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - AppSettings

/// shared, observable user settings injected via the environment.
/// `twosComplement` is persisted in `UserDefaults` under the legacy key
/// `"twosComplement"` so behavior matches the original app. screens that
/// only need the toggle may use `@AppStorage(AppSettings.twosComplementKey)`
/// directly; this type exists for the shared, observable case.
@Observable
@MainActor
final class AppSettings {
    /// legacy persistence key carried over from the objective-c app.
    static let twosComplementKey = "twosComplement"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// whether negative values are shown in two's-complement form.
    var twosComplement: Bool {
        get {
            access(keyPath: \.twosComplement)
            return defaults.bool(forKey: Self.twosComplementKey)
        }
        set {
            withMutation(keyPath: \.twosComplement) {
                defaults.set(newValue, forKey: Self.twosComplementKey)
            }
        }
    }
}
