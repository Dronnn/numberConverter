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
}
