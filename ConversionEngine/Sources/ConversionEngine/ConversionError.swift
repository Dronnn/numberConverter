//
//  ConversionError.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

// MARK: - ConversionError

/// typed, language-neutral engine errors. the app localizes these; the engine
/// never returns localized strings.
public enum ConversionError: Error, Equatable, Sendable {
    /// the input contains a character illegal for its base, or is otherwise
    /// malformed (e.g. more than one decimal point).
    case invalidCharacter

    /// a supplied base is outside `2...36`.
    case baseOutOfRange

    /// a division by zero was requested.
    case divisionByZero
}
