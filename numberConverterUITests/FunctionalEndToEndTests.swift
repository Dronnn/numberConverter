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
    /// Logic is independent of language. Translation/layout coverage lives in the localization tests.
    func testEnglishFunctionalEndToEnd() throws {
        try exerciseFunctionalWorkflow()
    }

    func testEnglishLargestTextFunctionalEndToEnd() throws {
        try exerciseFunctionalWorkflow(largestText: true)
    }

    private func exerciseFunctionalWorkflow(largestText: Bool = false) throws {
        // keep full native audit coverage once per text size, alongside the functional assertions.
        if largestText {
            try exerciseAccessibilityLayout(.english)
        } else {
            try exerciseLanguage(.english)
        }
        markWorkflowCompleted(.english, largestText: largestText)
    }
}
