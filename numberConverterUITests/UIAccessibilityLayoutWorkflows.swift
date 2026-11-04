//
//  UIAccessibilityLayoutWorkflows.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func exerciseAccessibilityLayout(_ language: UITestLanguage) throws {
        launch(language, largeText: true)
        capture(language, screen: "AX-converter-empty")
        try layoutConverter(language)
        try layoutArbitraryBases(language)
        try layoutCalculator(language)
        try layoutQuizCategories(language)
        try exerciseSupport(language)
        try exerciseHelp(language)
        app.terminate()
    }

    private func layoutConverter(_ language: UITestLanguage) throws {
        let number = 1_234_567_890
        let hexadecimal = String(number, radix: 16, uppercase: true)
        let base36 = String(number, radix: 36, uppercase: true)
        try replace("converter.input.10", with: String(number))
        dismissKeyboard()
        try auditScrolling(
            language,
            screen: "AX-converter-long",
            container: app.collectionViews.firstMatch,
            through: element("converter.twosComplement")
        )
        try tap("converter.detail.10")
        try auditScrolling(
            language,
            screen: "AX-main-systems-long",
            container: app.collectionViews.firstMatch,
            through: app.staticTexts[hexadecimal]
        )
        back()
        try replace("converter.all.input", with: String(number))
        dismissKeyboard()
        try tap("converter.all.detail")
        try auditScrolling(
            language,
            screen: "AX-all-bases-detail-long",
            container: app.collectionViews.firstMatch,
            through: app.staticTexts[base36]
        )
        back()
        try replace("converter.input.2", with: "2")
        dismissKeyboard()
        try expectValue("converter.input.2", "2")
        let error = element("converter.error.2")
        try reveal(error, identifier: "converter.error.2")
        XCTAssertTrue(error.label.contains("01"))
        capture(language, screen: "AX-converter-inline-error")
        try replace("converter.input.2", with: "101")
        dismissKeyboard()
    }

    private func layoutArbitraryBases(_ language: UITestLanguage) throws {
        try selectTab(1)
        try replace("allSystems.number", with: "1234567890")
        dismissKeyboard()
        try auditScrolling(
            language,
            screen: "AX-arbitrary-bases-long",
            container: app.collectionViews.firstMatch,
            through: element("allSystems.result")
        )
        try replace("allSystems.number", with: "G")
        dismissKeyboard()
        try reveal(element("allSystems.error"), identifier: "allSystems.error")
        XCTAssertTrue(try require("allSystems.error").isHittable)
        capture(language, screen: "AX-invalid-number-error")
    }

    private func layoutCalculator(_ language: UITestLanguage) throws {
        try selectTab(2)
        try replace("calculator.operandA", with: "1234567890")
        try replace("calculator.operandB", with: "7")
        dismissKeyboard()
        try auditScrolling(
            language,
            screen: "AX-calculator-long",
            container: app.collectionViews.firstMatch,
            through: app.segmentedControls.firstMatch
        )
        try replace("calculator.operandB", with: "0")
        dismissKeyboard()
        try tapOperation("÷")
        try reveal(element("calculator.error"), upward: false, identifier: "calculator.error")
        try expectText("calculator.error", language.divisionByZero)
        capture(language, screen: "AX-calculator-division-by-zero")
    }

    private func layoutQuizCategories(_ language: UITestLanguage) throws {
        try selectTab(3)
        capture(language, screen: "AX-quiz-menu")
        let categories = [
            "binaryInt", "octalInt", "decimalInt", "hexInt",
            "binaryFraction", "octalFraction", "decimalFraction", "hexFraction"
        ]
        for category in categories {
            try tap("quiz.category.\(category)")
            let session = try require("quiz.session")
            try auditScrolling(
                language,
                screen: "AX-quiz-\(category)",
                container: session,
                through: session.buttons["quiz.statistics"]
            )
            if category == "hexFraction" {
                try layoutQuizAlerts(language)
            }
            try tap("quiz.finish")
        }
        try openOverallStatistics()
        try auditScrolling(
            language,
            screen: "AX-overall-statistics",
            container: require("statistics.list"),
            through: element("statistics.reset")
        )
        try tap("statistics.reset")
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        capture(language, screen: "AX-statistics-reset-alert")
        app.alerts.firstMatch.buttons[language.resetStatistics].tap()
    }

    private func layoutQuizAlerts(_ language: UITestLanguage) throws {
        try replace("quiz.answer", with: "?")
        dismissKeyboard()
        try tap("quiz.check")
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        capture(language, screen: "AX-quiz-incorrect-alert")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        try openSessionStatistics()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        capture(language, screen: "AX-quiz-statistics-alert")
        app.alerts.firstMatch.buttons.firstMatch.tap()
    }
}
