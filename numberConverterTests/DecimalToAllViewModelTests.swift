//
//  DecimalToAllViewModelTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
@testable import numberConverter
import Testing

// MARK: - DecimalToAllViewModelTests

@MainActor
struct DecimalToAllViewModelTests {
    @Test
    func producesThirtyFiveRows() {
        let sut = DecimalToAllViewModel(number: "129")

        #expect(sut.rows.count == 35)
        #expect(sut.rows.first?.base == 2)
        #expect(sut.rows.last?.base == 36)
    }

    @Test
    func rowsHaveCorrectValuesAtSampledBases() {
        let sut = DecimalToAllViewModel(number: "129")

        #expect(value(in: sut, base: 2) == "10000001")
        #expect(value(in: sut, base: 8) == "201")
        #expect(value(in: sut, base: 16) == "81")
        #expect(value(in: sut, base: 36) == "3L")
    }

    @Test
    func recomputesOnInputChange() {
        let sut = DecimalToAllViewModel(number: "129")
        #expect(value(in: sut, base: 16) == "81")

        sut.number = "255"
        #expect(value(in: sut, base: 16) == "FF")
        #expect(value(in: sut, base: 2) == "11111111")
    }

    @Test
    func invalidInputYieldsNoRows() {
        let sut = DecimalToAllViewModel(number: "G")

        #expect(sut.rows.isEmpty)
    }

    // MARK: Helpers

    private func value(in sut: DecimalToAllViewModel, base: Int) -> String? {
        sut.rows.first { $0.base == base }?.value
    }
}
