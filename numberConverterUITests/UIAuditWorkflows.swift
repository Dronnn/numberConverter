//
//  UIAuditWorkflows.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testPrivacyNativeAuditViewportRestoration() throws {
        launch(.english)
        try openHelp()
        try tap("help.privacy")
        try auditScrolling(
            .english,
            screen: "privacy-native-viewport",
            container: require("privacy.content"),
            through: app.links.matching(identifier: "privacy.applePolicy").firstMatch,
            tabBarAffectsViewport: false
        )
        let completion =
            XCTAttachment(string: "Privacy's actual final Apple-policy Link was reached after native audits.")
        completion.name = "native-privacy-viewport-completed-en"
        completion.lifetime = .keepAlways
        add(completion)
        app.terminate()
        if collectsAllAuditIssues {
            XCTFail("Diagnostic Privacy traversal requires a strict rerun before acceptance")
        }
    }

    func testEnglishHelpNativeTraversal() throws {
        executionTimeAllowance = 1_800
        launch(.english)
        try exerciseHelp(.english)
        let completion = XCTAttachment(string: "All nine Help pages, Privacy and the contact alert returned.")
        completion.name = "native-help-workflow-completed-en"
        completion.lifetime = .keepAlways
        add(completion)
        app.terminate()
        if collectsAllAuditIssues {
            XCTFail("Diagnostic Help traversal requires a strict rerun before acceptance")
        }
    }

    func exerciseConverter(_ language: UITestLanguage) throws {
        let toggle = try require("converter.twosComplement")
        if toggle.value as? String == "1" {
            try tap("converter.twosComplement")
        }

        try replace("converter.input.10", with: "255")
        try expectValue("converter.input.2", "11111111")
        try expectValue("converter.input.8", "377")
        try expectValue("converter.input.16", "FF")
        dismissKeyboard()
        capture(language, screen: "converter-filled")

        try tap("converter.detail.10")
        XCTAssertTrue(app.staticTexts["FF"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["11111111"].exists)
        capture(language, screen: "main-systems")
        backToConverter(language)
        try exerciseInvalidDetails(language)

        try replace("converter.input.10", with: "-5")
        dismissKeyboard()
        try tap("converter.twosComplement")
        try expectValue("converter.input.2", "11111011")
        capture(language, screen: "twos-complement")
        try tap("converter.twosComplement")
        try expectValue("converter.input.2", "-101")

        try replace("converter.all.input", with: "255")
        dismissKeyboard()
        try tap("converter.all.detail")
        XCTAssertTrue(app.staticTexts["11111111"].waitForExistence(timeout: 5))
        capture(language, screen: "all-bases-detail")
        try reveal(element("base.value.36"), identifier: "base.value.36")
        try expectText("base.value.36", "73")
        capture(language, screen: "all-bases-detail-bottom")
        backToConverter(language)
    }

    private func exerciseInvalidDetails(_ language: UITestLanguage) throws {
        try replace("converter.input.2", with: "2")
        dismissKeyboard()
        try expectValue("converter.input.2", "2")
        XCTAssertFalse(try require("converter.detail.2").isEnabled)
        XCTAssertTrue(try require("converter.error.2").label.contains("01"))
        capture(language, screen: "invalid-binary-detail-disabled")
        try replace("converter.input.2", with: "101")
        dismissKeyboard()
        XCTAssertTrue(try require("converter.detail.2").isEnabled)

        try replace("converter.all.input", with: "1.2.3")
        dismissKeyboard()
        XCTAssertFalse(try require("converter.all.detail").isEnabled)
        capture(language, screen: "invalid-decimal-detail-disabled")
    }

    func exerciseAllSystems(_ language: UITestLanguage) throws {
        try selectTab(1)
        try replace("allSystems.sourceBase", with: "16")
        try replace("allSystems.targetBase", with: "10")
        try replace("allSystems.number", with: "FF")
        dismissKeyboard()
        try tap("allSystems.convert")
        try expectValue("allSystems.sourceBase", "16")
        try expectValue("allSystems.targetBase", "10")
        try expectText("allSystems.result", "255")
        capture(language, screen: "arbitrary-bases")

        try replace("allSystems.number", with: "G")
        dismissKeyboard()
        XCTAssertTrue(try require("allSystems.error").exists)
        assertNoLocalizationKeys()
        capture(language, screen: "invalid-digit")
        try replace("allSystems.number", with: "FF")
        dismissKeyboard()
        try expectText("allSystems.result", "255")
    }

    func exerciseCalculator(_ language: UITestLanguage) throws {
        try selectTab(2)
        try replace("calculator.operandA", with: "19")
        try replace("calculator.operandB", with: "5")
        dismissKeyboard()
        for (symbol, result) in [("+", "24"), ("−", "14"), ("×", "95"), ("÷", "3.8")] {
            try tapOperation(symbol)
            try expectText("calculator.result", result)
        }
        capture(language, screen: "calculator-division")

        try replace("calculator.operandB", with: "0")
        dismissKeyboard()
        try expectText("calculator.error", language.divisionByZero)
        capture(language, screen: "division-by-zero")

        try replace("calculator.baseA", with: "16")
        try replace("calculator.operandA", with: "FF")
        try replace("calculator.baseB", with: "2")
        try replace("calculator.operandB", with: "1")
        try replace("calculator.resultBase", with: "16")
        dismissKeyboard()
        try tapOperation("+")
        try expectText("calculator.result", "100")
        capture(language, screen: "mixed-base-arithmetic")
    }

    func tapOperation(_ symbol: String) throws {
        let operation = app.segmentedControls.buttons[symbol]
        try reveal(operation)
        operation.tap()
    }

    func exerciseRotation(_ language: UITestLanguage) throws {
        launch(language)
        try selectTab(3)
        try tap("quiz.category.binaryInt")
        let question = try require("quiz.question").label
        try replace("quiz.answer", with: "1")
        dismissKeyboard()
        for landscape in [true, false] {
            XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
            try expectText("quiz.question", question)
            try expectValue("quiz.answer", "1")
            assertNoLocalizationKeys()
            capture(language, screen: "quiz-\(landscape ? "landscape" : "portrait")")
        }
        try tap("quiz.finish")
        try openHelp()
        try tap("help.topic.7")
        let heading = try require("help.title").label
        for landscape in [true, false] {
            XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
            try expectText("help.title", heading)
            XCTAssertTrue(element("help.title").isHittable)
            capture(language, screen: "help-\(landscape ? "landscape" : "portrait")")
        }
        try closeHelp()
        app.terminate()
    }

    func exerciseQuiz(_ language: UITestLanguage) throws {
        try selectTab(3)
        try openOverallStatistics()
        try resetStatistics(language)
        backToList("quiz.sidebar")
        try reveal(element("quiz.category.binaryInt"), upward: false)
        try tap("quiz.category.binaryInt")
        XCTAssertTrue(try require("quiz.prompt").isHittable)
        capture(language, screen: "quiz-question")

        try answerCorrectly(language, answer: revealCorrectAnswer(language))

        try openSessionStatistics()
        expectAlertCounts(asked: 1, correct: 1)
        capture(language, screen: "quiz-statistics-alert")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        try openOverallStatistics()
        try expectCounts("statistics.counts.all", asked: 1, correct: 1)
        capture(language, screen: "statistics")
        try exerciseResetWhileQuizActive(language)
    }

    private func exerciseResetWhileQuizActive(_ language: UITestLanguage) throws {
        try resetStatistics(language, cancelFirst: true)
        backToList("quiz.sidebar")
        try reveal(element("quiz.category.binaryInt"), upward: false)
        try tap("quiz.category.binaryInt")
        try openSessionStatistics()
        expectAlertCounts(asked: 1, correct: 0)
        capture(language, screen: "quiz-new-session-after-reset")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        try answerCorrectly(language, answer: revealCorrectAnswer(language))
        try openSessionStatistics()
        expectAlertCounts(asked: 1, correct: 1)
        app.alerts.firstMatch.buttons.firstMatch.tap()
        try tap("quiz.next")
        try openSessionStatistics()
        expectAlertCounts(asked: 2, correct: 1)
        app.alerts.firstMatch.buttons.firstMatch.tap()
        try tap("quiz.finish")
        try openOverallStatistics()
        try expectCounts("statistics.counts.all", asked: 2, correct: 1)
        try checkStatisticsPersistence(language)
    }

    private func answerCorrectly(_ language: UITestLanguage, answer: String) throws {
        try replace("quiz.answer", with: answer)
        dismissKeyboard()
        try tap("quiz.check")
        let feedback = app.alerts.firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        XCTAssertTrue(feedback.staticTexts[language.correctAnswer].exists)
        capture(language, screen: "quiz-correct")
        feedback.buttons.firstMatch.tap()
    }

    func revealCorrectAnswer(_ language: UITestLanguage) throws -> String {
        try replace("quiz.answer", with: "?")
        dismissKeyboard()
        try tap("quiz.check")
        let feedback = app.alerts.firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        let message = feedback.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        let pattern = #"[0-9A-F]+(?:\.[0-9A-F]+)?$"#
        guard let range = message.range(of: pattern, options: .regularExpression) else {
            XCTFail("Incorrect-answer alert did not reveal a numeric answer: \(message)")
            throw UIAuditError.missingCorrectAnswer
        }
        let answer = String(message[range])
        XCTAssertFalse(message.contains("quiz.session."))
        capture(language, screen: "quiz-incorrect")
        feedback.buttons.firstMatch.tap()
        return answer
    }

    func expectAlertCounts(asked: Int, correct: Int) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let message = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        let counts = message.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(Array(counts.prefix(2)), [asked, correct], message)
        XCTAssertFalse(message.contains("quiz.stats.message"))
    }

    func checkStatisticsPersistence(_ language: UITestLanguage) throws {
        app.terminate()
        launch(language)
        try selectTab(3)
        try openOverallStatistics()
        try expectCounts("statistics.counts.all", asked: 2, correct: 1)
        capture(language, screen: "statistics-after-relaunch")
        try resetStatistics(language)
    }

    func resetStatistics(_ language: UITestLanguage, cancelFirst: Bool = false) throws {
        let originalCounts = cancelFirst ? try require("statistics.counts.all").label : nil
        try tap("statistics.reset")
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        if cancelFirst {
            let cancel = alert.buttons.matching(identifier: "statistics.cancel").firstMatch
            if cancel.exists {
                cancel.tap()
            } else {
                let otherButton = alert.buttons.allElementsBoundByIndex.first { $0.label != language.resetStatistics }
                try XCTUnwrap(otherButton).tap()
            }
            try reveal(element("statistics.counts.all"), upward: false)
            if let originalCounts {
                try expectText("statistics.counts.all", originalCounts)
            }
            try tap("statistics.reset")
        }
        alert.buttons.matching(identifier: language.resetStatistics).firstMatch.tap()
        try reveal(element("statistics.counts.all"), upward: false)
        try expectCounts("statistics.counts.all", asked: 0, correct: 0)
    }

    func exerciseHelp(_ language: UITestLanguage) throws {
        try openHelp()
        capture(language, screen: "help-index")
        let lastBlocks = [
            "help.page1.table", "help.page2.p13", "help.page3.p3", "help.page4.p5",
            "help.page5.p5", "help.page6.p8", "help.page7.p16", "help.page8.p8", "help.page9.p7"
        ]
        for page in 1 ... 9 {
            try tap("help.topic.\(page)")
            let title = try require("help.title")
            XCTAssertTrue(title.isHittable)
            XCTAssertFalse(title.label.hasPrefix("help."))
            assertNoLocalizationKeys()
            capture(language, screen: "help-page-\(page)-top")
            try auditHelpPage(language, page: page, lastBlock: lastBlocks[page - 1])
            backToList("help.sidebar")
        }
        try tap("help.privacy")
        XCTAssertTrue(try require("privacy.title").isHittable)
        XCTAssertEqual(
            app.buttons.matching(identifier: "help.close").allElementsBoundByIndex.filter(\.isHittable).count,
            1
        )
        try auditScrolling(
            language,
            screen: "privacy-policy",
            container: require("privacy.content"),
            through: app.links.matching(identifier: "privacy.applePolicy").firstMatch,
            tabBarAffectsViewport: false
        )
        backToList("help.sidebar")
        try tap("help.contact")
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        assertNoLocalizationKeys()
        capture(language, screen: "mail-unavailable")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        try closeHelp()
    }

    private func auditHelpPage(_ language: UITestLanguage, page: Int, lastBlock: String) throws {
        let content = try require("help.content")
        let finalMono = finalHelpMono(page: page)
        let finalTexts = finalMono.map { text in
            content.staticTexts.matching(NSPredicate(format: "label == %@", text))
        }
        let last = finalTexts?.element ?? element("help.block.\(lastBlock)")
        try auditScrolling(
            language,
            screen: "help-page-\(page)",
            container: content,
            through: last,
            tabBarAffectsViewport: false
        )
        if let finalTexts {
            XCTAssertEqual(
                finalTexts.count,
                1,
                "The complete final worked example must be unique in the current Help page"
            )
        }
        let mathProof: (block: String, equation: String)? = switch page {
        case 3: ("help.page3.p2", "0.89 * 2 = 1.78")
        case 4: ("help.page4.p4", "1*2^4 = 16")
        default: nil
        }
        if let mathProof {
            let identifier = "help.block.\(mathProof.block)"
            let renderedText = element(identifier)
            try reveal(renderedText, container: content, identifier: identifier)
            XCTAssertTrue(renderedText.label.contains(mathProof.equation), renderedText.label)
            capture(language, screen: "help-page-\(page)-rendered-operators")
        }
    }

    private func finalHelpMono(page: Int) -> String? {
        switch page {
        case 5:
            [
                "1*2^(-1) = 0.5", "0*2^(-2) = 0", "1*2^(-3) = 0.125",
                "1*2^(-1) + 0*2^(-2) + 1*2^(-3) = 0.625"
            ].joined(separator: "\n")
        case 6:
            [
                "    11011", "     1101", "---------", "    11011", "   00000",
                "  11011", " 11011", "----------", "101011111"
            ].joined(separator: "\n")
        default: nil
        }
    }
}
