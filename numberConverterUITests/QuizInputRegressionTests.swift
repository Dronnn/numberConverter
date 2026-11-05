//
//  QuizInputRegressionTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testLargestTextQuizAnswerIsReachableFromInitialQuestion() throws {
        capturesIncludeNativeAudit = false
        defer {
            capturesIncludeNativeAudit = true
            app.terminate()
        }
        launch(.russian, largeText: true)
        try selectTab(3)
        try tap("quiz.category.decimalInt")
        XCTAssertTrue(try require("quiz.session").exists)
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "quiz-largest-initial-answer-viewport"
        initial.lifetime = .keepAlways
        add(initial)
        attachInputFocusState("quiz.answer", stage: "initial-largest-question")

        try replace("quiz.answer", with: "?")
        try expectValue("quiz.answer", "?")
        dismissKeyboard()
        try tap("quiz.check")
        let feedback = app.alerts.firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        let message = feedback.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        XCTAssertTrue(message.contains("Ваш ответ неверный"), message)
        let result = XCTAttachment(screenshot: app.screenshot())
        result.name = "quiz-largest-revealed-answer-native-feedback"
        result.lifetime = .keepAlways
        add(result)
    }
}
