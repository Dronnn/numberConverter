//
//  FunctionalEndToEndTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testEnglishFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.english)
    }

    func testRussianFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.russian)
    }

    func testSpanishFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.spanish)
    }

    func testGermanFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.german)
    }

    func testFrenchFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.french)
    }

    func testPortugueseFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.portuguese)
    }

    func testEnglishLargestTextFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.english, largestText: true)
    }

    func testRussianLargestTextFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.russian, largestText: true)
    }

    func testSpanishLargestTextFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.spanish, largestText: true)
    }

    func testGermanLargestTextFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.german, largestText: true)
    }

    func testFrenchLargestTextFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.french, largestText: true)
    }

    func testPortugueseLargestTextFunctionalEndToEnd() throws {
        try exerciseFunctionalLanguage(.portuguese, largestText: true)
    }

    private func exerciseFunctionalLanguage(_ language: UITestLanguage, largestText: Bool = false) throws {
        capturesIncludeNativeAudit = false
        defer { capturesIncludeNativeAudit = true }
        if largestText {
            try exerciseAccessibilityLayout(language)
        } else {
            try exerciseLanguage(language)
        }
        markWorkflowCompleted(language, largestText: largestText)
    }
}
