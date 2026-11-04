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

    @Test
    func editingBinaryUpdatesOtherFields() {
        let sut = ConverterViewModel()

        // 11111111 binary == 255 decimal == 377 octal == FF hex.
        sut.userEdited(.binary, "11111111")

        #expect(sut.binary == "11111111")
        #expect(sut.decimal == "255")
        #expect(sut.octal == "377")
        #expect(sut.hexadecimal == "FF")
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func editingOctalUpdatesOtherFields() {
        let sut = ConverterViewModel()

        // 377 octal == 255 decimal == 11111111 binary == FF hex.
        sut.userEdited(.octal, "377")

        #expect(sut.octal == "377")
        #expect(sut.decimal == "255")
        #expect(sut.binary == "11111111")
        #expect(sut.hexadecimal == "FF")
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func fractionSyncsAcrossFields() {
        let sut = ConverterViewModel()

        // 0.5 decimal == 0.1 binary (0.5 * 2 = 1.0) == 0.8 hex (0.5 * 16 = 8.0).
        sut.userEdited(.decimal, "0.5")

        #expect(sut.decimal == "0.5")
        #expect(sut.binary == "0.1")
        #expect(sut.hexadecimal == "0.8")
        #expect(sut.octal == "0.4") // 0.5 * 8 = 4.0
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func invalidThenValidRecoversAllFields() {
        let sut = ConverterViewModel()
        sut.userEdited(.decimal, "255")

        // a bad binary digit flags only the binary field.
        sut.userEdited(.binary, "2")
        #expect(sut.invalidFields.contains(.binary))

        // a subsequent good value recovers every field and clears the flag.
        sut.userEdited(.binary, "1010")
        #expect(sut.invalidFields.isEmpty)
        #expect(sut.binary == "1010")
        #expect(sut.decimal == "10")
        #expect(sut.octal == "12")
        #expect(sut.hexadecimal == "A")
    }

    @Test
    func lowercaseHexInputConverts() {
        let sut = ConverterViewModel()

        // lowercase hex is accepted; ff == 255 decimal.
        sut.userEdited(.hexadecimal, "ff")

        #expect(sut.hexadecimal == "ff")
        #expect(sut.decimal == "255")
        #expect(sut.binary == "11111111")
        #expect(sut.octal == "377")
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func twosComplementDecodeAfterEditingBinary() {
        let sut = ConverterViewModel(twosComplement: true)

        // 10000000 decodes (8-bit two's complement) to -128.
        sut.userEdited(.binary, "10000000")

        #expect(sut.binary == "10000000")
        #expect(sut.decimal == "-128")
        #expect(sut.octal == "-200") // 128 == 200 octal, signed
        #expect(sut.hexadecimal == "-80") // 128 == 80 hex, signed
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func twosComplementWidthForMinus128() {
        let sut = ConverterViewModel(twosComplement: true)

        // -128 is the lower bound of the 8-bit signed range, so width stays 8.
        sut.userEdited(.decimal, "-128")

        #expect(sut.decimal == "-128")
        #expect(sut.binary == "10000000")
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func twosComplementWidthForMinus129() {
        let sut = ConverterViewModel(twosComplement: true)

        // -129 no longer fits 8 bits, so the pattern widens to 16 bits.
        sut.userEdited(.decimal, "-129")

        #expect(sut.decimal == "-129")
        #expect(sut.binary == "1111111101111111")
        #expect(sut.invalidFields.isEmpty)
    }

    @Test
    func clearingAnInputClearsEveryValidationError() {
        let sut = ConverterViewModel()
        sut.userEdited(.binary, "2")
        sut.userEdited(.hexadecimal, "G")
        #expect(sut.invalidFields == [.binary, .hexadecimal])
        #expect(sut.error(for: .binary) == .invalidCharacter)
        #expect(sut.error(for: .hexadecimal) == .invalidCharacter)

        sut.userEdited(.decimal, "")

        #expect(sut.binary.isEmpty)
        #expect(sut.hexadecimal.isEmpty)
        #expect(sut.invalidFields.isEmpty)
        #expect(BaseField.allCases.allSatisfy { sut.error(for: $0) == nil })
    }

    @Test
    func unchangedTwosComplementSettingPreservesTheEditedField() {
        let sut = ConverterViewModel()
        sut.userEdited(.hexadecimal, "ff")

        sut.twosComplement = false

        #expect(sut.hexadecimal == "ff")
        #expect(sut.decimal == "255")
    }

    @Test
    func togglingTwosComplementWithoutInputKeepsFieldsEmpty() {
        let sut = ConverterViewModel()
        sut.twosComplement = true

        #expect(sut.binary.isEmpty)
        #expect(sut.decimal.isEmpty)
    }

    @Test
    func everyFieldSuppliesItsOwnNavigationSeed() {
        let sut = ConverterViewModel()
        sut.userEdited(.decimal, "255")
        let expected: [(BaseField, Int, String)] = [
            (.binary, 2, "11111111"), (.octal, 8, "377"),
            (.decimal, 10, "255"), (.hexadecimal, 16, "FF")
        ]
        for (field, base, number) in expected {
            let seed = sut.seed(for: field)
            #expect(seed.base == base)
            #expect(seed.number == number)
        }
    }

    @Test
    func outOfRangeInputFlagsItsSourceAndPreservesPreviousConversions() {
        let sut = ConverterViewModel()
        sut.userEdited(.decimal, "255")

        sut.userEdited(.decimal, String(repeating: "9", count: 200))

        #expect(sut.invalidFields == [.decimal])
        #expect(sut.error(for: .decimal) == .numberOutOfRange)
        #expect(sut.binary == "11111111")
        #expect(sut.hexadecimal == "FF")

        sut.userEdited(.decimal, "10")
        #expect(sut.invalidFields.isEmpty)
        #expect(sut.error(for: .decimal) == nil)
        #expect(sut.binary == "1010")
    }

    @Test
    func signedBitPatternModeRejectsAnExplicitMinusSignAtTheSource() {
        let sut = ConverterViewModel(twosComplement: true)
        sut.userEdited(.decimal, "-5")

        sut.userEdited(.binary, "-101")

        #expect(sut.invalidFields == [.binary])
        #expect(sut.error(for: .binary) == .invalidCharacter)
        #expect(sut.decimal == "-5")
        #expect(sut.octal == "-5")
    }

    @Test
    func signedBinaryRangeFailureKeepsOtherBasesCorrectAndRecoversInPlainMode() {
        let sut = ConverterViewModel(twosComplement: true)
        sut.userEdited(.decimal, "5")
        #expect(sut.binary == "00000101")

        // 2^63 fits native decimal but exceeds the signed 64-bit binary range.
        sut.userEdited(.decimal, "9223372036854775808")

        #expect(sut.invalidFields == [.binary])
        #expect(sut.error(for: .binary) == .numberOutOfRange)
        #expect(sut.error(for: .decimal) == nil)
        #expect(sut.decimal == "9223372036854775808")
        #expect(sut.binary == "00000101")
        #expect(sut.octal == "1" + String(repeating: "0", count: 21))
        #expect(sut.hexadecimal == "8000000000000000")

        sut.twosComplement = false

        #expect(sut.invalidFields.isEmpty)
        #expect(sut.error(for: .binary) == nil)
        #expect(sut.binary == "1" + String(repeating: "0", count: 63))
    }

    @Test
    func invalidBinaryTextIsPreservedWithItsActualErrorUntilCorrected() {
        let sut = ConverterViewModel()
        sut.userEdited(.decimal, "255")

        sut.userEdited(.binary, "1021")

        #expect(sut.binary == "1021")
        #expect(sut.error(for: .binary) == .invalidCharacter)
        #expect(sut.invalidFields == [.binary])
        #expect(sut.decimal == "255")
        #expect(sut.octal == "377")
        #expect(sut.hexadecimal == "FF")

        sut.userEdited(.binary, "101")
        #expect(sut.error(for: .binary) == nil)
        #expect(sut.invalidFields.isEmpty)
        #expect(sut.decimal == "5")
    }
}
