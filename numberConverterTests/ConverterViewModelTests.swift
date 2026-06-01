//
//  ConverterViewModelTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
@testable import numberConverter
import Testing

// MARK: - ConverterViewModelTests

@MainActor
struct ConverterViewModelTests {
    @Test
    func editingDecimalUpdatesOtherFields() {
        let sut = ConverterViewModel()

        sut.userEdited(.decimal, "255")

        #expect(sut.decimal == "255")
        #expect(sut.binary == "11111111")
        #expect(sut.octal == "377")
        #expect(sut.hexadecimal == "FF")
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func editingHexUpdatesOtherFields() {
        let sut = ConverterViewModel()

        sut.userEdited(.hexadecimal, "FF")

        #expect(sut.hexadecimal == "FF")
        #expect(sut.decimal == "255")
        #expect(sut.binary == "11111111")
        #expect(sut.octal == "377")
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func invalidBinaryFlagsFieldAndLeavesOthersUntouched() {
        let sut = ConverterViewModel()
        sut.userEdited(.decimal, "255")

        sut.userEdited(.binary, "FF")

        #expect(sut.invalidFields.contains(.binary))
        #expect(sut.binary == "FF")
        // other fields keep their previous valid values.
        #expect(sut.decimal == "255")
        #expect(sut.octal == "377")
        #expect(sut.hexadecimal == "FF")
    }

    @Test
    func invalidHexFlagsField() {
        let sut = ConverterViewModel()

        sut.userEdited(.hexadecimal, "G")

        #expect(sut.invalidFields.contains(.hexadecimal))
        #expect(sut.hexadecimal == "G")
    }

    @Test
    func twosComplementOnRendersNegativeBinary() {
        let sut = ConverterViewModel(twosComplement: true)

        sut.userEdited(.decimal, "-1")

        #expect(sut.binary == "11111111")
        #expect(sut.decimal == "-1")
    }

    @Test
    func twosComplementOffRendersSignedBinary() {
        let sut = ConverterViewModel(twosComplement: false)

        sut.userEdited(.decimal, "-1")

        #expect(sut.binary == "-1")
    }

    @Test
    func togglingTwosComplementRecomputesBinary() {
        let sut = ConverterViewModel(twosComplement: false)
        sut.userEdited(.decimal, "-1")
        #expect(sut.binary == "-1")

        sut.twosComplement = true
        #expect(sut.binary == "11111111")

        sut.twosComplement = false
        #expect(sut.binary == "-1")
    }

    @Test
    func emptyInputClearsAllFields() {
        let sut = ConverterViewModel()
        sut.userEdited(.decimal, "255")

        sut.userEdited(.decimal, "")

        #expect(sut.binary.isEmpty)
        #expect(sut.octal.isEmpty)
        #expect(sut.decimal.isEmpty)
        #expect(sut.hexadecimal.isEmpty)
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func seedAccessorsReflectCurrentState() {
        let sut = ConverterViewModel()
        sut.userEdited(.decimal, "255")

        let hexSeed = sut.seed(for: .hexadecimal)
        #expect(hexSeed.base == 16)
        #expect(hexSeed.number == "FF")
        #expect(sut.decimalSeed == "255")
    }
}
