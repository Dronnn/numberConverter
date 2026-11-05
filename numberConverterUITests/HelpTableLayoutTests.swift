//
//  HelpTableLayoutTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

@MainActor
extension NumberConverterUITests {
    func testHelpTableRightColumnIsReachableInEveryLanguage() throws {
        capturesIncludeNativeAudit = false
        defer { capturesIncludeNativeAudit = true }
        for language in UITestLanguage.allCases {
            launch(language, largeText: true)
            try openHelp()
            try tap("help.topic.1")
            let content = try require("help.content")
            let identifier = "help.block.help.page1.table"
            let table = try require(identifier)
            try revealTableViewport(table, in: content)
            let text = table.staticTexts.firstMatch
            XCTAssertTrue(text.exists)
            XCTAssertTrue(text.label.contains("10100"), "The actual conversion table must be present")
            try revealTableRightEdge(table, text: text, in: content)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(language.rawValue)-AX-help-table-right-edge"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            try closeHelp()
            app.terminate()
        }
    }

    private func revealTableViewport(_ table: XCUIElement, in content: XCUIElement) throws {
        var previousY: CGFloat?
        var stalled = 0
        for _ in 0 ..< 160 {
            if visibleTableBounds(table, in: content).height >= 176 {
                return
            }
            let currentY = table.frame.minY
            stalled = previousY.map { abs(currentY - $0) < 1 } == true ? stalled + 1 : 0
            if stalled >= 3 {
                break
            }
            previousY = currentY
            if table.frame.maxY < content.frame.minY {
                content.swipeDown()
            } else {
                content.swipeUp()
            }
        }
        let geometry = XCTAttachment(string: """
        App: \(app.frame)
        Content: \(content.frame)
        Table: \(table.frame)
        Visible: \(visibleTableBounds(table, in: content))
        Navigation: \(app.navigationBars.allElementsBoundByIndex.map { "\($0.identifier): \($0.frame), hittable \($0.isHittable)" })
        """)
        geometry.name = "help-table-viewport-failure-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "help-table-viewport-failure-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTFail("A visible table viewport must be available for a horizontal gesture")
        throw UIAuditError.missingElement("help.table.viewport")
    }

    private func revealTableRightEdge(
        _ table: XCUIElement,
        text: XCUIElement,
        in content: XCUIElement
    ) throws {
        let initial = text.frame
        let viewport = visibleTableBounds(table, in: content)
        XCTAssertFalse(viewport.isEmpty)
        if initial.width <= viewport.width + 1 {
            XCTAssertGreaterThanOrEqual(initial.minX, viewport.minX - 1)
            XCTAssertLessThanOrEqual(initial.maxX, viewport.maxX + 1)
            return
        }
        for _ in 0 ..< 12 {
            if text.frame.maxX <= viewport.maxX + 1 {
                break
            }
            let inset = min(22, viewport.width / 4)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(
                dx: viewport.maxX - inset - app.frame.minX,
                dy: viewport.midY - app.frame.minY
            ))
            let end = origin.withOffset(CGVector(
                dx: viewport.minX + inset - app.frame.minX,
                dy: viewport.midY - app.frame.minY
            ))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertLessThan(text.frame.minX, initial.minX - 1, "The horizontal table must actually move")
        XCTAssertLessThanOrEqual(text.frame.maxX, viewport.maxX + 1, "The final table column must fit in the viewport")
    }

    private func visibleTableBounds(_ table: XCUIElement, in content: XCUIElement) -> CGRect {
        var bounds = table.frame.intersection(content.frame).intersection(app.frame)
        // the iPad resize grip occupies the bottom corner. keep the test's
        // horizontal pan inside the document, away from native window chrome.
        bounds = bounds.intersection(CGRect(
            x: app.frame.minX,
            y: app.frame.minY,
            width: app.frame.width,
            height: max(0, app.frame.height - 44)
        ))
        let navigationBottom = app.navigationBars.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable && $0.frame.intersects(bounds) }
            .map(\.frame.maxY).max() ?? bounds.minY
        if navigationBottom > bounds.minY {
            let bottom = bounds.maxY
            bounds.origin.y = navigationBottom
            bounds.size.height = max(0, bottom - navigationBottom)
        }
        return bounds
    }
}
