//
//  ConversionEngine.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - ConversionEngine

/// pure, dependency-free numeral-system conversion core (bases 2...36).
/// the full api is implemented test-first in phase 1; this is the phase-0 scaffold
/// that lets the app link the package and proves the wiring.
public enum ConversionEngine {
    /// the inclusive range of numeral-system bases the engine supports.
    public static let supportedBaseRange = 2...36
}
