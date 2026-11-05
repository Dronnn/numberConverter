//
//  UIAuditSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

enum UIAuditError: Error {
    case missingElement(String)
    case missingCorrectAnswer
}

@MainActor
extension NumberConverterUITests {
    var collectsAllAuditIssues: Bool {
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
        if app.state != .notRunning {
            app.terminate()
        }
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
        let target = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        if
            identifier.hasPrefix("app.tab."), !target.exists,
            let nativeControl = fallbackNativeTabControl(identifier: identifier)
        {
            return nativeControl
        }
        return target
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
        let input = try visibleEditableInput(identifier)
        let field = input.element
        let baseFields = [
            "allSystems.sourceBase", "allSystems.targetBase", "calculator.baseA", "calculator.baseB",
            "calculator.resultBase"
        ]
        if
            baseFields.contains(identifier),
            !["command", "touch"].contains(ProcessInfo.processInfo.environment["UI_PAD_REPLACEMENT"] ?? "")
        {
            // measure untouched digits before the insertion caret can merge
            // with the first glyph and obscure its OCR bounding box.
            try selectRenderedDigits(field, expected: XCTUnwrap(field.value as? String), name: identifier)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
            app.typeText(text)
            try expectValue(identifier, text)
            return
        }
        try tapEditableInput(input, identifier: identifier)
        let keyboardAppeared = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        if !keyboardAppeared {
            attachInputFocusState(identifier, stage: "no-keyboard-after-observed-tap")
        }
        XCTAssertTrue(keyboardAppeared, "No keyboard after focusing \(identifier)")
        if
            UIDevice.current.userInterfaceIdiom == .pad,
            ProcessInfo.processInfo.environment["UI_PAD_REPLACEMENT"] != "command"
        {
            // hardware-key events change iPad keyboard mode. base fields use
            // actual caret/delete events and prove the draft cleared first.
            if baseFields.contains(identifier) {
                try clearPadBaseField(field, identifier: identifier)
                app.typeText(text)
            } else {
                field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
                app.typeText(text)
            }
            return
        }
        // select all through the public keyboard API, independent of the caret
        // position chosen by native tap or the localized edit-menu labels.
        try replaceFocusedInput(field, identifier: identifier, with: text)
    }

    func visibleViewport(in container: XCUIElement, tabBarAffectsViewport: Bool = true) -> CGRect {
        let viewport = container.frame.intersection(app.frame)
        let navigationBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.intersects(viewport) }
            .map(\.frame.maxY).max() ?? viewport.minY
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBarAffectsViewport && tabBar.exists && tabBar.isHittable
            ? min(viewport.maxY, tabBar.frame.minY)
            : viewport.maxY
        let top = max(viewport.minY, navigationBottom)
        return CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, bottom - top))
    }

    private func clearPadBaseField(_ field: XCUIElement, identifier: String) throws {
        let before = field.debugDescription
        let count = (field.value as? String ?? "").count
        let placeholder = field.placeholderValue ?? ""
        field.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -min(6, field.frame.width / 4), dy: 0)).tap()
        if count > 0 {
            let numberPad = app.descendants(matching: .any)
                .matching(identifier: "UIKeyboardLayoutStar Preview").firstMatch
            if numberPad.exists {
                let delete = numberPad.keys.matching(NSPredicate(format: "label ==[c] %@", "Delete")).firstMatch
                XCTAssertTrue(
                    delete.exists && delete.isHittable,
                    "The observed native number-pad Delete key must be reachable"
                )
                for _ in 0 ..< count {
                    delete.tap()
                }
            } else {
                app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
            }
        }
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let value = field.value as? String ?? ""
            return value.isEmpty || value == placeholder
        }, object: field)
        let result = XCTWaiter.wait(for: [cleared], timeout: 3)
        if result != .completed {
            let report = XCTAttachment(string: "Before native deletes: \(before)\nAfter: \(field.debugDescription)")
            report.name = "\(identifier)-native-clear-failed"
            report.lifetime = .keepAlways
            add(report)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(identifier)-native-clear-failed-screen"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertEqual(result, .completed, "The focused base draft must be empty before replacement: \(identifier)")
    }

    func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        if !tapVisibleKeyboardDone() {
            app.swipeDown()
        }
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "keyboards.count == 0"), object: app
        )
        var result = XCTWaiter.wait(for: [dismissed], timeout: 3)
        if result != .completed {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "keyboard-dismissal-failed-screen"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let report = XCTAttachment(string: app.keyboards.firstMatch.debugDescription)
            report.name = "keyboard-dismissal-failed-hierarchy"
            report.lifetime = .keepAlways
            add(report)
            scrollToDismissKeyboard()
            let afterScroll = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "keyboards.count == 0"), object: app
            )
            result = XCTWaiter.wait(for: [afterScroll], timeout: 3)
        }
        XCTAssertEqual(result, .completed, "Keyboard did not dismiss")
    }

    private func scrollToDismissKeyboard() {
        guard let form = app.collectionViews.allElementsBoundByIndex.last(where: {
            $0.textFields.firstMatch.exists && $0.frame.intersects(app.frame)
        }) else { return }
        let viewport = visibleViewport(in: form)
        let keyboardTop = app.keyboards.allElementsBoundByIndex
            .filter { $0.frame.intersects(app.frame) }.map(\.frame.minY).min() ?? viewport.maxY
        let bottom = min(viewport.maxY, keyboardTop)
        guard bottom - viewport.minY >= 44 else { return }
        let start = CGPoint(x: viewport.midX, y: (viewport.minY + bottom) / 2)
        let end = CGPoint(x: start.x, y: min(app.frame.maxY - 12, bottom + 180))
        let origin = app.coordinate(withNormalizedOffset: .zero)
        XCTContext.runActivity(named: "Generic dismissal via the Form's native interactive scroll gesture") { _ in
            origin.withOffset(CGVector(dx: start.x - app.frame.minX, dy: start.y - app.frame.minY)).press(
                forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: end.x - app.frame.minX, dy: end.y - app.frame.minY))
            )
        }
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
        let includesTabBar = !description.hasPrefix("help.") && !description.hasPrefix("privacy.")
        let isToolbarControl = ["app.help", "help.close", "quiz.finish", "keyboard.done"].contains(description)
        let isVisible = {
            guard target.exists, target.isHittable else { return false }
            let viewport = isToolbarControl
                ? self.app.frame
                : self.visibleViewport(
                    in: scrollView, tabBarAffectsViewport: includesTabBar
                )
            let visible = target.frame.intersection(viewport)
            return visible.width >= min(44, target.frame.width)
                && visible.height >= min(44, target.frame.height)
        }
        let initialViewport = visibleViewport(in: scrollView, tabBarAffectsViewport: includesTabBar)
        let startsUpward = target.exists && target.frame.minY < initialViewport.minY ? false : upward
        for direction in [startsUpward, !startsUpward] {
            for _ in 0 ..< attempts {
                if isVisible() {
                    return
                }
                if direction {
                    scrollView.swipeUp()
                } else {
                    scrollView.swipeDown()
                }
            }
        }
        guard isVisible() else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(description)-unreachable-screen"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTFail("UI element is not reachable: \(description)")
            throw UIAuditError.missingElement(description)
        }
    }

    func back() {
        // iOS 27 can expose the native back item as legacy Other while its
        // modern role is Button. Its observed native identifier stays stable.
        let nativeBack = app.descendants(matching: .any).matching(identifier: "BackButton")
        if nativeBack.firstMatch.exists {
            let visible = nativeBack.allElementsBoundByIndex.filter(\.isHittable)
            XCTAssertEqual(visible.count, 1, "Exactly one native back control must be available")
            guard let back = visible.first else { return }
            back.tap()
            return
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func backToConverter(_ language: UITestLanguage) {
        back()
        let destination = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let titles = self.app.navigationBars.allElementsBoundByIndex
                .filter { $0.exists && $0.frame.intersects(self.app.frame) }.map(\.identifier)
            return titles == [language.converterTitle]
        }, object: app)
        XCTAssertEqual(
            XCTWaiter.wait(for: [destination], timeout: 5),
            .completed,
            "The actual Converter navigation destination must finish before further input"
        )
    }

    func backToList(_ sidebarIdentifier: String) {
        let sidebar = element(sidebarIdentifier)
        if sidebar.exists, sidebar.isHittable || hasVisibleSidebarAction(sidebar, identifier: sidebarIdentifier) {
            return
        }
        back()
    }

    private func hasVisibleSidebarAction(_ sidebar: XCUIElement, identifier: String) -> Bool {
        let prefix = identifier == "quiz.sidebar" ? "quiz.category." : "help.topic."
        let viewport = visibleViewport(in: sidebar, tabBarAffectsViewport: identifier != "help.sidebar")
        return sidebar.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .allElementsBoundByIndex.contains { action in
                guard action.isHittable else { return false }
                let visible = action.frame.intersection(viewport)
                return visible.width >= min(44, action.frame.width)
                    && visible.height >= min(44, action.frame.height)
            }
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

    func auditCapturedScreen(
        _ language: UITestLanguage,
        screen: String,
        auditTypes: XCUIAccessibilityAuditType? = nil
    ) {
        let forcedAXSize = app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXXXL")
        let types: XCUIAccessibilityAuditType = auditTypes ?? (forcedAXSize ? .all.subtracting(.dynamicType) : .all)
        let knownMessage = "Dynamic Type font sizes are partially unsupported"
        var currentIssueIsMeasuredToolFailure = false
        var unexpectedIssues: [String] = []
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        options.issueMatcher = {
            currentIssueIsMeasuredToolFailure
                && [knownMessage, "Contrast failed"].contains($0.compactDescription)
        }
        do {
            let previousContinuation = continueAfterFailure
            continueAfterFailure = true
            defer { continueAfterFailure = previousContinuation }
            XCTAssertNoThrow(try XCTExpectFailure(
                "Exact native audit findings have independent rendered glyph or pixel evidence; "
                    + "see HeaderDynamicTypeTests, NativeAlertDynamicTypeTests and NativeTextContrastTests",
                options: options
            ) {
                XCTAssertNoThrow(try app.performAccessibilityAudit(for: types) { issue in
                    currentIssueIsMeasuredToolFailure = !forcedAXSize
                        && issue.auditType == .dynamicType
                        && issue.compactDescription == knownMessage
                        && issue.element?.exists == true
                        && Self.measuredDynamicTypeBindings.contains(issue.element?.identifier ?? "")
                    currentIssueIsMeasuredToolFailure = currentIssueIsMeasuredToolFailure
                        || self.isMeasuredSupportContrastIssue(issue)
                        || self.isMeasuredFinishContrastIssue(issue, language: language)
                        || (!forcedAXSize && self.isMeasuredInvalidNumberErrorIssue(issue, language: language))
                        || (!forcedAXSize && self.isMeasuredStatisticsAlertIssue(issue, language: language))
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
        through last: XCUIElement,
        tabBarAffectsViewport: Bool = true
    ) throws {
        var previousPosition: ScrollAnchor?
        var stalledGestures = 0
        for part in 0 ..< 160 {
            assertNoLocalizationKeys()
            let beforeAudit = capturesIncludeNativeAudit ? scrollObservation(container, target: last) : ""
            let auditAnchor = capturesIncludeNativeAudit
                ? try captureNativeAuditScrollAnchor(
                    container: container, tabBarAffectsViewport: tabBarAffectsViewport, name: "\(screen)-part-\(part)"
                )
                : nil
            capture(language, screen: "\(screen)-part-\(part)")
            if capturesIncludeNativeAudit {
                try observeNativeAuditScroll(
                    container,
                    target: last,
                    beforeAudit: beforeAudit,
                    anchor: auditAnchor,
                    tabBarAffectsViewport: tabBarAffectsViewport,
                    name: "\(screen)-part-\(part)"
                )
            }
            let position = scrollAnchor(in: container, target: last)
            let moved = didScroll(from: previousPosition, to: position, height: container.frame.height)
            stalledGestures = moved ? 0 : stalledGestures + 1
            if !moved, isEndVisible(last, in: container, tabBarAffectsViewport: tabBarAffectsViewport) {
                return
            }
            guard stalledGestures < 3 else {
                attachScrollFailure(screen, container: container, target: last)
                XCTFail("Scroll gestures did not advance toward the final element: \(screen)")
                throw UIAuditError.missingElement(screen)
            }
            previousPosition = position
            container.swipeUp(velocity: .slow)
        }
        attachScrollFailure(screen, container: container, target: last)
        XCTFail("Scrollable screen did not reach its final element: \(screen)")
        throw UIAuditError.missingElement(screen)
    }

    private func observeNativeAuditScroll(
        _ container: XCUIElement,
        target: XCUIElement,
        beforeAudit: String,
        anchor: NativeAuditScrollAnchor?,
        tabBarAffectsViewport: Bool,
        name: String
    ) throws {
        let report = XCTAttachment(string: """
        Before native audit: \(beforeAudit)
        After native audit: \(scrollObservation(container, target: target))
        """)
        report.name = "\(name)-post-audit-scroll-geometry"
        report.lifetime = .keepAlways
        add(report)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(name)-post-audit-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        guard let anchor else {
            XCTFail("Native audit traversal has no validated noninteractive viewport anchor")
            throw UIAuditError.missingElement(name)
        }
        try restoreAuditScrollPosition(
            container: container,
            anchor: anchor,
            tabBarAffectsViewport: tabBarAffectsViewport,
            name: name
        )
    }

    func attachScrollFailure(_ screen: String, container: XCUIElement, target: XCUIElement) {
        let report = XCTAttachment(string: """
        Screen: \(screen); app state: \(app.state.rawValue); app frame: \(app.frame).
        Container exists: \(container.exists); frame: \(container.exists ? String(describing: container.frame) : "unavailable").
        Target exists: \(target.exists); frame: \(target.exists ? String(describing: target.frame) : "unavailable").
        Fresh native hierarchy including content, target and present chrome:
        \(app.debugDescription)
        """)
        report.name = "\(screen)-scroll-failure-geometry"
        report.lifetime = .keepAlways
        add(report)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(screen)-scroll-failure-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func scrollAnchor(in container: XCUIElement, target: XCUIElement) -> ScrollAnchor? {
        if target.exists, !target.frame.isEmpty {
            return ScrollAnchor(identity: "last element", minY: target.frame.minY)
        }
        let text = container.staticTexts.firstMatch
        guard text.exists else { return nil }
        return ScrollAnchor(identity: text.label, minY: text.frame.minY)
    }

    private func isEndVisible(
        _ target: XCUIElement,
        in container: XCUIElement,
        tabBarAffectsViewport: Bool
    ) -> Bool {
        guard target.exists, !target.frame.isEmpty else { return false }
        var bottom = container.frame.maxY
        let tabBar = app.tabBars.firstMatch
        if tabBarAffectsViewport, tabBar.exists, tabBar.isHittable {
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
