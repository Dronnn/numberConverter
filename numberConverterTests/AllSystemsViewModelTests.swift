//
//  AllSystemsViewModelTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
@testable import numberConverter
import Testing

// MARK: - AllSystemsViewModelTests

@MainActor
struct AllSystemsViewModelTests {
    @Test
    func convertsBetweenArbitraryBases() {
        let sut = AllSystemsViewModel(number: "1023", sourceBase: 6, targetBase: 9)

        #expect(sut.result == "276")
        #expect(sut.error == nil)
    }

    @Test
    func convertsHexToBinary() {
        let sut = AllSystemsViewModel(number: "FF", sourceBase: 16, targetBase: 2)

        #expect(sut.result == "11111111")
        #expect(sut.error == nil)
    }

    @Test
    func liveRecomputeOnInputChange() {
        let sut = AllSystemsViewModel(number: "10", sourceBase: 10, targetBase: 2)
        #expect(sut.result == "1010")

        sut.number = "255"
        sut.targetBase = 16
        #expect(sut.result == "FF")
    }

    @Test
    func invalidNumberFlagsError() {
        let sut = AllSystemsViewModel(number: "G", sourceBase: 10, targetBase: 2)

        #expect(sut.error == .invalidCharacter)
        #expect(sut.result.isEmpty)
    }

    @Test
    func outOfRangeSourceBaseFlagsError() {
        let sut = AllSystemsViewModel(number: "10", sourceBase: 37, targetBase: 2)

        #expect(sut.error == .baseOutOfRange)
        #expect(sut.result.isEmpty)
    }

    @Test
    func outOfRangeTargetBaseFlagsError() {
        let sut = AllSystemsViewModel(number: "10", sourceBase: 10, targetBase: 1)

        #expect(sut.error == .baseOutOfRange)
        #expect(sut.result.isEmpty)
    }

    @Test
    func changingSourceBaseLiveReDerives() {
        // "10" parsed from base 10 -> base 2 is 1010.
        let sut = AllSystemsViewModel(number: "10", sourceBase: 10, targetBase: 2)
        #expect(sut.result == "1010")

        // same text reinterpreted from base 16 -> base 2 is 16 decimal == 10000.
        sut.sourceBase = 16
        #expect(sut.result == "10000")
        #expect(sut.error == nil)
    }

    @Test
    func fractionalInputConverts() {
        // 10.5 decimal -> binary: 10 == 1010, .5 == .1 => 1010.1.
        let sut = AllSystemsViewModel(number: "10.5", sourceBase: 10, targetBase: 2)

        #expect(sut.result == "1010.1")
        #expect(sut.error == nil)
    }

    @Test
    func negativeInputConverts() {
        // all-systems never uses two's complement, so negatives stay signed.
        // -255 decimal -> hex == -FF.
        let sut = AllSystemsViewModel(number: "-255", sourceBase: 10, targetBase: 16)

        #expect(sut.result == "-FF")
        #expect(sut.error == nil)
    }

    @Test
    func emptyInputYieldsZeroWithoutError() {
        // empty input is valid and normalizes to zero.
        let sut = AllSystemsViewModel(number: "", sourceBase: 10, targetBase: 2)

        #expect(sut.result == "0")
        #expect(sut.error == nil)
    }

    @Test
    func recoversAfterError() {
        let sut = AllSystemsViewModel(number: "G", sourceBase: 10, targetBase: 2)
        #expect(sut.error == .invalidCharacter)
        #expect(sut.result.isEmpty)

        // a valid value clears the error and produces a result.
        sut.number = "10"
        #expect(sut.error == nil)
        #expect(sut.result == "1010")
    }

    @Test
    func boundaryBaseThirtySixToTwo() {
        // "Z" in base 36 == 35 decimal == 100011 binary.
        let sut = AllSystemsViewModel(number: "Z", sourceBase: 36, targetBase: 2)

        #expect(sut.result == "100011")
        #expect(sut.error == nil)
    }

    @Test
    func boundaryBaseTwoToThirtySix() {
        // 1010 binary == 10 decimal == A in base 36.
        let sut = AllSystemsViewModel(number: "1010", sourceBase: 2, targetBase: 36)

        #expect(sut.result == "A")
        #expect(sut.error == nil)
    }
}
