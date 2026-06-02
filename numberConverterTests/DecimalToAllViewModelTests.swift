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

    @Test
    func everyBaseAppearsExactlyOnce() {
        let sut = DecimalToAllViewModel(number: "129")

        let bases = sut.rows.map(\.base)
        #expect(bases == Array(2 ... 36))
        #expect(Set(bases).count == bases.count)
    }

    @Test
    func fractionalInputRendersEveryBase() {
        let sut = DecimalToAllViewModel(number: "0.5")

        // every base still produces a row for a valid fraction.
        #expect(sut.rows.count == 35)
        #expect(value(in: sut, base: 2) == "0.1") // 0.5 * 2 = 1.0
        #expect(value(in: sut, base: 4) == "0.2") // 0.5 * 4 = 2.0
        #expect(value(in: sut, base: 16) == "0.8") // 0.5 * 16 = 8.0
    }

    @Test
    func negativeInputRendersSignedRows() {
        // decimal-to-all does not apply two's complement, so negatives stay signed.
        let sut = DecimalToAllViewModel(number: "-10")

        #expect(sut.rows.count == 35)
        #expect(value(in: sut, base: 2) == "-1010")
        #expect(value(in: sut, base: 8) == "-12")
        #expect(value(in: sut, base: 16) == "-A")
    }

    @Test
    func zeroRendersZeroInEveryBase() {
        let sut = DecimalToAllViewModel(number: "0")

        #expect(sut.rows.count == 35)
        #expect(sut.rows.allSatisfy { $0.value == "0" })
    }

    @Test
    func emptyInputRendersZeroInEveryBase() {
        // empty input is valid (normalizes to zero), so every base renders "0".
        let sut = DecimalToAllViewModel(number: "")

        #expect(sut.rows.count == 35)
        #expect(sut.rows.allSatisfy { $0.value == "0" })
    }

    @Test
    func recoversAfterInvalidInput() {
        let sut = DecimalToAllViewModel(number: "G")
        #expect(sut.rows.isEmpty)

        // a valid value rebuilds the full set of rows.
        sut.number = "255"
        #expect(sut.rows.count == 35)
        #expect(value(in: sut, base: 16) == "FF")
        #expect(value(in: sut, base: 2) == "11111111")
    }

    // MARK: Helpers

    private func value(in sut: DecimalToAllViewModel, base: Int) -> String? {
        sut.rows.first { $0.base == base }?.value
    }
}
