//
//  numberConverterUITests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
final class NumberConverterUITests: XCTestCase {
    let app = XCUIApplication()
    var completedEndToEndWorkflow = false

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        let completed = await MainActor.run {
            let result = completedEndToEndWorkflow
            completedEndToEndWorkflow = false
            return result
        }
        if name.contains("EndToEnd") || name.contains("NavigationSmoke") {
            XCTAssertTrue(completed, "The end-to-end workflow exited before all screens and actions completed")
        }
        try await super.tearDown()
    }

    func testEnglishEndToEnd() throws {
        try exerciseLanguage(.english)
        markWorkflowCompleted(.english)
    }

    func testRussianEndToEnd() throws {
        try exerciseLanguage(.russian)
        markWorkflowCompleted(.russian)
    }

    func testSpanishEndToEnd() throws {
        try exerciseLanguage(.spanish)
        markWorkflowCompleted(.spanish)
    }

    func testGermanEndToEnd() throws {
        try exerciseLanguage(.german)
        markWorkflowCompleted(.german)
    }

    func testFrenchEndToEnd() throws {
        try exerciseLanguage(.french)
        markWorkflowCompleted(.french)
    }

    func testPortugueseEndToEnd() throws {
        try exerciseLanguage(.portuguese)
        markWorkflowCompleted(.portuguese)
    }

    func testEnglishLargestTextEndToEnd() throws {
        try exerciseAccessibilityLayout(.english)
        markWorkflowCompleted(.english, largestText: true)
    }

    func testRussianLargestTextEndToEnd() throws {
        try exerciseAccessibilityLayout(.russian)
        markWorkflowCompleted(.russian, largestText: true)
    }

    func testSpanishLargestTextEndToEnd() throws {
        try exerciseAccessibilityLayout(.spanish)
        markWorkflowCompleted(.spanish, largestText: true)
    }

    func testGermanLargestTextEndToEnd() throws {
        try exerciseAccessibilityLayout(.german)
        markWorkflowCompleted(.german, largestText: true)
    }

    func testFrenchLargestTextEndToEnd() throws {
        try exerciseAccessibilityLayout(.french)
        markWorkflowCompleted(.french, largestText: true)
    }

    func testPortugueseLargestTextEndToEnd() throws {
        try exerciseAccessibilityLayout(.portuguese)
        markWorkflowCompleted(.portuguese, largestText: true)
    }

    func testAccessibilityInEveryLanguage() throws {
        for language in UITestLanguage.allCases {
            launch(language)
            for tabIndex in 0 ..< 5 {
                try selectTab(tabIndex)
                capture(language, screen: "accessibility-tab-\(tabIndex)")
            }
            app.terminate()
        }
    }

    func testEnglishNavigationSmoke() throws {
        try exerciseNavigationSmoke(.english)
        markWorkflowCompleted(.english, smoke: true)
    }

    func testRussianNavigationSmoke() throws {
        try exerciseNavigationSmoke(.russian)
        markWorkflowCompleted(.russian, smoke: true)
    }

    func testSpanishNavigationSmoke() throws {
        try exerciseNavigationSmoke(.spanish)
        markWorkflowCompleted(.spanish, smoke: true)
    }

    func testGermanNavigationSmoke() throws {
        try exerciseNavigationSmoke(.german)
        markWorkflowCompleted(.german, smoke: true)
    }

    func testFrenchNavigationSmoke() throws {
        try exerciseNavigationSmoke(.french)
        markWorkflowCompleted(.french, smoke: true)
    }

    func testPortugueseNavigationSmoke() throws {
        try exerciseNavigationSmoke(.portuguese)
        markWorkflowCompleted(.portuguese, smoke: true)
    }

    func testRotationPreservesQuizAndHelpInEveryLanguage() throws {
        for language in UITestLanguage.allCases {
            try exerciseRotation(language)
        }
    }

    func exerciseLanguage(_ language: UITestLanguage, largeText: Bool = false) throws {
        launch(language, largeText: largeText)
        XCTAssertEqual(app.navigationBars.firstMatch.identifier, language.converterTitle)
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), language.tabLabels)
        capture(language, screen: "converter-empty")

        try exerciseConverter(language)
        try exerciseAllSystems(language)
        try exerciseCalculator(language)
        try exerciseQuiz(language)
        try exerciseSupport(language)
        try exerciseHelp(language)
        app.terminate()
    }
}
