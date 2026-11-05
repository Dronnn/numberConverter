//
//  NativeAlertDynamicTypeTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func isMeasuredStatisticsAlertIssue(_ issue: XCUIAccessibilityAuditIssue, language: UITestLanguage) -> Bool {
        guard
            language == .english, issue.auditType == .dynamicType,
            issue.compactDescription == "Dynamic Type font sizes are partially unsupported",
            let element = issue.element, element.exists, element.elementType == .staticText
        else { return false }
        let alert = app.alerts.firstMatch
        guard alert.exists, alert.frame.contains(element.frame) else { return false }
        let label = element.label
        let isMessage = label.range(
            of: "^Questions asked: [0-9]+\\s+Correct answers: [0-9]+$", options: .regularExpression
        ) != nil
        guard label == "Statistics" || isMessage else { return false }
        return alert.staticTexts.allElementsBoundByIndex.contains {
            $0.label == label && $0.frame == element.frame
        }
    }

    func testNativeStatisticsAlertScalesAtLargestText() throws {
        defer { app.terminate() }
        let normal = try measureNativeStatisticsAlert(category: "UICTContentSizeCategoryL", name: "normal")
        let largest = try measureNativeStatisticsAlert(
            category: "UICTContentSizeCategoryAccessibilityXXXL", name: "AX5"
        )

        for (name, initial, enlarged) in [
            ("title", normal.title, largest.title),
            ("message", normal.message, largest.message)
        ] {
            let report = """
            Native Statistics alert \(name)
            normal frame: \(initial.frame), glyph height: \(initial.glyphHeight) pixels
            AX5 frame: \(enlarged.frame), glyph height: \(enlarged.glyphHeight) pixels
            frame height growth: \(enlarged.frame.height / initial.frame.height)
            glyph height growth: \(enlarged.glyphHeight / initial.glyphHeight)
            normal complete message: \(normal.messageText)
            AX5 complete message: \(largest.messageText)
            """
            let attachment = XCTAttachment(string: report)
            attachment.name = "native-statistics-alert-\(name)-dynamic-type-measurements"
            attachment.lifetime = .keepAlways
            add(attachment)

            XCTAssertGreaterThan(enlarged.frame.height, initial.frame.height * 1.25, report)
            XCTAssertGreaterThan(enlarged.glyphHeight, initial.glyphHeight * 1.4, report)
        }
    }

    private func measureNativeStatisticsAlert(
        category: String,
        name: String
    ) throws -> (title: TextScaleMeasurement, message: TextScaleMeasurement, messageText: String) {
        launchTextMeasurement(category: category)
        try selectTab(3)
        try tap("quiz.category.binaryInt")
        try openSessionStatistics()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let title = alert.staticTexts["Statistics"].firstMatch
        let message = alert.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Questions asked:")
        ).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Statistics")
        let messageText = message.label
        XCTAssertTrue(messageText.contains("Questions asked:"))
        XCTAssertTrue(messageText.contains("Correct answers:"))

        let screenshot = XCTAttachment(screenshot: alert.screenshot())
        screenshot.name = "native-statistics-alert-\(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        return try (
            title: measureText(title, expectedText: "Statistics", name: "native-statistics-title-\(name)"),
            message: measureText(message, expectedText: messageText, name: "native-statistics-message-\(name)"),
            messageText: messageText
        )
    }
}
