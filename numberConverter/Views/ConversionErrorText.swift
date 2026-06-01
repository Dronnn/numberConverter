//
//  ConversionErrorText.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import SwiftUI

// MARK: - ConversionError + LocalizedStringResource

extension ConversionError {
    /// the localized message shown in a result field when a conversion fails.
    var localizedTextKey: LocalizedStringResource {
        switch self {
        case .invalidCharacter: "error.invalidCharacter"
        case .baseOutOfRange: "error.baseOutOfRange"
        case .divisionByZero: "error.divisionByZero"
        }
    }
}
