//
//  DecimalToAllViewModel.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation

// MARK: - DecimalToAllViewModel

/// view model that renders a single decimal value into every supported base
/// (2...36, 35 rows). it recomputes whenever the input changes; invalid input
/// yields no rows.
@Observable
@MainActor
final class DecimalToAllViewModel {
    /// a row pairing a base with the value rendered in that base.
    struct Row: Identifiable, Equatable {
        let base: Int
        let value: String

        var id: Int {
            base
        }
    }

    var number: String {
        didSet { recompute() }
    }

    private(set) var rows: [Row] = []

    init(number: String = "") {
        self.number = number
        recompute()
    }

    // MARK: Recompute

    /// rebuilds the rows for the current decimal input; clears them when invalid.
    func recompute() {
        guard ConversionEngine.isValid(number, base: 10) else {
            rows = []
            return
        }

        rows = ConversionEngine.supportedBaseRange.compactMap { base in
            switch ConversionEngine.convert(number, fromBase: 10, toBase: base) {
            case let .success(value): Row(base: base, value: value)
            case .failure: nil
            }
        }
    }
}
