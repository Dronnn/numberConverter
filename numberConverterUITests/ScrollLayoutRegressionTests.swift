//
//  ScrollLayoutRegressionTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testAllBasesDetailAccessibility() throws {
        launch(.english)
        try replace("converter.all.input", with: "255")
        dismissKeyboard()
        try tap("converter.all.detail")
        try expectText("base.value.2", "11111111")
        capture(.english, screen: "all-bases-detail-scroll-regression")
        app.terminate()
    }

    func testLargestTextConverterGutterScrollWithoutAudit() throws {
        try measureConverterScrollWithoutAudit(nativeSwipe: false)
    }

    func testLargestTextConverterNativeScrollWithoutAudit() throws {
        try measureConverterScrollWithoutAudit(nativeSwipe: true)
    }

    func testLargestTextConverterScrollWithAudit() throws {
        launch(.english, largeText: true)
        try replace("converter.input.10", with: "1234567890")
        dismissKeyboard()
        try auditScrolling(
            .english,
            screen: "AX-converter-audited-scroll-regression",
            container: app.collectionViews.firstMatch,
            through: element("converter.twosComplement")
        )
        app.terminate()
    }

    private func measureConverterScrollWithoutAudit(nativeSwipe: Bool) throws {
        launch(.english, largeText: true)
        try replace("converter.input.10", with: "1234567890")
        dismissKeyboard()
        let form = app.collectionViews.firstMatch
        let toggle = element("converter.twosComplement")
        var reached = false
        for step in 0 ..< 12 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "passive-AX-scroll-\(nativeSwipe ? "native" : "gutter")-\(step)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if toggle.exists {
                let frame = toggle.frame
                if !frame.isEmpty, visibleConverterFrame(form: form).contains(frame) {
                    reached = true
                    break
                }
            }
            if nativeSwipe {
                form.swipeUp(velocity: .slow)
            } else {
                form.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8)).press(
                    forDuration: 0.05,
                    thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.35)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.1
                )
            }
        }
        XCTAssertTrue(reached, "The complete Toggle row must be visible inside the form and native navigation chrome")
        app.terminate()
    }

    private func visibleConverterFrame(form: XCUIElement) -> CGRect {
        let viewport = app.frame.intersection(form.frame)
        var top = viewport.minY
        for navigationBar in app.navigationBars.allElementsBoundByIndex
            where navigationBar.exists && navigationBar.frame.intersects(viewport)
        {
            top = max(top, navigationBar.frame.maxY)
        }
        var bottom = viewport.maxY
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists, tabBar.frame.intersects(viewport) {
            bottom = min(bottom, tabBar.frame.minY)
        }
        return CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, bottom - top))
    }
}
