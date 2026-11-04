//
//  UIAuditSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

enum UIAuditError: Error {
    case missingElement(String)
    case missingCorrectAnswer
}

@MainActor
extension NumberConverterUITests {
    private static let measuredDynamicTypeBindings = [
        "converter.header.settings", "allSystems.resultLabel", "allSystems.result",
        "calculator.resultLabel", "calculator.result", "calculator.resultBaseLabel"
    ]

    func launch(_ language: UITestLanguage, largeText: Bool = false, tipStoreState: String = "available") {
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = [
            "-AppleLanguages", "(\(language.rawValue))",
            "-AppleLocale", language.region,
            "-ui-tip-store", tipStoreState
        ]
        if largeText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    func require(_ identifier: String) throws -> XCUIElement {
        let result = element(identifier)
        guard result.waitForExistence(timeout: 5) else {
            XCTFail("Missing UI element: \(identifier)")
            throw UIAuditError.missingElement(identifier)
        }
        return result
    }

    func tap(_ identifier: String) throws {
        let target = element(identifier)
        _ = target.waitForExistence(timeout: 2)
        try reveal(target, identifier: identifier)
        if target.elementType == .switch {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        } else {
            target.tap()
        }
    }

    func selectTab(_ index: Int) throws {
        dismissKeyboard()
        let buttons = app.tabBars.buttons
        guard buttons.count == 5 else {
            XCTFail("Expected five visible tabs; found \(buttons.count)")
            throw UIAuditError.missingElement("tab \(index)")
        }
        let identifiers = ["converter", "allSystems", "calculator", "quiz", "support"]
        try tap("app.tab.\(identifiers[index])")
        assertNoLocalizationKeys()
    }

    func openHelp() throws {
        try tap("app.help")
        XCTAssertTrue(try require("help.sidebar").exists)
        XCTAssertTrue(try require("help.close").isHittable)
    }

    func closeHelp() throws {
        try tap("help.close")
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: element("help.close")
        )
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertTrue(try require("app.help").isHittable)
    }

    func replace(_ identifier: String, with text: String) throws {
        dismissKeyboard()
        let field = try require(identifier)
        try reveal(field, identifier: identifier)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "No keyboard after focusing \(identifier)")
        // select all through the public keyboard API, independent of the caret
        // position chosen by native tap or the localized edit-menu labels.
        field.typeKey("a", modifierFlags: .command)
        field.typeText(XCUIKeyboardKey.delete.rawValue + text)
    }

    func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.buttons["keyboard.done"]
        if done.waitForExistence(timeout: 1), done.isHittable {
            done.tap()
        } else {
            app.swipeDown()
        }
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed, "Keyboard did not dismiss")
    }

    func reveal(
        _ target: XCUIElement,
        upward: Bool = true,
        attempts: Int = 10,
        container: XCUIElement? = nil,
        identifier: String? = nil
    ) throws {
        let description = identifier ?? (target.exists ? target.identifier : "unresolved element")
        let scrollView = container ?? scrollContainer(for: description)
        for direction in [upward, !upward] {
            for _ in 0 ..< attempts {
                if target.exists, target.isHittable {
                    return
                }
                if direction {
                    scrollView.swipeUp()
                } else {
                    scrollView.swipeDown()
                }
            }
        }
        guard target.exists, target.isHittable else {
            XCTFail("UI element is not reachable: \(description)")
            throw UIAuditError.missingElement(description)
        }
    }

    func back() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func backToList(_ sidebarIdentifier: String) {
        let sidebar = element(sidebarIdentifier)
        if sidebar.exists, sidebar.isHittable {
            return
        }
        back()
    }

    private func scrollContainer(for identifier: String) -> XCUIElement {
        let containerIdentifier: String? = if
            identifier.hasPrefix("help.topic.")
            || identifier == "help.contact" || identifier == "help.privacy"
        {
            "help.sidebar"
        } else if identifier.hasPrefix("help.block.") || identifier == "help.title" {
            "help.content"
        } else if identifier.hasPrefix("quiz.category.") {
            "quiz.sidebar"
        } else if identifier.hasPrefix("statistics.") {
            "statistics.list"
        } else {
            nil
        }
        if let containerIdentifier {
            let container = element(containerIdentifier)
            if container.exists, container.isHittable {
                return container
            }
        }
        return app
    }

    func openOverallStatistics() throws {
        backToList("quiz.sidebar")
        let sidebar = try require("quiz.sidebar")
        let link = sidebar.descendants(matching: .any).matching(identifier: "quiz.statistics").firstMatch
        try reveal(link, container: sidebar, identifier: "quiz.statistics")
        link.tap()
    }

    func openSessionStatistics() throws {
        let session = try require("quiz.session")
        let button = session.buttons["quiz.statistics"]
        try reveal(button, container: session, identifier: "quiz.statistics")
        button.tap()
    }

    func expectValue(_ identifier: String, _ expected: String) throws {
        let field = try require(identifier)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected),
            object: field
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            "\(identifier): expected value \(expected), actual \(String(describing: field.value))"
        )
    }

    func expectText(_ identifier: String, _ expected: String) throws {
        let text = try require(identifier)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected),
            object: text
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            "\(identifier): expected text \(expected), actual \(text.label)"
        )
    }

    func expectCounts(_ identifier: String, asked: Int, correct: Int) throws {
        let text = try require(identifier).label
        let counts = text.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(Array(counts.prefix(2)), [asked, correct], text)
        XCTAssertFalse(text.contains("quiz.stats.message"))
    }

    func assertNoLocalizationKeys() {
        let domains = "tab|nav|common|converter|allSystems|calculator|quiz|help|support|privacy|input|error"
            + "|mainSystems|decimalToAll"
        let pattern = "(?:^|\\n)(?:\(domains))\\."
        for text in app.staticTexts.allElementsBoundByIndex where text.exists && text.isHittable {
            XCTAssertNil(text.label.range(of: pattern, options: .regularExpression), text.label)
        }
    }

    func capture(_ language: UITestLanguage, screen: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(language.rawValue)-\(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
        auditCapturedScreen(language, screen: screen)
    }

    private func auditCapturedScreen(_ language: UITestLanguage, screen: String) {
        let forcedAXSize = app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXXXL")
        let types: XCUIAccessibilityAuditType = forcedAXSize ? .all.subtracting(.dynamicType) : .all
        let knownMessage = "Dynamic Type font sizes are partially unsupported"
        var currentIssueIsMeasuredToolFailure = false
        var unexpectedIssues: [String] = []
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        options.isEnabled = !forcedAXSize
        options.issueMatcher = {
            currentIssueIsMeasuredToolFailure && $0.compactDescription == knownMessage
        }
        do {
            let previousContinuation = continueAfterFailure
            continueAfterFailure = true
            defer { continueAfterFailure = previousContinuation }
            XCTAssertNoThrow(try XCTExpectFailure(
                "Native audit flags measured Settings/ResultRow/result-base bindings despite about 3x glyph growth; "
                    + "see HeaderDynamicTypeTests",
                options: options
            ) {
                XCTAssertNoThrow(try app.performAccessibilityAudit(for: types) { issue in
                    currentIssueIsMeasuredToolFailure = !forcedAXSize
                        && issue.auditType == .dynamicType
                        && issue.compactDescription == knownMessage
                        && issue.element?.exists == true
                        && Self.measuredDynamicTypeBindings.contains(issue.element?.identifier ?? "")
                    self.attachAuditIssue(issue, language: language, screen: screen)
                    if !currentIssueIsMeasuredToolFailure {
                        unexpectedIssues.append(issue.compactDescription)
                    }
                    return false
                })
            })
        }
        XCTAssertTrue(
            unexpectedIssues.isEmpty,
            "Unexpected accessibility issues in \(language.rawValue)-\(screen): \(unexpectedIssues.joined(separator: "; "))"
        )
    }

    private func attachAuditIssue(_ issue: XCUIAccessibilityAuditIssue, language: UITestLanguage, screen: String) {
        let element = issue.element
        let description = element?.exists == true ? element?.debugDescription : nil
        let detail = "\(issue.compactDescription)\n\(issue.detailedDescription)\nElement: \(description ?? "unavailable")"
        let attachment = XCTAttachment(string: detail)
        attachment.name = "\(language.rawValue)-\(screen)-accessibility-issue"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func markWorkflowCompleted(_ language: UITestLanguage, largestText: Bool = false, smoke: Bool = false) {
        completedEndToEndWorkflow = true
        let variant = smoke ? "navigation-smoke" : largestText ? "AX5-layout" : "normal-end-to-end"
        let scope = smoke
            ? "All five tabs, Help presentation/dismissal, localized Support explanation, "
                + "and a displayed tip price returned."
            : "Converter, arbitrary-base, calculator, quiz, statistics, Support retry, "
                + "and nine-page Help workflows returned."
        let attachment = XCTAttachment(string: """
        Completed locale: \(language.rawValue)
        Completed variant: \(variant)
        \(scope)
        """)
        attachment.name = "workflow-completed-\(language.rawValue)-\(variant)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func auditScrolling(
        _ language: UITestLanguage,
        screen: String,
        container: XCUIElement,
        through last: XCUIElement
    ) throws {
        var previousViewport: Data?
        for part in 0 ..< 160 {
            assertNoLocalizationKeys()
            capture(language, screen: "\(screen)-part-\(part)")
            let viewport = container.screenshot().pngRepresentation
            if previousViewport == viewport, last.exists, last.isHittable {
                return
            }
            previousViewport = viewport
            container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(
                forDuration: 0.1,
                thenDragTo: container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)),
                withVelocity: .slow,
                thenHoldForDuration: 0.1
            )
        }
        XCTFail("Scrollable screen did not reach its final element: \(screen)")
        throw UIAuditError.missingElement(screen)
    }
}
