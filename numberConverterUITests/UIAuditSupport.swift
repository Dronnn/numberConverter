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
    private var collectsAllAuditIssues: Bool {
        ProcessInfo.processInfo.environment["UI_AUDIT_COLLECT_ALL"] == "1"
    }

    private static let measuredDynamicTypeBindings = [
        "converter.header.settings", "allSystems.resultLabel", "allSystems.result",
        "calculator.resultLabel", "calculator.result", "calculator.resultBaseLabel", "quiz.statisticsLabel"
    ]

    static let tabIdentifiers = ["converter", "allSystems", "calculator", "quiz", "support"]

    func launch(_ language: UITestLanguage, largeText: Bool = false, tipStoreState: String? = "available") {
        let auditMode = capturesIncludeNativeAudit
            ? collectsAllAuditIssues
                ? "diagnostic full traversal"
                : "strict native-audit acceptance"
            : "functional screenshots; native audits run separately"
        XCTContext.runActivity(named: "UI audit mode: \(auditMode)") { _ in }
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = [
            "-AppleLanguages", "(\(language.rawValue))",
            "-AppleLocale", language.region
        ]
        if let tipStoreState {
            app.launchArguments += ["-ui-tip-store", tipStoreState]
        }
        if largeText || !capturesIncludeNativeAudit {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"
            ]
        }
        app.launch()
        XCTAssertTrue(element("app.tab.converter").waitForExistence(timeout: 10))
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    func require(_ identifier: String) throws -> XCUIElement {
        let result = element(identifier)
        guard result.exists || result.waitForExistence(timeout: 5) else {
            XCTFail("Missing UI element: \(identifier)")
            throw UIAuditError.missingElement(identifier)
        }
        return result
    }

    func tap(_ identifier: String) throws {
        let target = element(identifier)
        if !target.exists {
            _ = target.waitForExistence(timeout: 2)
        }
        try reveal(target, identifier: identifier)
        if target.elementType == .switch {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        } else {
            target.tap()
        }
    }

    func selectTab(_ index: Int) throws {
        dismissKeyboard()
        try verifyNativeTabInventory()
        try nativeTabButton(at: index).tap()
        assertNoLocalizationKeys()
    }

    func expectTabLabels(_ language: UITestLanguage) throws {
        try verifyNativeTabInventory(language: language)
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
        let field = element(identifier)
        try reveal(field, identifier: identifier)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "No keyboard after focusing \(identifier)")
        // select all through the public keyboard API, independent of the caret
        // position chosen by native tap or the localized edit-menu labels.
        field.typeKey("a", modifierFlags: .command)
        field.typeText(XCUIKeyboardKey.delete.rawValue + text)
    }

    func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let done = app.toolbars.buttons["keyboard.done"]
        if done.waitForExistence(timeout: 1), done.frame.intersects(app.frame), !done.frame.isEmpty {
            // native hit testing sometimes rejects this visible accessory
            // button's activation point; tap its observed frame and verify dismissal.
            done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            app.swipeDown()
        }
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "keyboards.count == 0"), object: app
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
        if capturesIncludeNativeAudit {
            auditCapturedScreen(language, screen: screen)
        }
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
                "Native audit flags measured Settings/ResultRow/result-base/quiz-statistics bindings despite "
                    + "about 3x glyph growth; "
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
        assertNoUnexpectedAuditIssues(unexpectedIssues, context: "\(language.rawValue)-\(screen)")
    }

    private func assertNoUnexpectedAuditIssues(_ issues: [String], context: String) {
        let previousContinuation = continueAfterFailure
        if collectsAllAuditIssues {
            continueAfterFailure = true
        }
        defer { continueAfterFailure = previousContinuation }
        XCTAssertTrue(
            issues.isEmpty,
            "Unexpected accessibility issues in \(context): \(issues.joined(separator: "; "))"
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
        let mode = capturesIncludeNativeAudit
            ? collectsAllAuditIssues
                ? "diagnostic-full-traversal"
                : "strict-native-audit-acceptance"
            : "functional-controls-and-passive-layout; native audits run separately"
        let attachment = XCTAttachment(string: """
        Completed locale: \(language.rawValue)
        Completed variant: \(variant)
        Mode: \(mode)
        \(scope)
        """)
        let prefix = collectsAllAuditIssues ? "diagnostic-" : capturesIncludeNativeAudit ? "" : "functional-"
        attachment.name = "\(prefix)workflow-completed-\(language.rawValue)-\(variant)"
        attachment.lifetime = .keepAlways
        add(attachment)
        if collectsAllAuditIssues {
            XCTFail("Diagnostic full traversal requires a strict rerun before acceptance")
        }
    }

    func auditScrolling(
        _ language: UITestLanguage,
        screen: String,
        container: XCUIElement,
        through last: XCUIElement
    ) throws {
        var previousPosition: ScrollAnchor?
        var stalledGestures = 0
        for part in 0 ..< 160 {
            assertNoLocalizationKeys()
            capture(language, screen: "\(screen)-part-\(part)")
            let position = scrollAnchor(in: container, target: last)
            let moved = didScroll(from: previousPosition, to: position, height: container.frame.height)
            stalledGestures = moved ? 0 : stalledGestures + 1
            if !moved, isEndVisible(last, in: container) {
                return
            }
            guard stalledGestures < 3 else {
                XCTFail("Scroll gestures did not advance toward the final element: \(screen)")
                throw UIAuditError.missingElement(screen)
            }
            previousPosition = position
            container.swipeUp(velocity: .slow)
        }
        XCTFail("Scrollable screen did not reach its final element: \(screen)")
        throw UIAuditError.missingElement(screen)
    }

    private func scrollAnchor(in container: XCUIElement, target: XCUIElement) -> ScrollAnchor? {
        if target.exists, !target.frame.isEmpty {
            return ScrollAnchor(identity: "last element", minY: target.frame.minY)
        }
        let text = container.staticTexts.firstMatch
        guard text.exists else { return nil }
        return ScrollAnchor(identity: text.label, minY: text.frame.minY)
    }

    private func isEndVisible(_ target: XCUIElement, in container: XCUIElement) -> Bool {
        guard target.exists, !target.frame.isEmpty else { return false }
        var bottom = container.frame.maxY
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists, tabBar.isHittable {
            bottom = min(bottom, tabBar.frame.minY)
        }
        let navigationBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.intersects(container.frame) }
            .map(\.frame.maxY).max() ?? container.frame.minY
        let top = max(container.frame.minY, navigationBottom)
        return target.frame.maxY <= bottom && target.frame.maxY >= top
    }

    private func didScroll(from previous: ScrollAnchor?, to current: ScrollAnchor?, height: CGFloat) -> Bool {
        guard let previous, let current else { return true }
        return previous.identity != current.identity || abs(previous.minY - current.minY) > height * 0.01
    }
}

private struct ScrollAnchor {
    let identity: String
    let minY: CGFloat
}
