//
//  MainSystemsViewModel.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation

// MARK: - MainSystemsViewModel

/// read-only view model seeded with a `(base, number)` pair. it renders that
/// value into binary, octal, decimal and hexadecimal once at init. the binary
/// field respects the two's-complement setting.
@Observable
@MainActor
final class MainSystemsViewModel {
    private(set) var binary = ""
    private(set) var octal = ""
    private(set) var decimal = ""
    private(set) var hexadecimal = ""

    init(base: Int, number: String, twosComplement: Bool) {
        binary = rendered(number, fromBase: base, toBase: 2, twosComplement: twosComplement)
        octal = rendered(number, fromBase: base, toBase: 8, twosComplement: false)
        decimal = rendered(number, fromBase: base, toBase: 10, twosComplement: false)
        hexadecimal = rendered(number, fromBase: base, toBase: 16, twosComplement: false)
    }

    // MARK: Private

    /// converts the seed value to a target base, returning an empty string when
    /// the input cannot be converted.
    private func rendered(
        _ number: String,
        fromBase: Int,
        toBase: Int,
        twosComplement: Bool
    ) -> String {
        switch ConversionEngine.convert(number, fromBase: fromBase, toBase: toBase, twosComplement: twosComplement) {
        case let .success(value): value
        case .failure: ""
        }
    }
}
