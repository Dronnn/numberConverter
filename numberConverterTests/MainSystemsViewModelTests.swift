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
}
