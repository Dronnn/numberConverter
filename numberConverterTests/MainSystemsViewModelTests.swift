//
//  MainSystemsViewModelTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
@testable import numberConverter
import Testing

// MARK: - MainSystemsViewModelTests

@MainActor
struct MainSystemsViewModelTests {
    @Test
    func seedsAllSystemsFromDecimal() {
        let sut = MainSystemsViewModel(base: 10, number: "255", twosComplement: false)

        #expect(sut.binary == "11111111")
        #expect(sut.octal == "377")
        #expect(sut.decimal == "255")
        #expect(sut.hexadecimal == "FF")
    }

    @Test
    func seedsFromHexSource() {
        let sut = MainSystemsViewModel(base: 16, number: "FF", twosComplement: false)

        #expect(sut.binary == "11111111")
        #expect(sut.octal == "377")
        #expect(sut.decimal == "255")
        #expect(sut.hexadecimal == "FF")
    }

    @Test
    func twosComplementAffectsBinaryOnly() {
        let sut = MainSystemsViewModel(base: 10, number: "-1", twosComplement: true)

        #expect(sut.binary == "11111111")
        #expect(sut.decimal == "-1")
    }

    @Test
    func twosComplementOffShowsSignedBinary() {
        let sut = MainSystemsViewModel(base: 10, number: "-1", twosComplement: false)

        #expect(sut.binary == "-1")
        #expect(sut.decimal == "-1")
    }

    @Test
    func seedsFromBinarySource() {
        // 1010 binary == 10 decimal == 12 octal == A hex.
        let sut = MainSystemsViewModel(base: 2, number: "1010", twosComplement: false)

        #expect(sut.binary == "1010")
        #expect(sut.octal == "12")
        #expect(sut.decimal == "10")
        #expect(sut.hexadecimal == "A")
    }

    @Test
    func seedsFromOctalSource() {
        // 17 octal == 15 decimal == 1111 binary == F hex.
        let sut = MainSystemsViewModel(base: 8, number: "17", twosComplement: false)

        #expect(sut.binary == "1111")
        #expect(sut.octal == "17")
        #expect(sut.decimal == "15")
        #expect(sut.hexadecimal == "F")
    }

    @Test
    func twosComplementNegativePinsNonBinaryFields() {
        // only the binary field uses two's complement; octal/decimal/hex stay
        // signed. -5 == 11111011 (8-bit TC) and -5/-5/-5 elsewhere.
        let sut = MainSystemsViewModel(base: 10, number: "-5", twosComplement: true)

        #expect(sut.binary == "11111011")
        #expect(sut.octal == "-5")
        #expect(sut.decimal == "-5")
        #expect(sut.hexadecimal == "-5")
    }

    @Test
    func binaryTwosComplementSeedPreservesSignedValueInEverySystem() {
        let sut = MainSystemsViewModel(base: 2, number: "11111011", twosComplement: true)

        #expect(sut.binary == "11111011")
        #expect(sut.octal == "-5")
        #expect(sut.decimal == "-5")
        #expect(sut.hexadecimal == "-5")
    }

    @Test
    func invalidSeedHasNoRenderedValues() {
        let sut = MainSystemsViewModel(base: 2, number: "2", twosComplement: true)

        #expect(sut.binary.isEmpty)
        #expect(sut.octal.isEmpty)
        #expect(sut.decimal.isEmpty)
        #expect(sut.hexadecimal.isEmpty)
    }
}
