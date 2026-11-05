//
//  ContentCorrectionLayoutTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

@MainActor
extension NumberConverterUITests {
    func testCorrectedRussianHelpAndFeedbackText() throws {
        executionTimeAllowance = 1_800
        capturesIncludeNativeAudit = false
        defer { capturesIncludeNativeAudit = true }
        for largest in [false, true] {
            launch(.russian, largeText: largest)
            try openHelp()
            for (page, checks) in correctedRussianHelpPages {
                try tap("help.topic.\(page)")
                for (key, fragment) in checks {
                    let block = try require("help.block.\(key)")
                    try inspectChangedParagraph(
                        .russian,
                        text: block,
                        fragment: fragment,
                        content: require("help.content"),
                        name: "\(key)-\(largest ? "AX5" : "normal")"
                    )
                }
                backToList("help.sidebar")
            }
            try closeHelp()
            try correctedRussianFeedback(largest: largest)
            app.terminate()
        }
    }

    private var correctedRussianHelpPages: [(Int, [(String, String)])] {
        [
            (1, [("help.page1.p9", "Итак, в нашей всем привычной десятичной системе")]),
            (2, [
                ("help.page2.p8", "частного, которое меньше основания"),
                ("help.page2.p10", "Запишем последнее частное, а за ним остаток: 23.")
            ]),
            (6, [("help.page6.p7", "0 - 1: занимаем из старшего разряда и записываем в результат 1.")]),
            (7, [("help.page7.p7", "Каждую триаду по таблице заменяем")]),
            (8, [
                ("help.page8.p3", "Преобразуем отрицательное число −5 в дополнительный код."),
                ("help.page8.p4", "Возьмём число пять, записанное"),
                ("help.page8.p8", "Мы получили число -5, записанное")
            ])
        ]
    }

    private func correctedRussianFeedback(largest: Bool) throws {
        try selectTab(3)
        try tap("quiz.category.decimalInt")
        try replace("quiz.answer", with: "?")
        dismissKeyboard()
        try tap("quiz.check")
        let feedback = app.alerts.firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        let message = feedback.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        XCTAssertTrue(message.contains("Ваш ответ неверный"), message)
        capture(.russian, screen: "corrected-wrong-feedback-\(largest ? "AX5" : "normal")")
    }

    func testCorrectedSpanishPrivacyOffloadingText() throws {
        executionTimeAllowance = 1_800
        capturesIncludeNativeAudit = false
        defer { capturesIncludeNativeAudit = true }
        for largest in [false, true] {
            launch(.spanish, largeText: largest)
            try openHelp()
            try tap("help.privacy")
            let section = try require("privacy.section.5")
            let text = try XCTUnwrap(section.staticTexts.allElementsBoundByIndex.first {
                $0.label.contains("Puedes restablecer los contadores")
            })
            try inspectChangedParagraph(
                .spanish,
                text: text,
                fragment: "la desinstalación conservando los datos",
                content: require("privacy.content"),
                name: "privacy.section.5-\(largest ? "AX5" : "normal")"
            )
            app.terminate()
        }
    }

    private func inspectChangedParagraph(
        _ language: UITestLanguage,
        text: XCUIElement,
        fragment: String,
        content: XCUIElement,
        name: String
    ) throws {
        XCTAssertTrue(text.exists)
        XCTAssertTrue(text.label.contains(fragment), text.label)
        try walkChangedParagraph(language, text: text, content: content, name: name)
        let attachment = XCTAttachment(string: """
        Corrected semantic fragment: \(fragment)
        Complete actual accessibility text: \(text.label)
        Actual paragraph frame: \(text.frame); content frame: \(content.frame).
        Contiguous actual paragraph bounds from the beginning through the final line were visible in captured viewports.
        Scope: complete accessibility text plus viewport coverage, not full-paragraph OCR or native-audit acceptance.
        """)
        attachment.name = "corrected-content-\(name)-actual-text"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func walkChangedParagraph(
        _ language: UITestLanguage,
        text: XCUIElement,
        content: XCUIElement,
        name: String
    ) throws {
        var coveredThrough: CGFloat = 0
        var previousTop: CGFloat?
        var stalled = 0
        for part in 0 ..< 160 {
            let frame = text.frame
            let viewport = changedParagraphViewport(content)
            XCTAssertGreaterThan(viewport.height, 80)
            let lower = max(0, viewport.minY - frame.minY)
            let upper = min(frame.height, viewport.maxY - frame.minY)
            if upper > lower, lower <= coveredThrough + 1 {
                XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - 1)
                XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + 1)
                capture(language, screen: "corrected-content-\(name)-part-\(part)")
                coveredThrough = max(coveredThrough, upper)
                if coveredThrough >= frame.height - 1 {
                    return
                }
            }
            stalled = previousTop.map { abs(frame.minY - $0) < 1 } == true ? stalled + 1 : 0
            guard stalled < 3 else { break }
            previousTop = frame.minY
            scrollChangedParagraph(frame: frame, viewport: viewport, headSeen: coveredThrough > 0)
        }
        let report =
            XCTAttachment(
                string: "Paragraph:\(text.frame); viewport:\(changedParagraphViewport(content)); contiguous covered pixels:\(coveredThrough)"
            )
        report.name = "corrected-content-\(name)-incomplete-viewport"
        report.lifetime = .keepAlways
        add(report)
        XCTFail("The changed paragraph must be captured continuously from its beginning through its final line")
        throw UIAuditError.missingElement(name)
    }

    private func changedParagraphViewport(_ content: XCUIElement) -> CGRect {
        var viewport = content.frame.intersection(app.frame)
        let top = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable && $0.frame.intersects(viewport) }
            .map(\.frame.maxY).max() ?? viewport.minY
        if top > viewport.minY {
            let bottom = viewport.maxY
            viewport.origin.y = top
            viewport.size.height = max(0, bottom - top)
        }
        return viewport
    }

    private func scrollChangedParagraph(frame: CGRect, viewport: CGRect, headSeen: Bool) {
        let backwards = !headSeen && frame.minY < viewport.minY - 1
        let gap = backwards ? viewport.minY - frame.minY + 12 : frame.maxY - viewport.maxY + 12
        let distance = min(viewport.height * 0.55, max(20, gap))
        let startY = backwards ? viewport.minY + 24 : viewport.maxY - 24
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: startY - app.frame.minY))
        let end = origin.withOffset(CGVector(
            dx: viewport.midX - app.frame.minX,
            dy: startY - app.frame.minY + (backwards ? distance : -distance)
        ))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }
}
