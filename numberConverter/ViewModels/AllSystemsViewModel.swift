//
//  AllSystemsViewModel.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation

// MARK: - AllSystemsViewModel

/// view model for converting a single number from one arbitrary base to another.
/// it recomputes whenever the input, source base or target base changes.
@Observable
@MainActor
final class AllSystemsViewModel {
    var number: String {
        didSet { convert() }
    }

    var sourceBase: Int {
        didSet { convert() }
    }

    var targetBase: Int {
        didSet { convert() }
    }

    private(set) var result = ""
    private(set) var error: ConversionError?

    init(number: String = "", sourceBase: Int = 10, targetBase: Int = 2) {
        self.number = number
        self.sourceBase = sourceBase
        self.targetBase = targetBase
        convert()
    }

    // MARK: Convert

    /// validates the input and bases, then sets `result` or `error`.
    func convert() {
        switch ConversionEngine.convert(number, fromBase: sourceBase, toBase: targetBase) {
        case let .success(value):
            result = value
            error = nil
        case let .failure(conversionError):
            result = ""
            error = conversionError
        }
    }
}
